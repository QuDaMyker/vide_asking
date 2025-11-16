# API Reference - Network Architecture

> Complete reference for the SwiftUI Network Architecture

## 📚 Table of Contents

- [NetworkManager](#networkmanager)
- [Endpoint Protocol](#endpoint-protocol)
- [HTTP Methods](#http-methods)
- [Cache Policies](#cache-policies)
- [Network Configuration](#network-configuration)
- [Token Manager](#token-manager)
- [Error Handling](#error-handling)

---

## NetworkManager

The main interface for making network requests.

### Protocol

```swift
protocol NetworkManager {
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        cachePolicy: CachePolicy
    ) async throws -> APIResponse<T>
    
    func upload<T: Decodable>(
        _ endpoint: Endpoint,
        data: Data,
        responseType: T.Type
    ) async throws -> APIResponse<T>
    
    func download(
        _ endpoint: Endpoint,
        to destination: URL
    ) async throws
}
```

### Convenience Methods

#### GET Request

```swift
func get<T: Decodable>(
    _ endpoint: Endpoint,
    responseType: T.Type,
    cachePolicy: CachePolicy = .ignoreCache
) async throws -> APIResponse<T>
```

**Example:**
```swift
let response = try await networkManager.get(
    UserEndpoint.getUser(id: 123),
    responseType: User.self,
    cachePolicy: .cacheResponse(expiration: .minutes(5))
)
```

#### POST Request

```swift
func post<T: Decodable>(
    _ endpoint: Endpoint,
    responseType: T.Type
) async throws -> APIResponse<T>
```

**Example:**
```swift
let response = try await networkManager.post(
    AuthEndpoint.login(email: "user@example.com", password: "password"),
    responseType: AuthResponse.self
)
```

#### PUT Request

```swift
func put<T: Decodable>(
    _ endpoint: Endpoint,
    responseType: T.Type
) async throws -> APIResponse<T>
```

**Example:**
```swift
let response = try await networkManager.put(
    UserEndpoint.updateUser(id: 123, name: "New Name", email: nil),
    responseType: User.self
)
```

#### PATCH Request

```swift
func patch<T: Decodable>(
    _ endpoint: Endpoint,
    responseType: T.Type
) async throws -> APIResponse<T>
```

**Example:**
```swift
let response = try await networkManager.patch(
    OrderEndpoint.updateStatus(id: 456, status: "shipped"),
    responseType: EmptyResponse.self
)
```

#### DELETE Request

```swift
func delete<T: Decodable>(
    _ endpoint: Endpoint,
    responseType: T.Type
) async throws -> APIResponse<T>

// Or without response
func delete(_ endpoint: Endpoint) async throws
```

**Example:**
```swift
// With response
let response = try await networkManager.delete(
    UserEndpoint.deleteUser(id: 123),
    responseType: EmptyResponse.self
)

// Without response
try await networkManager.delete(UserEndpoint.deleteUser(id: 123))
```

---

## Endpoint Protocol

Define your API endpoints by conforming to the `Endpoint` protocol.

### Required Properties

```swift
protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var parameters: Parameters? { get }
    var headers: HTTPHeaders? { get }
    var encoding: ParameterEncoding { get }
    var cacheKey: String { get }
}
```

### Example Implementation

```swift
enum UserEndpoint: Endpoint {
    case getUser(id: Int)
    case createUser(name: String, email: String)
    case updateUser(id: Int, name: String?, email: String?)
    case deleteUser(id: Int)
    
    var path: String {
        switch self {
        case .getUser(let id):
            return "/users/\(id)"
        case .createUser:
            return "/users"
        case .updateUser(let id, _, _):
            return "/users/\(id)"
        case .deleteUser(let id):
            return "/users/\(id)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getUser:
            return .get
        case .createUser:
            return .post
        case .updateUser:
            return .put
        case .deleteUser:
            return .delete
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .getUser, .deleteUser:
            return nil
        case .createUser(let name, let email):
            return ["name": name, "email": email]
        case .updateUser(_, let name, let email):
            var params: Parameters = [:]
            if let name = name { params["name"] = name }
            if let email = email { params["email"] = email }
            return params.isEmpty ? nil : params
        }
    }
}
```

---

## HTTP Methods

All standard HTTP methods are supported.

### Available Methods

| Method | Use Case | Example |
|--------|----------|---------|
| **GET** | Retrieve data | Fetch user profile, list products |
| **POST** | Create new resource | Register user, create order |
| **PUT** | Replace entire resource | Update user profile completely |
| **PATCH** | Partial update | Update user email only |
| **DELETE** | Remove resource | Delete user account, remove product |

### Usage

```swift
import Alamofire

var method: HTTPMethod {
    switch self {
    case .fetch:
        return .get
    case .create:
        return .post
    case .update:
        return .put
    case .partialUpdate:
        return .patch
    case .remove:
        return .delete
    }
}
```

---

## Cache Policies

Control how responses are cached.

### Available Policies

#### 1. ignoreCache
Always fetch fresh data from the network. Don't use or save cache.

**Use for:** Sensitive data, real-time information

```swift
cachePolicy: .ignoreCache
```

#### 2. returnCacheElseLoad
Return cached data if available, otherwise load from network.

**Use for:** Offline support, improve UX

```swift
cachePolicy: .returnCacheElseLoad
```

#### 3. returnCacheDontLoad
Return only cached data, never make network request.

**Use for:** Offline-only mode

```swift
cachePolicy: .returnCacheDontLoad
```

#### 4. cacheResponse(expiration:)
Fetch from network and cache the response with expiration.

**Use for:** Frequently accessed, relatively static data

```swift
// Cache for 5 minutes
cachePolicy: .cacheResponse(expiration: .minutes(5))

// Cache for 1 hour
cachePolicy: .cacheResponse(expiration: .hours(1))

// Cache for 1 day
cachePolicy: .cacheResponse(expiration: .days(1))

// Never expire
cachePolicy: .cacheResponse(expiration: .never)
```

### Expiration Options

```swift
enum CacheExpiration {
    case never
    case seconds(TimeInterval)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case date(Date)
}
```

**Examples:**
```swift
.seconds(30)                    // 30 seconds
.minutes(5)                     // 5 minutes
.hours(2)                       // 2 hours
.days(7)                        // 7 days
.date(Date().addingTimeInterval(3600))  // Specific date
.never                          // Never expires
```

---

## Network Configuration

Manage base URLs, timeouts, and headers dynamically.

### Properties

```swift
protocol NetworkConfiguration: AnyObject {
    var baseURL: String { get set }
    var apiVersion: String { get }
    var timeout: TimeInterval { get }
    var headers: [String: String] { get }
    
    func updateBaseURL(_ url: String)
    func reset()
}
```

### Usage

#### Update Base URL

```swift
let container = DefaultNetworkContainer.shared

// Update to staging
container.configuration.updateBaseURL("https://staging-api.example.com")

// Update to production
container.configuration.updateBaseURL("https://api.example.com")
```

#### Environment Management

```swift
enum AppEnvironment {
    case development
    case staging
    case production
    case custom(String)
    
    var baseURL: String {
        switch self {
        case .development:
            return "https://dev-api.example.com"
        case .staging:
            return "https://staging-api.example.com"
        case .production:
            return "https://api.example.com"
        case .custom(let url):
            return url
        }
    }
}

// Switch environments
let dependencies = AppDependencies()
dependencies.setEnvironment(.staging)
```

### Common Headers

Headers automatically added to all requests:
- `Content-Type: application/json`
- `Accept: application/json`
- `API-Version: v1` (configurable)
- `Authorization: Bearer <token>` (if token exists)
- `Device-ID` (in debug mode)
- `Platform: iOS` (in debug mode)

---

## Token Manager

Securely manage access and refresh tokens.

### Protocol

```swift
protocol TokenManager: AnyObject {
    var accessToken: String? { get set }
    var refreshToken: String? { get set }
    var tokenExpirationDate: Date? { get set }
    
    var isTokenExpired: Bool { get }
    var isTokenValid: Bool { get }
    
    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int)
    func clearTokens()
}
```

### Usage

#### Save Tokens (After Login)

```swift
let tokenManager = DefaultNetworkContainer.shared.tokenManager

// Save all tokens
tokenManager.saveTokens(
    accessToken: "eyJhbGc...",
    refreshToken: "eyJhbGc...",
    expiresIn: 3600  // 1 hour
)

// Or set individually
tokenManager.accessToken = "eyJhbGc..."
tokenManager.refreshToken = "eyJhbGc..."
```

#### Check Token Status

```swift
// Check if token is valid (exists and not expired)
if tokenManager.isTokenValid {
    // User is authenticated
} else {
    // Need to login
}

// Check if token is expired
if tokenManager.isTokenExpired {
    // Refresh token or re-login
}
```

#### Clear Tokens (Logout)

```swift
tokenManager.clearTokens()
```

### Automatic Token Refresh

Tokens are automatically refreshed when:
1. Request receives 401 Unauthorized
2. Token is expired
3. Interceptor handles refresh flow

```swift
// Automatic flow:
Request → 401 → Refresh Token → Retry → Success
```

---

## Error Handling

Comprehensive error handling with user-friendly messages.

### NetworkError Enum

```swift
enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case encodingError(Error)
    case unauthorized
    case forbidden
    case notFound
    case timeout
    case serverError(Int)
    case rateLimitExceeded
    case badRequest(String)
    case unknown(Error)
    case offline
}
```

### Error Messages

| Error | User Message |
|-------|--------------|
| `invalidURL` | "Invalid URL. Please check the endpoint configuration." |
| `noData` | "No data received from the server." |
| `unauthorized` | "Your session has expired. Please log in again." |
| `forbidden` | "You don't have permission to access this resource." |
| `notFound` | "The requested resource was not found." |
| `timeout` | "Request timed out. Please check your connection and try again." |
| `serverError` | "Server error. Please try again later." |
| `rateLimitExceeded` | "Too many requests. Please wait a moment and try again." |
| `offline` | "No internet connection. Please check your network settings." |

### Usage

```swift
do {
    let user = try await repository.getUser(id: 123)
    // Handle success
} catch let error as NetworkError {
    switch error {
    case .unauthorized:
        // Redirect to login
        showLogin()
        
    case .notFound:
        // Show not found message
        showAlert("User not found")
        
    case .offline:
        // Try cached data or show offline message
        if let cachedUser = loadFromCache() {
            user = cachedUser
        } else {
            showAlert("You're offline")
        }
        
    case .timeout:
        // Retry or show timeout message
        showRetryButton()
        
    default:
        // Generic error handling
        showAlert(error.localizedDescription)
    }
} catch {
    // Unknown error
    showAlert("An unexpected error occurred")
}
```

### Status Code Handling

All HTTP status codes (200-599) are handled:

```swift
// Success (200-299) - No error thrown

// Client Errors (400-499)
400 → .badRequest
401 → .unauthorized (auto token refresh)
403 → .forbidden
404 → .notFound
408 → .timeout (auto retry)
429 → .rateLimitExceeded (auto retry with backoff)

// Server Errors (500-599)
500-599 → .serverError(statusCode) (auto retry)
```

---

## Complete Example

```swift
// 1. Setup
let container = DefaultNetworkContainer.shared
container.configuration.updateBaseURL("https://api.example.com")

// 2. Create Repository
class UserRepository {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    // GET
    func getUser(id: Int) async throws -> User {
        let response = try await networkManager.get(
            UserEndpoint.getUser(id: id),
            responseType: User.self,
            cachePolicy: .cacheResponse(expiration: .minutes(5))
        )
        return try response.unwrap()
    }
    
    // POST
    func createUser(name: String, email: String) async throws -> User {
        let response = try await networkManager.post(
            UserEndpoint.createUser(name: name, email: email),
            responseType: User.self
        )
        return try response.unwrap()
    }
    
    // PUT
    func updateUser(id: Int, name: String) async throws -> User {
        let response = try await networkManager.put(
            UserEndpoint.updateUser(id: id, name: name, email: nil),
            responseType: User.self
        )
        return try response.unwrap()
    }
    
    // DELETE
    func deleteUser(id: Int) async throws {
        try await networkManager.delete(UserEndpoint.deleteUser(id: id))
    }
}

// 3. Use in ViewModel
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

// 4. Use in SwiftUI View
struct UserView: View {
    @StateObject private var viewModel: UserViewModel
    
    init() {
        let container = DefaultNetworkContainer.shared
        let repository = UserRepository(networkManager: container.networkManager)
        _viewModel = StateObject(wrappedValue: UserViewModel(repository: repository))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            } else if let user = viewModel.user {
                Text(user.name)
            }
        }
        .task {
            await viewModel.loadUser(id: 123)
        }
    }
}
```

---

## Quick Reference

### Make Requests

```swift
// GET
try await networkManager.get(endpoint, responseType: User.self)

// POST
try await networkManager.post(endpoint, responseType: User.self)

// PUT
try await networkManager.put(endpoint, responseType: User.self)

// PATCH
try await networkManager.patch(endpoint, responseType: EmptyResponse.self)

// DELETE
try await networkManager.delete(endpoint)
```

### Configuration

```swift
// Base URL
container.configuration.updateBaseURL("https://api.example.com")

// Token
container.tokenManager.accessToken = "token"

// Cache
cacheManager.clear()
```

### Error Handling

```swift
do {
    let data = try await repository.getData()
} catch let error as NetworkError {
    // Handle specific error
} catch {
    // Handle unknown error
}
```

---

**Version:** 1.0.0  
**Last Updated:** November 7, 2025
