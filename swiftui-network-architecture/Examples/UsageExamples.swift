//
//  UsageExamples.swift
//  SwiftUI Network Architecture
//
//  Created on 2025-11-07
//  Complete usage examples for GET, POST, PUT, PATCH, DELETE
//

import Foundation
import SwiftUI

// MARK: - Complete Setup Example

/*
 
 Step 1: Configure in your App entry point
 
 */

@main
struct MyApp: App {
    @StateObject private var dependencies = AppDependencies()
    
    init() {
        // Set base URL
        dependencies.configure(baseURL: "https://api.example.com")
        
        // Or use environment
        dependencies.setEnvironment(.production)
        
        // Configure logging
        #if DEBUG
        NetworkLogger().logLevel = .verbose
        #else
        NetworkLogger().logLevel = .error
        #endif
        
        // Load saved token if exists
        if let savedToken = UserDefaults.standard.string(forKey: "accessToken") {
            dependencies.networkContainer.tokenManager.accessToken = savedToken
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencies)
        }
    }
}

// MARK: - Example 1: GET Request (Fetch Users)

class UserRepository {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    // Simple GET
    func getUser(id: Int) async throws -> User {
        let response = try await networkManager.get(
            UserEndpoint.getUser(id: id),
            responseType: User.self,
            cachePolicy: .cacheResponse(expiration: .minutes(5))
        )
        return try response.unwrap()
    }
    
    // GET with pagination
    func getUsers(page: Int = 1, limit: Int = 20) async throws -> [User] {
        let response = try await networkManager.get(
            UserEndpoint.getUsers(page: page, limit: limit),
            responseType: [User].self,
            cachePolicy: .cacheResponse(expiration: .minutes(5))
        )
        return try response.unwrap()
    }
}

// MARK: - Example 2: POST Request (Create User)

extension UserRepository {
    
    func createUser(name: String, email: String, password: String) async throws -> User {
        let response = try await networkManager.post(
            UserEndpoint.createUser(name: name, email: email, password: password),
            responseType: User.self
        )
        
        // Save token if returned
        if let token = response.data?.token {
            DefaultNetworkContainer.shared.tokenManager.accessToken = token
        }
        
        return try response.unwrap()
    }
}

// MARK: - Example 3: PUT Request (Update User)

extension UserRepository {
    
    func updateUser(id: Int, name: String?, email: String?) async throws -> User {
        let response = try await networkManager.put(
            UserEndpoint.updateUser(id: id, name: name, email: email),
            responseType: User.self
        )
        return try response.unwrap()
    }
}

// MARK: - Example 4: PATCH Request (Partial Update)

class OrderRepository {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func updateOrderStatus(id: Int, status: String) async throws {
        let response = try await networkManager.patch(
            OrderEndpoint.updateStatus(id: id, status: status),
            responseType: EmptyResponse.self
        )
        
        guard response.isSuccess else {
            throw NetworkError.badRequest(response.errorMessage ?? "Failed to update status")
        }
    }
}

// MARK: - Example 5: DELETE Request

extension UserRepository {
    
    func deleteUser(id: Int) async throws {
        // Option 1: With explicit response type
        let response = try await networkManager.delete(
            UserEndpoint.deleteUser(id: id),
            responseType: EmptyResponse.self
        )
        
        if !response.isSuccess {
            throw NetworkError.badRequest(response.errorMessage ?? "Failed to delete user")
        }
        
        // Option 2: Without response (using convenience method)
        // try await networkManager.delete(UserEndpoint.deleteUser(id: id))
    }
}

// MARK: - Example 6: Authentication Flow

class AuthRepository {
    private let networkManager: NetworkManager
    private let tokenManager: TokenManager
    
    init(networkManager: NetworkManager, tokenManager: TokenManager) {
        self.networkManager = networkManager
        self.tokenManager = tokenManager
    }
    
    // Login
    func login(email: String, password: String) async throws -> AuthResponse {
        let response = try await networkManager.post(
            AuthEndpoint.login(email: email, password: password),
            responseType: AuthResponse.self
        )
        
        guard let authData = response.data else {
            throw NetworkError.noData
        }
        
        // Save tokens
        tokenManager.saveTokens(
            accessToken: authData.accessToken,
            refreshToken: authData.refreshToken,
            expiresIn: authData.expiresIn
        )
        
        return authData
    }
    
    // Register
    func register(name: String, email: String, password: String) async throws -> AuthResponse {
        let response = try await networkManager.post(
            AuthEndpoint.register(name: name, email: email, password: password),
            responseType: AuthResponse.self
        )
        
        guard let authData = response.data else {
            throw NetworkError.noData
        }
        
        tokenManager.saveTokens(
            accessToken: authData.accessToken,
            refreshToken: authData.refreshToken,
            expiresIn: authData.expiresIn
        )
        
        return authData
    }
    
    // Logout
    func logout() async throws {
        // Call logout endpoint
        _ = try await networkManager.post(
            AuthEndpoint.logout,
            responseType: EmptyResponse.self
        )
        
        // Clear local tokens
        tokenManager.clearTokens()
        
        // Clear cache
        DefaultNetworkContainer.shared.cacheManager.clear()
    }
}

// MARK: - Example 7: Product CRUD Operations

class ProductRepository {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    // GET all products
    func getAllProducts(page: Int? = nil, limit: Int? = nil) async throws -> [Product] {
        let response = try await networkManager.get(
            ProductEndpoint.getAll(page: page, limit: limit),
            responseType: [Product].self,
            cachePolicy: .cacheResponse(expiration: .minutes(10))
        )
        return try response.unwrap()
    }
    
    // GET single product
    func getProduct(id: Int) async throws -> Product {
        let response = try await networkManager.get(
            ProductEndpoint.getById(id: id),
            responseType: Product.self,
            cachePolicy: .cacheResponse(expiration: .minutes(15))
        )
        return try response.unwrap()
    }
    
    // POST create product
    func createProduct(_ product: Product) async throws -> Product {
        let response = try await networkManager.post(
            ProductEndpoint.create(product: product),
            responseType: Product.self
        )
        return try response.unwrap()
    }
    
    // PUT update product
    func updateProduct(id: Int, product: Product) async throws -> Product {
        let response = try await networkManager.put(
            ProductEndpoint.update(id: id, product: product),
            responseType: Product.self
        )
        return try response.unwrap()
    }
    
    // DELETE product
    func deleteProduct(id: Int) async throws {
        try await networkManager.delete(ProductEndpoint.delete(id: id))
    }
    
    // Search products
    func searchProducts(query: String, filters: [String: Any]? = nil) async throws -> [Product] {
        let response = try await networkManager.get(
            ProductEndpoint.search(query: query, filters: filters),
            responseType: [Product].self,
            cachePolicy: .ignoreCache  // Don't cache search results
        )
        return try response.unwrap()
    }
}

// MARK: - Example 8: ViewModel with all CRUD operations

@MainActor
class ProductListViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: ProductRepository
    
    init(repository: ProductRepository) {
        self.repository = repository
    }
    
    // GET
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            products = try await repository.getAllProducts()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // POST
    func createProduct(name: String, price: Double, description: String?) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let newProduct = Product(
                id: nil,
                name: name,
                description: description,
                price: price,
                imageUrl: nil,
                category: nil,
                stock: nil
            )
            
            let created = try await repository.createProduct(newProduct)
            products.append(created)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // PUT
    func updateProduct(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let id = product.id else { return }
            let updated = try await repository.updateProduct(id: id, product: product)
            
            if let index = products.firstIndex(where: { $0.id == id }) {
                products[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // DELETE
    func deleteProduct(_ product: Product) async {
        guard let id = product.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await repository.deleteProduct(id: id)
            products.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // Search
    func searchProducts(query: String) async {
        guard !query.isEmpty else {
            await loadProducts()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            products = try await repository.searchProducts(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Example 9: SwiftUI View with all operations

struct ProductListView: View {
    @EnvironmentObject var dependencies: AppDependencies
    @StateObject private var viewModel: ProductListViewModel
    @State private var showingAddProduct = false
    @State private var searchText = ""
    
    init() {
        let container = DefaultNetworkContainer.shared
        let repository = ProductRepository(networkManager: container.networkManager)
        _viewModel = StateObject(wrappedValue: ProductListViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadProducts() }
                    }
                } else {
                    List {
                        ForEach(viewModel.products, id: \.id) { product in
                            ProductRow(product: product)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteProduct(product)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .refreshable {
                        await viewModel.loadProducts()
                    }
                }
            }
            .navigationTitle("Products")
            .searchable(text: $searchText)
            .onChange(of: searchText) { newValue in
                Task {
                    await viewModel.searchProducts(query: newValue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddProduct = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProduct) {
                AddProductView { name, price, description in
                    Task {
                        await viewModel.createProduct(
                            name: name,
                            price: price,
                            description: description
                        )
                    }
                }
            }
            .task {
                await viewModel.loadProducts()
            }
        }
    }
}

struct ProductRow: View {
    let product: Product
    
    var body: some View {
        HStack {
            if let imageUrl = product.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                
                if let description = product.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text("$\(product.price, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
        }
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                retry()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct AddProductView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var price = ""
    @State private var description = ""
    
    let onCreate: (String, Double, String?) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                TextField("Price", text: $price)
                    .keyboardType(.decimalPad)
                TextField("Description", text: $description)
            }
            .navigationTitle("Add Product")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let priceValue = Double(price) {
                            onCreate(name, priceValue, description.isEmpty ? nil : description)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || price.isEmpty)
                }
            }
        }
    }
}

// MARK: - Example 10: Error Handling

extension ProductRepository {
    
    func getProductWithErrorHandling(id: Int) async throws -> Product {
        do {
            return try await getProduct(id: id)
        } catch let error as NetworkError {
            switch error {
            case .unauthorized:
                // Handle unauthorized - maybe logout user
                print("User unauthorized, logging out...")
                throw error
                
            case .notFound:
                // Handle not found - show appropriate message
                print("Product not found")
                throw error
                
            case .offline:
                // Handle offline - maybe use cached data
                print("Device offline, checking cache...")
                throw error
                
            case .timeout:
                // Handle timeout - retry maybe
                print("Request timed out")
                throw error
                
            default:
                // Generic error handling
                print("Error: \(error.localizedDescription)")
                throw error
            }
        } catch {
            // Unknown error
            print("Unknown error: \(error)")
            throw NetworkError.unknown(error)
        }
    }
}

// MARK: - Example 11: Upload File

extension UserRepository {
    
    func uploadAvatar(userId: Int, imageData: Data) async throws -> String {
        let response = try await networkManager.upload(
            UserEndpoint.uploadAvatar(userId: userId),
            data: imageData,
            responseType: UploadResponse.self
        )
        
        guard let uploadResponse = response.data else {
            throw NetworkError.noData
        }
        
        return uploadResponse.url
    }
}

// MARK: - Example Models

struct User: Codable {
    let id: Int
    let name: String
    let email: String
    let avatar: String?
    let token: String?
}

struct ContentView: View {
    var body: some View {
        Text("See UsageExamples.swift for complete implementation")
    }
}
