//
//  GetUserProfileUseCase.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Example use case implementation
//

import Foundation

// MARK: - Get User Profile Use Case

protocol GetUserProfileUseCase {
    func execute(userId: String) async throws -> User
}

class GetUserProfileUseCaseImpl: GetUserProfileUseCase {
    private let repository: UserRepository
    
    init(repository: UserRepository) {
        self.repository = repository
    }
    
    func execute(userId: String) async throws -> User {
        return try await repository.getProfile(userId: userId)
    }
}

// MARK: - Update User Profile Use Case

protocol UpdateUserProfileUseCase {
    func execute(userId: String, name: String?, bio: String?) async throws -> User
}

class UpdateUserProfileUseCaseImpl: UpdateUserProfileUseCase {
    private let repository: UserRepository
    
    init(repository: UserRepository) {
        self.repository = repository
    }
    
    func execute(userId: String, name: String?, bio: String?) async throws -> User {
        let request = UpdateProfileRequest(name: name, bio: bio)
        return try await repository.updateProfile(userId: userId, request: request)
    }
}

// MARK: - Upload Avatar Use Case

protocol UploadAvatarUseCase {
    func execute(userId: String, imageData: Data) async throws -> User
}

class UploadAvatarUseCaseImpl: UploadAvatarUseCase {
    private let repository: UserRepository
    
    init(repository: UserRepository) {
        self.repository = repository
    }
    
    func execute(userId: String, imageData: Data) async throws -> User {
        // Validate image size
        guard imageData.count <= 5 * 1024 * 1024 else { // 5 MB
            throw NetworkError.badRequest("Image size must be less than 5 MB")
        }
        
        return try await repository.uploadAvatar(userId: userId, imageData: imageData)
    }
}

// MARK: - Search Users Use Case

protocol SearchUsersUseCase {
    func execute(query: String?, page: Int, pageSize: Int) async throws -> [User]
}

class SearchUsersUseCaseImpl: SearchUsersUseCase {
    private let repository: UserRepository
    private let debouncer: RequestDebouncer
    
    init(repository: UserRepository, debouncer: RequestDebouncer = RequestDebouncer(delay: 0.3)) {
        self.repository = repository
        self.debouncer = debouncer
    }
    
    func execute(query: String?, page: Int = 1, pageSize: Int = 20) async throws -> [User] {
        return try await repository.getUsers(page: page, pageSize: pageSize, searchQuery: query)
    }
}
