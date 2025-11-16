//
//  Endpoint.swift
//  SwiftUI Network Architecture
//
//  Created on 2025-11-07
//  Endpoint protocol and common implementations
//

import Foundation
import Alamofire

// MARK: - Endpoint Protocol

protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var parameters: Parameters? { get }
    var headers: HTTPHeaders? { get }
    var encoding: ParameterEncoding { get }
    var cacheKey: String { get }
}

// MARK: - Default Implementations

extension Endpoint {
    var parameters: Parameters? {
        return nil
    }
    
    var headers: HTTPHeaders? {
        return nil
    }
    
    var encoding: ParameterEncoding {
        switch method {
        case .get:
            return URLEncoding.default
        default:
            return JSONEncoding.default
        }
    }
    
    var cacheKey: String {
        return "\(method.rawValue)_\(path)_\(parameters?.description ?? "")"
    }
}

// MARK: - HTTP Method Extension

extension HTTPMethod {
    static let get = HTTPMethod.get
    static let post = HTTPMethod.post
    static let put = HTTPMethod.put
    static let patch = HTTPMethod.patch
    static let delete = HTTPMethod.delete
}

// MARK: - Example Endpoints

// MARK: - User Endpoints

enum UserEndpoint: Endpoint {
    case getUser(id: Int)
    case getUsers(page: Int, limit: Int)
    case createUser(name: String, email: String, password: String)
    case updateUser(id: Int, name: String?, email: String?)
    case deleteUser(id: Int)
    case uploadAvatar(userId: Int)
    
    var path: String {
        switch self {
        case .getUser(let id):
            return "/users/\(id)"
        case .getUsers:
            return "/users"
        case .createUser:
            return "/users"
        case .updateUser(let id, _, _):
            return "/users/\(id)"
        case .deleteUser(let id):
            return "/users/\(id)"
        case .uploadAvatar(let userId):
            return "/users/\(userId)/avatar"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getUser, .getUsers:
            return .get
        case .createUser:
            return .post
        case .updateUser:
            return .put
        case .deleteUser:
            return .delete
        case .uploadAvatar:
            return .post
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .getUser, .deleteUser, .uploadAvatar:
            return nil
            
        case .getUsers(let page, let limit):
            return [
                "page": page,
                "limit": limit
            ]
            
        case .createUser(let name, let email, let password):
            return [
                "name": name,
                "email": email,
                "password": password
            ]
            
        case .updateUser(_, let name, let email):
            var params: Parameters = [:]
            if let name = name {
                params["name"] = name
            }
            if let email = email {
                params["email"] = email
            }
            return params.isEmpty ? nil : params
        }
    }
}

// MARK: - Auth Endpoints

enum AuthEndpoint: Endpoint {
    case login(email: String, password: String)
    case register(name: String, email: String, password: String)
    case refreshToken(refreshToken: String)
    case logout
    case forgotPassword(email: String)
    case resetPassword(token: String, newPassword: String)
    
    var path: String {
        switch self {
        case .login:
            return "/auth/login"
        case .register:
            return "/auth/register"
        case .refreshToken:
            return "/auth/refresh"
        case .logout:
            return "/auth/logout"
        case .forgotPassword:
            return "/auth/forgot-password"
        case .resetPassword:
            return "/auth/reset-password"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .login, .register, .refreshToken, .logout, .forgotPassword, .resetPassword:
            return .post
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .login(let email, let password):
            return [
                "email": email,
                "password": password
            ]
            
        case .register(let name, let email, let password):
            return [
                "name": name,
                "email": email,
                "password": password
            ]
            
        case .refreshToken(let refreshToken):
            return ["refresh_token": refreshToken]
            
        case .logout:
            return nil
            
        case .forgotPassword(let email):
            return ["email": email]
            
        case .resetPassword(let token, let newPassword):
            return [
                "token": token,
                "password": newPassword
            ]
        }
    }
}

// MARK: - Product Endpoints

enum ProductEndpoint: Endpoint {
    case getAll(page: Int?, limit: Int?)
    case getById(id: Int)
    case search(query: String, filters: [String: Any]?)
    case create(product: Product)
    case update(id: Int, product: Product)
    case delete(id: Int)
    case uploadImage(productId: Int)
    
    var path: String {
        switch self {
        case .getAll:
            return "/products"
        case .getById(let id):
            return "/products/\(id)"
        case .search:
            return "/products/search"
        case .create:
            return "/products"
        case .update(let id, _):
            return "/products/\(id)"
        case .delete(let id):
            return "/products/\(id)"
        case .uploadImage(let productId):
            return "/products/\(productId)/image"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getAll, .getById, .search:
            return .get
        case .create:
            return .post
        case .update:
            return .put
        case .delete:
            return .delete
        case .uploadImage:
            return .post
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .getAll(let page, let limit):
            var params: Parameters = [:]
            if let page = page {
                params["page"] = page
            }
            if let limit = limit {
                params["limit"] = limit
            }
            return params.isEmpty ? nil : params
            
        case .getById, .delete, .uploadImage:
            return nil
            
        case .search(let query, let filters):
            var params: Parameters = ["q": query]
            if let filters = filters {
                params.merge(filters) { _, new in new }
            }
            return params
            
        case .create(let product), .update(_, let product):
            return try? product.asDictionary()
        }
    }
}

// MARK: - Order Endpoints

enum OrderEndpoint: Endpoint {
    case getAll(status: String?)
    case getById(id: Int)
    case create(items: [OrderItem], shippingAddress: String)
    case updateStatus(id: Int, status: String)
    case cancel(id: Int)
    
    var path: String {
        switch self {
        case .getAll:
            return "/orders"
        case .getById(let id):
            return "/orders/\(id)"
        case .create:
            return "/orders"
        case .updateStatus(let id, _):
            return "/orders/\(id)/status"
        case .cancel(let id):
            return "/orders/\(id)/cancel"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getAll, .getById:
            return .get
        case .create:
            return .post
        case .updateStatus:
            return .patch
        case .cancel:
            return .post
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .getAll(let status):
            guard let status = status else { return nil }
            return ["status": status]
            
        case .getById:
            return nil
            
        case .create(let items, let shippingAddress):
            return [
                "items": items.map { $0.asDictionary() },
                "shipping_address": shippingAddress
            ]
            
        case .updateStatus(_, let status):
            return ["status": status]
            
        case .cancel:
            return nil
        }
    }
}

// MARK: - Helper Models

struct Product: Codable {
    let id: Int?
    let name: String
    let description: String?
    let price: Double
    let imageUrl: String?
    let category: String?
    let stock: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, price, category, stock
        case imageUrl = "image_url"
    }
}

struct OrderItem: Codable {
    let productId: Int
    let quantity: Int
    let price: Double
    
    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case quantity, price
    }
}

// MARK: - Encodable Extension

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError(domain: "EncodingError", code: 1, userInfo: nil)
        }
        return dictionary
    }
}
