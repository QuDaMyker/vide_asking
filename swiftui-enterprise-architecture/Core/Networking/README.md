# SwiftUI + Alamofire Networking - Complete Implementation

## 📝 Overview

This is a production-ready networking implementation for SwiftUI applications using Alamofire. It includes all modern best practices and patterns required for enterprise-level iOS development.

## ✅ Features Implemented

### Core Networking
- ✅ **Alamofire Integration** - Full Session configuration with interceptors
- ✅ **Request Interceptor** - Automatic authentication and token refresh
- ✅ **Response Interceptor** - Standardized response handling
- ✅ **Status Code Handling** - Comprehensive HTTP status code mapping (200-599)
- ✅ **Error Handling** - Typed errors with localized messages

### Response Models
- ✅ **APIResponse<T>** - Generic response wrapper
- ✅ **Response Metadata** - Request ID, timestamp, pagination
- ✅ **Standardized Errors** - APIError with field-level validation
- ✅ **Date Handling** - ISO8601 encoding/decoding

### Caching
- ✅ **Multi-Layer Cache** - Memory + Disk caching
- ✅ **Expiration Policies** - Never, seconds, minutes, hours, days
- ✅ **Cache Invalidation** - Automatic and manual clearing
- ✅ **SHA256 Keys** - Secure cache key generation

### Debouncing
- ✅ **Request Debouncer** - Prevent excessive API calls
- ✅ **Combine Integration** - Publisher extensions for debouncing
- ✅ **Property Wrapper** - @Debounced for easy usage
- ✅ **Throttling** - Alternative rate limiting

### Logging
- ✅ **HTTP Logging** - Request/response details
- ✅ **Network Metrics** - DNS, connection, SSL timing
- ✅ **File Logging** - Daily log files
- ✅ **Sensitive Data Masking** - Auto-mask authorization headers

### Dependency Injection
- ✅ **NetworkContainer** - Central dependency management
- ✅ **Protocol-Based** - Easy mocking for tests
- ✅ **SwiftUI Integration** - @EnvironmentObject support
- ✅ **Lazy Initialization** - Optimized startup

### Dynamic Configuration
- ✅ **Base URL Management** - Runtime URL switching
- ✅ **Token Management** - Keychain-based secure storage
- ✅ **Environment Support** - Dev, Staging, Production
- ✅ **Notification-Based** - Reactive configuration updates

## 🏗 Architecture

```
SwiftUI Views
    ↓
ViewModels (ObservableObject)
    ↓
Use Cases (Business Logic)
    ↓
Repositories (Data Layer)
    ↓
NetworkManager (Alamofire)
    ↓
API
```

## 📦 Dependencies

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
]
```

Or via Xcode:
1. File → Add Packages
2. Search: `https://github.com/Alamofire/Alamofire.git`
3. Version: 5.8.0 or later

## 🚀 Quick Start

### 1. Setup in App Entry Point

```swift
import SwiftUI

@main
struct MyApp: App {
    @StateObject private var dependencies = AppDependencies()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencies)
        }
    }
}
```

### 2. Configure Network

```swift
let container = DefaultNetworkContainer.shared

// Optional: Update base URL dynamically
container.configuration.updateBaseURL("https://api.example.com")

// Optional: Set access token
container.tokenManager.accessToken = "your_access_token"
```

### 3. Create a Repository

```swift
class ProductRepository {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func getProducts() async throws -> [Product] {
        let response = try await networkManager.request(
            ProductEndpoint.getAll,
            responseType: ProductListResponse.self,
            cachePolicy: .cacheResponse(expiration: .minutes(5))
        )
        
        guard let products = response.data else {
            throw NetworkError.notFound("No products found")
        }
        
        return products.items
    }
}
```

### 4. Create a ViewModel

```swift
@MainActor
class ProductListViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: ProductRepository
    
    init(repository: ProductRepository) {
        self.repository = repository
    }
    
    func loadProducts() async {
        isLoading = true
        
        do {
            products = try await repository.getProducts()
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
```

### 5. Use in SwiftUI View

```swift
struct ProductListView: View {
    @StateObject private var viewModel: ProductListViewModel
    
    init() {
        let container = DefaultNetworkContainer.shared
        let repository = ProductRepository(networkManager: container.networkManager)
        _viewModel = StateObject(wrappedValue: ProductListViewModel(repository: repository))
    }
    
    var body: some View {
        List(viewModel.products) { product in
            Text(product.name)
        }
        .onAppear {
            Task {
                await viewModel.loadProducts()
            }
        }
    }
}
```

## 🔧 Advanced Usage

### Custom Endpoints

```swift
enum ProductEndpoint: Endpoint {
    case getAll
    case getById(id: String)
    case create(name: String, price: Double)
    
    var path: String {
        switch self {
        case .getAll:
            return "/products"
        case .getById(let id):
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
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .getAll, .getById:
            return nil
        case .create(let name, let price):
            return ["name": name, "price": price]
        }
    }
}
```

### Debounced Search

```swift
class SearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var results: [Product] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $searchQuery
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task {
                    await self?.performSearch(query)
                }
            }
            .store(in: &cancellables)
    }
}
```

### Token Refresh

Token refresh is automatic! The `APIRequestInterceptor` handles it:

```swift
// When a 401 is received:
// 1. Interceptor automatically calls tokenManager.refreshToken()
// 2. Retries the original request with new token
// 3. If refresh fails, returns 401 error
```

### Dynamic Base URL

```swift
// In settings or debug menu
let configuration = DefaultNetworkContainer.shared.configuration

// Switch to staging
configuration.updateBaseURL("https://api-staging.example.com")

// Reset to default
configuration.resetToDefault()
```

### Cache Management

```swift
let cacheManager = DefaultNetworkContainer.shared.cacheManager

// Clear specific cache
cacheManager.remove(forKey: "products")

// Clear all cache
cacheManager.clear()

// Clear expired only
cacheManager.clearExpired()

// Get cache size
cacheManager.getCacheSize { size in
    print("Cache size: \(size) bytes")
}
```

## 🧪 Testing

### Mock Network Manager

```swift
class ProductRepositoryTests: XCTestCase {
    var sut: ProductRepository!
    var mockNetworkManager: MockNetworkManager!
    
    override func setUp() {
        mockNetworkManager = MockNetworkManager()
        sut = ProductRepository(networkManager: mockNetworkManager)
    }
    
    func testGetProducts_Success() async throws {
        // Given
        let expectedProducts = [Product(id: "1", name: "Test")]
        mockNetworkManager.mockResponse = APIResponse(
            isSuccess: true,
            message: "Success",
            createdAt: Date(),
            data: ProductListResponse(items: expectedProducts),
            statusCode: 200
        )
        
        // When
        let products = try await sut.getProducts()
        
        // Then
        XCTAssertTrue(mockNetworkManager.requestCalled)
        XCTAssertEqual(products.count, 1)
    }
}
```

## 📊 Monitoring

### View Logs

```swift
// Get log file URL
if let logURL = AppLogger.shared.getLogFileURL() {
    print("Logs at: \(logURL.path)")
}

// Clear logs
AppLogger.shared.clearLogs()
```

### Network Metrics

Metrics are automatically logged when `shouldLogRequests = true`:

```
📊 METRICS
Total Duration: 0.45s
DNS Lookup: 0.02s
Connection Time: 0.10s
SSL Handshake: 0.08s
Request Time: 0.15s
Response Time: 0.10s
```

## 🔒 Security

### Token Storage

Tokens are stored securely in Keychain:

```swift
let tokenManager = KeychainTokenManager(service: "com.yourapp.tokens")
tokenManager.accessToken = "secure_token"
```

### Header Masking

Sensitive headers are automatically masked in logs:
- Authorization
- X-API-Key
- Cookie
- Proxy-Authorization

## 🎯 Best Practices

1. **Always use repositories** - Don't call NetworkManager directly from ViewModels
2. **Cache read-only data** - Only cache GET requests
3. **Debounce search** - Use 0.3-0.5 second delay
4. **Handle all errors** - Use typed NetworkError
5. **Test with mocks** - Use MockNetworkManager for unit tests
6. **Monitor cache size** - Clear periodically to save disk space
7. **Version your API** - Include API version in headers
8. **Log in development only** - Disable in production

## 📁 File Structure

```
Core/
  Networking/
    ├── NetworkManager.swift           # Main network manager
    ├── APIModels.swift                # Response models
    ├── APIRequestInterceptor.swift    # Request/retry logic
    ├── StatusCodeHandler.swift        # HTTP status handling
    ├── CacheManager.swift             # Multi-layer caching
    ├── RequestDebouncer.swift         # Debouncing utilities
    ├── NetworkLogger.swift            # HTTP logging
    ├── NetworkConfiguration.swift     # Configuration & tokens
    └── Endpoint.swift                 # Endpoint definitions

DI/
  └── NetworkContainer.swift           # Dependency injection

Data/
  Repositories/
    └── UserRepository.swift           # Example repository

Domain/
  UseCases/
    └── UserUseCases.swift             # Example use cases

Presentation/
  ViewModels/
    └── UserProfileViewModel.swift    # Example view model
  Views/
    └── UserProfileView.swift         # Example view
```

## 🆘 Troubleshooting

### Issue: Token not included in requests
**Solution**: Set token before making requests:
```swift
DefaultNetworkContainer.shared.tokenManager.accessToken = "your_token"
```

### Issue: Cache not working
**Solution**: Use appropriate cache policy:
```swift
cachePolicy: .cacheResponse(expiration: .minutes(5))
```

### Issue: Requests timing out
**Solution**: Increase timeout or check network:
```swift
var timeout: TimeInterval { 60.0 }
```

### Issue: Logs not appearing
**Solution**: Enable logging in configuration:
```swift
var shouldLogRequests: Bool { true }
```

## 📚 Additional Resources

- [Alamofire Documentation](https://github.com/Alamofire/Alamofire)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [SwiftUI Architecture Guide](./SWIFTUI_ALAMOFIRE_BEST_PRACTICES.md)

## 📄 License

See LICENSE file for details.

---

**Created:** November 7, 2025  
**Version:** 1.0.0  
**Swift Version:** 5.9+  
**iOS Version:** 15.0+
