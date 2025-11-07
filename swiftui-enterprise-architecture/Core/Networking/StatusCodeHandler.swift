//
//  StatusCodeHandler.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Comprehensive HTTP status code handling
//

import Foundation

// MARK: - HTTP Status Code

enum HTTPStatusCode: Int {
    // 2xx Success
    case ok = 200
    case created = 201
    case accepted = 202
    case noContent = 204
    
    // 4xx Client Errors
    case badRequest = 400
    case unauthorized = 401
    case paymentRequired = 402
    case forbidden = 403
    case notFound = 404
    case methodNotAllowed = 405
    case notAcceptable = 406
    case requestTimeout = 408
    case conflict = 409
    case gone = 410
    case unprocessableEntity = 422
    case tooManyRequests = 429
    
    // 5xx Server Errors
    case internalServerError = 500
    case notImplemented = 501
    case badGateway = 502
    case serviceUnavailable = 503
    case gatewayTimeout = 504
    
    var isSuccess: Bool {
        return (200...299).contains(rawValue)
    }
    
    var isClientError: Bool {
        return (400...499).contains(rawValue)
    }
    
    var isServerError: Bool {
        return (500...599).contains(rawValue)
    }
    
    var isRetryable: Bool {
        switch self {
        case .requestTimeout, .tooManyRequests, .internalServerError, 
             .badGateway, .serviceUnavailable, .gatewayTimeout:
            return true
        default:
            return false
        }
    }
}

// MARK: - Status Code Handler

class StatusCodeHandler {
    
    static func handle(statusCode: Int, data: Data?) -> NetworkError? {
        guard let code = HTTPStatusCode(rawValue: statusCode) else {
            return .unknown("Unknown status code: \(statusCode)")
        }
        
        // Success codes
        if code.isSuccess {
            return nil
        }
        
        // Client errors
        if code.isClientError {
            return handleClientError(code: code, data: data)
        }
        
        // Server errors
        if code.isServerError {
            return handleServerError(code: code, data: data)
        }
        
        return .unknown("Unexpected status code: \(statusCode)")
    }
    
    // MARK: - Client Error Handling
    
    private static func handleClientError(code: HTTPStatusCode, data: Data?) -> NetworkError {
        switch code {
        case .badRequest:
            return parseErrorFromData(data) ?? .badRequest("Invalid request")
            
        case .unauthorized:
            return .unauthorized("Authentication required. Please log in again.")
            
        case .paymentRequired:
            return .forbidden("Payment required to access this resource")
            
        case .forbidden:
            return .forbidden("You don't have permission to access this resource")
            
        case .notFound:
            return .notFound("The requested resource was not found")
            
        case .methodNotAllowed:
            return .badRequest("This operation is not allowed")
            
        case .notAcceptable:
            return .badRequest("The request is not acceptable")
            
        case .requestTimeout:
            return .timeout("Request timeout. Please try again.")
            
        case .conflict:
            return parseErrorFromData(data) ?? .conflict("Resource conflict detected")
            
        case .gone:
            return .notFound("This resource is no longer available")
            
        case .unprocessableEntity:
            return parseValidationError(data) ?? .validationError("Validation failed")
            
        case .tooManyRequests:
            let retryAfter = extractRetryAfter(data: data)
            return .rateLimitExceeded("Too many requests. Please try again\(retryAfter).")
            
        default:
            return parseErrorFromData(data) ?? .badRequest("Client error occurred")
        }
    }
    
    // MARK: - Server Error Handling
    
    private static func handleServerError(code: HTTPStatusCode, data: Data?) -> NetworkError {
        switch code {
        case .internalServerError:
            return .serverError("Internal server error. Please try again later.")
            
        case .notImplemented:
            return .serverError("This feature is not yet implemented")
            
        case .badGateway:
            return .serverError("Bad gateway. Please try again later.")
            
        case .serviceUnavailable:
            return .serviceUnavailable("Service temporarily unavailable. Please try again later.")
            
        case .gatewayTimeout:
            return .timeout("Gateway timeout. Please try again.")
            
        default:
            return .serverError("Server error occurred. Please try again later.")
        }
    }
    
    // MARK: - Error Parsing
    
    private static func parseErrorFromData(_ data: Data?) -> NetworkError? {
        guard let data = data,
              let apiError = try? JSONDecoder().decode(APIError.self, from: data) else {
            return nil
        }
        return .apiError(apiError)
    }
    
    private static func parseValidationError(_ data: Data?) -> NetworkError? {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Try to extract field-level errors
        var fields: [String: String]?
        
        if let errors = json["errors"] as? [String: String] {
            fields = errors
        } else if let errors = json["errors"] as? [[String: String]] {
            // Handle array format
            fields = errors.reduce(into: [:]) { result, error in
                if let field = error["field"], let message = error["message"] {
                    result[field] = message
                }
            }
        }
        
        let message = json["message"] as? String ?? "Validation failed"
        return .validationError(message, fields: fields)
    }
    
    private static func extractRetryAfter(data: Data?) -> String {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let retryAfter = json["retry_after"] as? Int else {
            return ""
        }
        return " in \(retryAfter) seconds"
    }
}
