//
//  NetworkManager.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Complete Alamofire-based network manager with all best practices
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
}

// MARK: - Cache Policy

enum CachePolicy {
    case ignoreCache
    case returnCacheElseLoad
    case returnCacheDontLoad
    case cacheResponse(expiration: CacheExpiration)
}

// MARK: - Alamofire Network Manager Implementation

class AlamofireNetworkManager: NetworkManager {
    private let session: Session
    private let configuration: NetworkConfiguration
    private let cacheManager: CacheManager
    private let debouncer: RequestDebouncer
    
    init(
        configuration: NetworkConfiguration,
        tokenManager: TokenManager,
        cacheManager: CacheManager
    ) {
        self.configuration = configuration
        self.cacheManager = cacheManager
        self.debouncer = RequestDebouncer()
        
        let interceptor = APIRequestInterceptor(
            configuration: configuration,
            tokenManager: tokenManager
        )
        
        let logger = NetworkLogger()
        
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeout
        sessionConfiguration.timeoutIntervalForResource = configuration.timeout
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = Session(
            configuration: sessionConfiguration,
            interceptor: interceptor,
            eventMonitors: configuration.shouldLogRequests ? [logger] : []
        )
    }
    
    // MARK: - Request
    
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        cachePolicy: CachePolicy = .ignoreCache
    ) async throws -> APIResponse<T> {
        
        // Check cache first based on policy
        switch cachePolicy {
        case .returnCacheElseLoad:
            if let cached: APIResponse<T> = cacheManager.retrieve(
                forKey: endpoint.cacheKey,
                as: APIResponse<T>.self
            ) {
                return cached
            }
            
        case .returnCacheDontLoad:
            if let cached: APIResponse<T> = cacheManager.retrieve(
                forKey: endpoint.cacheKey,
                as: APIResponse<T>.self
            ) {
                return cached
            }
            throw NetworkError.notFound("No cached data available")
            
        case .ignoreCache, .cacheResponse:
            break
        }
        
        // Construct URL
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
        .serializingDecodable(APIResponse<T>.self)
        .response
        
        // Handle response
        switch response.result {
        case .success(let apiResponse):
            // Validate business logic success
            guard apiResponse.isSuccess else {
                throw NetworkError.apiError(
                    APIError(
                        code: "\(apiResponse.statusCode)",
                        message: apiResponse.message,
                        details: nil,
                        statusCode: apiResponse.statusCode
                    )
                )
            }
            
            // Cache response if needed
            if case .cacheResponse(let expiration) = cachePolicy {
                cacheManager.cache(apiResponse, forKey: endpoint.cacheKey, expiration: expiration)
            }
            
            return apiResponse
            
        case .failure(let error):
            // Handle HTTP status code errors
            if let statusCode = response.response?.statusCode,
               let networkError = StatusCodeHandler.handle(statusCode: statusCode, data: response.data) {
                throw networkError
            }
            
            // Handle AFError
            throw mapAFError(error)
        }
    }
    
    // MARK: - Upload
    
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
        .serializingDecodable(APIResponse<T>.self)
        .response
        
        switch response.result {
        case .success(let apiResponse):
            guard apiResponse.isSuccess else {
                throw NetworkError.apiError(
                    APIError(
                        code: "\(apiResponse.statusCode)",
                        message: apiResponse.message,
                        details: nil,
                        statusCode: apiResponse.statusCode
                    )
                )
            }
            return apiResponse
            
        case .failure(let error):
            if let statusCode = response.response?.statusCode,
               let networkError = StatusCodeHandler.handle(statusCode: statusCode, data: response.data) {
                throw networkError
            }
            throw mapAFError(error)
        }
    }
    
    // MARK: - Error Mapping
    
    private func mapAFError(_ error: AFError) -> NetworkError {
        switch error {
        case .sessionTaskFailed(let urlError as URLError):
            if urlError.code == .timedOut {
                return .timeout("Request timeout")
            } else if urlError.code == .notConnectedToInternet {
                return .networkError(urlError)
            }
            return .networkError(urlError)
            
        case .responseSerializationFailed(let reason):
            if case .decodingFailed(let decodingError) = reason {
                return .decodingError(decodingError)
            }
            return .unknown(error.localizedDescription)
            
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - Mock Network Manager (for testing)

class MockNetworkManager: NetworkManager {
    var mockResponse: Any?
    var mockError: Error?
    var requestCalled = false
    var uploadCalled = false
    
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        cachePolicy: CachePolicy
    ) async throws -> APIResponse<T> {
        requestCalled = true
        
        if let error = mockError {
            throw error
        }
        
        if let response = mockResponse as? APIResponse<T> {
            return response
        }
        
        throw NetworkError.unknown("No mock response configured")
    }
    
    func upload<T: Decodable>(
        _ endpoint: Endpoint,
        data: Data,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        uploadCalled = true
        
        if let error = mockError {
            throw error
        }
        
        if let response = mockResponse as? APIResponse<T> {
            return response
        }
        
        throw NetworkError.unknown("No mock response configured")
    }
}
