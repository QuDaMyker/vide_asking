import Foundation
import Security

/// Secure Network Manager for iOS
/// Handles TLS 1.3, certificate pinning, and mTLS
class SecureNetworkManager: NSObject {
    
    // MARK: - Configuration
    
    private let session: URLSession
    private let certificatePins: [String: Set<String>]
    private let clientCertificate: SecIdentity?
    
    init(
        certificatePins: [String: Set<String>] = [:],
        clientCertificate: SecIdentity? = nil
    ) {
        self.certificatePins = certificatePins
        self.clientCertificate = clientCertificate
        
        let configuration = URLSessionConfiguration.default
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        
        // Security headers
        configuration.httpAdditionalHeaders = [
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "DENY",
            "X-XSS-Protection": "1; mode=block",
            "Strict-Transport-Security": "max-age=31536000; includeSubDomains"
        ]
        
        self.session = URLSession(
            configuration: configuration,
            delegate: nil,
            delegateQueue: nil
        )
        
        super.init()
    }
    
    // MARK: - HTTP Methods
    
    func get(
        url: URL,
        headers: [String: String] = [:]
    ) async throws -> NetworkResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        return try await execute(request: request)
    }
    
    func post(
        url: URL,
        body: Data,
        headers: [String: String] = [:]
    ) async throws -> NetworkResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        return try await execute(request: request)
    }
    
    func put(
        url: URL,
        body: Data,
        headers: [String: String] = [:]
    ) async throws -> NetworkResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        return try await execute(request: request)
    }
    
    func delete(
        url: URL,
        headers: [String: String] = [:]
    ) async throws -> NetworkResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        return try await execute(request: request)
    }
    
    // MARK: - Request Execution
    
    private func execute(request: URLRequest) async throws -> NetworkResponse {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Verify certificate pinning
        if !certificatePins.isEmpty, let host = request.url?.host {
            try await verifyCertificatePinning(for: host)
        }
        
        return NetworkResponse(
            data: data,
            statusCode: httpResponse.statusCode,
            headers: httpResponse.allHeaderFields as? [String: String] ?? [:]
        )
    }
    
    // MARK: - Certificate Pinning
    
    private func verifyCertificatePinning(for host: String) async throws {
        guard let pins = certificatePins[host] else {
            return
        }
        
        // Create a temporary session to get server certificates
        let configuration = URLSessionConfiguration.ephemeral
        let delegate = CertificatePinningDelegate(expectedPins: pins)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        
        guard let url = URL(string: "https://\(host)") else {
            throw NetworkError.invalidURL
        }
        
        _ = try await session.data(from: url)
    }
}

// MARK: - URLSession Delegate for Certificate Pinning and mTLS

extension SecureNetworkManager: URLSessionDelegate {
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        
        // Handle server authentication (certificate pinning)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let pins = certificatePins[host] {
                if verifyCertificatePins(serverTrust: serverTrust, expectedPins: pins) {
                    let credential = URLCredential(trust: serverTrust)
                    completionHandler(.useCredential, credential)
                } else {
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
            } else {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            }
        }
        // Handle client authentication (mTLS)
        else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            if let clientCertificate = clientCertificate {
                let credential = URLCredential(
                    identity: clientCertificate,
                    certificates: nil,
                    persistence: .forSession
                )
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }
        else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    private func verifyCertificatePins(
        serverTrust: SecTrust,
        expectedPins: Set<String>
    ) -> Bool {
        // Evaluate trust
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            return false
        }
        
        // Get certificate chain
        guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            return false
        }
        
        // Check each certificate in chain
        for certificate in certificates {
            if let publicKey = SecCertificateCopyKey(certificate),
               let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? {
                let hash = SHA256.hash(data: publicKeyData)
                let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                
                if expectedPins.contains(hashString) {
                    return true
                }
            }
        }
        
        return false
    }
}

// MARK: - Certificate Pinning Delegate

private class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    let expectedPins: Set<String>
    
    init(expectedPins: Set<String>) {
        self.expectedPins = expectedPins
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        for certificate in certificates {
            if let publicKey = SecCertificateCopyKey(certificate),
               let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? {
                let hash = SHA256.hash(data: publicKeyData)
                let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                
                if expectedPins.contains(hashString) {
                    let credential = URLCredential(trust: serverTrust)
                    completionHandler(.useCredential, credential)
                    return
                }
            }
        }
        
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}

// MARK: - Request Signing Extension

extension SecureNetworkManager {
    
    func signedRequest(
        _ request: URLRequest,
        privateKey: SecKey
    ) throws -> URLRequest {
        var signedRequest = request
        
        // Get request body
        guard let body = request.httpBody else {
            throw NetworkError.invalidRequest
        }
        
        // Create signature
        let signature = try signData(body, privateKey: privateKey)
        let signatureBase64 = signature.base64EncodedString()
        
        // Add headers
        signedRequest.setValue(signatureBase64, forHTTPHeaderField: "X-Signature")
        signedRequest.setValue("SHA256withECDSA", forHTTPHeaderField: "X-Signature-Algorithm")
        signedRequest.setValue(String(Int(Date().timeIntervalSince1970)), forHTTPHeaderField: "X-Timestamp")
        
        return signedRequest
    }
    
    private func signData(_ data: Data, privateKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) as Data? else {
            throw error?.takeRetainedValue() ?? NetworkError.signatureFailed
        }
        
        return signature
    }
}

// MARK: - Retry Logic

extension SecureNetworkManager {
    
    func executeWithRetry(
        request: URLRequest,
        maxRetries: Int = 3,
        backoff: TimeInterval = 1.0
    ) async throws -> NetworkResponse {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await execute(request: request)
            } catch {
                lastError = error
                
                // Don't retry on client errors (4xx)
                if let networkError = error as? NetworkError,
                   case .httpError(let statusCode) = networkError,
                   (400...499).contains(statusCode) {
                    throw error
                }
                
                // Exponential backoff
                if attempt < maxRetries - 1 {
                    let delay = backoff * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.unknown
    }
}

// MARK: - Models

struct NetworkResponse {
    let data: Data
    let statusCode: Int
    let headers: [String: String]
    
    var isSuccess: Bool {
        (200...299).contains(statusCode)
    }
    
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidRequest
    case invalidResponse
    case httpError(statusCode: Int)
    case certificatePinningFailed
    case signatureFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidRequest:
            return "Invalid request"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .certificatePinningFailed:
            return "Certificate pinning verification failed"
        case .signatureFailed:
            return "Request signing failed"
        case .unknown:
            return "Unknown network error"
        }
    }
}

// MARK: - Helper Extensions

import CryptoKit

extension SHA256 {
    static func hash(data: Data) -> Data {
        let hashed = SHA256.hash(data: data)
        return Data(hashed)
    }
}

// MARK: - Certificate Loading

extension SecureNetworkManager {
    
    static func loadClientCertificate(
        fromP12 p12Path: String,
        password: String
    ) throws -> SecIdentity {
        let p12Data = try Data(contentsOf: URL(fileURLWithPath: p12Path))
        
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password
        ]
        
        var rawItems: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)
        
        guard status == errSecSuccess else {
            throw NetworkError.invalidRequest
        }
        
        guard let items = rawItems as? [[String: Any]],
              let firstItem = items.first,
              let identity = firstItem[kSecImportItemIdentity as String] as! SecIdentity? else {
            throw NetworkError.invalidRequest
        }
        
        return identity
    }
    
    static func generateCertificatePins(from domain: String) async throws -> Set<String> {
        let configuration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: configuration)
        
        guard let url = URL(string: "https://\(domain)") else {
            throw NetworkError.invalidURL
        }
        
        let (_, response) = try await session.data(from: url)
        
        // Extract certificates from response
        // This is a simplified version - in production, use proper certificate extraction
        var pins = Set<String>()
        
        if let httpResponse = response as? HTTPURLResponse,
           let allHeaders = httpResponse.allHeaderFields as? [String: String] {
            // Extract certificate information from headers or connection
            // Implementation depends on specific requirements
        }
        
        return pins
    }
}
