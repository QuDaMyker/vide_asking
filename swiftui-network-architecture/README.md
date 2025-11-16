# SwiftUI Network Architecture

> **Production-ready networking layer for SwiftUI applications with Alamofire, DI, Interceptors, Caching, and Dynamic Configuration**

[![Swift Version](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2015.0+-lightgrey.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 📋 Overview

A comprehensive, production-ready networking architecture that provides:

- ✅ **Alamofire Integration** - Modern async/await API with Alamofire 5.8+
- ✅ **Dependency Injection** - Protocol-based DI container for easy testing
- ✅ **Request Interceptor** - Auto token management, retry logic, and refresh
- ✅ **Status Code Handling** - Comprehensive HTTP 200-599 error mapping
- ✅ **Response Models** - Standardized `APIResponse<T>` with metadata
- ✅ **Multi-Layer Caching** - Memory + Disk with expiration policies
- ✅ **Network Logger** - Detailed request/response logging with metrics
- ✅ **Dynamic Configuration** - Runtime base URL and token updates
- ✅ **SwiftUI Ready** - Environment and ObservableObject support
- ✅ **Offline Support** - Network reachability monitoring

## 🚀 Quick Start

### 1. Add Alamofire Dependency

**Swift Package Manager:**
```swift
dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
]
```

**Xcode:**
1. File → Add Packages
2. URL: `https://github.com/Alamofire/Alamofire.git`
3. Version: 5.8.0+

### 2. Copy Files to Your Project

```
YourApp/
├── Core/
│   ├── Networking/
│   │   ├── NetworkManager.swift           # API Client (GET/POST/PUT/PATCH/DELETE)
│   │   ├── APIModels.swift                # Response models
│   │   ├── APIRequestInterceptor.swift    # Auth interceptor
│   │   ├── StatusCodeHandler.swift        # Status code handling
│   │   ├── CacheManager.swift             # Caching system
│   │   ├── NetworkLogger.swift            # Request/response logging
│   │   ├── NetworkConfiguration.swift     # Dynamic baseURL & tokens
│   │   └── Endpoint.swift                 # Endpoint definitions
│   └── DI/
│       └── NetworkContainer.swift         # Dependency injection
└── Examples/
    └── UsageExamples.swift                # Complete usage examples
```

### 3. Initialize in Your App

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

class AppDependencies: ObservableObject {
    let networkContainer = DefaultNetworkContainer.shared
    
    init() {
        // Configure on startup
        networkContainer.configuration.updateBaseURL("https://api.example.com")
        
        // Optional: Set logging level
        #if DEBUG
        NetworkLogger.shared.logLevel = .verbose
        #else
        NetworkLogger.shared.logLevel = .error
        #endif
    }
}
```

### 4. Make Your First Request

```swift
// Define your endpoint
enum UserEndpoint: Endpoint {
    case getUser(id: Int)
    case updateProfile(User)
    
    var path: String {
        switch self {
        case .getUser(let id):
            return "/users/\(id)"
        case .updateProfile:
            return "/users/profile"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getUser:
            return .get
        case .updateProfile:
            return .put
        }
    }
}

// Create repository
class UserRepository {
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
}

// Use in ViewModel
@MainActor
class UserViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: UserRepository
    
    init(repository: UserRepository) {
        self.repository = repository
    }
    
    func loadUser(id: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            user = try await repository.getUser(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// SwiftUI View
struct UserProfileView: View {
    @StateObject private var viewModel: UserViewModel
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error)
            } else if let user = viewModel.user {
                UserDetailView(user: user)
            }
        }
        .task {
            await viewModel.loadUser(id: 123)
        }
    }
}
```

## 📦 Core Features

### Response Model Structure

All API responses follow a standardized format:

```swift
struct APIResponse<T: Decodable>: Decodable {
    let isSuccess: Bool        // Operation success status
    let message: String?       // User-friendly message
    let messages: [String]?    // Multiple messages (errors, warnings)
    let createdAt: Date?       // Response timestamp
    let data: T?               // Generic payload
    let meta: ResponseMeta?    // Pagination, rate limits, etc.
}
```

**Example Response:**
```json
{
  "isSuccess": true,
  "message": "User retrieved successfully",
  "created_at": "2025-11-07T10:30:00Z",
  "data": {
    "id": 123,
    "name": "John Doe",
    "email": "john@example.com"
  },
  "meta": {
    "version": "v1"
  }
}
```

### Request Interceptor

Automatically handles:
- **Authorization** - Adds Bearer token to all requests
- **Retry Logic** - Retries failed requests with exponential backoff
- **Token Refresh** - Auto-refreshes expired tokens on 401
- **Common Headers** - Adds API version, device ID, etc.

```swift
// Flow: Request → Add Token → Send → 401? → Refresh Token → Retry → Success
```

### Status Code Handling

Comprehensive HTTP status code handling (200-599):

| Code | Type | Message |
|------|------|---------|
| 200-299 | Success | - |
| 400 | Bad Request | "Invalid request. Please check your input." |
| 401 | Unauthorized | "Your session has expired. Please log in again." |
| 403 | Forbidden | "You don't have permission." |
| 404 | Not Found | "The requested resource was not found." |
| 408 | Timeout | "Request timed out." |
| 429 | Rate Limit | "Too many requests. Please wait." |
| 500-599 | Server Error | "Server error. Please try again later." |

### Multi-Layer Caching

**Memory Cache:**
- Fast access via NSCache
- Automatic memory management
- LRU eviction

**Disk Cache:**
- Persistent storage
- Size limits (200 MB default)
- Automatic cleanup of expired entries

**Cache Policies:**
```swift
.ignoreCache                // Always fetch fresh
.returnCacheElseLoad        // Cache-first strategy
.returnCacheDontLoad        // Cache-only (offline mode)
.cacheResponse(expiration:) // Cache after successful fetch
```

### Network Logger

Logs every request/response with:
- HTTP method and URL
- Request/response headers
- Request/response body (pretty-printed JSON)
- Response status code
- Timing metrics
- Error details

**Example Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📤 REQUEST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔹 GET https://api.example.com/users/123
📋 Headers:
   Authorization: Bearer ***
   Content-Type: application/json
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ RESPONSE: 200 OK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔹 GET https://api.example.com/users/123
⏱️  Duration: 0.245s
📦 Response Body:
   {
     "isSuccess": true,
     "data": { "id": 123, "name": "John" }
   }
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Dynamic Configuration

Update base URL and tokens at runtime:

```swift
let container = DefaultNetworkContainer.shared

// Switch environments
container.configuration.updateBaseURL("https://staging-api.example.com")

// Update access token after login
container.tokenManager.accessToken = "new_token"

// Clear tokens on logout
container.tokenManager.clearTokens()
```

## 🏗 Architecture

### Layered Architecture

```
SwiftUI Views
    ↓
ViewModels (@Published)
    ↓
Use Cases (Business Logic)
    ↓
Repositories (Data Layer)
    ↓
NetworkManager (Alamofire)
    ↓
API
```

### Dependency Injection

```swift
protocol NetworkContainer {
    var networkManager: NetworkManager { get }
    var configuration: NetworkConfiguration { get }
    var cacheManager: CacheManager { get }
    var tokenManager: TokenManager { get }
}

class DefaultNetworkContainer: NetworkContainer {
    static let shared = DefaultNetworkContainer()
    
    lazy var configuration = NetworkConfigurationImpl()
    lazy var tokenManager = KeychainTokenManager()
    lazy var cacheManager = NetworkCacheManager()
    lazy var networkManager = AlamofireNetworkManager(...)
}
```

## 📖 Usage Examples

### Example 1: GET Request with Caching

```swift
func getProducts() async throws -> [Product] {
    let response = try await networkManager.request(
        ProductEndpoint.getAll,
        responseType: [Product].self,
        cachePolicy: .cacheResponse(expiration: .minutes(10))
    )
    
    return try response.unwrap()
}
```

### Example 2: POST Request

```swift
func createUser(_ user: User) async throws -> User {
    let response = try await networkManager.request(
        UserEndpoint.create(user),
        responseType: User.self,
        cachePolicy: .ignoreCache
    )
    
    return try response.unwrap()
}
```

### Example 3: Upload File

```swift
func uploadAvatar(_ imageData: Data) async throws -> String {
    let response = try await networkManager.upload(
        UserEndpoint.uploadAvatar,
        data: imageData,
        responseType: UploadResponse.self
    )
    
    return try response.unwrap().url
}
```

### Example 4: Search with Debouncing

```swift
@Published var searchText = ""
private var searchTask: Task<Void, Never>?

func search() {
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
        guard !Task.isCancelled else { return }
        await performSearch()
    }
}
```

## 🧪 Testing

### Mock NetworkManager

```swift
class MockNetworkManager: NetworkManager {
    var mockResponse: Any?
    var mockError: Error?
    
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        cachePolicy: CachePolicy
    ) async throws -> APIResponse<T> {
        if let error = mockError {
            throw error
        }
        return mockResponse as! APIResponse<T>
    }
}
```

### Unit Test Example

```swift
final class UserRepositoryTests: XCTestCase {
    func testGetUser_Success() async throws {
        let mockManager = MockNetworkManager()
        mockManager.mockResponse = APIResponse(
            isSuccess: true,
            data: User(id: 1, name: "John")
        )
        
        let repository = UserRepositoryImpl(networkManager: mockManager)
        let user = try await repository.getUser(id: 1)
        
        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.name, "John")
    }
}
```

## ⚙️ Configuration

### Environment Setup

```swift
// Configure for different environments
enum AppEnvironment {
    case development
    case staging
    case production
    
    var baseURL: String {
        switch self {
        case .development: return "https://dev-api.example.com"
        case .staging: return "https://staging-api.example.com"
        case .production: return "https://api.example.com"
        }
    }
}

// Set on app launch
let environment: AppEnvironment = .development
container.configuration.updateBaseURL(environment.baseURL)
```

### Logging Levels

```swift
#if DEBUG
NetworkLogger.shared.logLevel = .verbose  // Log everything
#else
NetworkLogger.shared.logLevel = .error    // Only errors
#endif
```

### Cache Configuration

```swift
let cacheManager = NetworkCacheManager(
    maxMemoryCost: 50 * 1024 * 1024,  // 50 MB
    maxDiskSize: 200 * 1024 * 1024     // 200 MB
)
```

## 📚 Documentation

- [BEST_PRACTICES.md](BEST_PRACTICES.md) - Comprehensive best practices guide
- [QUICK_START.md](QUICK_START.md) - Step-by-step setup instructions
- See `Examples/` folder for complete sample implementations

## ✅ Requirements Checklist

| Feature | Status | File |
|---------|--------|------|
| Alamofire Integration | ✅ | NetworkManager.swift |
| Dependency Injection | ✅ | NetworkContainer.swift |
| Request Interceptor | ✅ | APIRequestInterceptor.swift |
| Status Code Handling | ✅ | StatusCodeHandler.swift |
| Response Models | ✅ | APIModels.swift |
| Multi-Layer Caching | ✅ | CacheManager.swift |
| Network Logger | ✅ | NetworkLogger.swift |
| Dynamic Base URL | ✅ | NetworkConfiguration.swift |
| Dynamic Access Token | ✅ | NetworkConfiguration.swift |
| Token Refresh | ✅ | APIRequestInterceptor.swift |
| Offline Support | ✅ | NetworkConfiguration.swift |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is available under the MIT license. See the LICENSE file for more info.

## 📞 Support

For questions or issues, please create an issue on GitHub.

---

**Version:** 1.0.0  
**Last Updated:** November 7, 2025  
**Swift Version:** 5.9+  
**Platform:** iOS 15.0+
