# SwiftUI Network Architecture - Best Practices Guide

> **Production-ready networking layer with Alamofire, DI, Interceptors, Logging, Caching, and Dynamic Configuration**

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture Design](#architecture-design)
3. [Core Features](#core-features)
4. [Implementation Guide](#implementation-guide)
5. [Best Practices](#best-practices)
6. [Usage Examples](#usage-examples)
7. [Testing Strategies](#testing-strategies)
8. [Common Pitfalls](#common-pitfalls)

---

## 🎯 Overview

This networking architecture provides a complete, production-ready solution with:

- ✅ **Alamofire Integration** - Modern async/await networking
- ✅ **Dependency Injection** - Protocol-based DI with NetworkContainer
- ✅ **Request Interceptor** - Authentication, retry logic, token refresh
- ✅ **Status Code Handling** - Comprehensive 200-599 HTTP status mapping
- ✅ **Response Models** - Standardized APIResponse with metadata
- ✅ **Caching System** - Multi-layer (memory + disk) with expiration
- ✅ **Network Logger** - Detailed request/response logging
- ✅ **Dynamic Configuration** - Runtime baseURL and accessToken updates
- ✅ **Error Handling** - User-friendly error messages
- ✅ **SwiftUI Ready** - @Environment and @EnvironmentObject support

---

## 🏗 Architecture Design

### Layered Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SwiftUI Views                         │
│  (User Interface, State Display)                        │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                 ViewModels                               │
│  (@Published properties, View logic)                    │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                 Use Cases                                │
│  (Business logic, Domain rules)                         │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│               Repositories                               │
│  (Data operations, Transformations)                     │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│             NetworkManager                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │          Alamofire Session                      │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │     APIRequestInterceptor                │  │   │
│  │  │  - Add Authorization Header              │  │   │
│  │  │  - Retry on 401                          │  │   │
│  │  │  - Token Refresh                         │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │     NetworkLogger (EventMonitor)         │  │   │
│  │  │  - Log Request/Response                  │  │   │
│  │  │  - Performance Metrics                   │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  Components:                                            │
│  • NetworkConfiguration (Dynamic BaseURL)              │
│  • TokenManager (Secure Token Storage)                 │
│  • CacheManager (Memory + Disk Caching)                │
│  • StatusCodeHandler (HTTP Status Mapping)             │
└──────────────────────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                  REST API                                │
└──────────────────────────────────────────────────────────┘
```

### Dependency Injection Container

```
┌─────────────────────────────────────────────────────────┐
│            DefaultNetworkContainer                       │
│  (Singleton, Protocol-based DI)                         │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │  lazy var configuration                        │    │
│  │  → NetworkConfigurationImpl()                  │    │
│  │    • baseURL (dynamic)                         │    │
│  │    • apiVersion                                │    │
│  │    • timeout                                   │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │  lazy var tokenManager                         │    │
│  │  → KeychainTokenManager()                      │    │
│  │    • accessToken (dynamic, secure)             │    │
│  │    • refreshToken                              │    │
│  │    • save/retrieve/delete                      │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │  lazy var cacheManager                         │    │
│  │  → NetworkCacheManager()                       │    │
│  │    • Memory cache (NSCache)                    │    │
│  │    • Disk cache (FileManager)                  │    │
│  │    • Expiration policies                       │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │  lazy var networkManager                       │    │
│  │  → AlamofireNetworkManager(...)                │    │
│  │    • request<T>()                              │    │
│  │    • upload<T>()                               │    │
│  └────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

---

## ⚡ Core Features

### 1. Response Model Structure

All API responses follow a standardized format:

```swift
struct APIResponse<T: Decodable>: Decodable {
    let isSuccess: Bool        // Operation success status
    let message: String?       // User-friendly message
    let messages: [String]?    // Multiple messages (errors, warnings)
    let createdAt: Date?       // Response timestamp
    let data: T?               // Generic payload
    let meta: ResponseMeta?    // Pagination, etc.
}
```

**Benefits:**
- Consistent error handling across the app
- Built-in timestamp for debugging
- Support for multiple error messages
- Type-safe generic data payload
- Optional metadata for pagination

### 2. Request Interceptor

Automatically handles:
- **Authorization** - Adds Bearer token to all requests
- **Retry Logic** - Retries failed requests (3 attempts)
- **Token Refresh** - Auto-refreshes expired tokens
- **Common Headers** - Adds API version, device ID, etc.

```swift
// Automatic flow:
Request → Add Token → Send → 401? → Refresh Token → Retry → Success
```

### 3. Status Code Handling

Comprehensive HTTP status code mapping (200-599):

| Status Code | Error Type | User Message |
|------------|-----------|--------------|
| 200-299 | Success | - |
| 400 | Bad Request | "Invalid request. Please check your input." |
| 401 | Unauthorized | "Please log in again." |
| 403 | Forbidden | "You don't have permission." |
| 404 | Not Found | "The requested resource was not found." |
| 408 | Timeout | "Request timed out. Please try again." |
| 429 | Rate Limit | "Too many requests. Please wait." |
| 500-599 | Server Error | "Server error. Please try again later." |

### 4. Multi-Layer Caching

**Memory Cache (NSCache):**
- Fast access
- Automatic memory management
- LRU eviction

**Disk Cache (FileManager):**
- Persistent storage
- Size limits
- Custom expiration

**Cache Policies:**
```swift
enum CachePolicy {
    case ignoreCache                 // Always fetch fresh
    case returnCacheElseLoad         // Cache-first
    case returnCacheDontLoad         // Cache-only
    case cacheResponse(expiration:)  // Cache after fetch
}
```

### 5. Network Logger

Logs every request/response with:
- HTTP method and URL
- Request headers and body
- Response status code
- Response body (pretty-printed JSON)
- Timing metrics (duration)
- Error details

**Example Output:**
```
📤 REQUEST: GET https://api.example.com/users/123
Headers: ["Authorization": "Bearer xxx", "Content-Type": "application/json"]
Body: nil

📥 RESPONSE: 200 OK (0.245s)
Body: {
  "isSuccess": true,
  "data": { "id": 123, "name": "John" }
}
```

### 6. Dynamic Configuration

**Update Base URL at Runtime:**
```swift
container.configuration.updateBaseURL("https://staging-api.example.com")
```

**Update Access Token:**
```swift
container.tokenManager.accessToken = "new_token_here"
```

**Use Cases:**
- Switch between environments (dev, staging, prod)
- A/B testing different API endpoints
- Feature flags
- Multi-tenant applications

---

## 🛠 Implementation Guide

### Step 1: Add Alamofire Dependency

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

### Step 2: Project Structure

```
YourApp/
├── Core/
│   ├── Networking/
│   │   ├── NetworkManager.swift           # Main manager
│   │   ├── APIModels.swift                # Response models
│   │   ├── APIRequestInterceptor.swift    # Interceptor
│   │   ├── StatusCodeHandler.swift        # Status handling
│   │   ├── CacheManager.swift             # Caching
│   │   ├── NetworkLogger.swift            # Logging
│   │   ├── NetworkConfiguration.swift     # Configuration
│   │   └── Endpoint.swift                 # Endpoint protocol
│   └── DI/
│       └── NetworkContainer.swift         # DI container
├── Data/
│   └── Repositories/
│       └── UserRepository.swift           # Example repo
├── Domain/
│   └── UseCases/
│       └── UserUseCases.swift             # Business logic
└── Presentation/
    ├── ViewModels/
    │   └── UserViewModel.swift            # View model
    └── Views/
        └── UserView.swift                 # SwiftUI view
```

### Step 3: Initialize Container

```swift
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
        // Configure on app launch
        networkContainer.configuration.updateBaseURL("https://api.example.com")
    }
}
```

### Step 4: Create Repository

```swift
protocol UserRepository {
    func getUser(id: Int) async throws -> User
    func updateUser(_ user: User) async throws -> User
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
        
        guard let user = response.data else {
            throw NetworkError.noData
        }
        
        return user
    }
    
    func updateUser(_ user: User) async throws -> User {
        let response = try await networkManager.request(
            UserEndpoint.updateUser(user),
            responseType: User.self,
            cachePolicy: .ignoreCache
        )
        
        guard let updatedUser = response.data else {
            throw NetworkError.noData
        }
        
        return updatedUser
    }
}
```

### Step 5: Create ViewModel

```swift
@MainActor
class UserViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userRepository: UserRepository
    
    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }
    
    func loadUser(id: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            user = try await userRepository.getUser(id: id)
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }
        
        isLoading = false
    }
}
```

### Step 6: Use in SwiftUI View

```swift
struct UserProfileView: View {
    @EnvironmentObject var dependencies: AppDependencies
    @StateObject private var viewModel: UserViewModel
    
    init(userId: Int) {
        _viewModel = StateObject(wrappedValue: UserViewModel(
            userRepository: UserRepositoryImpl(
                networkManager: dependencies.networkContainer.networkManager
            )
        ))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                ErrorView(message: errorMessage)
            } else if let user = viewModel.user {
                UserDetailView(user: user)
            }
        }
        .task {
            await viewModel.loadUser(id: userId)
        }
    }
}
```

---

## ✨ Best Practices

### 1. Error Handling

**DO:**
```swift
do {
    let response = try await networkManager.request(...)
    guard let data = response.data else {
        throw NetworkError.noData
    }
    return data
} catch let error as NetworkError {
    // Handle specific network errors
    logger.error("Network error: \(error)")
    throw error
} catch {
    // Handle unexpected errors
    logger.error("Unexpected error: \(error)")
    throw NetworkError.unknown(error)
}
```

**DON'T:**
```swift
// Don't swallow errors
do {
    let response = try await networkManager.request(...)
    return response.data
} catch {
    return nil  // ❌ Lost error context
}
```

### 2. Caching Strategy

**Cache static/rarely-changing data:**
```swift
// Good for: User profiles, app config, product catalogs
cachePolicy: .cacheResponse(expiration: .minutes(15))
```

**Don't cache dynamic/sensitive data:**
```swift
// Good for: Orders, payments, real-time data
cachePolicy: .ignoreCache
```

**Use cache-first for offline support:**
```swift
// Try cache first, fallback to network
cachePolicy: .returnCacheElseLoad
```

### 3. Token Management

**DO:**
```swift
// Store tokens securely
tokenManager.accessToken = token  // → Keychain
tokenManager.refreshToken = refreshToken
```

**DON'T:**
```swift
// Don't store in UserDefaults (insecure)
UserDefaults.standard.set(token, forKey: "token")  // ❌
```

### 4. Request Deduplication

**DO:**
```swift
// Use Task to prevent duplicate requests
private var loadTask: Task<Void, Never>?

func loadData() {
    loadTask?.cancel()
    loadTask = Task {
        await performRequest()
    }
}
```

**DON'T:**
```swift
// Don't fire multiple concurrent requests
func loadData() {
    Task { await performRequest() }  // ❌ Can create duplicates
}
```

### 5. Type Safety

**DO:**
```swift
// Use strongly-typed endpoints
enum UserEndpoint: Endpoint {
    case getUser(id: Int)
    case updateUser(User)
}
```

**DON'T:**
```swift
// Don't use string URLs everywhere
func getUser(id: Int) {
    let url = "https://api.example.com/users/\(id)"  // ❌
}
```

### 6. Logging Levels

**Production:**
```swift
// Only log errors
NetworkLogger.level = .error
```

**Development:**
```swift
// Log everything for debugging
NetworkLogger.level = .verbose
```

### 7. Memory Management

**DO:**
```swift
// Use weak self in closures
Task { [weak self] in
    guard let self = self else { return }
    await self.loadData()
}
```

**DON'T:**
```swift
// Don't create retain cycles
Task {
    self.loadData()  // ⚠️ Potential retain cycle
}
```

### 8. Dependency Injection

**DO:**
```swift
// Inject dependencies via initializers
class UserViewModel {
    private let repository: UserRepository
    
    init(repository: UserRepository) {
        self.repository = repository
    }
}
```

**DON'T:**
```swift
// Don't hard-code dependencies
class UserViewModel {
    private let repository = UserRepositoryImpl()  // ❌ Hard to test
}
```

---

## 📖 Usage Examples

### Example 1: Simple GET Request

```swift
// 1. Define endpoint
enum ProductEndpoint: Endpoint {
    case getProduct(id: Int)
    
    var path: String {
        switch self {
        case .getProduct(let id):
            return "/products/\(id)"
        }
    }
    
    var method: HTTPMethod { .get }
}

// 2. Make request in repository
func getProduct(id: Int) async throws -> Product {
    let response = try await networkManager.request(
        ProductEndpoint.getProduct(id: id),
        responseType: Product.self,
        cachePolicy: .cacheResponse(expiration: .minutes(10))
    )
    
    return try response.unwrap()  // Throws if data is nil
}
```

### Example 2: POST with Body

```swift
// 1. Define endpoint
enum AuthEndpoint: Endpoint {
    case login(email: String, password: String)
    
    var path: String { "/auth/login" }
    var method: HTTPMethod { .post }
    
    var parameters: Parameters? {
        switch self {
        case .login(let email, let password):
            return ["email": email, "password": password]
        }
    }
    
    var encoding: ParameterEncoding {
        JSONEncoding.default
    }
}

// 2. Make request
func login(email: String, password: String) async throws -> AuthToken {
    let response = try await networkManager.request(
        AuthEndpoint.login(email: email, password: password),
        responseType: AuthToken.self,
        cachePolicy: .ignoreCache
    )
    
    guard let token = response.data else {
        throw NetworkError.noData
    }
    
    // Save token for future requests
    tokenManager.accessToken = token.accessToken
    tokenManager.refreshToken = token.refreshToken
    
    return token
}
```

### Example 3: Upload File

```swift
func uploadAvatar(imageData: Data) async throws -> String {
    let response = try await networkManager.upload(
        UserEndpoint.uploadAvatar,
        data: imageData,
        responseType: UploadResponse.self
    )
    
    guard let imageUrl = response.data?.url else {
        throw NetworkError.noData
    }
    
    return imageUrl
}
```

### Example 4: Pagination

```swift
func getProducts(page: Int, limit: Int = 20) async throws -> PaginatedResponse<Product> {
    let response = try await networkManager.request(
        ProductEndpoint.getAll(page: page, limit: limit),
        responseType: PaginatedResponse<Product>.self,
        cachePolicy: .ignoreCache
    )
    
    guard let data = response.data else {
        throw NetworkError.noData
    }
    
    return data
}

// Usage in ViewModel
func loadMoreProducts() async {
    guard !isLoading && hasMorePages else { return }
    
    isLoading = true
    currentPage += 1
    
    do {
        let result = try await repository.getProducts(page: currentPage)
        products.append(contentsOf: result.items)
        hasMorePages = result.hasMore
    } catch {
        errorMessage = error.localizedDescription
    }
    
    isLoading = false
}
```

### Example 5: Search with Debouncing

```swift
@Published var searchText = ""
private var searchTask: Task<Void, Never>?

func searchProducts() {
    // Cancel previous search
    searchTask?.cancel()
    
    // Debounce 500ms
    searchTask = Task {
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard !Task.isCancelled else { return }
        
        await performSearch()
    }
}

private func performSearch() async {
    guard !searchText.isEmpty else {
        products = []
        return
    }
    
    do {
        products = try await repository.searchProducts(query: searchText)
    } catch {
        errorMessage = error.localizedDescription
    }
}

// In SwiftUI View
TextField("Search", text: $viewModel.searchText)
    .onChange(of: viewModel.searchText) { _ in
        viewModel.searchProducts()
    }
```

---

## 🧪 Testing Strategies

### 1. Mock NetworkManager

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
        
        if let response = mockResponse as? APIResponse<T> {
            return response
        }
        
        throw NetworkError.unknown(NSError(domain: "", code: 0))
    }
}
```

### 2. Test Repository

```swift
final class UserRepositoryTests: XCTestCase {
    var sut: UserRepositoryImpl!
    var mockNetworkManager: MockNetworkManager!
    
    override func setUp() {
        super.setUp()
        mockNetworkManager = MockNetworkManager()
        sut = UserRepositoryImpl(networkManager: mockNetworkManager)
    }
    
    func testGetUser_Success() async throws {
        // Given
        let expectedUser = User(id: 1, name: "John")
        mockNetworkManager.mockResponse = APIResponse(
            isSuccess: true,
            message: nil,
            messages: nil,
            createdAt: Date(),
            data: expectedUser,
            meta: nil
        )
        
        // When
        let user = try await sut.getUser(id: 1)
        
        // Then
        XCTAssertEqual(user.id, expectedUser.id)
        XCTAssertEqual(user.name, expectedUser.name)
    }
    
    func testGetUser_NetworkError() async {
        // Given
        mockNetworkManager.mockError = NetworkError.unauthorized
        
        // When/Then
        do {
            _ = try await sut.getUser(id: 1)
            XCTFail("Should throw error")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }
}
```

### 3. Test ViewModel

```swift
@MainActor
final class UserViewModelTests: XCTestCase {
    var sut: UserViewModel!
    var mockRepository: MockUserRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockUserRepository()
        sut = UserViewModel(userRepository: mockRepository)
    }
    
    func testLoadUser_Success() async {
        // Given
        let expectedUser = User(id: 1, name: "John")
        mockRepository.mockUser = expectedUser
        
        // When
        await sut.loadUser(id: 1)
        
        // Then
        XCTAssertEqual(sut.user?.id, expectedUser.id)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testLoadUser_Error() async {
        // Given
        mockRepository.mockError = NetworkError.notFound
        
        // When
        await sut.loadUser(id: 1)
        
        // Then
        XCTAssertNil(sut.user)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
}
```

---

## ⚠️ Common Pitfalls

### 1. Not Handling Main Actor

**Problem:**
```swift
// ❌ Crash: Publishing changes from background thread
Task {
    isLoading = true  // Crash if not on main actor
}
```

**Solution:**
```swift
// ✅ Use @MainActor
@MainActor
class ViewModel: ObservableObject {
    @Published var isLoading = false
}

// Or explicitly dispatch
Task { @MainActor in
    isLoading = true
}
```

### 2. Memory Leaks with Strong References

**Problem:**
```swift
// ❌ Retain cycle
Task {
    self.data = try await repository.getData()  // Strong reference
}
```

**Solution:**
```swift
// ✅ Use weak/unowned
Task { [weak self] in
    guard let self = self else { return }
    self.data = try await repository.getData()
}
```

### 3. Ignoring Token Expiration

**Problem:**
```swift
// ❌ Token expires, app breaks
tokenManager.accessToken = token
// Never refreshed!
```

**Solution:**
```swift
// ✅ Interceptor handles automatically
// But also implement manual refresh:
func refreshTokenIfNeeded() async {
    if tokenManager.isTokenExpired {
        try? await authRepository.refreshToken()
    }
}
```

### 4. Over-Caching

**Problem:**
```swift
// ❌ Caching everything, including sensitive data
cachePolicy: .cacheResponse(expiration: .hours(24))  // For payment data!
```

**Solution:**
```swift
// ✅ Don't cache sensitive data
cachePolicy: .ignoreCache  // For payments, orders, personal data
```

### 5. Not Cancelling Tasks

**Problem:**
```swift
// ❌ Multiple concurrent requests
func search() {
    Task {
        await performSearch()  // Creates new task every time
    }
}
```

**Solution:**
```swift
// ✅ Cancel previous task
private var searchTask: Task<Void, Never>?

func search() {
    searchTask?.cancel()
    searchTask = Task {
        await performSearch()
    }
}
```

### 6. Blocking Main Thread

**Problem:**
```swift
// ❌ Synchronous network call on main thread
func loadData() {
    let data = try! networkManager.requestSync()  // Blocks UI
}
```

**Solution:**
```swift
// ✅ Always use async/await
func loadData() async {
    let data = try await networkManager.request(...)
}
```

### 7. Not Validating Response Data

**Problem:**
```swift
// ❌ Force unwrap
let user = response.data!  // Crashes if nil
```

**Solution:**
```swift
// ✅ Safely unwrap
guard let user = response.data else {
    throw NetworkError.noData
}
```

---

## 📚 Additional Resources

### Official Documentation
- [Alamofire Documentation](https://github.com/Alamofire/Alamofire)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [SwiftUI Environment](https://developer.apple.com/documentation/swiftui/environment)

### Recommended Reading
- "Clean Architecture" by Robert C. Martin
- "Design Patterns" - Gang of Four
- "iOS Design Patterns" by Raywenderlich

### Tools
- **Charles Proxy** - HTTP debugging
- **Postman** - API testing
- **Xcode Instruments** - Performance profiling

---

## ✅ Implementation Checklist

Use this checklist to ensure complete implementation:

- [ ] Alamofire added to project (SPM or CocoaPods)
- [ ] All core networking files copied
- [ ] NetworkContainer initialized in App
- [ ] Base URL configured
- [ ] Token manager integrated
- [ ] Endpoints defined for your API
- [ ] Repositories created for data layer
- [ ] Use cases implemented for business logic
- [ ] ViewModels created with @Published properties
- [ ] SwiftUI views integrated with @EnvironmentObject
- [ ] Error handling implemented throughout
- [ ] Caching strategy defined per endpoint
- [ ] Logging configured (off in production)
- [ ] Unit tests written for repositories
- [ ] Integration tests for critical flows
- [ ] Token refresh tested
- [ ] Offline behavior tested
- [ ] Memory leaks checked with Instruments

---

## 🎯 Summary

This networking architecture provides:

1. **Type Safety** - Compile-time safety with generics and protocols
2. **Testability** - Easy mocking with protocol-based DI
3. **Maintainability** - Clear separation of concerns
4. **Performance** - Multi-layer caching and request optimization
5. **Security** - Keychain token storage, automatic token refresh
6. **Observability** - Comprehensive logging and error tracking
7. **Flexibility** - Dynamic configuration, easy to extend
8. **SwiftUI Native** - Built for modern SwiftUI apps

**Key Principles:**
- Protocol-oriented design
- Dependency injection
- Separation of concerns
- Single responsibility
- Error handling first
- Type safety everywhere

---

**Version:** 1.0.0  
**Last Updated:** November 7, 2025  
**Author:** Enterprise iOS Team
