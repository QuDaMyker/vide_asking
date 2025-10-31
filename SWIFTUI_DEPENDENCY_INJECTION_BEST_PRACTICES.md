# Dependency Injection Best Practices in SwiftUI

A comprehensive guide to implementing clean, testable, and maintainable Dependency Injection patterns in SwiftUI applications.

## 📋 Table of Contents

1. [Core Concepts](#core-concepts)
2. [DI Patterns in SwiftUI](#di-patterns-in-swiftui)
3. [Implementation Methods](#implementation-methods)
4. [Best Practices](#best-practices)
5. [Common Patterns](#common-patterns)
6. [Testing with DI](#testing-with-di)
7. [Production Examples](#production-examples)

## 🎯 Core Concepts

### What is Dependency Injection?

Dependency Injection is a design pattern where dependencies are provided to a class rather than the class creating them itself.

**Benefits:**
- ✅ **Testability**: Easy to mock dependencies
- ✅ **Flexibility**: Swap implementations easily
- ✅ **Maintainability**: Loose coupling between components
- ✅ **Reusability**: Components can be reused in different contexts

### Types of DI in SwiftUI

1. **Constructor Injection** (Initializer)
2. **Property Injection** (Environment)
3. **Method Injection** (Parameters)
4. **Service Locator Pattern**

## 🏗️ DI Patterns in SwiftUI

### 1. Environment Object Pattern (Recommended)

**Best for:** Shared state across view hierarchy

```swift
import SwiftUI
import Combine

// MARK: - Service Protocol

protocol AuthServiceProtocol {
    var isAuthenticated: Bool { get }
    func signIn(email: String, password: String) async throws
    func signOut()
}

// MARK: - Concrete Implementation

class AuthService: AuthServiceProtocol, ObservableObject {
    @Published var isAuthenticated = false
    
    func signIn(email: String, password: String) async throws {
        // Implementation
        try await Task.sleep(nanoseconds: 1_000_000_000)
        isAuthenticated = true
    }
    
    func signOut() {
        isAuthenticated = false
    }
}

// MARK: - Mock Implementation for Testing

class MockAuthService: AuthServiceProtocol, ObservableObject {
    @Published var isAuthenticated = false
    var signInCalled = false
    var signOutCalled = false
    
    func signIn(email: String, password: String) async throws {
        signInCalled = true
        isAuthenticated = true
    }
    
    func signOut() {
        signOutCalled = true
        isAuthenticated = false
    }
}

// MARK: - Usage in Views

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            Button("Sign In") {
                Task {
                    try? await authService.signIn(email: email, password: password)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - App Entry Point

@main
struct MyApp: App {
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
```

### 2. Environment Values Pattern

**Best for:** Configuration and lightweight dependencies

```swift
import SwiftUI

// MARK: - Define Environment Key

private struct APIClientKey: EnvironmentKey {
    static let defaultValue: APIClient = APIClient()
}

extension EnvironmentValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// MARK: - API Client

class APIClient {
    private let baseURL: String
    
    init(baseURL: String = "https://api.example.com") {
        self.baseURL = baseURL
    }
    
    func fetch<T: Decodable>(_ endpoint: String) async throws -> T {
        // Implementation
        fatalError("Not implemented")
    }
}

// MARK: - Usage in Views

struct UserListView: View {
    @Environment(\.apiClient) private var apiClient
    @State private var users: [User] = []
    
    var body: some View {
        List(users) { user in
            Text(user.name)
        }
        .task {
            users = (try? await apiClient.fetch("/users")) ?? []
        }
    }
}

// MARK: - Setting Custom Values

struct ContentView: View {
    private let customAPIClient = APIClient(baseURL: "https://staging.api.example.com")
    
    var body: some View {
        UserListView()
            .environment(\.apiClient, customAPIClient)
    }
}
```

### 3. Constructor Injection Pattern

**Best for:** ViewModels and explicit dependencies

```swift
import SwiftUI
import Combine

// MARK: - Repository Protocol

protocol UserRepositoryProtocol {
    func fetchUsers() async throws -> [User]
    func createUser(_ user: User) async throws
}

// MARK: - Concrete Repository

class UserRepository: UserRepositoryProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func fetchUsers() async throws -> [User] {
        return try await apiClient.fetch("/users")
    }
    
    func createUser(_ user: User) async throws {
        // Implementation
    }
}

// MARK: - ViewModel with DI

@MainActor
class UserViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: UserRepositoryProtocol
    
    // Constructor Injection
    init(repository: UserRepositoryProtocol) {
        self.repository = repository
    }
    
    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            users = try await repository.fetchUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - View with ViewModel

struct UsersView: View {
    @StateObject private var viewModel: UserViewModel
    
    // Inject dependencies through initializer
    init(repository: UserRepositoryProtocol = UserRepository(apiClient: APIClient())) {
        _viewModel = StateObject(wrappedValue: UserViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error)
                } else {
                    List(viewModel.users) { user in
                        UserRowView(user: user)
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
```

### 4. Dependency Container Pattern

**Best for:** Complex apps with many dependencies

```swift
import Foundation

// MARK: - Dependency Container

@MainActor
class DependencyContainer: ObservableObject {
    // Singletons
    static let shared = DependencyContainer()
    
    // Services
    lazy var authService: AuthServiceProtocol = AuthService()
    lazy var apiClient: APIClient = APIClient()
    lazy var storageService: StorageServiceProtocol = StorageService()
    
    // Repositories
    lazy var userRepository: UserRepositoryProtocol = {
        UserRepository(apiClient: apiClient)
    }()
    
    lazy var productRepository: ProductRepositoryProtocol = {
        ProductRepository(apiClient: apiClient)
    }()
    
    // Use Cases / Interactors
    lazy var loginUseCase: LoginUseCaseProtocol = {
        LoginUseCase(authService: authService)
    }()
    
    // Private initializer for singleton
    private init() {}
    
    // Factory methods for ViewModels
    func makeUserViewModel() -> UserViewModel {
        return UserViewModel(repository: userRepository)
    }
    
    func makeProductViewModel() -> ProductViewModel {
        return ProductViewModel(repository: productRepository)
    }
}

// MARK: - Usage in Views

struct MainView: View {
    @EnvironmentObject private var container: DependencyContainer
    
    var body: some View {
        TabView {
            UsersView(viewModel: container.makeUserViewModel())
                .tabItem {
                    Label("Users", systemImage: "person.3")
                }
            
            ProductsView(viewModel: container.makeProductViewModel())
                .tabItem {
                    Label("Products", systemImage: "cart")
                }
        }
    }
}

// MARK: - App Setup

@main
struct MyApp: App {
    @StateObject private var container = DependencyContainer.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(container)
        }
    }
}
```

### 5. Protocol-Based DI with Environment

**Best for:** Maximum testability and flexibility

```swift
import SwiftUI

// MARK: - Service Protocols

protocol NetworkServiceProtocol {
    func request<T: Decodable>(_ endpoint: String) async throws -> T
}

protocol CacheServiceProtocol {
    func get<T: Decodable>(_ key: String) -> T?
    func set<T: Encodable>(_ key: String, value: T)
}

protocol AnalyticsServiceProtocol {
    func track(event: String, parameters: [String: Any]?)
}

// MARK: - Environment Keys

private struct NetworkServiceKey: EnvironmentKey {
    static let defaultValue: NetworkServiceProtocol = NetworkService()
}

private struct CacheServiceKey: EnvironmentKey {
    static let defaultValue: CacheServiceProtocol = CacheService()
}

private struct AnalyticsServiceKey: EnvironmentKey {
    static let defaultValue: AnalyticsServiceProtocol = AnalyticsService()
}

extension EnvironmentValues {
    var networkService: NetworkServiceProtocol {
        get { self[NetworkServiceKey.self] }
        set { self[NetworkServiceKey.self] = newValue }
    }
    
    var cacheService: CacheServiceProtocol {
        get { self[CacheServiceKey.self] }
        set { self[CacheServiceKey.self] = newValue }
    }
    
    var analyticsService: AnalyticsServiceProtocol {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
}

// MARK: - Concrete Implementations

class NetworkService: NetworkServiceProtocol {
    func request<T: Decodable>(_ endpoint: String) async throws -> T {
        // Implementation
        fatalError("Not implemented")
    }
}

class CacheService: CacheServiceProtocol {
    private var cache: [String: Any] = [:]
    
    func get<T: Decodable>(_ key: String) -> T? {
        return cache[key] as? T
    }
    
    func set<T: Encodable>(_ key: String, value: T) {
        cache[key] = value
    }
}

class AnalyticsService: AnalyticsServiceProtocol {
    func track(event: String, parameters: [String: Any]?) {
        print("Track event: \(event)")
    }
}

// MARK: - Usage in Views

struct ProductDetailView: View {
    @Environment(\.networkService) private var networkService
    @Environment(\.cacheService) private var cacheService
    @Environment(\.analyticsService) private var analyticsService
    
    let productId: String
    @State private var product: Product?
    
    var body: some View {
        VStack {
            if let product = product {
                Text(product.name)
                Text(product.description)
            } else {
                ProgressView()
            }
        }
        .task {
            await loadProduct()
        }
        .onAppear {
            analyticsService.track(event: "product_viewed", parameters: ["id": productId])
        }
    }
    
    private func loadProduct() async {
        // Check cache first
        if let cached: Product = cacheService.get(productId) {
            product = cached
            return
        }
        
        // Fetch from network
        do {
            let fetched: Product = try await networkService.request("/products/\(productId)")
            product = fetched
            cacheService.set(productId, value: fetched)
        } catch {
            print("Error loading product: \(error)")
        }
    }
}
```

## ✅ Best Practices

### 1. Use Protocols for Abstraction

```swift
// ✅ GOOD: Protocol-based
protocol DataServiceProtocol {
    func fetch() async throws -> [Item]
}

class ViewModel {
    private let service: DataServiceProtocol
    init(service: DataServiceProtocol) {
        self.service = service
    }
}

// ❌ BAD: Concrete implementation
class ViewModel {
    private let service = DataService() // Hard to test
}
```

### 2. Prefer Constructor Injection for ViewModels

```swift
// ✅ GOOD: Dependencies passed via initializer
@MainActor
class UserViewModel: ObservableObject {
    private let repository: UserRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol
    
    init(repository: UserRepositoryProtocol, 
         analyticsService: AnalyticsServiceProtocol) {
        self.repository = repository
        self.analyticsService = analyticsService
    }
}

// ❌ BAD: Dependencies created internally
class UserViewModel: ObservableObject {
    private let repository = UserRepository()
    private let analyticsService = AnalyticsService()
}
```

### 3. Use @EnvironmentObject for Shared State

```swift
// ✅ GOOD: Shared across view hierarchy
@main
struct MyApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(themeManager)
        }
    }
}
```

### 4. Keep Dependencies Minimal

```swift
// ✅ GOOD: Only necessary dependencies
class LoginViewModel: ObservableObject {
    private let authService: AuthServiceProtocol
    
    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }
}

// ❌ BAD: Too many dependencies
class LoginViewModel: ObservableObject {
    private let authService: AuthServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let loggingService: LoggingServiceProtocol
    private let crashReportingService: CrashReportingServiceProtocol
    private let featureFlagService: FeatureFlagServiceProtocol
    // Consider using a facade or coordinator
}
```

### 5. Use Default Parameters for Flexibility

```swift
// ✅ GOOD: Default parameter with option to override
struct UserListView: View {
    @StateObject private var viewModel: UserViewModel
    
    init(repository: UserRepositoryProtocol = UserRepository()) {
        _viewModel = StateObject(wrappedValue: UserViewModel(repository: repository))
    }
    
    var body: some View {
        // View implementation
        EmptyView()
    }
}

// Usage in production
let productionView = UserListView()

// Usage in tests
let testView = UserListView(repository: MockUserRepository())
```

### 6. Avoid Service Locator Anti-Pattern

```swift
// ❌ BAD: Service Locator (hard to track dependencies)
class ServiceLocator {
    static let shared = ServiceLocator()
    
    func get<T>() -> T {
        // Magic lookup
        fatalError()
    }
}

class ViewModel {
    private let service: DataService = ServiceLocator.shared.get()
}

// ✅ GOOD: Explicit dependencies
class ViewModel {
    private let service: DataServiceProtocol
    
    init(service: DataServiceProtocol) {
        self.service = service
    }
}
```

## 🎨 Common Patterns

### Repository Pattern with DI

```swift
// MARK: - Repository Protocol

protocol ProductRepositoryProtocol {
    func getProducts() async throws -> [Product]
    func getProduct(id: String) async throws -> Product
    func createProduct(_ product: Product) async throws
    func updateProduct(_ product: Product) async throws
    func deleteProduct(id: String) async throws
}

// MARK: - Repository Implementation

class ProductRepository: ProductRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let cacheService: CacheServiceProtocol
    
    init(networkService: NetworkServiceProtocol, 
         cacheService: CacheServiceProtocol) {
        self.networkService = networkService
        self.cacheService = cacheService
    }
    
    func getProducts() async throws -> [Product] {
        // Check cache
        if let cached: [Product] = cacheService.get("products") {
            return cached
        }
        
        // Fetch from network
        let products: [Product] = try await networkService.request("/products")
        cacheService.set("products", value: products)
        return products
    }
    
    func getProduct(id: String) async throws -> Product {
        return try await networkService.request("/products/\(id)")
    }
    
    func createProduct(_ product: Product) async throws {
        try await networkService.request("/products")
        cacheService.set("products", value: [Product]?.none as Any) // Invalidate cache
    }
    
    func updateProduct(_ product: Product) async throws {
        try await networkService.request("/products/\(product.id)")
        cacheService.set("products", value: [Product]?.none as Any)
    }
    
    func deleteProduct(id: String) async throws {
        try await networkService.request("/products/\(id)")
        cacheService.set("products", value: [Product]?.none as Any)
    }
}

// MARK: - Mock Repository for Testing

class MockProductRepository: ProductRepositoryProtocol {
    var mockProducts: [Product] = []
    var getProductsCalled = false
    var createProductCalled = false
    
    func getProducts() async throws -> [Product] {
        getProductsCalled = true
        return mockProducts
    }
    
    func getProduct(id: String) async throws -> Product {
        return mockProducts.first { $0.id == id }!
    }
    
    func createProduct(_ product: Product) async throws {
        createProductCalled = true
        mockProducts.append(product)
    }
    
    func updateProduct(_ product: Product) async throws {
        if let index = mockProducts.firstIndex(where: { $0.id == product.id }) {
            mockProducts[index] = product
        }
    }
    
    func deleteProduct(id: String) async throws {
        mockProducts.removeAll { $0.id == id }
    }
}
```

### Use Case Pattern with DI

```swift
// MARK: - Use Case Protocol

protocol LoginUseCaseProtocol {
    func execute(email: String, password: String) async throws -> User
}

// MARK: - Use Case Implementation

class LoginUseCase: LoginUseCaseProtocol {
    private let authService: AuthServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let userRepository: UserRepositoryProtocol
    
    init(authService: AuthServiceProtocol,
         analyticsService: AnalyticsServiceProtocol,
         userRepository: UserRepositoryProtocol) {
        self.authService = authService
        self.analyticsService = analyticsService
        self.userRepository = userRepository
    }
    
    func execute(email: String, password: String) async throws -> User {
        // Validate input
        guard !email.isEmpty, !password.isEmpty else {
            throw LoginError.invalidInput
        }
        
        // Track attempt
        analyticsService.track(event: "login_attempt", parameters: ["email": email])
        
        // Perform login
        try await authService.signIn(email: email, password: password)
        
        // Fetch user data
        let user = try await userRepository.getCurrentUser()
        
        // Track success
        analyticsService.track(event: "login_success", parameters: ["user_id": user.id])
        
        return user
    }
}

enum LoginError: Error {
    case invalidInput
}
```

### Coordinator Pattern with DI

```swift
// MARK: - Coordinator Protocol

protocol CoordinatorProtocol: AnyObject {
    func start()
    func showLogin()
    func showHome()
    func showProfile()
}

// MARK: - Main Coordinator

@MainActor
class MainCoordinator: ObservableObject, CoordinatorProtocol {
    @Published var currentScreen: Screen = .login
    
    private let container: DependencyContainer
    
    init(container: DependencyContainer) {
        self.container = container
    }
    
    func start() {
        if container.authService.isAuthenticated {
            showHome()
        } else {
            showLogin()
        }
    }
    
    func showLogin() {
        currentScreen = .login
    }
    
    func showHome() {
        currentScreen = .home
    }
    
    func showProfile() {
        currentScreen = .profile
    }
    
    enum Screen {
        case login
        case home
        case profile
    }
}

// MARK: - Coordinator View

struct CoordinatorView: View {
    @StateObject private var coordinator: MainCoordinator
    
    init(container: DependencyContainer = .shared) {
        _coordinator = StateObject(wrappedValue: MainCoordinator(container: container))
    }
    
    var body: some View {
        switch coordinator.currentScreen {
        case .login:
            LoginView()
                .environmentObject(coordinator)
        case .home:
            HomeView()
                .environmentObject(coordinator)
        case .profile:
            ProfileView()
                .environmentObject(coordinator)
        }
    }
}
```

## 🧪 Testing with DI

### Unit Testing ViewModels

```swift
import XCTest
@testable import MyApp

@MainActor
class UserViewModelTests: XCTestCase {
    var sut: UserViewModel!
    var mockRepository: MockUserRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockUserRepository()
        sut = UserViewModel(repository: mockRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    func testLoadUsers_Success() async {
        // Given
        let expectedUsers = [
            User(id: "1", name: "John"),
            User(id: "2", name: "Jane")
        ]
        mockRepository.mockUsers = expectedUsers
        
        // When
        await sut.loadUsers()
        
        // Then
        XCTAssertTrue(mockRepository.getUsersCalled)
        XCTAssertEqual(sut.users.count, 2)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testLoadUsers_Failure() async {
        // Given
        mockRepository.shouldFail = true
        
        // When
        await sut.loadUsers()
        
        // Then
        XCTAssertTrue(mockRepository.getUsersCalled)
        XCTAssertTrue(sut.users.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }
}
```

### UI Testing with Mock Dependencies

```swift
import SwiftUI

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with real services
            ContentView()
                .environmentObject(DependencyContainer.shared.authService as! AuthService)
                .previewDisplayName("Production")
            
            // Preview with mock services
            ContentView()
                .environmentObject(MockAuthService() as! AuthService)
                .previewDisplayName("Mock - Authenticated")
            
            // Preview with different states
            ContentView()
                .environmentObject({
                    let mock = MockAuthService()
                    mock.isAuthenticated = false
                    return mock as! AuthService
                }())
                .previewDisplayName("Mock - Not Authenticated")
        }
    }
}
```

## 📦 Production Example: Complete App Structure

```swift
// MARK: - Models

struct User: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
}

struct Product: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let price: Double
}

// MARK: - Services Layer

protocol AuthServiceProtocol {
    var isAuthenticated: Bool { get }
    func signIn(email: String, password: String) async throws
    func signOut()
}

protocol NetworkServiceProtocol {
    func request<T: Decodable>(_ endpoint: String) async throws -> T
}

// MARK: - Repository Layer

protocol UserRepositoryProtocol {
    func getCurrentUser() async throws -> User
    func updateUser(_ user: User) async throws
}

class UserRepository: UserRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }
    
    func getCurrentUser() async throws -> User {
        return try await networkService.request("/user")
    }
    
    func updateUser(_ user: User) async throws {
        // Implementation
    }
}

// MARK: - ViewModel Layer

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: UserRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol
    
    init(repository: UserRepositoryProtocol, 
         analyticsService: AnalyticsServiceProtocol) {
        self.repository = repository
        self.analyticsService = analyticsService
    }
    
    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            user = try await repository.getCurrentUser()
            analyticsService.track(event: "profile_loaded", parameters: nil)
        } catch {
            errorMessage = error.localizedDescription
            analyticsService.track(event: "profile_load_failed", parameters: ["error": error.localizedDescription])
        }
        
        isLoading = false
    }
}

// MARK: - View Layer

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    
    init(repository: UserRepositoryProtocol, 
         analyticsService: AnalyticsServiceProtocol) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            repository: repository,
            analyticsService: analyticsService
        ))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let user = viewModel.user {
                VStack(alignment: .leading, spacing: 16) {
                    Text(user.name)
                        .font(.title)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error)
            }
        }
        .task {
            await viewModel.loadProfile()
        }
    }
}

// MARK: - App Setup

@main
struct ProductionApp: App {
    @StateObject private var container = DependencyContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ProfileView(
                repository: container.userRepository,
                analyticsService: container.analyticsService as! AnalyticsService
            )
            .environmentObject(container)
        }
    }
}
```

## 🎯 Summary: Choosing the Right Pattern

| Pattern | Best For | Pros | Cons |
|---------|----------|------|------|
| **@EnvironmentObject** | Shared state, app-wide services | Easy to propagate, SwiftUI-native | Can lead to implicit dependencies |
| **Environment Values** | Configuration, lightweight deps | Type-safe, scoped | More boilerplate |
| **Constructor Injection** | ViewModels, explicit deps | Most testable, clear dependencies | More verbose |
| **Dependency Container** | Large apps, many services | Centralized, organized | Can become a god object |
| **Protocol-Based** | Maximum flexibility | Easy to mock, flexible | More code to write |

## 📚 Key Takeaways

1. ✅ **Always use protocols** for dependencies
2. ✅ **Inject through constructors** for ViewModels
3. ✅ **Use @EnvironmentObject** for shared state
4. ✅ **Keep dependencies minimal** and focused
5. ✅ **Provide default parameters** for flexibility
6. ✅ **Write tests** using mock implementations
7. ✅ **Document dependencies** clearly
8. ❌ **Avoid Service Locator** anti-pattern
9. ❌ **Don't create dependencies** inside classes
10. ❌ **Don't make everything** @EnvironmentObject

## 🔗 Additional Resources

- [Swift Design Patterns](https://www.swift.org/documentation/)
- [SwiftUI Data Flow](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [SOLID Principles in Swift](https://www.kodeco.com/books/design-patterns-by-tutorials)
