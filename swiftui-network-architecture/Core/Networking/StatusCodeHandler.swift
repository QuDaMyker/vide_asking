//
//  StatusCodeHandler.swift
//  SwiftUI Network Architecture
//
//  Created on 2025-11-07
//  Comprehensive HTTP status code handling (200-599)
//

import Foundation

// MARK: - Status Code Handler

struct StatusCodeHandler {
    
    /// Handle HTTP status codes and return appropriate errors
    /// - Parameters:
    ///   - statusCode: HTTP status code
    ///   - data: Response data for additional error information
    /// - Returns: NetworkError if status code indicates failure
    static func handle(statusCode: Int, data: Data?) -> NetworkError? {
        switch statusCode {
        // Success (200-299)
        case 200...299:
            return nil
            
        // Client Errors (400-499)
        case 400:
            return .badRequest(extractErrorMessage(from: data) ?? "Bad request. Please check your input.")
            
        case 401:
            return .unauthorized
            
        case 403:
            return .forbidden
            
        case 404:
            return .notFound
            
        case 405:
            return .badRequest("Method not allowed.")
            
        case 406:
            return .badRequest("Not acceptable. The server cannot produce a response matching the accept headers.")
            
        case 408:
            return .timeout
            
        case 409:
            return .badRequest("Conflict. The request conflicts with the current state.")
            
        case 410:
            return .badRequest("The requested resource is no longer available.")
            
        case 415:
            return .badRequest("Unsupported media type.")
            
        case 422:
            return .badRequest(extractErrorMessage(from: data) ?? "Unprocessable entity. Validation failed.")
            
        case 429:
            return .rateLimitExceeded
            
        // Server Errors (500-599)
        case 500:
            return .serverError(500)
            
        case 501:
            return .serverError(501)
            
        case 502:
            return .serverError(502)
            
        case 503:
            return .serverError(503)
            
        case 504:
            return .serverError(504)
            
        case 500...599:
            return .serverError(statusCode)
            
        // Unknown status code
        default:
            return .unknown(NSError(
                domain: "HTTPError",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Unexpected HTTP status code: \(statusCode)"]
            ))
        }
    }
    
    /// Get user-friendly message for status code
    /// - Parameter statusCode: HTTP status code
    /// - Returns: User-friendly error message
    static func userFriendlyMessage(for statusCode: Int) -> String {
        switch statusCode {
        // Success
        case 200:
            return "Success"
        case 201:
            return "Created successfully"
        case 202:
            return "Request accepted"
        case 204:
            return "Success (no content)"
            
        // Client Errors
        case 400:
            return "Invalid request. Please check your input."
        case 401:
            return "Your session has expired. Please log in again."
        case 403:
            return "You don't have permission to access this resource."
        case 404:
            return "The requested resource was not found."
        case 405:
            return "This operation is not allowed."
        case 408:
            return "Request timed out. Please try again."
        case 409:
            return "This operation conflicts with the current state."
        case 415:
            return "The file type is not supported."
        case 422:
            return "The data provided is invalid."
        case 429:
            return "Too many requests. Please wait a moment and try again."
            
        // Server Errors
        case 500:
            return "Internal server error. Please try again later."
        case 501:
            return "This feature is not yet implemented."
        case 502:
            return "Bad gateway. Please try again."
        case 503:
            return "Service temporarily unavailable. Please try again later."
        case 504:
            return "Gateway timeout. The server took too long to respond."
        case 500...599:
            return "Server error (\(statusCode)). Please try again later."
            
        default:
            return "An error occurred (Status: \(statusCode))."
        }
    }
    
    /// Check if status code represents success
    /// - Parameter statusCode: HTTP status code
    /// - Returns: true if success (200-299)
    static func isSuccess(_ statusCode: Int) -> Bool {
        return (200...299).contains(statusCode)
    }
    
    /// Check if status code is a client error
    /// - Parameter statusCode: HTTP status code
    /// - Returns: true if client error (400-499)
    static func isClientError(_ statusCode: Int) -> Bool {
        return (400...499).contains(statusCode)
    }
    
    /// Check if status code is a server error
    /// - Parameter statusCode: HTTP status code
    /// - Returns: true if server error (500-599)
    static func isServerError(_ statusCode: Int) -> Bool {
        return (500...599).contains(statusCode)
    }
    
    /// Check if error is retryable
    /// - Parameter statusCode: HTTP status code
    /// - Returns: true if the request should be retried
    static func isRetryable(_ statusCode: Int) -> Bool {
        switch statusCode {
        case 408, 429, 500...599:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    private static func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data else { return nil }
        
        do {
            // Try to decode as ErrorResponse
            let decoder = JSONDecoder.api
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            return errorResponse.error
        } catch {
            // Try to decode as APIResponse with generic error
            do {
                let apiResponse = try JSONDecoder().decode(APIResponse<EmptyResponse>.self, from: data)
                return apiResponse.errorMessage
            } catch {
                // Try to extract any "message" or "error" field
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let message = json["message"] as? String {
                        return message
                    }
                    if let error = json["error"] as? String {
                        return error
                    }
                }
            }
        }
        
        return nil
    }
}

// MARK: - HTTP Status Code Extension

extension HTTPURLResponse {
    
    /// Check if response is successful
    var isSuccess: Bool {
        return StatusCodeHandler.isSuccess(statusCode)
    }
    
    /// Check if response is a client error
    var isClientError: Bool {
        return StatusCodeHandler.isClientError(statusCode)
    }
    
    /// Check if response is a server error
    var isServerError: Bool {
        return StatusCodeHandler.isServerError(statusCode)
    }
    
    /// Check if the request should be retried
    var isRetryable: Bool {
        return StatusCodeHandler.isRetryable(statusCode)
    }
    
    /// Get user-friendly message for this response
    var userFriendlyMessage: String {
        return StatusCodeHandler.userFriendlyMessage(for: statusCode)
    }
}

// MARK: - Status Code Categories

enum HTTPStatusCategory {
    case informational  // 100-199
    case success        // 200-299
    case redirection    // 300-399
    case clientError    // 400-499
    case serverError    // 500-599
    case unknown
    
    init(statusCode: Int) {
        switch statusCode {
        case 100...199:
            self = .informational
        case 200...299:
            self = .success
        case 300...399:
            self = .redirection
        case 400...499:
            self = .clientError
        case 500...599:
            self = .serverError
        default:
            self = .unknown
        }
    }
    
    var description: String {
        switch self {
        case .informational:
            return "Informational"
        case .success:
            return "Success"
        case .redirection:
            return "Redirection"
        case .clientError:
            return "Client Error"
        case .serverError:
            return "Server Error"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Common HTTP Status Codes

enum HTTPStatusCode: Int {
    // Success
    case ok = 200
    case created = 201
    case accepted = 202
    case noContent = 204
    
    // Redirection
    case movedPermanently = 301
    case found = 302
    case notModified = 304
    
    // Client Errors
    case badRequest = 400
    case unauthorized = 401
    case forbidden = 403
    case notFound = 404
    case methodNotAllowed = 405
    case requestTimeout = 408
    case conflict = 409
    case unprocessableEntity = 422
    case tooManyRequests = 429
    
    // Server Errors
    case internalServerError = 500
    case notImplemented = 501
    case badGateway = 502
    case serviceUnavailable = 503
    case gatewayTimeout = 504
    
    var userFriendlyMessage: String {
        return StatusCodeHandler.userFriendlyMessage(for: rawValue)
    }
    
    var category: HTTPStatusCategory {
        return HTTPStatusCategory(statusCode: rawValue)
    }
    
    var isSuccess: Bool {
        return StatusCodeHandler.isSuccess(rawValue)
    }
    
    var isRetryable: Bool {
        return StatusCodeHandler.isRetryable(rawValue)
    }
}
