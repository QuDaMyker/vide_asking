//
//  APIClient.swift (Legacy - Replaced by NetworkManager)
//  SwiftUI Enterprise Architecture
//
//  ⚠️ DEPRECATED: This file is kept for backward compatibility
//  Use NetworkManager.swift instead for new implementations
//

import Foundation

// MARK: - Legacy API Client (Use NetworkManager instead)

protocol APIClient {
    func request<T: Decodable>(url: URL, responseType: T.Type) async throws -> T
}

class DefaultAPIClient: APIClient {
    func request<T: Decodable>(url: URL, responseType: T.Type) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Migration Guide
/*
 
 Old (APIClient):
 ----------------
 let client = DefaultAPIClient()
 let user = try await client.request(url: url, responseType: User.self)
 
 
 New (NetworkManager):
 --------------------
 let networkManager = DefaultNetworkContainer.shared.networkManager
 let response = try await networkManager.request(
     UserEndpoint.getProfile(userId: "123"),
     responseType: User.self,
     cachePolicy: .cacheResponse(expiration: .minutes(5))
 )
 let user = response.data
 
 Benefits:
 • Automatic token refresh
 • Request/Response interceptors
 • Multi-layer caching
 • Debouncing support
 • Comprehensive logging
 • Status code handling
 • Dependency injection
 
 */
