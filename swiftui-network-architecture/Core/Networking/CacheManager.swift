//
//  CacheManager.swift
//  SwiftUI Network Architecture
//
//  Created on 2025-11-07
//  Multi-layer caching system with memory and disk caching
//

import Foundation

// MARK: - Cache Expiration

enum CacheExpiration {
    case never
    case seconds(TimeInterval)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case date(Date)
    
    var date: Date? {
        switch self {
        case .never:
            return nil
        case .seconds(let seconds):
            return Date().addingTimeInterval(seconds)
        case .minutes(let minutes):
            return Date().addingTimeInterval(TimeInterval(minutes * 60))
        case .hours(let hours):
            return Date().addingTimeInterval(TimeInterval(hours * 3600))
        case .days(let days):
            return Date().addingTimeInterval(TimeInterval(days * 86400))
        case .date(let date):
            return date
        }
    }
    
    var isExpired: Bool {
        guard let expirationDate = date else {
            return false // Never expires
        }
        return Date() > expirationDate
    }
}

// MARK: - Cache Entry

private struct CacheEntry<T: Codable>: Codable {
    let value: T
    let expirationDate: Date?
    let createdAt: Date
    
    var isExpired: Bool {
        guard let expirationDate = expirationDate else {
            return false
        }
        return Date() > expirationDate
    }
}

// MARK: - Cache Manager Protocol

protocol CacheManager {
    func cache<T: Codable>(_ object: T, forKey key: String, expiration: CacheExpiration)
    func retrieve<T: Codable>(forKey key: String, as type: T.Type) -> T?
    func remove(forKey key: String)
    func clear()
    func clearExpired()
}

// MARK: - Network Cache Manager

class NetworkCacheManager: CacheManager {
    
    // MARK: - Properties
    
    private let memoryCache = NSCache<NSString, CacheBox>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.app.cache.manager", qos: .utility)
    
    // Configuration
    private let maxMemoryCost: Int
    private let maxDiskSize: Int
    
    // MARK: - Initialization
    
    init(
        maxMemoryCost: Int = 50 * 1024 * 1024,  // 50 MB
        maxDiskSize: Int = 200 * 1024 * 1024     // 200 MB
    ) {
        self.maxMemoryCost = maxMemoryCost
        self.maxDiskSize = maxDiskSize
        
        // Setup memory cache
        memoryCache.totalCostLimit = maxMemoryCost
        memoryCache.countLimit = 100
        
        // Setup disk cache directory
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDirectory.appendingPathComponent("NetworkCache", isDirectory: true)
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Setup periodic cleanup
        setupPeriodicCleanup()
    }
    
    // MARK: - Cache Operations
    
    func cache<T: Codable>(_ object: T, forKey key: String, expiration: CacheExpiration) {
        let entry = CacheEntry(
            value: object,
            expirationDate: expiration.date,
            createdAt: Date()
        )
        
        // Cache in memory
        cacheInMemory(entry, forKey: key)
        
        // Cache on disk (async)
        queue.async { [weak self] in
            self?.cacheOnDisk(entry, forKey: key)
        }
    }
    
    func retrieve<T: Codable>(forKey key: String, as type: T.Type) -> T? {
        // Try memory cache first
        if let entry: CacheEntry<T> = retrieveFromMemory(forKey: key) {
            if !entry.isExpired {
                return entry.value
            } else {
                remove(forKey: key)
                return nil
            }
        }
        
        // Try disk cache
        if let entry: CacheEntry<T> = retrieveFromDisk(forKey: key) {
            if !entry.isExpired {
                // Move to memory cache for faster access
                cacheInMemory(entry, forKey: key)
                return entry.value
            } else {
                remove(forKey: key)
                return nil
            }
        }
        
        return nil
    }
    
    func remove(forKey key: String) {
        // Remove from memory
        memoryCache.removeObject(forKey: key as NSString)
        
        // Remove from disk (async)
        queue.async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.fileURL(forKey: key)
            try? self.fileManager.removeItem(at: fileURL)
        }
    }
    
    func clear() {
        // Clear memory cache
        memoryCache.removeAllObjects()
        
        // Clear disk cache (async)
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.diskCacheURL)
            try? self.fileManager.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
        }
        
        print("🗑️ Cache cleared")
    }
    
    func clearExpired() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard let files = try? self.fileManager.contentsOfDirectory(
                at: self.diskCacheURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else { return }
            
            var removedCount = 0
            
            for fileURL in files {
                if let data = try? Data(contentsOf: fileURL),
                   let entry = try? JSONDecoder().decode(CacheEntry<Data>.self, from: data),
                   entry.isExpired {
                    try? self.fileManager.removeItem(at: fileURL)
                    removedCount += 1
                }
            }
            
            if removedCount > 0 {
                print("🗑️ Removed \(removedCount) expired cache entries")
            }
        }
    }
    
    // MARK: - Memory Cache
    
    private func cacheInMemory<T: Codable>(_ entry: CacheEntry<T>, forKey key: String) {
        let box = CacheBox(entry)
        let cost = MemoryLayout<T>.size
        memoryCache.setObject(box, forKey: key as NSString, cost: cost)
    }
    
    private func retrieveFromMemory<T: Codable>(forKey key: String) -> CacheEntry<T>? {
        guard let box = memoryCache.object(forKey: key as NSString) else {
            return nil
        }
        return box.value as? CacheEntry<T>
    }
    
    // MARK: - Disk Cache
    
    private func cacheOnDisk<T: Codable>(_ entry: CacheEntry<T>, forKey key: String) {
        let fileURL = fileURL(forKey: key)
        
        do {
            let data = try JSONEncoder().encode(entry)
            try data.write(to: fileURL)
            
            // Check disk size and cleanup if needed
            checkDiskSizeAndCleanup()
        } catch {
            print("❌ Failed to cache on disk: \(error)")
        }
    }
    
    private func retrieveFromDisk<T: Codable>(forKey key: String) -> CacheEntry<T>? {
        let fileURL = fileURL(forKey: key)
        
        guard let data = try? Data(contentsOf: fileURL),
              let entry = try? JSONDecoder().decode(CacheEntry<T>.self, from: data) else {
            return nil
        }
        
        return entry
    }
    
    private func fileURL(forKey key: String) -> URL {
        let filename = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return diskCacheURL.appendingPathComponent(filename)
    }
    
    // MARK: - Disk Management
    
    private func checkDiskSizeAndCleanup() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }
        
        let totalSize = files.reduce(0) { total, fileURL in
            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + fileSize
        }
        
        guard totalSize > maxDiskSize else { return }
        
        // Sort by modification date (oldest first)
        let sortedFiles = files.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return date1 < date2
        }
        
        // Remove oldest files until under limit
        var currentSize = totalSize
        for fileURL in sortedFiles {
            guard currentSize > maxDiskSize else { break }
            
            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            try? fileManager.removeItem(at: fileURL)
            currentSize -= fileSize
        }
        
        print("🗑️ Cleaned up disk cache: \(totalSize - currentSize) bytes removed")
    }
    
    // MARK: - Periodic Cleanup
    
    private func setupPeriodicCleanup() {
        // Clear expired entries every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.clearExpired()
        }
    }
    
    // MARK: - Cache Stats
    
    func cacheStats() -> CacheStats {
        var diskSize = 0
        var fileCount = 0
        
        if let files = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) {
            fileCount = files.count
            diskSize = files.reduce(0) { total, fileURL in
                let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + fileSize
            }
        }
        
        return CacheStats(
            memoryCount: memoryCache.countLimit,
            diskSize: diskSize,
            fileCount: fileCount
        )
    }
}

// MARK: - Cache Box (Type Eraser for NSCache)

private class CacheBox {
    let value: Any
    
    init<T>(_ value: T) {
        self.value = value
    }
}

// MARK: - Cache Stats

struct CacheStats {
    let memoryCount: Int
    let diskSize: Int
    let fileCount: Int
    
    var diskSizeMB: Double {
        return Double(diskSize) / (1024 * 1024)
    }
    
    var description: String {
        return """
        Cache Statistics:
        - Memory entries: \(memoryCount)
        - Disk files: \(fileCount)
        - Disk size: \(String(format: "%.2f", diskSizeMB)) MB
        """
    }
}

// MARK: - In-Memory Cache Manager (for Testing)

class InMemoryCacheManager: CacheManager {
    private var cache: [String: Any] = [:]
    private var expirations: [String: Date?] = [:]
    private let queue = DispatchQueue(label: "com.app.memory.cache")
    
    func cache<T: Codable>(_ object: T, forKey key: String, expiration: CacheExpiration) {
        queue.async {
            self.cache[key] = object
            self.expirations[key] = expiration.date
        }
    }
    
    func retrieve<T: Codable>(forKey key: String, as type: T.Type) -> T? {
        return queue.sync {
            // Check expiration
            if let expirationDate = expirations[key] {
                if let date = expirationDate, Date() > date {
                    remove(forKey: key)
                    return nil
                }
            }
            
            return cache[key] as? T
        }
    }
    
    func remove(forKey key: String) {
        queue.async {
            self.cache.removeValue(forKey: key)
            self.expirations.removeValue(forKey: key)
        }
    }
    
    func clear() {
        queue.async {
            self.cache.removeAll()
            self.expirations.removeAll()
        }
    }
    
    func clearExpired() {
        queue.async {
            let now = Date()
            let expiredKeys = self.expirations.compactMap { key, date -> String? in
                guard let expirationDate = date, now > expirationDate else { return nil }
                return key
            }
            
            expiredKeys.forEach { key in
                self.cache.removeValue(forKey: key)
                self.expirations.removeValue(forKey: key)
            }
        }
    }
}
