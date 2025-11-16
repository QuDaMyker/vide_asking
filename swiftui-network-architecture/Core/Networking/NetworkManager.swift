//
//  NetworkManager.swift
//  SwiftUI Network Architecture
//
//  Created on 2025-11-07
//  Main API client with GET, POST, PUT, PATCH, DELETE support
//

import Foundation
import Alamofire

// MARK: - Network Manager Protocol

protocol NetworkManager {
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        cachePolicy: CachePolicy
    ) async throws -> APIResponse<T>
    
    func upload<T: Decodable>(
        _ endpoint: Endpoint,
        data: Data,
        responseType: T.Type
    ) async throws -> APIResponse<T>
    
    func download(
        _ endpoint: Endpoint,
        to destination: URL
    ) async throws
}

// MARK: - Cache Policy

enum CachePolicy {
    case ignoreCache                    // Always fetch fresh from network
    case returnCacheElseLoad            // Return cache if available, else load from network
    case returnCacheDontLoad            // Return cache only, don't make network request
    case cacheResponse(expiration: CacheExpiration)  // Fetch from network and cache result
}

// MARK: - Alamofire Network Manager Implementation

class AlamofireNetworkManager: NetworkManager {
    
    // MARK: - Properties
    
    private let session: Session
    private let configuration: NetworkConfiguration
    private let tokenManager: TokenManager
    private let cacheManager: CacheManager
    private let logger: NetworkLogger
    
    // MARK: - Initialization
    
    init(
        configuration: NetworkConfiguration,
        tokenManager: TokenManager,
        cacheManager: CacheManager
    ) {
        self.configuration = configuration
        self.tokenManager = tokenManager
        self.cacheManager = cacheManager
        self.logger = NetworkLogger()
        
        // Create interceptor
        let interceptor = APIRequestInterceptor(
            configuration: configuration,
            tokenManager: tokenManager
        )
        
        // Create session configuration
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeout
        sessionConfiguration.timeoutIntervalForResource = configuration.timeout
        
        // Create Alamofire session with interceptor and logger
        self.session = Session(
            configuration: sessionConfiguration,
            interceptor: interceptor,
            eventMonitors: [logger]
        )
    }
    
    // MARK: - Request Methods
    
    /// Make a network request (GET, POST, PUT, PATCH, DELETE)
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        cachePolicy: CachePolicy = .ignoreCache
    ) async throws -> APIResponse<T> {
        
        // Check cache first if policy allows
        if case .returnCacheDontLoad = cachePolicy {
            if let cached: APIResponse<T> = cacheManager.retrieve(
                forKey: endpoint.cacheKey,
                as: APIResponse<T>.self
            ) {
                print("📦 Returning cached response for: \(endpoint.path)")
                return cached
            }
            throw NetworkError.noData
        }
        
        if case .returnCacheElseLoad = cachePolicy {
            if let cached: APIResponse<T> = cacheManager.retrieve(
                forKey: endpoint.cacheKey,
                as: APIResponse<T>.self
            ) {
                print("📦 Returning cached response for: \(endpoint.path)")
                return cached
            }
        }
        
        // Build URL
        let url = configuration.baseURL + endpoint.path
        
        // Make request
        let response = await session.request(
            url,
            method: endpoint.method,
            parameters: endpoint.parameters,
            encoding: endpoint.encoding,
            headers: endpoint.headers
        )
        .validate()
        .serializingDecodable(APIResponse<T>.self, decoder: JSONDecoder.api)
        .response
        
        // Handle response
        switch response.result {
        case .success(let apiResponse):
            // Cache response if needed
            if case .cacheResponse(let expiration) = cachePolicy {
                cacheManager.cache(
                    apiResponse,
                    forKey: endpoint.cacheKey,
                    expiration: expiration
                )
                print("💾 Cached response for: \(endpoint.path)")
            }
            
            return apiResponse
            
        case .failure(let error):
            // Handle status code errors
            if let statusCode = response.response?.statusCode,
               let networkError = StatusCodeHandler.handle(statusCode: statusCode, data: response.data) {
                throw networkError
            }
            
            // Handle AFError
            throw mapAlamofireError(error)
        }
    }
    
    /// Upload data (e.g., images, files)
    func upload<T: Decodable>(
        _ endpoint: Endpoint,
        data: Data,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        
        let url = configuration.baseURL + endpoint.path
        
        let response = await session.upload(
            data,
            to: url,
            method: endpoint.method,
            headers: endpoint.headers
        )
        .validate()
        .serializingDecodable(APIResponse<T>.self, decoder: JSONDecoder.api)
        .response
        
        switch response.result {
        case .success(let apiResponse):
            return apiResponse
            
        case .failure(let error):
            if let statusCode = response.response?.statusCode,
               let networkError = StatusCodeHandler.handle(statusCode: statusCode, data: response.data) {
                throw networkError
            }
            throw mapAlamofireError(error)
        }
    }
    
    /// Download file to destination
    func download(
        _ endpoint: Endpoint,
        to destination: URL
    ) async throws {
        
        let url = configuration.baseURL + endpoint.path
        
        let response = await session.download(
            url,
            method: endpoint.method,
            parameters: endpoint.parameters,
            encoding: endpoint.encoding,
            headers: endpoint.headers,
            to: { _, _ in
                return (destination, [.removePreviousFile, .createIntermediateDirectories])
            }
        )
        .validate()
        .serializingDownload(using: .url)
        .response
        
        switch response.result {
        case .success:
            print("✅ Downloaded file to: \(destination.path)")
            
        case .failure(let error):
            if let statusCode = response.response?.statusCode,
               let networkError = StatusCodeHandler.handle(statusCode: statusCode, data: nil) {
                throw networkError
            }
            throw mapAlamofireError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func mapAlamofireError(_ error: AFError) -> NetworkError {
        switch error {
        case .sessionTaskFailed(let urlError as URLError):
            if urlError.code == .notConnectedToInternet {
                return .offline
            }
            if urlError.code == .timedOut {
                return .timeout
            }
            return .unknown(urlError)
            
        case .responseValidationFailed(let reason):
            switch reason {
            case .unacceptableStatusCode(let code):
                return StatusCodeHandler.handle(statusCode: code, data: nil) ?? .serverError(code)
            default:
                return .unknown(error)
            }
            
        case .responseSerializationFailed(let reason):
            return .decodingError(error)
            
        default:
            return .unknown(error)
        }
    }
}

// MARK: - Convenience Methods Extension

extension NetworkManager {
    
    // MARK: - GET
    
    /// Perform GET request
    func get<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        cachePolicy: CachePolicy = .ignoreCache
    ) async throws -> APIResponse<T> {
        return try await request(endpoint, responseType: responseType, cachePolicy: cachePolicy)
    }
    
    // MARK: - POST
    
    /// Perform POST request
    func post<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        return try await request(endpoint, responseType: responseType, cachePolicy: .ignoreCache)
    }
    
    // MARK: - PUT
    
    /// Perform PUT request
    func put<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        return try await request(endpoint, responseType: responseType, cachePolicy: .ignoreCache)
    }
    
    // MARK: - PATCH
    
    /// Perform PATCH request
    func patch<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        return try await request(endpoint, responseType: responseType, cachePolicy: .ignoreCache)
    }
    
    // MARK: - DELETE
    
    /// Perform DELETE request
    func delete<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        return try await request(endpoint, responseType: responseType, cachePolicy: .ignoreCache)
    }
    
    /// Perform DELETE request with empty response
    func delete(_ endpoint: Endpoint) async throws {
        _ = try await request(endpoint, responseType: EmptyResponse.self, cachePolicy: .ignoreCache)
    }
}

// MARK: - Simple API Client (Alternative Implementation)

/// Simple API client without Alamofire dependency
class SimpleAPIClient {
    
    // MARK: - Properties
    
    private let baseURL: String
    private var accessToken: String?
    private let session: URLSession
    
    // MARK: - Initialization
    
    init(baseURL: String, accessToken: String? = nil) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Request Methods
    
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        
        // Build URL
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        // Add headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let headers = endpoint.headers {
            for header in headers {
                request.setValue(header.value, forHTTPHeaderField: header.name)
            }
        }
        
        // Add body parameters
        if let parameters = endpoint.parameters,
           endpoint.method != .get {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        }
        
        // Add query parameters for GET
        if let parameters = endpoint.parameters,
           endpoint.method == .get,
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
            if let urlWithQuery = components.url {
                request.url = urlWithQuery
            }
        }
        
        // Log request
        SimpleNetworkLogger.shared.log(request: request)
        
        // Perform request
        let (data, response) = try await session.data(for: request)
        
        // Log response
        SimpleNetworkLogger.shared.log(response: response, data: data, error: nil)
        
        // Handle status code
        if let httpResponse = response as? HTTPURLResponse {
            if let error = StatusCodeHandler.handle(statusCode: httpResponse.statusCode, data: data) {
                throw error
            }
        }
        
        // Decode response
        do {
            let decoder = JSONDecoder.api
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    // MARK: - Convenience Methods
    
    func get<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await request(endpoint, responseType: responseType)
    }
    
    func post<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await request(endpoint, responseType: responseType)
    }
    
    func put<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await request(endpoint, responseType: responseType)
    }
    
    func patch<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await request(endpoint, responseType: responseType)
    }
    
    func delete<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await request(endpoint, responseType: responseType)
    }
    
    // MARK: - Token Management
    
    func setAccessToken(_ token: String?) {
        self.accessToken = token
    }
    
    func clearToken() {
        self.accessToken = nil
    }
}
