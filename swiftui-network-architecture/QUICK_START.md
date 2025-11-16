# Quick Start Guide

> Get up and running with SwiftUI Network Architecture in 10 minutes

## 🎯 What You'll Build

A fully functional networking layer with:
- API requests with automatic token management
- Response caching
- Error handling
- Network logging

## 📝 Prerequisites

- Xcode 14.0+
- iOS 15.0+
- Swift 5.9+
- Basic knowledge of SwiftUI and async/await

## 🚀 Step-by-Step Setup

### Step 1: Install Alamofire (2 minutes)

#### Option A: Swift Package Manager (Recommended)

1. Open your project in Xcode
2. Go to **File → Add Packages...**
3. Enter: `https://github.com/Alamofire/Alamofire.git`
4. Select version: **5.8.0** or later
5. Click **Add Package**

#### Option B: Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
]
```

### Step 2: Copy Files to Your Project (3 minutes)

Create this folder structure in your project:

```
YourApp/
├── Core/
│   └── Networking/
│       ├── NetworkManager.swift
│       ├── APIModels.swift
│       ├── APIRequestInterceptor.swift
│       ├── StatusCodeHandler.swift
│       ├── CacheManager.swift
│       ├── NetworkLogger.swift
│       ├── NetworkConfiguration.swift
│       └── Endpoint.swift
└── DI/
    └── NetworkContainer.swift
```

Copy all files from this repository to your project.

### Step 3: Create App Dependencies (1 minute)

Create a new file `AppDependencies.swift`:

```swift
import SwiftUI

class AppDependencies: ObservableObject {
    let networkContainer = DefaultNetworkContainer.shared
    
    init() {
        // Configure your API base URL
        networkContainer.configuration.updateBaseURL("https://api.example.com")
        
        // Configure logging (optional)
        #if DEBUG
        // Verbose logging in development
        networkContainer.configuration.logLevel = .verbose
        #else
        // Only errors in production
        networkContainer.configuration.logLevel = .error
        #endif
    }
}
```

### Step 4: Initialize in Your App (1 minute)

Update your main app file:

```swift
import SwiftUI

@main
struct YourApp: App {
    @StateObject private var dependencies = AppDependencies()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencies)
        }
    }
}
```

### Step 5: Create Your First Endpoint (1 minute)

Create a file `APIEndpoints.swift`:

```swift
import Alamofire

enum UserEndpoint: Endpoint {
    case getUser(id: Int)
    case getUsers
    case createUser(name: String, email: String)
    
    var path: String {
        switch self {
        case .getUser(let id):
            return "/users/\(id)"
        case .getUsers:
            return "/users"
        case .createUser:
            return "/users"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getUser, .getUsers:
            return .get
        case .createUser:
            return .post
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .getUser, .getUsers:
            return nil
        case .createUser(let name, let email):
            return ["name": name, "email": email]
        }
    }
    
    var encoding: ParameterEncoding {
        switch self {
        case .getUser, .getUsers:
            return URLEncoding.default
        case .createUser:
            return JSONEncoding.default
        }
    }
}
```

### Step 6: Create Your Model (1 minute)

Create `User.swift`:

```swift
struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let avatar: String?
}
```

### Step 7: Create Repository (1 minute)

Create `UserRepository.swift`:

```swift
protocol UserRepository {
    func getUser(id: Int) async throws -> User
    func getUsers() async throws -> [User]
}

class UserRepositoryImpl: UserRepository {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func getUser(id: Int) async throws -> User {
        let response = try await networkManager.request(
            UserEndpoint.getUser(id: id),
            responseType: User.self,
            cachePolicy: .cacheResponse(expiration: .minutes(5))
        )
        
        return try response.unwrap()
    }
    
    func getUsers() async throws -> [User] {
        let response = try await networkManager.request(
            UserEndpoint.getUsers,
            responseType: [User].self,
            cachePolicy: .cacheResponse(expiration: .minutes(5))
        )
        
        return try response.unwrap()
    }
}
```

### Step 8: Create ViewModel (1 minute)

Create `UserListViewModel.swift`:

```swift
import SwiftUI

@MainActor
class UserListViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: UserRepository
    
    init(repository: UserRepository) {
        self.repository = repository
    }
    
    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            users = try await repository.getUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadUsers()
    }
}
```

### Step 9: Create SwiftUI View (1 minute)

Create `UserListView.swift`:

```swift
import SwiftUI

struct UserListView: View {
    @EnvironmentObject var dependencies: AppDependencies
    @StateObject private var viewModel: UserListViewModel
    
    init() {
        // Initialize with injected dependencies
        let container = DefaultNetworkContainer.shared
        let repository = UserRepositoryImpl(networkManager: container.networkManager)
        _viewModel = StateObject(wrappedValue: UserListViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading users...")
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Task { await viewModel.loadUsers() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    List(viewModel.users) { user in
                        UserRow(user: user)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Users")
            .task {
                await viewModel.loadUsers()
            }
        }
    }
}

struct UserRow: View {
    let user: User
    
    var body: some View {
        HStack {
            if let avatar = user.avatar {
                AsyncImage(url: URL(string: avatar)) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            }
            
            VStack(alignment: .leading) {
                Text(user.name)
                    .font(.headline)
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

### Step 10: Run Your App! (30 seconds)

1. Build and run your app (⌘R)
2. Check the console for network logs
3. See your users loaded from the API!

## 🎉 You're Done!

Your app now has:
- ✅ Complete networking layer
- ✅ Automatic token management
- ✅ Response caching
- ✅ Error handling
- ✅ Network logging
- ✅ Pull-to-refresh

## 🔧 Next Steps

### Configure Authentication

```swift
// After successful login
dependencies.networkContainer.tokenManager.saveTokens(
    accessToken: "your_access_token",
    refreshToken: "your_refresh_token",
    expiresIn: 3600
)

// Check if user is authenticated
if dependencies.networkContainer.tokenManager.isTokenValid {
    // User is logged in
}

// Logout
dependencies.networkContainer.tokenManager.clearTokens()
```

### Switch Environments

```swift
enum Environment {
    case development
    case staging
    case production
    
    var baseURL: String {
        switch self {
        case .development:
            return "https://dev-api.example.com"
        case .staging:
            return "https://staging-api.example.com"
        case .production:
            return "https://api.example.com"
        }
    }
}

// Switch environment
let environment: Environment = .staging
dependencies.networkContainer.configuration.updateBaseURL(environment.baseURL)
```

### Add More Endpoints

```swift
enum ProductEndpoint: Endpoint {
    case getAll
    case getById(id: Int)
    case search(query: String)
    case create(Product)
    
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
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getAll, .getById, .search:
            return .get
        case .create:
            return .post
        }
    }
}
```

### Configure Caching Strategy

```swift
// Cache for 5 minutes (good for frequently accessed data)
cachePolicy: .cacheResponse(expiration: .minutes(5))

// Cache for 1 hour (good for static content)
cachePolicy: .cacheResponse(expiration: .hours(1))

// Never cache (good for sensitive/real-time data)
cachePolicy: .ignoreCache

// Cache-first (good for offline support)
cachePolicy: .returnCacheElseLoad
```

### Handle Offline Mode

```swift
// Check network status
if NetworkMonitor.shared.isConnected {
    // Online - fetch from network
    cachePolicy = .cacheResponse(expiration: .minutes(5))
} else {
    // Offline - use cached data
    cachePolicy = .returnCacheDontLoad
}
```

### Custom Error Handling

```swift
do {
    let user = try await repository.getUser(id: 123)
    // Success
} catch let error as NetworkError {
    switch error {
    case .unauthorized:
        // Redirect to login
        showLoginScreen()
    case .notFound:
        // Show not found message
        showAlert("User not found")
    case .offline:
        // Show offline message
        showOfflineMessage()
    default:
        // Generic error
        showAlert(error.localizedDescription)
    }
} catch {
    // Unknown error
    showAlert("An unexpected error occurred")
}
```

## 📚 Learn More

- [BEST_PRACTICES.md](BEST_PRACTICES.md) - Comprehensive guide
- [README.md](README.md) - Full documentation
- Check the `Examples/` folder for more samples

## 🐛 Troubleshooting

### "No such module 'Alamofire'"
- Make sure you've added Alamofire via Swift Package Manager
- Clean build folder (Shift + ⌘ + K)
- Rebuild project (⌘ + B)

### Network requests not working
- Check your base URL is correct
- Verify your API endpoints
- Check console logs for detailed error messages

### Token not being added to requests
- Make sure you've set the access token:
  ```swift
  tokenManager.accessToken = "your_token"
  ```
- Check if token has expired

### Cache not working
- Verify you're using the correct cache policy
- Check cache expiration settings
- Clear cache if needed:
  ```swift
  dependencies.networkContainer.cacheManager.clear()
  ```

## ✅ Checklist

- [ ] Alamofire installed
- [ ] All networking files copied
- [ ] AppDependencies created and initialized
- [ ] First endpoint created
- [ ] Model defined
- [ ] Repository implemented
- [ ] ViewModel created
- [ ] View integrated
- [ ] App builds successfully
- [ ] API requests working
- [ ] Caching configured
- [ ] Error handling tested

## 🎓 Tips for Success

1. **Start Simple** - Begin with one endpoint and gradually add more
2. **Use Logging** - Enable verbose logging during development
3. **Test Error Cases** - Test offline mode, timeouts, and server errors
4. **Mock for Testing** - Use mock repositories for unit tests
5. **Monitor Performance** - Check request times in console logs

## 💬 Need Help?

- Check the console logs for detailed error messages
- Review the [BEST_PRACTICES.md](BEST_PRACTICES.md) guide
- Look at example implementations in `Examples/` folder

---

**Congratulations!** 🎉 You now have a production-ready networking layer!

**Next:** Read [BEST_PRACTICES.md](BEST_PRACTICES.md) for advanced patterns and optimization techniques.
