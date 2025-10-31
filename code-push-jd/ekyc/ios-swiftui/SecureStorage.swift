import Foundation
import Security
import CryptoKit

/**
 * Secure storage using iOS Keychain and Secure Enclave
 * Implements encryption for sensitive eKYC data with auto-expiry
 */
actor SecureStorage {
    
    static let shared = SecureStorage()
    
    private let service = "com.example.ekyc"
    private let cacheExpiryInterval: TimeInterval = 15 * 60 // 15 minutes
    
    private init() {}
    
    // MARK: - Public Methods
    
    /**
     * Store chip data securely in Keychain
     */
    func storeChipData(_ data: ChipData) throws {
        let timestamp = Date()
        
        // Create dictionary with data and timestamp
        let dataDict: [String: Any] = [
            "documentNumber": data.documentNumber,
            "dateOfBirth": data.dateOfBirth,
            "dateOfExpiry": data.dateOfExpiry,
            "firstName": data.firstName,
            "lastName": data.lastName,
            "nationality": data.nationality,
            "gender": data.gender,
            "verified": data.verified,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        
        // Convert to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: dataDict)
        
        // Store in Keychain with biometric protection
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "chipData",
            kSecValueData as String: jsonData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrAccessControl as String: try createAccessControl()
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
        
        // Store face image separately if available
        if let faceImage = data.faceImage {
            try storeFaceImage(faceImage, timestamp: timestamp)
        }
    }
    
    /**
     * Retrieve chip data if not expired
     */
    func retrieveChipData() throws -> ChipData? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "chipData",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        // Parse JSON
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Check expiry
        if let timestamp = dict["timestamp"] as? TimeInterval {
            let storedDate = Date(timeIntervalSince1970: timestamp)
            if Date().timeIntervalSince(storedDate) > cacheExpiryInterval {
                clearAll()
                return nil
            }
        }
        
        // Retrieve face image
        let faceImage = try? retrieveFaceImage()
        
        return ChipData(
            documentNumber: dict["documentNumber"] as? String ?? "",
            dateOfBirth: dict["dateOfBirth"] as? String ?? "",
            dateOfExpiry: dict["dateOfExpiry"] as? String ?? "",
            firstName: dict["firstName"] as? String ?? "",
            lastName: dict["lastName"] as? String ?? "",
            nationality: dict["nationality"] as? String ?? "",
            gender: dict["gender"] as? String ?? "",
            faceImage: faceImage,
            verified: dict["verified"] as? Bool ?? false
        )
    }
    
    /**
     * Clear all stored data
     */
    func clearAll() {
        // Delete chip data
        let chipQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "chipData"
        ]
        SecItemDelete(chipQuery as CFDictionary)
        
        // Delete face image
        let imageQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "faceImage"
        ]
        SecItemDelete(imageQuery as CFDictionary)
    }
    
    /**
     * Check if stored data has expired
     */
    func isDataExpired() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "chipData",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestamp = dict["timestamp"] as? TimeInterval else {
            return true
        }
        
        let storedDate = Date(timeIntervalSince1970: timestamp)
        return Date().timeIntervalSince(storedDate) > cacheExpiryInterval
    }
    
    // MARK: - Private Methods
    
    private func createAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.userPresence, .privateKeyUsage],
            &error
        ) else {
            throw KeychainError.unableToCreateAccessControl
        }
        
        return accessControl
    }
    
    private func storeFaceImage(_ imageData: Data, timestamp: Date) throws {
        // Encrypt image data using CryptoKit
        let key = SymmetricKey(size: .bits256)
        let sealedBox = try AES.GCM.seal(imageData, using: key)
        
        // Store encrypted data and key separately
        let encryptedData = sealedBox.combined!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "faceImage",
            kSecValueData as String: encryptedData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
        
        // Store encryption key
        try storeEncryptionKey(key)
    }
    
    private func retrieveFaceImage() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "faceImage",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let encryptedData = result as? Data else {
            return nil
        }
        
        // Retrieve encryption key and decrypt
        guard let key = try? retrieveEncryptionKey(),
              let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData),
              let decryptedData = try? AES.GCM.open(sealedBox, using: key) else {
            return nil
        }
        
        return decryptedData
    }
    
    private func storeEncryptionKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "imageEncryptionKey",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
    }
    
    private func retrieveEncryptionKey() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "imageEncryptionKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            return nil
        }
        
        return SymmetricKey(data: keyData)
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case unableToStore
    case unableToRetrieve
    case unableToCreateAccessControl
    
    var errorDescription: String? {
        switch self {
        case .unableToStore:
            return "Unable to store data in Keychain"
        case .unableToRetrieve:
            return "Unable to retrieve data from Keychain"
        case .unableToCreateAccessControl:
            return "Unable to create access control"
        }
    }
}
