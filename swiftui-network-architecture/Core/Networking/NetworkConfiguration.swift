//
//  NetworkConfiguration.swift
//  SwiftUI Network Architecture
//
//  Created on 2025-11-07
//  Dynamic network configuration for baseURL, API version, timeouts, etc.
//

import Foundation

// MARK: - Network Configuration Protocol

protocol NetworkConfiguration: AnyObject {
    var baseURL: String { get set }
    var apiVersion: String { get }
    var timeout: TimeInterval { get }
    var headers: [String: String] { get }
    
    func updateBaseURL(_ url: String)
    func reset()
}

// MARK: - Network Configuration Implementation

class NetworkConfigurationImpl: NetworkConfiguration {
    
    // MARK: - Properties
    
    var baseURL: String {
        didSet {
            notifyObservers()
        }
    }
    
    let apiVersion: String
    let timeout: TimeInterval
    
    var headers: [String: String] {
        var defaultHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "API-Version": apiVersion
        ]
        
        // Add device info for debugging
        #if DEBUG
        if let deviceID = deviceIdentifier {
            defaultHeaders["Device-ID"] = deviceID
        }
        defaultHeaders["Platform"] = "iOS"
        defaultHeaders["App-Version"] = appVersion
        #endif
        
        return defaultHeaders
    }
    
    // MARK: - Configuration Environments
    
    enum Environment {
        case development
        case staging
        case production
        case custom(String)
        
        var baseURL: String {
            switch self {
            case .development:
                return "https://dev-api.example.com"
            case .staging:
                return "https://staging-api.example.com"
            case .production:
                return "https://api.example.com"
            case .custom(let url):
                return url
            }
        }
    }
    
    // MARK: - Observers
    
    private var observers: [() -> Void] = []
    
    // MARK: - Initialization
    
    init(
        environment: Environment = .production,
        apiVersion: String = "v1",
        timeout: TimeInterval = 30
    ) {
        self.baseURL = environment.baseURL
        self.apiVersion = apiVersion
        self.timeout = timeout
    }
    
    // MARK: - Public Methods
    
    func updateBaseURL(_ url: String) {
        guard !url.isEmpty else { return }
        
        // Ensure URL doesn't end with slash
        self.baseURL = url.hasSuffix("/") ? String(url.dropLast()) : url
        
        print("🔄 Base URL updated to: \(self.baseURL)")
    }
    
    func reset() {
        self.baseURL = Environment.production.baseURL
    }
    
    func addObserver(_ observer: @escaping () -> Void) {
        observers.append(observer)
    }
    
    // MARK: - Private Methods
    
    private func notifyObservers() {
        observers.forEach { $0() }
    }
    
    // MARK: - Helpers
    
    private var deviceIdentifier: String? {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString
        #else
        return nil
        #endif
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

// MARK: - Token Manager Protocol

protocol TokenManager: AnyObject {
    var accessToken: String? { get set }
    var refreshToken: String? { get set }
    var tokenExpirationDate: Date? { get set }
    
    var isTokenExpired: Bool { get }
    var isTokenValid: Bool { get }
    
    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int)
    func clearTokens()
}

// MARK: - Keychain Token Manager

class KeychainTokenManager: TokenManager {
    
    // MARK: - Properties
    
    private let service: String
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"
    private let expirationKey = "token_expiration"
    
    var accessToken: String? {
        get {
            return KeychainHelper.load(key: accessTokenKey, service: service)
        }
        set {
            if let token = newValue {
                KeychainHelper.save(key: accessTokenKey, value: token, service: service)
            } else {
                KeychainHelper.delete(key: accessTokenKey, service: service)
            }
        }
    }
    
    var refreshToken: String? {
        get {
            return KeychainHelper.load(key: refreshTokenKey, service: service)
        }
        set {
            if let token = newValue {
                KeychainHelper.save(key: refreshTokenKey, value: token, service: service)
            } else {
                KeychainHelper.delete(key: refreshTokenKey, service: service)
            }
        }
    }
    
    var tokenExpirationDate: Date? {
        get {
            if let timestamp = KeychainHelper.load(key: expirationKey, service: service),
               let timeInterval = TimeInterval(timestamp) {
                return Date(timeIntervalSince1970: timeInterval)
            }
            return nil
        }
        set {
            if let date = newValue {
                let timestamp = String(date.timeIntervalSince1970)
                KeychainHelper.save(key: expirationKey, value: timestamp, service: service)
            } else {
                KeychainHelper.delete(key: expirationKey, service: service)
            }
        }
    }
    
    var isTokenExpired: Bool {
        guard let expirationDate = tokenExpirationDate else {
            return true
        }
        // Consider token expired if within 5 minutes of expiration
        return Date().addingTimeInterval(300) >= expirationDate
    }
    
    var isTokenValid: Bool {
        return accessToken != nil && !isTokenExpired
    }
    
    // MARK: - Initialization
    
    init(service: String = "com.app.network.tokens") {
        self.service = service
    }
    
    // MARK: - Public Methods
    
    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        
        print("✅ Tokens saved successfully")
    }
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil
        
        print("🗑️ Tokens cleared")
    }
}

// MARK: - In-Memory Token Manager (for Testing)

class InMemoryTokenManager: TokenManager {
    var accessToken: String?
    var refreshToken: String?
    var tokenExpirationDate: Date?
    
    var isTokenExpired: Bool {
        guard let expirationDate = tokenExpirationDate else {
            return true
        }
        return Date().addingTimeInterval(300) >= expirationDate
    }
    
    var isTokenValid: Bool {
        return accessToken != nil && !isTokenExpired
    }
    
    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
    }
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil
    }
}

// MARK: - Keychain Helper

private class KeychainHelper {
    
    static func save(key: String, value: String, service: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("❌ Keychain save error: \(status)")
        }
    }
    
    static func load(key: String, service: String) -> String? {
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
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    static func delete(key: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    static func deleteAll(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Network Reachability

import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.app.network.monitor")
    
    private(set) var isConnected = true
    private(set) var connectionType: NWInterface.InterfaceType?
    
    var isReachable: Bool {
        return isConnected
    }
    
    var isWiFi: Bool {
        return connectionType == .wifi
    }
    
    var isCellular: Bool {
        return connectionType == .cellular
    }
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            
            if path.usesInterfaceType(.wifi) {
                self?.connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                self?.connectionType = .cellular
            } else {
                self?.connectionType = nil
            }
            
            print("📶 Network status: \(path.status == .satisfied ? "Connected" : "Disconnected")")
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}
