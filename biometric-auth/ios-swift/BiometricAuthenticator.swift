import LocalAuthentication
import Foundation
import CryptoKit

/**
 * Comprehensive Biometric Authentication Manager for iOS
 * Supports Touch ID, Face ID with Secure Enclave integration
 */
@available(iOS 13.0, *)
class BiometricAuthenticator {
    
    private let context = LAContext()
    
    // MARK: - Availability Check
    
    /**
     * Check biometric availability
     */
    func canAuthenticate() -> BiometricAvailability {
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                switch LAError.Code(rawValue: error.code) {
                case .biometryNotAvailable:
                    return .notAvailable
                case .biometryNotEnrolled:
                    return .notEnrolled
                case .biometryLockout:
                    return .lockedOut
                case .passcodeNotSet:
                    return .passcodeNotSet
                default:
                    return .unknown(error.localizedDescription)
                }
            }
            return .unknown("Unknown error")
        }
        
        return .available(getBiometricType())
    }
    
    /**
     * Get biometric type (Touch ID or Face ID)
     */
    func getBiometricType() -> BiometricType {
        switch context.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        @unknown default:
            return .unknown
        }
    }
    
    // MARK: - Authentication
    
    /**
     * Authenticate with biometric
     * @param reason: User-facing reason for authentication
     * @param fallbackTitle: Optional fallback button title
     */
    func authenticate(
        reason: String,
        fallbackTitle: String? = nil,
        completion: @escaping (Result<LAContext, BiometricError>) -> Void
    ) {
        let context = LAContext()
        context.localizedFallbackTitle = fallbackTitle
        context.localizedCancelTitle = "Cancel"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(.failure(.notAvailable(error?.localizedDescription ?? "Biometric not available")))
            return
        }
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(context))
                } else {
                    if let error = error as? LAError {
                        completion(.failure(self.mapLAError(error)))
                    } else {
                        completion(.failure(.unknown(error?.localizedDescription ?? "Unknown error")))
                    }
                }
            }
        }
    }
    
    /**
     * Authenticate with async/await
     */
    @available(iOS 15.0, *)
    func authenticate(reason: String, fallbackTitle: String? = nil) async throws -> LAContext {
        return try await withCheckedThrowingContinuation { continuation in
            authenticate(reason: reason, fallbackTitle: fallbackTitle) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /**
     * Authenticate with device passcode fallback
     */
    func authenticateWithPasscode(
        reason: String,
        completion: @escaping (Result<LAContext, BiometricError>) -> Void
    ) {
        let context = LAContext()
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(.failure(.notAvailable(error?.localizedDescription ?? "Authentication not available")))
            return
        }
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(context))
                } else {
                    if let error = error as? LAError {
                        completion(.failure(self.mapLAError(error)))
                    } else {
                        completion(.failure(.unknown(error?.localizedDescription ?? "Unknown error")))
                    }
                }
            }
        }
    }
    
    // MARK: - Biometric-Bound Keys
    
    /**
     * Create biometric-protected key in Secure Enclave
     */
    func createBiometricProtectedKey(
        tag: String,
        requiresBiometry: Bool = true
    ) throws -> SecKey {
        guard SecureEnclave.isAvailable else {
            throw BiometricError.secureEnclaveNotAvailable
        }
        
        var accessControl: SecAccessControl
        if requiresBiometry {
            accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.privateKeyUsage, .biometryCurrentSet],
                nil
            )!
        } else {
            accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .privateKeyUsage,
                nil
            )!
        }
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
                kSecAttrAccessControl as String: accessControl
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw BiometricError.keyGenerationFailed(error?.takeRetainedValue().localizedDescription ?? "Unknown error")
        }
        
        return privateKey
    }
    
    /**
     * Retrieve biometric-protected key
     */
    func getBiometricProtectedKey(tag: String, context: LAContext? = nil) -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: context as Any
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        return item as! SecKey?
    }
    
    /**
     * Delete biometric-protected key
     */
    func deleteBiometricProtectedKey(tag: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Helper Methods
    
    private func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancelled
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCancelled
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryNotAvailable:
            return .notAvailable("Biometry not available")
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .lockedOut
        case .appCancel:
            return .appCancelled
        case .invalidContext:
            return .invalidContext
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - Data Models

enum BiometricAvailability {
    case available(BiometricType)
    case notAvailable
    case notEnrolled
    case lockedOut
    case passcodeNotSet
    case unknown(String)
    
    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }
    
    var userMessage: String {
        switch self {
        case .available(let type):
            return "\(type.displayName) is available"
        case .notAvailable:
            return "Biometric authentication not available on this device"
        case .notEnrolled:
            return "No biometrics enrolled. Please set up in Settings"
        case .lockedOut:
            return "Biometric authentication locked. Use passcode"
        case .passcodeNotSet:
            return "Device passcode not set. Please set up in Settings"
        case .unknown(let message):
            return message
        }
    }
}

enum BiometricType {
    case none
    case touchID
    case faceID
    case unknown
    
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .unknown:
            return "Unknown"
        }
    }
}

enum BiometricError: Error, LocalizedError {
    case notAvailable(String)
    case notEnrolled
    case lockedOut
    case passcodeNotSet
    case authenticationFailed
    case userCancelled
    case userFallback
    case systemCancelled
    case appCancelled
    case invalidContext
    case secureEnclaveNotAvailable
    case keyGenerationFailed(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable(let message):
            return "Biometric not available: \(message)"
        case .notEnrolled:
            return "No biometrics enrolled"
        case .lockedOut:
            return "Biometric authentication locked out"
        case .passcodeNotSet:
            return "Device passcode not set"
        case .authenticationFailed:
            return "Authentication failed"
        case .userCancelled:
            return "User cancelled authentication"
        case .userFallback:
            return "User selected fallback"
        case .systemCancelled:
            return "System cancelled authentication"
        case .appCancelled:
            return "App cancelled authentication"
        case .invalidContext:
            return "Invalid authentication context"
        case .secureEnclaveNotAvailable:
            return "Secure Enclave not available"
        case .keyGenerationFailed(let message):
            return "Key generation failed: \(message)"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Secure Enclave Helper

struct SecureEnclave {
    static var isAvailable: Bool {
        return SecureEnclave.isSupported()
    }
    
    private static func isSupported() -> Bool {
        // Check if device supports Secure Enclave
        var error: Unmanaged<CFError>?
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave
        ]
        
        let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error)
        if let key = key {
            // Clean up test key
            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecValueRef as String: key
            ]
            SecItemDelete(query as CFDictionary)
            return true
        }
        
        return false
    }
}
