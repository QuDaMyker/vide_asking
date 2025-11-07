//
//  Endpoint.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Endpoint protocol and implementations
//

import Foundation
import Alamofire

// MARK: - Endpoint Protocol

protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var parameters: Parameters? { get }
    var encoding: ParameterEncoding { get }
    var headers: HTTPHeaders? { get }
    var cacheKey: String { get }
}

// MARK: - Default Implementations

extension Endpoint {
    var encoding: ParameterEncoding {
        switch method {
        case .get, .delete:
            return URLEncoding.default
        default:
            return JSONEncoding.default
        }
    }
    
    var headers: HTTPHeaders? {
        return nil
    }
    
    var cacheKey: String {
        var key = path
        if let params = parameters {
            let paramString = params
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "&")
            key += "?\(paramString)"
        }
        return key
    }
}

// MARK: - Example Endpoints

// User Endpoints
enum UserEndpoint: Endpoint {
    case getProfile(userId: String)
    case updateProfile(userId: String, data: [String: Any])
    case uploadAvatar(userId: String, imageData: Data)
    case deleteAccount(userId: String)
    case getUsers(page: Int, pageSize: Int, searchQuery: String?)
    
    var path: String {
        switch self {
        case .getProfile(let userId):
            return "/users/\(userId)"
        case .updateProfile(let userId, _):
            return "/users/\(userId)"
        case .uploadAvatar(let userId, _):
            return "/users/\(userId)/avatar"
        case .deleteAccount(let userId):
            return "/users/\(userId)"
        case .getUsers:
            return "/users"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getProfile, .getUsers:
            return .get
        case .updateProfile:
            return .put
        case .uploadAvatar:
            return .post
        case .deleteAccount:
            return .delete
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .getProfile, .uploadAvatar, .deleteAccount:
            return nil
            
        case .updateProfile(_, let data):
            return data
            
        case .getUsers(let page, let pageSize, let searchQuery):
            var params: [String: Any] = [
                "page": page,
                "page_size": pageSize
            ]
            if let query = searchQuery, !query.isEmpty {
                params["q"] = query
            }
            return params
        }
    }
}

// Auth Endpoints
enum AuthEndpoint: Endpoint {
    case login(email: String, password: String)
    case register(email: String, password: String, name: String)
    case logout
    case refreshToken(refreshToken: String)
    case forgotPassword(email: String)
    case resetPassword(token: String, newPassword: String)
    case verifyEmail(token: String)
    
    var path: String {
        switch self {
        case .login:
            return "/auth/login"
        case .register:
            return "/auth/register"
        case .logout:
            return "/auth/logout"
        case .refreshToken:
            return "/auth/refresh"
        case .forgotPassword:
            return "/auth/forgot-password"
        case .resetPassword:
            return "/auth/reset-password"
        case .verifyEmail:
            return "/auth/verify-email"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .login, .register, .logout, .refreshToken, .forgotPassword, .resetPassword, .verifyEmail:
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
            
        case .register(let email, let password, let name):
            return [
                "email": email,
                "password": password,
                "name": name
            ]
            
        case .logout:
            return nil
            
        case .refreshToken(let refreshToken):
            return ["refresh_token": refreshToken]
            
        case .forgotPassword(let email):
            return ["email": email]
            
        case .resetPassword(let token, let newPassword):
            return [
                "token": token,
                "password": newPassword
            ]
            
        case .verifyEmail(let token):
            return ["token": token]
        }
    }
}

// Post Endpoints
enum PostEndpoint: Endpoint {
    case getPosts(page: Int, pageSize: Int)
    case getPost(postId: String)
    case createPost(title: String, content: String, tags: [String])
    case updatePost(postId: String, data: [String: Any])
    case deletePost(postId: String)
    case likePost(postId: String)
    case unlikePost(postId: String)
    
    var path: String {
        switch self {
        case .getPosts:
            return "/posts"
        case .getPost(let postId):
            return "/posts/\(postId)"
        case .createPost:
            return "/posts"
        case .updatePost(let postId, _):
            return "/posts/\(postId)"
        case .deletePost(let postId):
            return "/posts/\(postId)"
        case .likePost(let postId):
            return "/posts/\(postId)/like"
        case .unlikePost(let postId):
            return "/posts/\(postId)/unlike"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getPosts, .getPost:
            return .get
        case .createPost, .likePost, .unlikePost:
            return .post
        case .updatePost:
            return .put
        case .deletePost:
            return .delete
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .getPosts(let page, let pageSize):
            return [
                "page": page,
                "page_size": pageSize
            ]
            
        case .getPost, .deletePost, .likePost, .unlikePost:
            return nil
            
        case .createPost(let title, let content, let tags):
            return [
                "title": title,
                "content": content,
                "tags": tags
            ]
            
        case .updatePost(_, let data):
            return data
        }
    }
}

// File Upload Endpoint
struct FileUploadEndpoint: Endpoint {
    let path: String
    let fileData: Data
    let fileName: String
    let mimeType: String
    let additionalParameters: [String: Any]?
    
    var method: HTTPMethod {
        return .post
    }
    
    var parameters: Parameters? {
        return additionalParameters
    }
    
    var encoding: ParameterEncoding {
        return URLEncoding.default
    }
}
