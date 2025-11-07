//
//  UserRepository.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Example repository implementation using NetworkManager
//

import Foundation

// MARK: - User Model

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let avatarURL: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UpdateProfileRequest: Encodable {
    let name: String?
    let bio: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case bio
    }
}

struct UserListResponse: Codable {
    let users: [User]
}

// MARK: - User Repository Protocol

protocol UserRepository {
    func getProfile(userId: String) async throws -> User
    func updateProfile(userId: String, request: UpdateProfileRequest) async throws -> User
    func uploadAvatar(userId: String, imageData: Data) async throws -> User
    func getUsers(page: Int, pageSize: Int, searchQuery: String?) async throws -> [User]
}

// MARK: - User Repository Implementation

class UserRepositoryImpl: UserRepository {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func getProfile(userId: String) async throws -> User {
        let response = try await networkManager.request(
            UserEndpoint.getProfile(userId: userId),
            responseType: User.self,
            cachePolicy: .cacheResponse(expiration: .minutes(5))
        )
        
        guard let user = response.data else {
            throw NetworkError.notFound("User not found")
        }
        
        return user
    }
    
    func updateProfile(userId: String, request: UpdateProfileRequest) async throws -> User {
        let parameters = try request.asDictionary()
        
        let response = try await networkManager.request(
            UserEndpoint.updateProfile(userId: userId, data: parameters),
            responseType: User.self,
            cachePolicy: .ignoreCache
        )
        
        guard let user = response.data else {
            throw NetworkError.unknown("Failed to update profile")
        }
        
        return user
    }
    
    func uploadAvatar(userId: String, imageData: Data) async throws -> User {
        let response = try await networkManager.upload(
            UserEndpoint.uploadAvatar(userId: userId, imageData: imageData),
            data: imageData,
            responseType: User.self
        )
        
        guard let user = response.data else {
            throw NetworkError.unknown("Failed to upload avatar")
        }
        
        return user
    }
    
    func getUsers(page: Int, pageSize: Int, searchQuery: String?) async throws -> [User] {
        let cachePolicy: CachePolicy = searchQuery == nil
            ? .cacheResponse(expiration: .minutes(2))
            : .ignoreCache
        
        let response = try await networkManager.request(
            UserEndpoint.getUsers(page: page, pageSize: pageSize, searchQuery: searchQuery),
            responseType: UserListResponse.self,
            cachePolicy: cachePolicy
        )
        
        guard let userList = response.data else {
            throw NetworkError.notFound("No users found")
        }
        
        return userList.users
    }
}
