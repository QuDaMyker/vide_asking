//
//  APIRequestInterceptor.swift
//  SwiftUI Network Architecture
//
//  Created on 2025-11-07
//  Request interceptor for authentication, retry logic, and token refresh
//

import Foundation
import Alamofire

// MARK: - API Request Interceptor

class APIRequestInterceptor: RequestInterceptor {
    
    // MARK: - Properties
    
    private let configuration: NetworkConfiguration
    private let tokenManager: TokenManager
    private let refreshQueue = DispatchQueue(label: "com.app.token.refresh", qos: .utility)
    private var isRefreshing = false
    private var requestsToRetry: [(RetryResult) -> Void] = []
    
    // MARK: - Initialization
    
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
        
        // Add authorization header
        if let accessToken = tokenManager.accessToken {
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Add common headers from configuration
        for (key, value) in configuration.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add request ID for tracking
        let requestID = UUID().uuidString
        urlRequest.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        
        // Add timestamp
        let timestamp = ISO8601DateFormatter().string(from: Date())
        urlRequest.setValue(timestamp, forHTTPHeaderField: "X-Request-Time")
        
        completion(.success(urlRequest))
    }
    
    // MARK: - RequestRetrier
    
    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        // Check if it's a 401 unauthorized error
        guard let response = request.task?.response as? HTTPURLResponse else {
            completion(.doNotRetryWithError(error))
            return
        }
        
        // Handle 401 Unauthorized - try token refresh
        if response.statusCode == 401 {
            refreshQueue.async { [weak self] in
                guard let self = self else {
                    completion(.doNotRetry)
                    return
                }
                
                // If already refreshing, queue this request
                guard !self.isRefreshing else {
                    self.requestsToRetry.append(completion)
                    return
                }
                
                // Start refreshing
                self.isRefreshing = true
                
                // Attempt token refresh
                self.refreshToken { [weak self] success in
                    guard let self = self else { return }
                    
                    self.refreshQueue.async {
                        self.isRefreshing = false
                        
                        if success {
                            // Retry all queued requests
                            self.requestsToRetry.forEach { $0(.retry) }
                            self.requestsToRetry.removeAll()
                            completion(.retry)
                        } else {
                            // Failed to refresh - don't retry
                            self.requestsToRetry.forEach { $0(.doNotRetry) }
                            self.requestsToRetry.removeAll()
                            completion(.doNotRetry)
                        }
                    }
                }
            }
            return
        }
        
        // Handle retryable errors (timeout, server errors)
        if shouldRetry(response: response, error: error) {
            let delay = retryDelay(for: request.retryCount)
            completion(.retryWithDelay(delay))
            return
        }
        
        // Don't retry
        completion(.doNotRetryWithError(error))
    }
    
    // MARK: - Private Methods
    
    private func shouldRetry(response: HTTPURLResponse, error: Error) -> Bool {
        let statusCode = response.statusCode
        
        // Retry on server errors (500-599) and timeout
        if (500...599).contains(statusCode) {
            return true
        }
        
        // Retry on timeout
        if (error as NSError).code == NSURLErrorTimedOut {
            return true
        }
        
        // Retry on rate limit (429) with exponential backoff
        if statusCode == 429 {
            return true
        }
        
        return false
    }
    
    private func retryDelay(for retryCount: Int) -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s
        let maxRetries = 3
        guard retryCount < maxRetries else {
            return 0
        }
        
        let delay = pow(2.0, Double(retryCount))
        return delay
    }
    
    private func refreshToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = tokenManager.refreshToken else {
            print("❌ No refresh token available")
            completion(false)
            return
        }
        
        print("🔄 Refreshing access token...")
        
        // Make refresh token request
        let url = "\(configuration.baseURL)/auth/refresh"
        
        guard let requestURL = URL(string: url) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["refresh_token": refreshToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            if let error = error {
                print("❌ Token refresh failed: \(error)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("❌ No data received during token refresh")
                completion(false)
                return
            }
            
            do {
                let decoder = JSONDecoder.api
                let authResponse = try decoder.decode(APIResponse<AuthResponse>.self, from: data)
                
                guard let tokens = authResponse.data else {
                    print("❌ No tokens in refresh response")
                    completion(false)
                    return
                }
                
                // Save new tokens
                self.tokenManager.saveTokens(
                    accessToken: tokens.accessToken,
                    refreshToken: tokens.refreshToken,
                    expiresIn: tokens.expiresIn
                )
                
                print("✅ Token refreshed successfully")
                completion(true)
                
            } catch {
                print("❌ Failed to decode refresh response: \(error)")
                completion(false)
            }
        }.resume()
    }
}

// MARK: - Retry Policy

enum RetryPolicy {
    case immediate
    case exponential(base: TimeInterval = 2, maxRetries: Int = 3)
    case custom(delay: TimeInterval, maxRetries: Int)
    
    func shouldRetry(attemptCount: Int) -> Bool {
        switch self {
        case .immediate:
            return attemptCount < 3
        case .exponential(_, let maxRetries):
            return attemptCount < maxRetries
        case .custom(_, let maxRetries):
            return attemptCount < maxRetries
        }
    }
    
    func retryDelay(for attemptCount: Int) -> TimeInterval {
        switch self {
        case .immediate:
            return 0
        case .exponential(let base, _):
            return pow(base, Double(attemptCount))
        case .custom(let delay, _):
            return delay * Double(attemptCount)
        }
    }
}
