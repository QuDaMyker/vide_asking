//
//  NetworkContainer.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Dependency injection container for networking
//

import Foundation

// MARK: - Network Container Protocol

protocol NetworkContainer {
    var networkManager: NetworkManager { get }
    var configuration: NetworkConfiguration { get }
    var cacheManager: CacheManager { get }
    var tokenManager: TokenManager { get }
}

// MARK: - Default Network Container

class DefaultNetworkContainer: NetworkContainer {
    static let shared = DefaultNetworkContainer()
    
    // MARK: - Dependencies
    
    lazy var configuration: NetworkConfiguration = {
        return NetworkConfigurationImpl()
    }()
    
    lazy var tokenManager: TokenManager = {
        return KeychainTokenManager(service: "com.app.tokens")
    }()
    
    lazy var cacheManager: CacheManager = {
        return NetworkCacheManager(
            memoryCacheCountLimit: 100,
            memoryCacheSizeLimit: 50 * 1024 * 1024 // 50 MB
        )
    }()
    
    lazy var networkManager: NetworkManager = {
        return AlamofireNetworkManager(
            configuration: configuration,
            tokenManager: tokenManager,
            cacheManager: cacheManager
        )
    }()
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBaseURLChange),
            name: .baseURLDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTokenChange),
            name: .accessTokenDidChange,
            object: nil
        )
    }
    
    @objc private func handleBaseURLChange(_ notification: Notification) {
        if let newURL = notification.object as? String {
            print("Base URL changed to: \(newURL)")
            // Optionally recreate network manager if needed
        }
    }
    
    @objc private func handleTokenChange(_ notification: Notification) {
        if let newToken = notification.object as? String {
            print("Access token updated")
        } else {
            print("Access token cleared")
        }
    }
}

// MARK: - App Dependencies (for SwiftUI)

class AppDependencies: ObservableObject {
    let networkContainer: NetworkContainer
    
    init(networkContainer: NetworkContainer = DefaultNetworkContainer.shared) {
        self.networkContainer = networkContainer
    }
    
    // Add other containers here (e.g., database, analytics, etc.)
}

// MARK: - Dependency Environment Key

import SwiftUI

private struct NetworkContainerKey: EnvironmentKey {
    static let defaultValue: NetworkContainer = DefaultNetworkContainer.shared
}

extension EnvironmentValues {
    var networkContainer: NetworkContainer {
        get { self[NetworkContainerKey.self] }
        set { self[NetworkContainerKey.self] = newValue }
    }
}

extension View {
    func networkContainer(_ container: NetworkContainer) -> some View {
        environment(\.networkContainer, container)
    }
}

// MARK: - Mock Container (for testing)

class MockNetworkContainer: NetworkContainer {
    var networkManager: NetworkManager
    var configuration: NetworkConfiguration
    var cacheManager: CacheManager
    var tokenManager: TokenManager
    
    init(
        networkManager: NetworkManager? = nil,
        configuration: NetworkConfiguration? = nil,
        cacheManager: CacheManager? = nil,
        tokenManager: TokenManager? = nil
    ) {
        self.networkManager = networkManager ?? MockNetworkManager()
        self.configuration = configuration ?? NetworkConfigurationImpl()
        self.cacheManager = cacheManager ?? NetworkCacheManager()
        self.tokenManager = tokenManager ?? MockTokenManager()
    }
}

// MARK: - Mock Token Manager

class MockTokenManager: TokenManager {
    var accessToken: String?
    var refreshToken: String?
    var tokenExpirationDate: Date?
    
    var refreshTokenCalled = false
    var clearTokensCalled = false
    
    func refreshToken(completion: @escaping (Result<Void, Error>) -> Void) {
        refreshTokenCalled = true
        completion(.success(()))
    }
    
    func clearTokens() {
        clearTokensCalled = true
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil
    }
    
    func isTokenExpired() -> Bool {
        guard let expirationDate = tokenExpirationDate else {
            return true
        }
        return Date() >= expirationDate
    }
}
