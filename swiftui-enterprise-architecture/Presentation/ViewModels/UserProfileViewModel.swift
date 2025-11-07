//
//  UserProfileViewModel.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Example ViewModel with debouncing and error handling
//

import Foundation
import SwiftUI
import Combine

// MARK: - User Profile View Model

@MainActor
class UserProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Dependencies
    
    private let getUserProfileUseCase: GetUserProfileUseCase
    private let updateUserProfileUseCase: UpdateUserProfileUseCase
    private let uploadAvatarUseCase: UploadAvatarUseCase
    
    // MARK: - Private Properties
    
    private let debouncer = RequestDebouncer(delay: 0.5)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        getUserProfileUseCase: GetUserProfileUseCase,
        updateUserProfileUseCase: UpdateUserProfileUseCase,
        uploadAvatarUseCase: UploadAvatarUseCase
    ) {
        self.getUserProfileUseCase = getUserProfileUseCase
        self.updateUserProfileUseCase = updateUserProfileUseCase
        self.uploadAvatarUseCase = uploadAvatarUseCase
    }
    
    // MARK: - Public Methods
    
    func loadProfile(userId: String, forceRefresh: Bool = false) {
        debouncer.debounce(key: "loadProfile") { [weak self] in
            await self?.performLoadProfile(userId: userId)
        }
    }
    
    func updateProfile(userId: String, name: String?, bio: String?) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedUser = try await updateUserProfileUseCase.execute(
                userId: userId,
                name: name,
                bio: bio
            )
            user = updatedUser
        } catch let error as NetworkError {
            handleError(error)
        } catch {
            errorMessage = "An unexpected error occurred"
            showError = true
        }
        
        isLoading = false
    }
    
    func uploadAvatar(userId: String, imageData: Data) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedUser = try await uploadAvatarUseCase.execute(
                userId: userId,
                imageData: imageData
            )
            user = updatedUser
        } catch let error as NetworkError {
            handleError(error)
        } catch {
            errorMessage = "Failed to upload avatar"
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func performLoadProfile(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            user = try await getUserProfileUseCase.execute(userId: userId)
        } catch let error as NetworkError {
            handleError(error)
        } catch {
            errorMessage = "An unexpected error occurred"
            showError = true
        }
        
        isLoading = false
    }
    
    private func handleError(_ error: NetworkError) {
        errorMessage = error.localizedDescription
        showError = true
        
        // Log error for analytics
        AppLogger.shared.error("User profile error: \(error.localizedDescription)")
    }
}

// MARK: - Search Users View Model

@MainActor
class SearchUsersViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var searchQuery = ""
    @Published var users: [User] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let searchUsersUseCase: SearchUsersUseCase
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 1
    private let pageSize = 20
    
    // MARK: - Initialization
    
    init(searchUsersUseCase: SearchUsersUseCase) {
        self.searchUsersUseCase = searchUsersUseCase
        setupSearchObserver()
    }
    
    // MARK: - Setup
    
    private func setupSearchObserver() {
        $searchQuery
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task {
                    await self?.performSearch(query: query.isEmpty ? nil : query)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadMore() async {
        currentPage += 1
        await loadUsers(append: true)
    }
    
    func refresh() async {
        currentPage = 1
        await loadUsers(append: false)
    }
    
    // MARK: - Private Methods
    
    private func performSearch(query: String?) async {
        currentPage = 1
        await loadUsers(append: false)
    }
    
    private func loadUsers(append: Bool) async {
        isSearching = true
        errorMessage = nil
        
        do {
            let newUsers = try await searchUsersUseCase.execute(
                query: searchQuery.isEmpty ? nil : searchQuery,
                page: currentPage,
                pageSize: pageSize
            )
            
            if append {
                users.append(contentsOf: newUsers)
            } else {
                users = newUsers
            }
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }
        
        isSearching = false
    }
}
