//
//  NetworkContainer.swift
//  SwiftUI Network Architecture
//
//  Created on 2025-11-07
//  Dependency Injection container for networking layer
//

import Foundation
import SwiftUI

// MARK: - Network Container Protocol

protocol NetworkContainer {
    var networkManager: NetworkManager { get }
    var configuration: NetworkConfiguration { get }
    var cacheManager: CacheManager { get }
    var tokenManager: TokenManager { get }
}

// MARK: - Default Network Container

class DefaultNetworkContainer: NetworkContainer {
    
    // MARK: - Singleton
    
    static let shared = DefaultNetworkContainer()
    
    // MARK: - Properties
    
    lazy var configuration: NetworkConfiguration = {
        return NetworkConfigurationImpl(
            environment: .production,
            apiVersion: "v1",
            timeout: 30
        )
    }()
    
    lazy var tokenManager: TokenManager = {
        return KeychainTokenManager(service: "com.app.network.tokens")
    }()
    
    lazy var cacheManager: CacheManager = {
        return NetworkCacheManager(
            maxMemoryCost: 50 * 1024 * 1024,  // 50 MB
            maxDiskSize: 200 * 1024 * 1024     // 200 MB
        )
    }()
    
    lazy var networkManager: NetworkManager = {
        return AlamofireNetworkManager(
            configuration: configuration,
            tokenManager: tokenManager,
            cacheManager: cacheManager
        )
    }()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration Methods
    
    func configure(baseURL: String) {
        configuration.updateBaseURL(baseURL)
    }
    
    func setAccessToken(_ token: String) {
        tokenManager.accessToken = token
    }
    
    func clearTokens() {
        tokenManager.clearTokens()
    }
    
    func clearCache() {
        cacheManager.clear()
    }
}

// MARK: - App Dependencies (SwiftUI Integration)

class AppDependencies: ObservableObject {
    
    // MARK: - Properties
    
    let networkContainer: NetworkContainer
    
    // MARK: - Initialization
    
    init(networkContainer: NetworkContainer = DefaultNetworkContainer.shared) {
        self.networkContainer = networkContainer
    }
    
    // MARK: - Configuration
    
    func configure(baseURL: String) {
        networkContainer.configuration.updateBaseURL(baseURL)
    }
    
    func setEnvironment(_ environment: AppEnvironment) {
        configure(baseURL: environment.baseURL)
    }
}

// MARK: - App Environment

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
    
    var displayName: String {
        switch self {
        case .development:
            return "Development"
        case .staging:
            return "Staging"
        case .production:
            return "Production"
        case .custom:
            return "Custom"
        }
    }
}

// MARK: - Environment Key for SwiftUI

struct NetworkContainerKey: EnvironmentKey {
    static let defaultValue: NetworkContainer = DefaultNetworkContainer.shared
}

extension EnvironmentValues {
    var networkContainer: NetworkContainer {
        get { self[NetworkContainerKey.self] }
        set { self[NetworkContainerKey.self] = newValue }
    }
}

extension View {
    func networkContainer(_ container: NetworkContainer) -> some View {
        environment(\.networkContainer, container)
    }
}

// MARK: - Mock Network Container (for Testing)

class MockNetworkContainer: NetworkContainer {
    
    var networkManager: NetworkManager
    var configuration: NetworkConfiguration
    var cacheManager: CacheManager
    var tokenManager: TokenManager
    
    init(
        networkManager: NetworkManager? = nil,
        configuration: NetworkConfiguration? = nil,
        cacheManager: CacheManager? = nil,
        tokenManager: TokenManager? = nil
    ) {
        self.networkManager = networkManager ?? MockNetworkManager()
        self.configuration = configuration ?? NetworkConfigurationImpl()
        self.cacheManager = cacheManager ?? InMemoryCacheManager()
        self.tokenManager = tokenManager ?? InMemoryTokenManager()
    }
}

// MARK: - Mock Network Manager

class MockNetworkManager: NetworkManager {
    
    var mockResponse: Any?
    var mockError: Error?
    var requestCallCount = 0
    var lastEndpoint: Endpoint?
    
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        cachePolicy: CachePolicy
    ) async throws -> APIResponse<T> {
        requestCallCount += 1
        lastEndpoint = endpoint
        
        if let error = mockError {
            throw error
        }
        
        if let response = mockResponse as? APIResponse<T> {
            return response
        }
        
        throw NetworkError.noData
    }
    
    func upload<T: Decodable>(
        _ endpoint: Endpoint,
        data: Data,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        requestCallCount += 1
        lastEndpoint = endpoint
        
        if let error = mockError {
            throw error
        }
        
        if let response = mockResponse as? APIResponse<T> {
            return response
        }
        
        throw NetworkError.noData
    }
    
    func download(_ endpoint: Endpoint, to destination: URL) async throws {
        requestCallCount += 1
        lastEndpoint = endpoint
        
        if let error = mockError {
            throw error
        }
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        mockResponse = nil
        mockError = nil
        requestCallCount = 0
        lastEndpoint = nil
    }
    
    func setMockResponse<T: Codable>(_ data: T, isSuccess: Bool = true, message: String? = nil) {
        mockResponse = APIResponse(
            isSuccess: isSuccess,
            message: message,
            messages: nil,
            createdAt: Date(),
            data: data,
            meta: nil
        )
    }
    
    func setMockError(_ error: Error) {
        mockError = error
    }
}

// MARK: - Usage Examples

/*
 
 // MARK: - Example 1: Basic Setup in App
 
 @main
 struct MyApp: App {
     @StateObject private var dependencies = AppDependencies()
     
     init() {
         // Configure environment
         dependencies.setEnvironment(.production)
         
         // Optional: Set initial token if stored
         if let token = UserDefaults.standard.string(forKey: "accessToken") {
             dependencies.networkContainer.tokenManager.accessToken = token
         }
     }
     
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .environmentObject(dependencies)
         }
     }
 }
 
 // MARK: - Example 2: Using in Repository
 
 class UserRepository {
     private let networkManager: NetworkManager
     
     init(networkManager: NetworkManager) {
         self.networkManager = networkManager
     }
     
     func getUser(id: Int) async throws -> User {
         let response = try await networkManager.get(
             UserEndpoint.getUser(id: id),
             responseType: User.self,
             cachePolicy: .cacheResponse(expiration: .minutes(5))
         )
         return try response.unwrap()
     }
     
     func createUser(name: String, email: String, password: String) async throws -> User {
         let response = try await networkManager.post(
             UserEndpoint.createUser(name: name, email: email, password: password),
             responseType: User.self
         )
         return try response.unwrap()
     }
     
     func updateUser(id: Int, name: String?, email: String?) async throws -> User {
         let response = try await networkManager.put(
             UserEndpoint.updateUser(id: id, name: name, email: email),
             responseType: User.self
         )
         return try response.unwrap()
     }
     
     func deleteUser(id: Int) async throws {
         try await networkManager.delete(UserEndpoint.deleteUser(id: id))
     }
 }
 
 // MARK: - Example 3: Using in ViewModel
 
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
 
 // MARK: - Example 4: Using in SwiftUI View
 
 struct UserProfileView: View {
     @EnvironmentObject var dependencies: AppDependencies
     @StateObject private var viewModel: UserViewModel
     
     init(userId: Int) {
         let container = DefaultNetworkContainer.shared
         let repository = UserRepository(networkManager: container.networkManager)
         _viewModel = StateObject(wrappedValue: UserViewModel(repository: repository))
     }
     
     var body: some View {
         VStack {
             if viewModel.isLoading {
                 ProgressView()
             } else if let error = viewModel.errorMessage {
                 Text(error)
                     .foregroundColor(.red)
             } else if let user = viewModel.user {
                 Text(user.name)
             }
         }
         .task {
             await viewModel.loadUser(id: 123)
         }
     }
 }
 
 // MARK: - Example 5: Unit Testing with Mock
 
 final class UserRepositoryTests: XCTestCase {
     var sut: UserRepository!
     var mockNetworkManager: MockNetworkManager!
     
     override func setUp() {
         super.setUp()
         mockNetworkManager = MockNetworkManager()
         sut = UserRepository(networkManager: mockNetworkManager)
     }
     
     func testGetUser_Success() async throws {
         // Given
         let expectedUser = User(id: 1, name: "John", email: "john@example.com")
         mockNetworkManager.setMockResponse(expectedUser)
         
         // When
         let user = try await sut.getUser(id: 1)
         
         // Then
         XCTAssertEqual(user.id, expectedUser.id)
         XCTAssertEqual(user.name, expectedUser.name)
         XCTAssertEqual(mockNetworkManager.requestCallCount, 1)
     }
     
     func testGetUser_NetworkError() async {
         // Given
         mockNetworkManager.setMockError(NetworkError.unauthorized)
         
         // When/Then
         do {
             _ = try await sut.getUser(id: 1)
             XCTFail("Should throw error")
         } catch {
             XCTAssertTrue(error is NetworkError)
         }
     }
 }
 
 // MARK: - Example 6: All HTTP Methods
 
 class APIClient {
     private let networkManager: NetworkManager
     
     init(networkManager: NetworkManager) {
         self.networkManager = networkManager
     }
     
     // GET
     func fetchUsers() async throws -> [User] {
         let response = try await networkManager.get(
             UserEndpoint.getUsers(page: 1, limit: 20),
             responseType: [User].self,
             cachePolicy: .cacheResponse(expiration: .minutes(5))
         )
         return try response.unwrap()
     }
     
     // POST
     func login(email: String, password: String) async throws -> AuthResponse {
         let response = try await networkManager.post(
             AuthEndpoint.login(email: email, password: password),
             responseType: AuthResponse.self
         )
         return try response.unwrap()
     }
     
     // PUT
     func updateProduct(id: Int, product: Product) async throws -> Product {
         let response = try await networkManager.put(
             ProductEndpoint.update(id: id, product: product),
             responseType: Product.self
         )
         return try response.unwrap()
     }
     
     // PATCH
     func updateOrderStatus(orderId: Int, status: String) async throws {
         _ = try await networkManager.patch(
             OrderEndpoint.updateStatus(id: orderId, status: status),
             responseType: EmptyResponse.self
         )
     }
     
     // DELETE
     func deleteProduct(id: Int) async throws {
         try await networkManager.delete(ProductEndpoint.delete(id: id))
     }
 }
 
 */
