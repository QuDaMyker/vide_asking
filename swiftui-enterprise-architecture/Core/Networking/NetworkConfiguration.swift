//
//  NetworkConfiguration.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Dynamic network configuration with base URL and settings
//

import Foundation

// MARK: - Network Configuration Protocol

protocol NetworkConfiguration {
    var baseURL: String { get set }
    var apiVersion: String { get }
    var timeout: TimeInterval { get }
    var shouldLogRequests: Bool { get }
    var maxRetryCount: Int { get }
    
    func updateBaseURL(_ url: String)
    func resetToDefault()
}

// MARK: - Network Configuration Implementation

class NetworkConfigurationImpl: NetworkConfiguration {
    private let userDefaults = UserDefaults.standard
    private let baseURLKey = "network.baseURL"
    
    // MARK: - Properties
    
    var baseURL: String {
        get {
            return userDefaults.string(forKey: baseURLKey) ?? defaultBaseURL
        }
        set {
            userDefaults.set(newValue, forKey: baseURLKey)
            NotificationCenter.default.post(name: .baseURLDidChange, object: newValue)
        }
    }
    
    var apiVersion: String {
        return "v1"
    }
    
    var timeout: TimeInterval {
        #if DEBUG
        return 60.0 // Longer timeout for debugging
        #else
        return 30.0
        #endif
    }
    
    var shouldLogRequests: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    var maxRetryCount: Int {
        return 3
    }
    
    // MARK: - Environment URLs
    
    private var defaultBaseURL: String {
        return environment.baseURL
    }
    
    private var environment: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    // MARK: - Methods
    
    func updateBaseURL(_ url: String) {
        guard URL(string: url) != nil else {
            print("Invalid URL: \(url)")
            return
        }
        self.baseURL = url
    }
    
    func resetToDefault() {
        userDefaults.removeObject(forKey: baseURLKey)
        NotificationCenter.default.post(name: .baseURLDidChange, object: defaultBaseURL)
    }
}

// MARK: - Environment

enum Environment {
    case development
    case staging
    case production
    
    var baseURL: String {
        switch self {
        case .development:
            return "https://api-dev.example.com"
        case .staging:
            return "https://api-staging.example.com"
        case .production:
            return "https://api.example.com"
        }
    }
    
    var name: String {
        switch self {
        case .development: return "Development"
        case .staging: return "Staging"
        case .production: return "Production"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let baseURLDidChange = Notification.Name("baseURLDidChange")
    static let accessTokenDidChange = Notification.Name("accessTokenDidChange")
}

// MARK: - Token Manager Protocol

protocol TokenManager {
    var accessToken: String? { get set }
    var refreshToken: String? { get set }
    var tokenExpirationDate: Date? { get }
    
    func refreshToken(completion: @escaping (Result<Void, Error>) -> Void)
    func clearTokens()
    func isTokenExpired() -> Bool
}

// MARK: - Keychain Token Manager

import Security

class KeychainTokenManager: TokenManager {
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"
    private let tokenExpirationKey = "token_expiration"
    private let service: String
    
    var accessToken: String? {
        get {
            return read(key: accessTokenKey)
        }
        set {
            if let token = newValue {
                save(key: accessTokenKey, value: token)
            } else {
                delete(key: accessTokenKey)
            }
            NotificationCenter.default.post(name: .accessTokenDidChange, object: newValue)
        }
    }
    
    var refreshToken: String? {
        get {
            return read(key: refreshTokenKey)
        }
        set {
            if let token = newValue {
                save(key: refreshTokenKey, value: token)
            } else {
                delete(key: refreshTokenKey)
            }
        }
    }
    
    var tokenExpirationDate: Date? {
        get {
            guard let timestampString = read(key: tokenExpirationKey),
                  let timestamp = TimeInterval(timestampString) else {
                return nil
            }
            return Date(timeIntervalSince1970: timestamp)
        }
        set {
            if let date = newValue {
                save(key: tokenExpirationKey, value: "\(date.timeIntervalSince1970)")
            } else {
                delete(key: tokenExpirationKey)
            }
        }
    }
    
    init(service: String = "com.app.tokens") {
        self.service = service
    }
    
    // MARK: - Token Management
    
    func refreshToken(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let refreshToken = refreshToken else {
            completion(.failure(NetworkError.unauthorized("No refresh token available")))
            return
        }
        
        // Create refresh request
        let configuration = NetworkConfigurationImpl()
        let url = configuration.baseURL + "/auth/refresh"
        
        guard let requestURL = URL(string: url) else {
            completion(.failure(NetworkError.badRequest("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // Make request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(NetworkError.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.unknown("No data received")))
                return
            }
            
            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                self?.accessToken = tokenResponse.accessToken
                self?.refreshToken = tokenResponse.refreshToken
                
                // Calculate expiration
                let expirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
                self?.tokenExpirationDate = expirationDate
                
                completion(.success(()))
            } catch {
                completion(.failure(NetworkError.decodingError(error)))
            }
        }.resume()
    }
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil
    }
    
    func isTokenExpired() -> Bool {
        guard let expirationDate = tokenExpirationDate else {
            return true
        }
        // Consider token expired 5 minutes before actual expiration
        return Date().addingTimeInterval(300) >= expirationDate
    }
    
    // MARK: - Keychain Operations
    
    private func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save to keychain: \(status)")
        }
    }
    
    private func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
