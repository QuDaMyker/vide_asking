# Navigation and Data Passing Best Practices

## Problem
How to handle navigation between tabs and pass data back when using TabView or similar navigation patterns.

## Solution

### 1. Use a Coordinator for Tab Navigation

```swift
import SwiftUI
import Combine

@Observable
class MainTabCoordinator {
    var selectedTab: Int = 1
    private let appContainer: AppContainer
    
    // Keep view models alive for the lifecycle of the coordinator
    private var homeViewModel: HomeViewModel?
    private var profileViewModel: ProfileViewModel?
    
    init(appContainer: AppContainer) {
        self.appContainer = appContainer
    }
    
    func createHomeViewModel() -> HomeViewModel {
        if homeViewModel == nil {
            homeViewModel = HomeViewModel(
                logoutUseCase: appContainer.logoutUseCase,
                homeActionService: appContainer.homeActionService
            )
        }
        return homeViewModel!
    }
    
    func createProfileViewModel() -> ProfileViewModel {
        if profileViewModel == nil {
            profileViewModel = ProfileViewModel(
                // Inject dependencies here
            )
            // Set up callbacks
            profileViewModel?.onNavigateToTab = { [weak self] tabIndex in
                self?.selectedTab = tabIndex
            }
        }
        return profileViewModel!
    }
}
```

### 2. View Models Should Not Know About Each Other

```swift
import Foundation
import Combine

@Observable
class ProfileViewModel {
    // Instead of directly calling another view model,
    // use a callback that the coordinator will handle
    var onNavigateToTab: ((Int) -> Void)?
    
    // Or use a shared service for data updates
    private let profileService: ProfileService
    
    init(profileService: ProfileService) {
        self.profileService = profileService
    }
    
    func navigateBackToFeed() {
        // Option 1: Use callback for navigation
        onNavigateToTab?(1)
    }
    
    func updateProfile(data: ProfileData) {
        // Option 2: Update shared service, other view models can observe
        profileService.updateProfile(data)
    }
}
```

### 3. Root View Uses the Coordinator

```swift
import SwiftUI

struct RootView: View {
    @State private var coordinator: MainTabCoordinator
    
    init(appContainer: AppContainer) {
        self.coordinator = MainTabCoordinator(appContainer: appContainer)
    }
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            ProfileView(viewModel: coordinator.createProfileViewModel())
                .tag(0)
            
            FeedView(viewModel: coordinator.createFeedViewModel())
                .tag(1)
            
            MessagesView(viewModel: coordinator.createMessagesViewModel())
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}
```

### 4. For Data Sharing Between Tabs - Use a Shared Service

```swift
import Foundation
import Combine

class ProfileService {
    @Published var currentProfile: ProfileData?
    
    func updateProfile(_ data: ProfileData) {
        currentProfile = data
    }
}

// In FeedViewModel, observe the service
class FeedViewModel: ObservableObject {
    private let profileService: ProfileService
    private var cancellables = Set<AnyCancellable>()
    
    init(profileService: ProfileService) {
        self.profileService = profileService
        
        // Listen for profile updates
        profileService.$currentProfile
            .sink { [weak self] profile in
                self?.handleProfileUpdate(profile)
            }
            .store(in: &cancellables)
    }
    
    private func handleProfileUpdate(_ profile: ProfileData?) {
        // React to profile changes
    }
}
```

## Key Principles

1. **Coordinator Manages Navigation**: The coordinator owns the navigation state and view model lifecycle.

2. **View Models Don't Reference Each Other**: Use callbacks or shared services instead.

3. **Dependency Injection**: Always inject dependencies through the initializer.

4. **Shared State via Services**: For cross-tab communication, use a shared service that view models can observe.

5. **Avoid Retain Cycles**: Use `[weak self]` in closures, and let the coordinator manage view model lifecycle.

## Example: Complete Flow

```swift
// 1. User taps a button in ProfileView
Button("Go to Feed") {
    viewModel.navigateToFeed()
}

// 2. ProfileViewModel calls its callback
func navigateToFeed() {
    onNavigateToTab?(1)
}

// 3. Coordinator handles the navigation
profileViewModel?.onNavigateToTab = { [weak self] tabIndex in
    self?.selectedTab = tabIndex
}

// 4. TabView updates because selectedTab is bound
TabView(selection: $coordinator.selectedTab) { ... }
```

## For Your Specific Case

Replace this:
```swift
var profileViewModel: ProfileViewModel = {
    ProfileViewModel(onBackFeed: { [weak self] index in
        self?.onChangePage(to: index)
    })
}()
```

With this pattern:
```swift
// In MainTabCoordinator
func createProfileViewModel() -> ProfileViewModel {
    if profileViewModel == nil {
        profileViewModel = ProfileViewModel()
        profileViewModel?.onNavigateToTab = { [weak self] tabIndex in
            self?.selectedTab = tabIndex
        }
    }
    return profileViewModel!
}
```

This keeps concerns properly separated and prevents retain cycles.
