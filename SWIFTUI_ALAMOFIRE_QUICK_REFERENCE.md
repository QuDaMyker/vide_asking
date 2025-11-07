# SwiftUI + Alamofire Quick Reference

## 🚀 Quick Start (5 Minutes)

### 1. Add Alamofire
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
]
```

### 2. Get Container
```swift
let container = DefaultNetworkContainer.shared
let networkManager = container.networkManager
```

### 3. Make Request
```swift
let response = try await networkManager.request(
    YourEndpoint.getData,
    responseType: YourModel.self,
    cachePolicy: .cacheResponse(expiration: .minutes(5))
)
```

---

## 📋 Common Patterns

### Repository Pattern
```swift
class UserRepository {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func getUser(id: String) async throws -> User {
        let response = try await networkManager.request(
            UserEndpoint.getById(id: id),
            responseType: User.self,
            cachePolicy: .cacheResponse(expiration: .minutes(5))
        )
        guard let user = response.data else {
            throw NetworkError.notFound("User not found")
        }
        return user
    }
}
```

### ViewModel Pattern
```swift
@MainActor
class UserViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var error: String?
    
    private let repository: UserRepository
    
    func loadUser(id: String) async {
        isLoading = true
        do {
            user = try await repository.getUser(id: id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
```

### SwiftUI View
```swift
struct UserView: View {
    @StateObject var viewModel: UserViewModel
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let user = viewModel.user {
                Text(user.name)
            }
        }
        .task {
            await viewModel.loadUser(id: "123")
        }
    }
}
```

---

## 🎯 Cache Policies

```swift
// No cache - always fetch from network
.ignoreCache

// Use cache if available, otherwise fetch
.returnCacheElseLoad

// Only use cache, throw error if not cached
.returnCacheDontLoad

// Fetch and cache the response
.cacheResponse(expiration: .minutes(5))
.cacheResponse(expiration: .hours(1))
.cacheResponse(expiration: .days(7))
.cacheResponse(expiration: .never)
```

---

## 🔄 Debouncing

### Method 1: Debouncer
```swift
let debouncer = RequestDebouncer(delay: 0.5)

func search(query: String) {
    debouncer.debounce(key: "search") {
        performSearch(query)
    }
}
```

### Method 2: Combine
```swift
$searchText
    .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
    .sink { query in
        performSearch(query)
    }
    .store(in: &cancellables)
```

---

## 🔧 Configuration

### Change Base URL
```swift
DefaultNetworkContainer.shared.configuration
    .updateBaseURL("https://api-staging.example.com")
```

### Update Token
```swift
DefaultNetworkContainer.shared.tokenManager
    .accessToken = "your_new_token"
```

### Clear Cache
```swift
DefaultNetworkContainer.shared.cacheManager.clear()
DefaultNetworkContainer.shared.cacheManager.clearExpired()
DefaultNetworkContainer.shared.cacheManager.remove(forKey: "specific-key")
```

---

## 📝 Define Endpoints

```swift
enum ProductEndpoint: Endpoint {
    case getAll(page: Int)
    case getById(id: String)
    case create(name: String, price: Double)
    case update(id: String, data: [String: Any])
    case delete(id: String)
    
    var path: String {
        switch self {
        case .getAll:
            return "/products"
        case .getById(let id), .update(let id, _), .delete(let id):
            return "/products/\(id)"
        case .create:
            return "/products"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getAll, .getById:
            return .get
        case .create:
            return .post
        case .update:
            return .put
        case .delete:
            return .delete
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .getAll(let page):
            return ["page": page]
        case .create(let name, let price):
            return ["name": name, "price": price]
        case .update(_, let data):
            return data
        default:
            return nil
        }
    }
}
```

---

## ❌ Error Handling

```swift
do {
    let user = try await repository.getUser(id: "123")
} catch NetworkError.unauthorized(let message) {
    // Handle 401 - redirect to login
    print(message)
} catch NetworkError.notFound(let message) {
    // Handle 404 - show not found UI
    print(message)
} catch NetworkError.serverError(let message) {
    // Handle 5xx - show retry
    print(message)
} catch NetworkError.validationError(let message, let fields) {
    // Handle 422 - show field errors
    print(message)
    print(fields)
} catch {
    // Handle other errors
    print(error.localizedDescription)
}
```

---

## 🧪 Testing

```swift
class UserRepositoryTests: XCTestCase {
    var sut: UserRepository!
    var mockNetworkManager: MockNetworkManager!
    
    override func setUp() {
        mockNetworkManager = MockNetworkManager()
        sut = UserRepository(networkManager: mockNetworkManager)
    }
    
    func testGetUser_Success() async throws {
        // Given
        let expectedUser = User(id: "1", name: "Test")
        mockNetworkManager.mockResponse = APIResponse(
            isSuccess: true,
            message: "Success",
            createdAt: Date(),
            data: expectedUser,
            statusCode: 200
        )
        
        // When
        let user = try await sut.getUser(id: "1")
        
        // Then
        XCTAssertEqual(user.id, expectedUser.id)
        XCTAssertTrue(mockNetworkManager.requestCalled)
    }
    
    func testGetUser_NotFound() async {
        // Given
        mockNetworkManager.mockError = NetworkError.notFound("User not found")
        
        // When/Then
        do {
            _ = try await sut.getUser(id: "999")
            XCTFail("Should throw error")
        } catch NetworkError.notFound {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }
}
```

---

## 📊 Monitoring

### View Logs
```swift
// Console logs (Debug mode only)
// Automatically enabled when shouldLogRequests = true

// Get log file
if let logURL = AppLogger.shared.getLogFileURL() {
    print("Log file: \(logURL.path)")
}

// Clear logs
AppLogger.shared.clearLogs()
```

### Check Cache Size
```swift
cacheManager.getCacheSize { bytes in
    let mb = Double(bytes) / 1024 / 1024
    print("Cache size: \(String(format: "%.2f", mb)) MB")
}
```

---

## 🔐 Security Best Practices

### DO ✅
- Store tokens in Keychain
- Mask sensitive headers in logs
- Use HTTPS only
- Validate SSL certificates
- Clear cache on logout
- Implement token refresh
- Use request timeout

### DON'T ❌
- Store tokens in UserDefaults
- Log sensitive data in production
- Cache sensitive responses
- Hardcode API keys
- Use HTTP in production
- Ignore SSL errors

---

## 📱 SwiftUI Integration

### With Environment
```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .networkContainer(DefaultNetworkContainer.shared)
        }
    }
}

struct MyView: View {
    @Environment(\.networkContainer) var container
    
    var body: some View {
        // Use container.networkManager
    }
}
```

### With Observable Object
```swift
class AppDependencies: ObservableObject {
    let networkContainer = DefaultNetworkContainer.shared
}

@main
struct MyApp: App {
    @StateObject var dependencies = AppDependencies()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencies)
        }
    }
}
```

---

## 🎨 Response Models

### Your API Response Format
```json
{
  "is_success": true,
  "message": "Success",
  "messages": ["Info 1", "Info 2"],
  "created_at": "2025-11-07T10:30:00Z",
  "status_code": 200,
  "data": {
    "id": "123",
    "name": "John Doe"
  },
  "metadata": {
    "request_id": "uuid",
    "timestamp": "2025-11-07T10:30:00Z",
    "version": "1.0"
  }
}
```

### Your Model
```swift
struct User: Codable {
    let id: String
    let name: String
}

// Request will automatically wrap in APIResponse<User>
let response = try await networkManager.request(
    endpoint,
    responseType: User.self,
    cachePolicy: .ignoreCache
)

// Access your data
let user = response.data
```

---

## 🚀 Performance Tips

1. **Cache GET requests**: Use `.cacheResponse(expiration: .minutes(5))`
2. **Debounce search**: 300-500ms delay
3. **Paginate lists**: 20-50 items per page
4. **Compress images**: Before upload
5. **Batch requests**: When possible
6. **Clear expired cache**: Periodically
7. **Monitor cache size**: Limit to reasonable size
8. **Use background tasks**: For large downloads

---

## 🔗 Related Files

- `NetworkManager.swift` - Main networking
- `APIModels.swift` - Response models
- `StatusCodeHandler.swift` - Status mapping
- `CacheManager.swift` - Caching
- `NetworkLogger.swift` - Logging
- `NetworkConfiguration.swift` - Configuration
- `NetworkContainer.swift` - DI

---

## 📚 Full Documentation

See `SWIFTUI_ALAMOFIRE_BEST_PRACTICES.md` for complete guide with:
- Architecture diagrams
- Implementation details
- Advanced patterns
- Common pitfalls
- Migration guides

---

**Quick Reference - Version 1.0.0**
