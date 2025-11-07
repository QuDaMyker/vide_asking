//
//  CacheManager.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Multi-layer caching with memory and disk storage
//

import Foundation
import CryptoKit

// MARK: - Cache Manager Protocol

protocol CacheManager {
    func cache<T: Encodable>(_ object: T, forKey key: String, expiration: CacheExpiration)
    func retrieve<T: Decodable>(forKey key: String, as type: T.Type) -> T?
    func remove(forKey key: String)
    func clear()
    func clearExpired()
}

// MARK: - Cache Expiration

enum CacheExpiration {
    case never
    case seconds(TimeInterval)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case custom(Date)
    
    var expirationDate: Date {
        switch self {
        case .never:
            return Date.distantFuture
        case .seconds(let seconds):
            return Date().addingTimeInterval(seconds)
        case .minutes(let minutes):
            return Date().addingTimeInterval(TimeInterval(minutes * 60))
        case .hours(let hours):
            return Date().addingTimeInterval(TimeInterval(hours * 3600))
        case .days(let days):
            return Date().addingTimeInterval(TimeInterval(days * 86400))
        case .custom(let date):
            return date
        }
    }
}

// MARK: - Network Cache Manager

class NetworkCacheManager: CacheManager {
    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    private let queue = DispatchQueue(label: "com.app.cache", attributes: .concurrent)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Configuration
    private let memoryCacheCountLimit: Int
    private let memoryCacheSizeLimit: Int
    
    init(
        memoryCacheCountLimit: Int = 100,
        memoryCacheSizeLimit: Int = 50 * 1024 * 1024 // 50 MB
    ) {
        self.memoryCacheCountLimit = memoryCacheCountLimit
        self.memoryCacheSizeLimit = memoryCacheSizeLimit
        
        // Setup disk cache directory
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDirectory.appendingPathComponent("NetworkCache", isDirectory: true)
        
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.countLimit = memoryCacheCountLimit
        memoryCache.totalCostLimit = memoryCacheSizeLimit
        
        // Setup date encoding/decoding
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Clear expired cache on init
        clearExpired()
    }
    
    // MARK: - Cache
    
    func cache<T: Encodable>(_ object: T, forKey key: String, expiration: CacheExpiration) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            do {
                let data = try self.encoder.encode(object)
                let entry = CacheEntry(data: data, expiration: expiration.expirationDate)
                
                // Memory cache
                let cost = data.count
                self.memoryCache.setObject(entry, forKey: key as NSString, cost: cost)
                
                // Disk cache
                let fileURL = self.diskCacheURL.appendingPathComponent(key.sha256Hash)
                let entryData = try self.encoder.encode(entry)
                try entryData.write(to: fileURL, options: .atomic)
                
            } catch {
                print("Failed to cache object for key '\(key)': \(error)")
            }
        }
    }
    
    // MARK: - Retrieve
    
    func retrieve<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        var entry: CacheEntry?
        
        // Try memory cache first
        queue.sync {
            entry = memoryCache.object(forKey: key as NSString)
        }
        
        // Try disk cache if not in memory
        if entry == nil {
            let fileURL = diskCacheURL.appendingPathComponent(key.sha256Hash)
            if let entryData = try? Data(contentsOf: fileURL),
               let cachedEntry = try? decoder.decode(CacheEntry.self, from: entryData) {
                entry = cachedEntry
                
                // Populate memory cache
                let cost = cachedEntry.data.count
                memoryCache.setObject(cachedEntry, forKey: key as NSString, cost: cost)
            }
        }
        
        // Check expiration
        guard let entry = entry else { return nil }
        
        if entry.expiration < Date() {
            remove(forKey: key)
            return nil
        }
        
        // Decode
        do {
            return try decoder.decode(type, from: entry.data)
        } catch {
            print("Failed to decode cached object for key '\(key)': \(error)")
            remove(forKey: key)
            return nil
        }
    }
    
    // MARK: - Remove
    
    func remove(forKey key: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Remove from memory
            self.memoryCache.removeObject(forKey: key as NSString)
            
            // Remove from disk
            let fileURL = self.diskCacheURL.appendingPathComponent(key.sha256Hash)
            try? self.fileManager.removeItem(at: fileURL)
        }
    }
    
    // MARK: - Clear
    
    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Clear memory cache
            self.memoryCache.removeAllObjects()
            
            // Clear disk cache
            try? self.fileManager.removeItem(at: self.diskCacheURL)
            try? self.fileManager.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Clear Expired
    
    func clearExpired() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            guard let files = try? self.fileManager.contentsOfDirectory(
                at: self.diskCacheURL,
                includingPropertiesForKeys: nil
            ) else { return }
            
            let now = Date()
            
            for fileURL in files {
                guard let entryData = try? Data(contentsOf: fileURL),
                      let entry = try? self.decoder.decode(CacheEntry.self, from: entryData) else {
                    continue
                }
                
                if entry.expiration < now {
                    try? self.fileManager.removeItem(at: fileURL)
                }
            }
        }
    }
    
    // MARK: - Cache Size
    
    func getCacheSize(completion: @escaping (Int64) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(0)
                return
            }
            
            var totalSize: Int64 = 0
            
            guard let files = try? self.fileManager.contentsOfDirectory(
                at: self.diskCacheURL,
                includingPropertiesForKeys: [.fileSizeKey]
            ) else {
                completion(0)
                return
            }
            
            for fileURL in files {
                if let attributes = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
            
            DispatchQueue.main.async {
                completion(totalSize)
            }
        }
    }
}

// MARK: - Cache Entry

struct CacheEntry: Codable {
    let data: Data
    let expiration: Date
    let createdAt: Date
    
    init(data: Data, expiration: Date) {
        self.data = data
        self.expiration = expiration
        self.createdAt = Date()
    }
}

// MARK: - String Hash Extension

extension String {
    var sha256Hash: String {
        let inputData = Data(self.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
