//
//  APIRequestInterceptor.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Handles request adaptation and retry logic
//

import Foundation
import Alamofire

// MARK: - API Request Interceptor

class APIRequestInterceptor: RequestInterceptor {
    private let configuration: NetworkConfiguration
    private let tokenManager: TokenManager
    private let refreshQueue = DispatchQueue(label: "com.app.token.refresh")
    private var isRefreshing = false
    private var requestsToRetry: [(RetryResult) -> Void] = []
    
    init(configuration: NetworkConfiguration, tokenManager: TokenManager) {
        self.configuration = configuration
        self.tokenManager = tokenManager
    }
    
    // MARK: - RequestAdapter
    
    func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var urlRequest = urlRequest
        
        // Add access token
        if let token = tokenManager.accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add common headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(configuration.apiVersion, forHTTPHeaderField: "API-Version")
        
        // Add device information
        #if os(iOS)
        urlRequest.setValue(UIDevice.current.identifierForVendor?.uuidString, 
                           forHTTPHeaderField: "Device-ID")
        urlRequest.setValue("iOS", forHTTPHeaderField: "Platform")
        urlRequest.setValue(UIDevice.current.systemVersion, forHTTPHeaderField: "OS-Version")
        #elseif os(macOS)
        urlRequest.setValue("macOS", forHTTPHeaderField: "Platform")
        #endif
        
        // Add app version
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            urlRequest.setValue(appVersion, forHTTPHeaderField: "App-Version")
        }
        
        // Add request ID for tracking
        let requestId = UUID().uuidString
        urlRequest.setValue(requestId, forHTTPHeaderField: "X-Request-ID")
        
        completion(.success(urlRequest))
    }
    
    // MARK: - RequestRetrier
    
    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        // Check if we should retry
        guard shouldRetry(request: request, error: error) else {
            completion(.doNotRetryWithError(error))
            return
        }
        
        // Handle 401 (Unauthorized) with token refresh
        if let response = request.task?.response as? HTTPURLResponse,
           response.statusCode == 401 {
            handleTokenRefresh(completion: completion)
            return
        }
        
        // Retry with delay for server errors
        if let response = request.task?.response as? HTTPURLResponse,
           (500...599).contains(response.statusCode) {
            let retryDelay = calculateRetryDelay(for: request)
            completion(.retryWithDelay(retryDelay))
            return
        }
        
        completion(.doNotRetryWithError(error))
    }
    
    // MARK: - Private Methods
    
    private func shouldRetry(request: Request, error: Error) -> Bool {
        // Check retry count
        guard request.retryCount < 3 else { return false }
        
        // Check if it's a retryable error
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        // Check status code
        if let response = request.task?.response as? HTTPURLResponse {
            switch response.statusCode {
            case 401, 408, 429, 500...599:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private func handleTokenRefresh(completion: @escaping (RetryResult) -> Void) {
        refreshQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.requestsToRetry.append(completion)
            
            if !self.isRefreshing {
                self.isRefreshing = true
                
                self.tokenManager.refreshToken { [weak self] result in
                    guard let self = self else { return }
                    
                    self.refreshQueue.async {
                        self.isRefreshing = false
                        
                        switch result {
                        case .success:
                            self.requestsToRetry.forEach { $0(.retry) }
                        case .failure(let error):
                            self.requestsToRetry.forEach { $0(.doNotRetryWithError(error)) }
                        }
                        
                        self.requestsToRetry.removeAll()
                    }
                }
            }
        }
    }
    
    private func calculateRetryDelay(for request: Request) -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s
        let baseDelay: TimeInterval = 1.0
        let retryCount = request.retryCount
        return baseDelay * pow(2.0, Double(retryCount))
    }
}
