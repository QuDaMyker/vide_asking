//
//  UserProfileView.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Example SwiftUI view with networking
//

import SwiftUI

// MARK: - User Profile View

struct UserProfileView: View {
    @Environment(\.networkContainer) private var networkContainer
    @StateObject private var viewModel: UserProfileViewModel
    
    let userId: String
    
    init(userId: String) {
        self.userId = userId
        
        // Initialize ViewModel with dependencies
        let container = DefaultNetworkContainer.shared
        let repository = UserRepositoryImpl(networkManager: container.networkManager)
        
        let getUserProfileUseCase = GetUserProfileUseCaseImpl(repository: repository)
        let updateUserProfileUseCase = UpdateUserProfileUseCaseImpl(repository: repository)
        let uploadAvatarUseCase = UploadAvatarUseCaseImpl(repository: repository)
        
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(
            getUserProfileUseCase: getUserProfileUseCase,
            updateUserProfileUseCase: updateUserProfileUseCase,
            uploadAvatarUseCase: uploadAvatarUseCase
        ))
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let user = viewModel.user {
                profileContent(user: user)
            } else {
                emptyState
            }
        }
        .navigationTitle("Profile")
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onAppear {
            viewModel.loadProfile(userId: userId)
        }
    }
    
    // MARK: - Profile Content
    
    @ViewBuilder
    private func profileContent(user: User) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Avatar
                AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                
                // User Info
                VStack(spacing: 8) {
                    Text(user.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Edit Profile") {
                        // Navigate to edit screen
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Upload Avatar") {
                        // Show image picker
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top)
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No profile data")
                .font(.headline)
            
            Button("Retry") {
                viewModel.loadProfile(userId: userId)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Search Users View

struct SearchUsersView: View {
    @StateObject private var viewModel: SearchUsersViewModel
    
    init() {
        let container = DefaultNetworkContainer.shared
        let repository = UserRepositoryImpl(networkManager: container.networkManager)
        let searchUsersUseCase = SearchUsersUseCaseImpl(repository: repository)
        
        _viewModel = StateObject(wrappedValue: SearchUsersViewModel(
            searchUsersUseCase: searchUsersUseCase
        ))
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.users) { user in
                    NavigationLink(destination: UserProfileView(userId: user.id)) {
                        UserRowView(user: user)
                    }
                }
                
                if viewModel.isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Search users")
            .navigationTitle("Users")
            .refreshable {
                await viewModel.refresh()
            }
            .alert(item: Binding(
                get: { viewModel.errorMessage.map { ErrorWrapper(message: $0) } },
                set: { viewModel.errorMessage = $0?.message }
            )) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

// MARK: - User Row View

struct UserRowView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Error Wrapper

struct ErrorWrapper: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - Preview

struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView(userId: "123")
    }
}

struct SearchUsersView_Previews: PreviewProvider {
    static var previews: some View {
        SearchUsersView()
    }
}
