//
//  APIModels.swift
//  SwiftUI Network Architecture
//
//  Created on 2025-11-07
//  Standardized API response models with all required fields
//

import Foundation

// MARK: - API Response Model

/// Generic API response wrapper with standardized fields
/// - isSuccess: Indicates if the operation was successful
/// - message: Single user-friendly message
/// - messages: Array of messages (errors, warnings, info)
/// - createdAt: Timestamp when the response was created
/// - data: Generic payload of type T
/// - meta: Optional metadata (pagination, etc.)
struct APIResponse<T: Decodable>: Decodable {
    let isSuccess: Bool
    let message: String?
    let messages: [String]?
    let createdAt: Date?
    let data: T?
    let meta: ResponseMeta?
    
    enum CodingKeys: String, CodingKey {
        case isSuccess = "isSuccess"
        case message
        case messages
        case createdAt = "created_at"
        case data
        case meta
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        isSuccess = try container.decode(Bool.self, forKey: .isSuccess)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        messages = try container.decodeIfPresent([String].self, forKey: .messages)
        data = try container.decodeIfPresent(T.self, forKey: .data)
        meta = try container.decodeIfPresent(ResponseMeta.self, forKey: .meta)
        
        // Handle different date formats
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString)
        } else if let timestamp = try? container.decodeIfPresent(Double.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            createdAt = nil
        }
    }
    
    // Manual initializer for testing
    init(
        isSuccess: Bool,
        message: String? = nil,
        messages: [String]? = nil,
        createdAt: Date? = nil,
        data: T? = nil,
        meta: ResponseMeta? = nil
    ) {
        self.isSuccess = isSuccess
        self.message = message
        self.messages = messages
        self.createdAt = createdAt
        self.data = data
        self.meta = meta
    }
}

// MARK: - Response Metadata

/// Metadata for pagination, rate limiting, etc.
struct ResponseMeta: Decodable {
    let pagination: Pagination?
    let rateLimit: RateLimit?
    let version: String?
    
    enum CodingKeys: String, CodingKey {
        case pagination
        case rateLimit = "rate_limit"
        case version
    }
}

// MARK: - Pagination

/// Pagination information
struct Pagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case page
        case limit
        case total
        case totalPages = "total_pages"
        case hasMore = "has_more"
    }
    
    var offset: Int {
        (page - 1) * limit
    }
}

// MARK: - Rate Limit

/// API rate limiting information
struct RateLimit: Decodable {
    let limit: Int
    let remaining: Int
    let reset: Date
    
    enum CodingKeys: String, CodingKey {
        case limit
        case remaining
        case reset
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        limit = try container.decode(Int.self, forKey: .limit)
        remaining = try container.decode(Int.self, forKey: .remaining)
        
        // Handle timestamp or ISO8601 date
        if let timestamp = try? container.decode(Double.self, forKey: .reset) {
            reset = Date(timeIntervalSince1970: timestamp)
        } else {
            let dateString = try container.decode(String.self, forKey: .reset)
            reset = ISO8601DateFormatter().date(from: dateString) ?? Date()
        }
    }
}

// MARK: - Helper Extensions

extension APIResponse {
    /// Unwraps data or throws an error
    func unwrap() throws -> T {
        guard let data = data else {
            throw NetworkError.noData
        }
        return data
    }
    
    /// Returns data or default value
    func unwrapOrDefault(_ defaultValue: T) -> T {
        return data ?? defaultValue
    }
    
    /// Check if response has errors
    var hasErrors: Bool {
        !isSuccess || messages?.isEmpty == false
    }
    
    /// Get all error messages combined
    var errorMessage: String? {
        if let messages = messages, !messages.isEmpty {
            return messages.joined(separator: "\n")
        }
        return message
    }
}

// MARK: - Empty Response

/// Use for endpoints that don't return data
struct EmptyResponse: Decodable {}

extension APIResponse where T == EmptyResponse {
    static func success(message: String? = nil) -> APIResponse<EmptyResponse> {
        APIResponse(
            isSuccess: true,
            message: message,
            createdAt: Date(),
            data: EmptyResponse()
        )
    }
}

// MARK: - Network Error

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case encodingError(Error)
    case unauthorized
    case forbidden
    case notFound
    case timeout
    case serverError(Int)
    case rateLimitExceeded
    case badRequest(String)
    case unknown(Error)
    case offline
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL. Please check the endpoint configuration."
        case .noData:
            return "No data received from the server."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .forbidden:
            return "You don't have permission to access this resource."
        case .notFound:
            return "The requested resource was not found."
        case .timeout:
            return "Request timed out. Please check your connection and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again."
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        case .offline:
            return "No internet connection. Please check your network settings."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .timeout, .serverError, .offline, .unknown:
            return true
        default:
            return false
        }
    }
}

// MARK: - Common Response Types

/// Generic list response
struct ListResponse<T: Decodable>: Decodable {
    let items: [T]
    let total: Int?
    
    enum CodingKeys: String, CodingKey {
        case items
        case total
    }
}

/// Generic paginated response
struct PaginatedResponse<T: Decodable>: Decodable {
    let items: [T]
    let page: Int
    let limit: Int
    let total: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case items
        case page
        case limit
        case total
        case hasMore = "has_more"
    }
    
    var totalPages: Int {
        return (total + limit - 1) / limit
    }
}

/// Generic ID response
struct IDResponse: Decodable {
    let id: Int
}

/// Generic success response
struct SuccessResponse: Decodable {
    let success: Bool
    let message: String?
}

/// Generic message response
struct MessageResponse: Decodable {
    let message: String
}

// MARK: - Upload Response

struct UploadResponse: Decodable {
    let url: String
    let filename: String
    let size: Int
    let mimeType: String?
    
    enum CodingKeys: String, CodingKey {
        case url
        case filename
        case size
        case mimeType = "mime_type"
    }
}

// MARK: - Auth Response

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
    
    var expirationDate: Date {
        return Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}

// MARK: - Error Response

/// Server error response
struct ErrorResponse: Decodable {
    let error: String
    let errorCode: String?
    let details: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorCode = "error_code"
        case details
    }
}

// MARK: - Custom JSON Decoder

extension JSONDecoder {
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            
            // Try ISO8601 string
            if let dateString = try? container.decode(String.self),
               let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            
            // Try timestamp
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            
            // Fallback to current date
            return Date()
        }
        return decoder
    }
}

// MARK: - Custom JSON Encoder

extension JSONEncoder {
    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
