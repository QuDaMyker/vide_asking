# SwiftUI + Alamofire Best Practices Guide

> **Complete networking solution with interceptors, status code handling, response models, caching, debouncing, logging, DI, and dynamic configuration**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture Design](#architecture-design)
3. [Response Model Structure](#response-model-structure)
4. [Interceptor Implementation](#interceptor-implementation)
5. [Status Code Handling](#status-code-handling)
6. [Caching Strategy](#caching-strategy)
7. [Debouncing Requests](#debouncing-requests)
8. [HTTP Logging](#http-logging)
9. [Dependency Injection](#dependency-injection)
10. [Dynamic Configuration](#dynamic-configuration)
11. [Complete Implementation](#complete-implementation)
12. [Usage Examples](#usage-examples)
13. [Testing](#testing)
14. [Common Pitfalls](#common-pitfalls)

---

## 🎯 Overview

This guide provides production-ready patterns for building a robust networking layer in SwiftUI applications using Alamofire with:

- ✅ Request/Response interceptors
- ✅ Comprehensive status code handling
- ✅ Standardized response models
- ✅ Multi-layer caching (Memory + Disk)
- ✅ Request debouncing
- ✅ Detailed HTTP logging
- ✅ Dependency injection
- ✅ Dynamic base URL and token management

---

## 🏗 Architecture Design

```
┌─────────────────────────────────────────────────────────────┐
│                         SwiftUI Views                        │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                       ViewModels                             │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                       Use Cases                              │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                      Repositories                            │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                    Network Manager                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Alamofire Session                       │   │
│  │  • Request Interceptor                              │   │
│  │  • Response Interceptor                             │   │
│  │  • Event Monitors (Logging)                         │   │
│  └─────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
    │ Caching │    │ Logging │    │  Config │
    └─────────┘    └─────────┘    └─────────┘
```

### Key Components:

1. **NetworkManager**: Central networking hub
2. **APIRequestInterceptor**: Handles authentication and retries
3. **ResponseMapper**: Transforms responses to domain models
4. **CacheManager**: Multi-layer caching
5. **NetworkLogger**: HTTP request/response logging
6. **NetworkConfiguration**: Dynamic base URL and tokens

---

## 📦 Response Model Structure

### Base Response Model

All API responses follow a standardized structure:

```swift
struct APIResponse<T: Decodable>: Decodable {
    let isSuccess: Bool
    let message: String
    let messages: [String]?
    let createdAt: Date
    let data: T?
    let statusCode: Int
    let metadata: ResponseMetadata?
    
    enum CodingKeys: String, CodingKey {
        case isSuccess = "is_success"
        case message
        case messages
        case createdAt = "created_at"
        case data
        case statusCode = "status_code"
        case metadata
    }
}

struct ResponseMetadata: Decodable {
    let requestId: String?
    let timestamp: Date?
    let version: String?
    
    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case timestamp
        case version
    }
}
```

### Empty Response

```swift
struct EmptyResponse: Decodable {
    // Used for endpoints that don't return data
}
```

### Error Response

```swift
struct APIError: Decodable, Error {
    let code: String
    let message: String
    let details: [String: String]?
    let statusCode: Int
    
    var localizedDescription: String {
        return message
    }
}
```

---

## 🔐 Interceptor Implementation

### Request Interceptor

```swift
class APIRequestInterceptor: RequestInterceptor {
    private let configuration: NetworkConfiguration
    private let tokenManager: TokenManager
    private let refreshQueue = DispatchQueue(label: "com.app.token.refresh")
    private var isRefreshing = false
    private var requestsToRetry: [(RetryResult) -> Void] = []
    
    init(configuration: NetworkConfiguration, tokenManager: TokenManager) {
        self.configuration = configuration
        self.tokenManager = tokenManager
    }
    
    // MARK: - RequestAdapter
    
    func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var urlRequest = urlRequest
        
        // Add access token
        if let token = tokenManager.accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add common headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(configuration.apiVersion, forHTTPHeaderField: "API-Version")
        urlRequest.setValue(UIDevice.current.identifierForVendor?.uuidString, 
                           forHTTPHeaderField: "Device-ID")
        
        completion(.success(urlRequest))
    }
    
    // MARK: - RequestRetrier
    
    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        guard let response = request.task?.response as? HTTPURLResponse,
              response.statusCode == 401 else {
            completion(.doNotRetryWithError(error))
            return
        }
        
        refreshQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.requestsToRetry.append(completion)
            
            if !self.isRefreshing {
                self.isRefreshing = true
                
                self.tokenManager.refreshToken { [weak self] result in
                    guard let self = self else { return }
                    
                    self.refreshQueue.async {
                        self.isRefreshing = false
                        
                        switch result {
                        case .success:
                            self.requestsToRetry.forEach { $0(.retry) }
                        case .failure(let error):
                            self.requestsToRetry.forEach { $0(.doNotRetryWithError(error)) }
                        }
                        
                        self.requestsToRetry.removeAll()
                    }
                }
            }
        }
    }
}
```

---

## 📊 Status Code Handling

### HTTP Status Code Handler

```swift
enum HTTPStatusCode: Int {
    case ok = 200
    case created = 201
    case accepted = 202
    case noContent = 204
    case badRequest = 400
    case unauthorized = 401
    case forbidden = 403
    case notFound = 404
    case requestTimeout = 408
    case conflict = 409
    case unprocessableEntity = 422
    case tooManyRequests = 429
    case internalServerError = 500
    case badGateway = 502
    case serviceUnavailable = 503
    case gatewayTimeout = 504
    
    var isSuccess: Bool {
        return (200...299).contains(rawValue)
    }
    
    var isClientError: Bool {
        return (400...499).contains(rawValue)
    }
    
    var isServerError: Bool {
        return (500...599).contains(rawValue)
    }
}

class StatusCodeHandler {
    static func handle(statusCode: Int, data: Data?) -> NetworkError? {
        guard let code = HTTPStatusCode(rawValue: statusCode) else {
            return .unknown("Unknown status code: \(statusCode)")
        }
        
        switch code {
        case .ok, .created, .accepted, .noContent:
            return nil
            
        case .badRequest:
            return parseErrorFromData(data) ?? .badRequest("Invalid request")
            
        case .unauthorized:
            return .unauthorized("Authentication required")
            
        case .forbidden:
            return .forbidden("Access denied")
            
        case .notFound:
            return .notFound("Resource not found")
            
        case .requestTimeout:
            return .timeout("Request timeout")
            
        case .conflict:
            return .conflict("Resource conflict")
            
        case .unprocessableEntity:
            return parseValidationError(data) ?? .validationError("Validation failed")
            
        case .tooManyRequests:
            return .rateLimitExceeded("Too many requests")
            
        case .internalServerError:
            return .serverError("Internal server error")
            
        case .badGateway:
            return .serverError("Bad gateway")
            
        case .serviceUnavailable:
            return .serviceUnavailable("Service temporarily unavailable")
            
        case .gatewayTimeout:
            return .timeout("Gateway timeout")
        }
    }
    
    private static func parseErrorFromData(_ data: Data?) -> NetworkError? {
        guard let data = data,
              let apiError = try? JSONDecoder().decode(APIError.self, from: data) else {
            return nil
        }
        return .apiError(apiError)
    }
    
    private static func parseValidationError(_ data: Data?) -> NetworkError? {
        // Parse validation errors with field details
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errors = json["errors"] as? [String: String] else {
            return nil
        }
        return .validationError("Validation failed", fields: errors)
    }
}

enum NetworkError: Error {
    case unauthorized(String)
    case forbidden(String)
    case notFound(String)
    case badRequest(String)
    case conflict(String)
    case validationError(String, fields: [String: String]? = nil)
    case rateLimitExceeded(String)
    case timeout(String)
    case serverError(String)
    case serviceUnavailable(String)
    case apiError(APIError)
    case decodingError(Error)
    case networkError(Error)
    case unknown(String)
    
    var localizedDescription: String {
        switch self {
        case .unauthorized(let msg): return msg
        case .forbidden(let msg): return msg
        case .notFound(let msg): return msg
        case .badRequest(let msg): return msg
        case .conflict(let msg): return msg
        case .validationError(let msg, _): return msg
        case .rateLimitExceeded(let msg): return msg
        case .timeout(let msg): return msg
        case .serverError(let msg): return msg
        case .serviceUnavailable(let msg): return msg
        case .apiError(let error): return error.message
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .unknown(let msg): return msg
        }
    }
}
```

---

## 💾 Caching Strategy

### Multi-Layer Cache Manager

```swift
protocol CacheManager {
    func cache<T: Encodable>(_ object: T, forKey key: String, expiration: CacheExpiration)
    func retrieve<T: Decodable>(forKey key: String, as type: T.Type) -> T?
    func remove(forKey key: String)
    func clear()
}

enum CacheExpiration {
    case never
    case seconds(TimeInterval)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    
    var timeInterval: TimeInterval {
        switch self {
        case .never: return .infinity
        case .seconds(let seconds): return seconds
        case .minutes(let minutes): return TimeInterval(minutes * 60)
        case .hours(let hours): return TimeInterval(hours * 3600)
        case .days(let days): return TimeInterval(days * 86400)
        }
    }
}

class NetworkCacheManager: CacheManager {
    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    private let queue = DispatchQueue(label: "com.app.cache", attributes: .concurrent)
    
    init() {
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDirectory.appendingPathComponent("NetworkCache")
        
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }
    
    func cache<T: Encodable>(_ object: T, forKey key: String, expiration: CacheExpiration) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let entry = CacheEntry(
                data: try? JSONEncoder().encode(object),
                expiration: Date().addingTimeInterval(expiration.timeInterval)
            )
            
            // Memory cache
            self.memoryCache.setObject(entry, forKey: key as NSString)
            
            // Disk cache
            let fileURL = self.diskCacheURL.appendingPathComponent(key.md5Hash)
            try? NSKeyedArchiver.archivedData(withRootObject: entry, requiringSecureCoding: false)
                .write(to: fileURL)
        }
    }
    
    func retrieve<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        var entry: CacheEntry?
        
        // Try memory cache first
        queue.sync {
            entry = memoryCache.object(forKey: key as NSString)
        }
        
        // Try disk cache if not in memory
        if entry == nil {
            let fileURL = diskCacheURL.appendingPathComponent(key.md5Hash)
            if let data = try? Data(contentsOf: fileURL),
               let cachedEntry = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CacheEntry.self, from: data
               ) {
                entry = cachedEntry
                // Populate memory cache
                memoryCache.setObject(cachedEntry, forKey: key as NSString)
            }
        }
        
        // Check expiration
        guard let entry = entry, entry.expiration > Date() else {
            remove(forKey: key)
            return nil
        }
        
        // Decode
        guard let data = entry.data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    func remove(forKey key: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.memoryCache.removeObject(forKey: key as NSString)
            
            let fileURL = self.diskCacheURL.appendingPathComponent(key.md5Hash)
            try? self.fileManager.removeItem(at: fileURL)
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.memoryCache.removeAllObjects()
            try? self.fileManager.removeItem(at: self.diskCacheURL)
            try? self.fileManager.createDirectory(at: self.diskCacheURL, 
                                                  withIntermediateDirectories: true)
        }
    }
}

class CacheEntry: NSObject, NSCoding {
    let data: Data?
    let expiration: Date
    
    init(data: Data?, expiration: Date) {
        self.data = data
        self.expiration = expiration
    }
    
    required init?(coder: NSCoder) {
        self.data = coder.decodeObject(forKey: "data") as? Data
        self.expiration = coder.decodeObject(forKey: "expiration") as? Date ?? Date()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(data, forKey: "data")
        coder.encode(expiration, forKey: "expiration")
    }
}

extension String {
    var md5Hash: String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_MD5($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
```

---

## ⏱ Debouncing Requests

### Request Debouncer

```swift
class RequestDebouncer {
    private var workItems: [String: DispatchWorkItem] = [:]
    private let queue = DispatchQueue(label: "com.app.debouncer")
    private let delay: TimeInterval
    
    init(delay: TimeInterval = 0.5) {
        self.delay = delay
    }
    
    func debounce(key: String, action: @escaping () -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Cancel previous work item
            self.workItems[key]?.cancel()
            
            // Create new work item
            let workItem = DispatchWorkItem(block: action)
            self.workItems[key] = workItem
            
            // Schedule execution
            DispatchQueue.main.asyncAfter(deadline: .now() + self.delay, execute: workItem)
        }
    }
    
    func cancel(key: String) {
        queue.async { [weak self] in
            self?.workItems[key]?.cancel()
            self?.workItems.removeValue(forKey: key)
        }
    }
    
    func cancelAll() {
        queue.async { [weak self] in
            self?.workItems.values.forEach { $0.cancel() }
            self?.workItems.removeAll()
        }
    }
}

// Usage with Combine for SwiftUI
extension Publisher {
    func debounceRequest(
        for delay: TimeInterval = 0.5,
        scheduler: DispatchQueue = .main
    ) -> Publishers.Debounce<Self, DispatchQueue> {
        return self.debounce(for: .seconds(delay), scheduler: scheduler)
    }
}
```

---

## 📝 HTTP Logging

### Network Event Monitor

```swift
class NetworkLogger: EventMonitor {
    let queue = DispatchQueue(label: "com.app.networklogger")
    private let logger: Logger
    
    init(logger: Logger = .shared) {
        self.logger = logger
    }
    
    // Request logging
    func requestDidResume(_ request: Request) {
        guard let urlRequest = request.request else { return }
        
        logger.info("🚀 REQUEST")
        logger.info("URL: \(urlRequest.url?.absoluteString ?? "N/A")")
        logger.info("Method: \(urlRequest.httpMethod ?? "N/A")")
        
        if let headers = urlRequest.allHTTPHeaderFields {
            logger.info("Headers: \(headers.prettyPrinted)")
        }
        
        if let body = urlRequest.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            logger.info("Body: \(bodyString.prettyJSON)")
        }
        
        logger.info("─────────────────────────────────")
    }
    
    // Response logging
    func request<Value>(
        _ request: DataRequest,
        didParseResponse response: DataResponse<Value, AFError>
    ) {
        logger.info("📥 RESPONSE")
        logger.info("URL: \(request.request?.url?.absoluteString ?? "N/A")")
        logger.info("Status Code: \(response.response?.statusCode ?? 0)")
        logger.info("Duration: \(String(format: "%.2f", request.metrics?.taskInterval.duration ?? 0))s")
        
        if let headers = response.response?.allHeaderFields {
            logger.info("Headers: \(headers.prettyPrinted)")
        }
        
        switch response.result {
        case .success:
            if let data = response.data,
               let bodyString = String(data: data, encoding: .utf8) {
                logger.info("✅ Response Body: \(bodyString.prettyJSON)")
            }
        case .failure(let error):
            logger.error("❌ Error: \(error.localizedDescription)")
            if let data = response.data,
               let errorBody = String(data: data, encoding: .utf8) {
                logger.error("Error Body: \(errorBody)")
            }
        }
        
        logger.info("═════════════════════════════════")
    }
    
    // Network error logging
    func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: AFError) {
        logger.error("🔴 REQUEST FAILED")
        logger.error("URL: \(request.request?.url?.absoluteString ?? "N/A")")
        logger.error("Error: \(error.localizedDescription)")
        logger.error("═════════════════════════════════")
    }
}

// Logger implementation
class Logger {
    static let shared = Logger()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    enum Level: String {
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case debug = "🐛"
    }
    
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    func warning(_ message: String) {
        log(message, level: .warning)
    }
    
    func error(_ message: String) {
        log(message, level: .error)
    }
    
    func debug(_ message: String) {
        #if DEBUG
        log(message, level: .debug)
        #endif
    }
    
    private func log(_ message: String, level: Level) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] \(level.rawValue) \(message)")
    }
}

// Helper extensions
extension Dictionary {
    var prettyPrinted: String {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return "\(self)"
        }
        return string
    }
}

extension String {
    var prettyJSON: String {
        guard let data = self.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return self
        }
        return prettyString
    }
}
```

---

## 💉 Dependency Injection

### Network Container

```swift
protocol NetworkContainer {
    var networkManager: NetworkManager { get }
    var configuration: NetworkConfiguration { get }
    var cacheManager: CacheManager { get }
    var tokenManager: TokenManager { get }
}

class DefaultNetworkContainer: NetworkContainer {
    static let shared = DefaultNetworkContainer()
    
    lazy var configuration: NetworkConfiguration = NetworkConfigurationImpl()
    
    lazy var tokenManager: TokenManager = KeychainTokenManager(
        service: "com.app.tokens"
    )
    
    lazy var cacheManager: CacheManager = NetworkCacheManager()
    
    lazy var networkManager: NetworkManager = {
        return AlamofireNetworkManager(
            configuration: configuration,
            tokenManager: tokenManager,
            cacheManager: cacheManager
        )
    }()
    
    private init() {}
}

// Usage with @EnvironmentObject in SwiftUI
class AppDependencies: ObservableObject {
    let networkContainer: NetworkContainer
    
    init(networkContainer: NetworkContainer = DefaultNetworkContainer.shared) {
        self.networkContainer = networkContainer
    }
}

// In SwiftUI App
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

---

## ⚙️ Dynamic Configuration

### Network Configuration Protocol

```swift
protocol NetworkConfiguration {
    var baseURL: String { get set }
    var apiVersion: String { get }
    var timeout: TimeInterval { get }
    var shouldLogRequests: Bool { get }
    
    func updateBaseURL(_ url: String)
    func updateAccessToken(_ token: String?)
}

class NetworkConfigurationImpl: NetworkConfiguration {
    private let userDefaults = UserDefaults.standard
    private let baseURLKey = "network.baseURL"
    
    var baseURL: String {
        get {
            return userDefaults.string(forKey: baseURLKey) ?? defaultBaseURL
        }
        set {
            userDefaults.set(newValue, forKey: baseURLKey)
            NotificationCenter.default.post(name: .baseURLDidChange, object: newValue)
        }
    }
    
    var apiVersion: String {
        return "v1"
    }
    
    var timeout: TimeInterval {
        return 30.0
    }
    
    var shouldLogRequests: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    private var defaultBaseURL: String {
        #if DEBUG
        return "https://api-dev.example.com"
        #else
        return "https://api.example.com"
        #endif
    }
    
    func updateBaseURL(_ url: String) {
        self.baseURL = url
    }
    
    func updateAccessToken(_ token: String?) {
        // Handled by TokenManager
    }
}

extension Notification.Name {
    static let baseURLDidChange = Notification.Name("baseURLDidChange")
    static let accessTokenDidChange = Notification.Name("accessTokenDidChange")
}
```

### Token Manager

```swift
protocol TokenManager {
    var accessToken: String? { get set }
    var refreshToken: String? { get set }
    
    func refreshToken(completion: @escaping (Result<Void, Error>) -> Void)
    func clearTokens()
}

class KeychainTokenManager: TokenManager {
    private let keychain: KeychainSwift
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"
    
    var accessToken: String? {
        get { keychain.get(accessTokenKey) }
        set {
            if let token = newValue {
                keychain.set(token, forKey: accessTokenKey)
            } else {
                keychain.delete(accessTokenKey)
            }
            NotificationCenter.default.post(name: .accessTokenDidChange, object: newValue)
        }
    }
    
    var refreshToken: String? {
        get { keychain.get(refreshTokenKey) }
        set {
            if let token = newValue {
                keychain.set(token, forKey: refreshTokenKey)
            } else {
                keychain.delete(refreshTokenKey)
            }
        }
    }
    
    init(service: String) {
        self.keychain = KeychainSwift()
        self.keychain.synchronizable = true
    }
    
    func refreshToken(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let refreshToken = refreshToken else {
            completion(.failure(NetworkError.unauthorized("No refresh token available")))
            return
        }
        
        // Call refresh token endpoint
        let url = "\(DefaultNetworkContainer.shared.configuration.baseURL)/auth/refresh"
        
        AF.request(url, method: .post, parameters: ["refresh_token": refreshToken])
            .validate()
            .responseDecodable(of: TokenResponse.self) { [weak self] response in
                switch response.result {
                case .success(let tokenResponse):
                    self?.accessToken = tokenResponse.accessToken
                    self?.refreshToken = tokenResponse.refreshToken
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
    }
}

struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
```

---

## 🚀 Complete Implementation

### Network Manager

```swift
protocol NetworkManager {
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        cachePolicy: CachePolicy
    ) async throws -> APIResponse<T>
}

enum CachePolicy {
    case ignoreCache
    case returnCacheElseLoad
    case returnCacheDontLoad
    case cacheResponse(expiration: CacheExpiration)
}

class AlamofireNetworkManager: NetworkManager {
    private let session: Session
    private let configuration: NetworkConfiguration
    private let cacheManager: CacheManager
    private let debouncer: RequestDebouncer
    
    init(
        configuration: NetworkConfiguration,
        tokenManager: TokenManager,
        cacheManager: CacheManager
    ) {
        self.configuration = configuration
        self.cacheManager = cacheManager
        self.debouncer = RequestDebouncer()
        
        let interceptor = APIRequestInterceptor(
            configuration: configuration,
            tokenManager: tokenManager
        )
        
        let logger = NetworkLogger()
        
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeout
        sessionConfiguration.timeoutIntervalForResource = configuration.timeout
        
        self.session = Session(
            configuration: sessionConfiguration,
            interceptor: interceptor,
            eventMonitors: configuration.shouldLogRequests ? [logger] : []
        )
    }
    
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        cachePolicy: CachePolicy = .ignoreCache
    ) async throws -> APIResponse<T> {
        
        // Check cache first
        if case .returnCacheElseLoad = cachePolicy,
           let cached: APIResponse<T> = cacheManager.retrieve(
            forKey: endpoint.cacheKey,
            as: APIResponse<T>.self
           ) {
            return cached
        }
        
        if case .returnCacheDontLoad = cachePolicy,
           let cached: APIResponse<T> = cacheManager.retrieve(
            forKey: endpoint.cacheKey,
            as: APIResponse<T>.self
           ) {
            return cached
        }
        
        // Make request
        let url = configuration.baseURL + endpoint.path
        
        let response = await session.request(
            url,
            method: endpoint.method,
            parameters: endpoint.parameters,
            encoding: endpoint.encoding,
            headers: endpoint.headers
        )
        .validate()
        .serializingDecodable(APIResponse<T>.self)
        .response
        
        // Handle response
        switch response.result {
        case .success(let apiResponse):
            // Cache response if needed
            if case .cacheResponse(let expiration) = cachePolicy {
                cacheManager.cache(apiResponse, forKey: endpoint.cacheKey, expiration: expiration)
            }
            
            return apiResponse
            
        case .failure(let error):
            // Handle status code errors
            if let statusCode = response.response?.statusCode,
               let networkError = StatusCodeHandler.handle(statusCode: statusCode, data: response.data) {
                throw networkError
            }
            
            // Handle AFError
            throw mapAFError(error)
        }
    }
    
    private func mapAFError(_ error: AFError) -> NetworkError {
        switch error {
        case .sessionTaskFailed(let urlError as URLError):
            if urlError.code == .timedOut {
                return .timeout("Request timeout")
            } else if urlError.code == .notConnectedToInternet {
                return .networkError(urlError)
            }
            return .networkError(urlError)
            
        case .responseSerializationFailed(let reason):
            if case .decodingFailed(let decodingError) = reason {
                return .decodingError(decodingError)
            }
            return .unknown(error.localizedDescription)
            
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
```

### Endpoint Definition

```swift
protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var parameters: Parameters? { get }
    var encoding: ParameterEncoding { get }
    var headers: HTTPHeaders? { get }
    var cacheKey: String { get }
}

extension Endpoint {
    var encoding: ParameterEncoding {
        switch method {
        case .get:
            return URLEncoding.default
        default:
            return JSONEncoding.default
        }
    }
    
    var headers: HTTPHeaders? {
        return nil
    }
    
    var cacheKey: String {
        let parametersString = parameters?.map { "\($0.key)=\($0.value)" }.joined(separator: "&") ?? ""
        return "\(path)?\(parametersString)"
    }
}

// Example endpoints
enum UserEndpoint: Endpoint {
    case getProfile(userId: String)
    case updateProfile(userId: String, data: [String: Any])
    case uploadAvatar(userId: String, image: Data)
    
    var path: String {
        switch self {
        case .getProfile(let userId):
            return "/users/\(userId)"
        case .updateProfile(let userId, _):
            return "/users/\(userId)"
        case .uploadAvatar(let userId, _):
            return "/users/\(userId)/avatar"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getProfile:
            return .get
        case .updateProfile:
            return .put
        case .uploadAvatar:
            return .post
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .getProfile:
            return nil
        case .updateProfile(_, let data):
            return data
        case .uploadAvatar:
            return nil
        }
    }
}
```

---

## 📖 Usage Examples

### In Repository

```swift
protocol UserRepository {
    func getProfile(userId: String) async throws -> User
    func updateProfile(userId: String, data: UpdateProfileRequest) async throws -> User
}

class UserRepositoryImpl: UserRepository {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func getProfile(userId: String) async throws -> User {
        let response = try await networkManager.request(
            UserEndpoint.getProfile(userId: userId),
            responseType: User.self,
            cachePolicy: .returnCacheElseLoad
        )
        
        guard response.isSuccess, let user = response.data else {
            throw NetworkError.unknown(response.message)
        }
        
        return user
    }
    
    func updateProfile(userId: String, data: UpdateProfileRequest) async throws -> User {
        let parameters = try data.asDictionary()
        
        let response = try await networkManager.request(
            UserEndpoint.updateProfile(userId: userId, data: parameters),
            responseType: User.self,
            cachePolicy: .ignoreCache
        )
        
        guard response.isSuccess, let user = response.data else {
            throw NetworkError.unknown(response.message)
        }
        
        return user
    }
}
```

### In ViewModel

```swift
@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let getUserProfileUseCase: GetUserProfileUseCase
    private let debouncer = RequestDebouncer(delay: 0.5)
    
    init(getUserProfileUseCase: GetUserProfileUseCase) {
        self.getUserProfileUseCase = getUserProfileUseCase
    }
    
    func loadProfile(userId: String) {
        debouncer.debounce(key: "loadProfile") { [weak self] in
            await self?.performLoadProfile(userId: userId)
        }
    }
    
    private func performLoadProfile(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            user = try await getUserProfileUseCase.execute(userId: userId)
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }
        
        isLoading = false
    }
}
```

### In SwiftUI View

```swift
struct UserProfileView: View {
    @EnvironmentObject var dependencies: AppDependencies
    @StateObject private var viewModel: UserProfileViewModel
    
    init() {
        let getUserProfileUseCase = GetUserProfileUseCase(
            repository: dependencies.networkContainer.userRepository
        )
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(
            getUserProfileUseCase: getUserProfileUseCase
        ))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let user = viewModel.user {
                UserDetailView(user: user)
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    viewModel.loadProfile(userId: "123")
                }
            }
        }
        .onAppear {
            viewModel.loadProfile(userId: "123")
        }
    }
}
```

### Dynamic Configuration Update

```swift
class SettingsViewModel: ObservableObject {
    @Published var currentBaseURL: String
    
    private let configuration: NetworkConfiguration
    
    init(configuration: NetworkConfiguration) {
        self.configuration = configuration
        self.currentBaseURL = configuration.baseURL
    }
    
    func updateBaseURL(_ newURL: String) {
        configuration.updateBaseURL(newURL)
        currentBaseURL = newURL
    }
    
    func resetToDefault() {
        #if DEBUG
        updateBaseURL("https://api-dev.example.com")
        #else
        updateBaseURL("https://api.example.com")
        #endif
    }
}
```

---

## 🧪 Testing

### Mock Network Manager

```swift
class MockNetworkManager: NetworkManager {
    var mockResponse: Any?
    var mockError: Error?
    var requestCalled = false
    
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        cachePolicy: CachePolicy
    ) async throws -> APIResponse<T> {
        requestCalled = true
        
        if let error = mockError {
            throw error
        }
        
        if let response = mockResponse as? APIResponse<T> {
            return response
        }
        
        throw NetworkError.unknown("No mock response configured")
    }
}

// Usage in tests
class UserRepositoryTests: XCTestCase {
    var sut: UserRepositoryImpl!
    var mockNetworkManager: MockNetworkManager!
    
    override func setUp() {
        super.setUp()
        mockNetworkManager = MockNetworkManager()
        sut = UserRepositoryImpl(networkManager: mockNetworkManager)
    }
    
    func testGetProfile_Success() async throws {
        // Given
        let expectedUser = User(id: "123", name: "John Doe")
        mockNetworkManager.mockResponse = APIResponse(
            isSuccess: true,
            message: "Success",
            messages: nil,
            createdAt: Date(),
            data: expectedUser,
            statusCode: 200,
            metadata: nil
        )
        
        // When
        let user = try await sut.getProfile(userId: "123")
        
        // Then
        XCTAssertTrue(mockNetworkManager.requestCalled)
        XCTAssertEqual(user.id, expectedUser.id)
        XCTAssertEqual(user.name, expectedUser.name)
    }
}
```

---

## ⚠️ Common Pitfalls

### 1. **Not Handling All Status Codes**
❌ Bad:
```swift
if response.statusCode == 200 {
    // Handle success only
}
```

✅ Good:
```swift
switch response.statusCode {
case 200...299:
    // Handle success
case 401:
    // Handle unauthorized
case 500...599:
    // Handle server error
default:
    // Handle unknown
}
```

### 2. **Ignoring Token Refresh**
❌ Bad:
```swift
if statusCode == 401 {
    throw NetworkError.unauthorized
}
```

✅ Good:
```swift
// Use RequestInterceptor to automatically refresh tokens
// and retry failed requests
```

### 3. **Not Debouncing Search**
❌ Bad:
```swift
func searchUsers(query: String) {
    // Fires on every keystroke
    performSearch(query)
}
```

✅ Good:
```swift
func searchUsers(query: String) {
    debouncer.debounce(key: "search") {
        performSearch(query)
    }
}
```

### 4. **Caching Everything**
❌ Bad:
```swift
// Caching sensitive data or POST requests
cacheManager.cache(creditCard, forKey: "card")
```

✅ Good:
```swift
// Only cache safe, read-only data
cachePolicy: .returnCacheElseLoad // For GET requests only
```

### 5. **Hardcoding URLs**
❌ Bad:
```swift
let url = "https://api.example.com/users"
```

✅ Good:
```swift
let url = configuration.baseURL + "/users"
```

---

## 📚 Additional Resources

- [Alamofire Documentation](https://github.com/Alamofire/Alamofire)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [SwiftUI MVVM Architecture](https://www.swiftbysundell.com/articles/mvvm-in-swift/)
- [Dependency Injection in Swift](https://www.swiftbysundell.com/articles/dependency-injection-using-factories-in-swift/)

---

## 🎯 Checklist

Use this checklist to ensure your implementation is complete:

- [ ] Alamofire integrated with Session configuration
- [ ] Request interceptor for authentication
- [ ] Comprehensive status code handling (200-500)
- [ ] Standardized response model with metadata
- [ ] Multi-layer caching (memory + disk)
- [ ] Request debouncing for search/filters
- [ ] HTTP logging with request/response details
- [ ] Dependency injection container
- [ ] Dynamic base URL configuration
- [ ] Dynamic access token management
- [ ] Token refresh mechanism
- [ ] Error handling with user-friendly messages
- [ ] Unit tests for repositories
- [ ] Integration tests for network layer

---

**Last Updated:** November 2025
**Version:** 1.0.0
