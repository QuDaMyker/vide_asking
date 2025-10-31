import Foundation
import CryptoKit
import Security
import CommonCrypto

/**
 * Comprehensive Cryptography Manager for iOS
 * Handles encryption, decryption, key management, and secure operations
 */
@available(iOS 13.0, *)
class CryptoManager {
    
    // MARK: - AES Encryption
    
    /**
     * Encrypt data with AES-256-GCM
     */
    func encryptAES(data: Data, key: SymmetricKey) throws -> EncryptedData {
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        
        return EncryptedData(
            ciphertext: combined,
            nonce: sealedBox.nonce,
            tag: sealedBox.tag
        )
    }
    
    /**
     * Decrypt data with AES-256-GCM
     */
    func decryptAES(encryptedData: EncryptedData, key: SymmetricKey) throws -> Data {
        guard let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData.ciphertext) else {
            throw CryptoError.decryptionFailed
        }
        
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    /**
     * Generate symmetric key
     */
    func generateSymmetricKey(size: SymmetricKeySize = .bits256) -> SymmetricKey {
        return SymmetricKey(size: size)
    }
    
    // MARK: - ChaCha20-Poly1305 Encryption
    
    /**
     * Encrypt with ChaCha20-Poly1305 (faster on mobile)
     */
    func encryptChaCha20(data: Data, key: SymmetricKey) throws -> EncryptedData {
        let sealedBox = try ChaChaPoly.seal(data, using: key)
        
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        
        return EncryptedData(
            ciphertext: combined,
            nonce: sealedBox.nonce,
            tag: sealedBox.tag
        )
    }
    
    /**
     * Decrypt with ChaCha20-Poly1305
     */
    func decryptChaCha20(encryptedData: EncryptedData, key: SymmetricKey) throws -> Data {
        guard let sealedBox = try? ChaChaPoly.SealedBox(combined: encryptedData.ciphertext) else {
            throw CryptoError.decryptionFailed
        }
        
        return try ChaChaPoly.open(sealedBox, using: key)
    }
    
    // MARK: - RSA Encryption
    
    /**
     * Generate RSA key pair
     */
    func generateRSAKeyPair(keySize: Int = 2048) throws -> (publicKey: SecKey, privateKey: SecKey) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: keySize,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw CryptoError.keyGenerationFailed(error?.takeRetainedValue().localizedDescription ?? "Unknown")
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CryptoError.keyGenerationFailed("Failed to extract public key")
        }
        
        return (publicKey, privateKey)
    }
    
    /**
     * Encrypt with RSA public key
     */
    func encryptRSA(data: Data, publicKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(
            publicKey,
            .rsaEncryptionOAEPSHA256,
            data as CFData,
            &error
        ) else {
            throw CryptoError.encryptionFailed
        }
        
        return encryptedData as Data
    }
    
    /**
     * Decrypt with RSA private key
     */
    func decryptRSA(encryptedData: Data, privateKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let decryptedData = SecKeyCreateDecryptedData(
            privateKey,
            .rsaEncryptionOAEPSHA256,
            encryptedData as CFData,
            &error
        ) else {
            throw CryptoError.decryptionFailed
        }
        
        return decryptedData as Data
    }
    
    // MARK: - ECC Encryption
    
    /**
     * Generate ECC key pair (P-256)
     */
    func generateECCKeyPair() throws -> (publicKey: P256.KeyAgreement.PublicKey, privateKey: P256.KeyAgreement.PrivateKey) {
        let privateKey = P256.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        return (publicKey, privateKey)
    }
    
    /**
     * Perform ECDH key agreement
     */
    func performECDH(
        privateKey: P256.KeyAgreement.PrivateKey,
        publicKey: P256.KeyAgreement.PublicKey
    ) throws -> SymmetricKey {
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: 32
        )
    }
    
    // MARK: - Key Derivation
    
    /**
     * Derive key from password using PBKDF2
     */
    func deriveKeyFromPassword(
        password: String,
        salt: Data,
        iterations: Int = 100_000,
        keyLength: Int = 32
    ) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw CryptoError.invalidInput
        }
        
        var derivedKeyData = Data(count: keyLength)
        let result = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }
        
        guard result == kCCSuccess else {
            throw CryptoError.keyDerivationFailed
        }
        
        return SymmetricKey(data: derivedKeyData)
    }
    
    /**
     * Generate cryptographically secure random salt
     */
    func generateSalt(size: Int = 32) -> Data {
        var salt = Data(count: size)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, size, $0.baseAddress!) }
        return salt
    }
    
    // MARK: - Digital Signatures
    
    /**
     * Sign data with ECC private key
     */
    func signData(data: Data, privateKey: P256.Signing.PrivateKey) throws -> Data {
        let signature = try privateKey.signature(for: data)
        return signature.derRepresentation
    }
    
    /**
     * Verify signature with ECC public key
     */
    func verifySignature(
        data: Data,
        signature: Data,
        publicKey: P256.Signing.PublicKey
    ) -> Bool {
        guard let ecdsaSignature = try? P256.Signing.ECDSASignature(derRepresentation: signature) else {
            return false
        }
        
        return publicKey.isValidSignature(ecdsaSignature, for: data)
    }
    
    /**
     * Generate signing key pair
     */
    func generateSigningKeyPair() -> (publicKey: P256.Signing.PublicKey, privateKey: P256.Signing.PrivateKey) {
        let privateKey = P256.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        return (publicKey, privateKey)
    }
    
    // MARK: - Hashing
    
    /**
     * Hash data with SHA-256
     */
    func hashSHA256(data: Data) -> Data {
        return Data(SHA256.hash(data: data))
    }
    
    /**
     * Hash data with SHA-512
     */
    func hashSHA512(data: Data) -> Data {
        return Data(SHA512.hash(data: data))
    }
    
    /**
     * HMAC-SHA256
     */
    func hmacSHA256(data: Data, key: SymmetricKey) -> Data {
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(authenticationCode)
    }
    
    // MARK: - Keychain Storage
    
    /**
     * Store key in Keychain
     */
    func storeKeyInKeychain(
        key: Data,
        tag: String,
        requireBiometry: Bool = false
    ) throws {
        var accessControl: SecAccessControl
        if requireBiometry {
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
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "CryptoManager",
            kSecAttrAccount as String: tag,
            kSecValueData as String: key,
            kSecAttrAccessControl as String: accessControl
        ]
        
        // Delete existing
        SecItemDelete(query as CFDictionary)
        
        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CryptoError.keychainError(status)
        }
    }
    
    /**
     * Retrieve key from Keychain
     */
    func retrieveKeyFromKeychain(tag: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "CryptoManager",
            kSecAttrAccount as String: tag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw CryptoError.keychainError(status)
        }
        
        return data
    }
    
    /**
     * Delete key from Keychain
     */
    func deleteKeyFromKeychain(tag: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "CryptoManager",
            kSecAttrAccount as String: tag
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Utility
    
    /**
     * Secure wipe data
     */
    func secureWipe(data: inout Data) {
        data.withUnsafeMutableBytes { ptr in
            memset(ptr.baseAddress, 0, data.count)
        }
        data.removeAll()
    }
    
    /**
     * Generate random bytes
     */
    func generateRandomBytes(count: Int) -> Data {
        var bytes = Data(count: count)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        return bytes
    }
}

// MARK: - Data Models

struct EncryptedData {
    let ciphertext: Data
    let nonce: AES.GCM.Nonce
    let tag: Data
}

enum CryptoError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed(String)
    case keyDerivationFailed
    case invalidInput
    case keychainError(OSStatus)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        case .keyGenerationFailed(let message):
            return "Key generation failed: \(message)"
        case .keyDerivationFailed:
            return "Key derivation failed"
        case .invalidInput:
            return "Invalid input"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .unknown(let message):
            return message
        }
    }
}
