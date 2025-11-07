//
//  APIModels.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Standardized API response models
//

import Foundation

// MARK: - API Response

struct APIResponse<T: Decodable>: Decodable {
    let isSuccess: Bool
    let message: String
    let messages: [String]?
    let createdAt: Date
    let data: T?
    let statusCode: Int
    let metadata: ResponseMetadata?
    
    enum CodingKeys: String, CodingKey {
        case isSuccess = "is_success"
        case message
        case messages
        case createdAt = "created_at"
        case data
        case statusCode = "status_code"
        case metadata
    }
    
    init(
        isSuccess: Bool,
        message: String,
        messages: [String]? = nil,
        createdAt: Date = Date(),
        data: T? = nil,
        statusCode: Int,
        metadata: ResponseMetadata? = nil
    ) {
        self.isSuccess = isSuccess
        self.message = message
        self.messages = messages
        self.createdAt = createdAt
        self.data = data
        self.statusCode = statusCode
        self.metadata = metadata
    }
}

// MARK: - Response Metadata

struct ResponseMetadata: Decodable {
    let requestId: String?
    let timestamp: Date?
    let version: String?
    let pagination: PaginationInfo?
    
    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case timestamp
        case version
        case pagination
    }
}

// MARK: - Pagination Info

struct PaginationInfo: Decodable {
    let currentPage: Int
    let totalPages: Int
    let pageSize: Int
    let totalItems: Int
    let hasNext: Bool
    let hasPrevious: Bool
    
    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case totalPages = "total_pages"
        case pageSize = "page_size"
        case totalItems = "total_items"
        case hasNext = "has_next"
        case hasPrevious = "has_previous"
    }
}

// MARK: - Empty Response

struct EmptyResponse: Decodable {
    // Used for endpoints that don't return data
    init() {}
}

// MARK: - API Error

struct APIError: Decodable, Error, LocalizedError {
    let code: String
    let message: String
    let details: [String: String]?
    let statusCode: Int
    
    var errorDescription: String? {
        return message
    }
    
    enum CodingKeys: String, CodingKey {
        case code
        case message
        case details
        case statusCode = "status_code"
    }
    
    init(code: String, message: String, details: [String: String]? = nil, statusCode: Int) {
        self.code = code
        self.message = message
        self.details = details
        self.statusCode = statusCode
    }
}

// MARK: - Network Error

enum NetworkError: Error, LocalizedError {
    case unauthorized(String)
    case forbidden(String)
    case notFound(String)
    case badRequest(String)
    case conflict(String)
    case validationError(String, fields: [String: String]? = nil)
    case rateLimitExceeded(String)
    case timeout(String)
    case serverError(String)
    case serviceUnavailable(String)
    case apiError(APIError)
    case decodingError(Error)
    case networkError(Error)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let msg): return msg
        case .forbidden(let msg): return msg
        case .notFound(let msg): return msg
        case .badRequest(let msg): return msg
        case .conflict(let msg): return msg
        case .validationError(let msg, _): return msg
        case .rateLimitExceeded(let msg): return msg
        case .timeout(let msg): return msg
        case .serverError(let msg): return msg
        case .serviceUnavailable(let msg): return msg
        case .apiError(let error): return error.message
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .unknown(let msg): return msg
        }
    }
    
    var fieldErrors: [String: String]? {
        if case .validationError(_, let fields) = self {
            return fields
        }
        return nil
    }
}

// MARK: - Token Response

struct TokenResponse: Decodable {
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
}

// MARK: - Helper Extensions

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkError.unknown("Failed to convert to dictionary")
        }
        return dictionary
    }
}
