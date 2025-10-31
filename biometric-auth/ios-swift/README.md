# Biometric Authentication & Cryptography - iOS (Swift)

Complete implementation of biometric authentication, encryption, and secure communication for iOS using Swift, SwiftUI, and Apple Security frameworks.

## 📋 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Security Features](#security-features)
- [Testing](#testing)
- [App Store Requirements](#app-store-requirements)

---

## ✨ Features

### Biometric Authentication
- ✅ Touch ID and Face ID support
- ✅ LocalAuthentication framework integration
- ✅ Secure Enclave key generation
- ✅ Biometric-bound cryptographic operations
- ✅ Fallback to device passcode

### Encryption
- ✅ AES-256-GCM (CryptoKit)
- ✅ ChaCha20-Poly1305 encryption
- ✅ RSA-2048/4096 asymmetric encryption
- ✅ ECC P-256 key agreement
- ✅ PBKDF2 key derivation
- ✅ Digital signatures (ECDSA)

### Secure Networking
- ✅ TLS 1.3 support
- ✅ Certificate pinning
- ✅ Mutual TLS (mTLS)
- ✅ Request signing
- ✅ Retry with exponential backoff
- ✅ URLSession security

---

## 📦 Requirements

### Minimum iOS Version
```swift
iOS 14.0+
iPadOS 14.0+
macOS 11.0+ (for Mac Catalyst)
```

### Xcode
```
Xcode 15.0+
Swift 5.9+
```

### Frameworks

```swift
import LocalAuthentication    // Biometric authentication
import CryptoKit              // Modern cryptography
import Security               // Keychain, certificates
import CommonCrypto          // PBKDF2
import Foundation            // Networking
```

---

## 🚀 Installation

### 1. Add Capabilities

In Xcode, add these capabilities to your target:

**Keychain Sharing** (Optional, for shared keychain access)
```
Signing & Capabilities → + Capability → Keychain Sharing
```

### 2. Update Info.plist

Add biometric usage descriptions:

```xml
<key>NSFaceIDUsageDescription</key>
<string>We use Face ID to secure your data</string>

<!-- Optional: Camera for additional verification -->
<key>NSCameraUsageDescription</key>
<string>Camera is used for identity verification</string>
```

### 3. Privacy Manifest

Create `PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>E174.1</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyTracking</key>
    <false/>
</dict>
</plist>
```

### 4. Copy Implementation Files

Add these files to your project:

```
YourApp/Security/
├── BiometricAuthenticator.swift
├── CryptoManager.swift
└── SecureNetworkManager.swift
```

---

## 💻 Usage

### Biometric Authentication

#### Check Availability

```swift
let biometricAuth = BiometricAuthenticator()

let availability = biometricAuth.checkAvailability()
switch availability {
case .available(let biometryType):
    print("Available: \(biometryType)") // .faceID or .touchID
case .notAvailable(let reason):
    print("Not available: \(reason)")
case .notEnrolled:
    print("No biometrics enrolled")
case .passcodeNotSet:
    print("Device passcode not set")
}
```

#### Authenticate

```swift
Task {
    do {
        let success = try await biometricAuth.authenticate(
            reason: "Authenticate to access your data"
        )
        
        if success {
            // Authentication successful
        }
    } catch {
        // Handle error
        print("Authentication failed: \(error.localizedDescription)")
    }
}
```

#### Biometric-Bound Keys

```swift
// Generate key in Secure Enclave
do {
    let privateKey = try biometricAuth.generateSecureEnclaveKey(
        tag: "com.yourapp.biometric-key"
    )
    
    // Key can only be used after biometric authentication
    // Use with CryptoManager for encryption/signing
    
} catch {
    print("Failed to generate key: \(error)")
}
```

### Encryption

#### AES-256-GCM

```swift
let cryptoManager = CryptoManager()

// Generate key
let key = cryptoManager.generateAESKey()

// Encrypt
do {
    let encrypted = try cryptoManager.encryptAESGCM(
        data: plainData,
        key: key
    )
    
    // Decrypt
    let decrypted = try cryptoManager.decryptAESGCM(
        sealedBox: encrypted,
        key: key
    )
} catch {
    print("Encryption failed: \(error)")
}
```

#### ChaCha20-Poly1305

```swift
// Faster on mobile processors
do {
    let encrypted = try cryptoManager.encryptChaCha20(
        data: plainData,
        key: key
    )
    
    let decrypted = try cryptoManager.decryptChaCha20(
        sealedData: encrypted,
        key: key
    )
} catch {
    print("Encryption failed: \(error)")
}
```

#### RSA Encryption

```swift
// Generate key pair
do {
    let keyPair = try cryptoManager.generateRSAKeyPair(
        keySize: 2048,
        tag: "com.yourapp.rsa-key"
    )
    
    // Encrypt with public key
    let encrypted = try cryptoManager.encryptRSA(
        data: plainData,
        publicKey: keyPair.publicKey
    )
    
    // Decrypt with private key
    let decrypted = try cryptoManager.decryptRSA(
        encryptedData: encrypted,
        privateKey: keyPair.privateKey
    )
} catch {
    print("RSA operation failed: \(error)")
}
```

#### Key Derivation

```swift
// Derive key from password using PBKDF2
let salt = cryptoManager.generateSalt(length: 32)
let derivedKey = cryptoManager.deriveKeyPBKDF2(
    password: "user_password",
    salt: salt,
    iterations: 100_000,
    keyLength: 32
)
```

#### Digital Signatures

```swift
// Sign data
do {
    let signature = try cryptoManager.signDataECDSA(
        data: plainData,
        privateKey: privateKey
    )
    
    // Verify signature
    let isValid = cryptoManager.verifySignatureECDSA(
        data: plainData,
        signature: signature,
        publicKey: publicKey
    )
} catch {
    print("Signature operation failed: \(error)")
}
```

### Keychain Storage

```swift
// Store in Keychain
do {
    try cryptoManager.storeInKeychain(
        key: key,
        tag: "com.yourapp.encryption-key",
        accessControl: .biometryCurrentSet
    )
    
    // Retrieve from Keychain
    let retrievedKey = try cryptoManager.retrieveFromKeychain(
        tag: "com.yourapp.encryption-key"
    )
} catch {
    print("Keychain operation failed: \(error)")
}
```

### Secure Networking

#### Basic Setup

```swift
let certificatePins: [String: Set<String>] = [
    "api.example.com": [
        "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" // Backup
    ]
]

let networkManager = SecureNetworkManager(
    certificatePins: certificatePins
)
```

#### Making Requests

```swift
Task {
    do {
        // GET request
        let url = URL(string: "https://api.example.com/users")!
        let response = try await networkManager.get(url: url)
        
        // POST request
        let postURL = URL(string: "https://api.example.com/users")!
        let jsonData = try JSONEncoder().encode(newUser)
        let postResponse = try await networkManager.post(
            url: postURL,
            body: jsonData,
            headers: ["Content-Type": "application/json"]
        )
        
        if postResponse.statusCode == 200 {
            let user = try postResponse.decode(User.self)
            print("Created user: \(user)")
        }
        
    } catch {
        print("Network error: \(error)")
    }
}
```

#### Mutual TLS (mTLS)

```swift
// Load client certificate
do {
    let clientCert = try SecureNetworkManager.loadClientCertificate(
        fromP12: Bundle.main.path(forResource: "client", ofType: "p12")!,
        password: "certificate_password"
    )
    
    let networkManager = SecureNetworkManager(
        certificatePins: pins,
        clientCertificate: clientCert
    )
} catch {
    print("Failed to load certificate: \(error)")
}
```

#### Request Signing

```swift
// Create signed request
do {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    
    let signedRequest = try networkManager.signedRequest(
        request,
        privateKey: privateKey
    )
    
    let response = try await networkManager.execute(request: signedRequest)
} catch {
    print("Failed to sign request: \(error)")
}
```

#### Retry Logic

```swift
// Automatic retry with exponential backoff
Task {
    do {
        let response = try await networkManager.executeWithRetry(
            request: request,
            maxRetries: 3,
            backoff: 1.0
        )
    } catch {
        print("Request failed after retries: \(error)")
    }
}
```

---

## 🔒 Security Features

### Secure Enclave

All sensitive keys stored in Secure Enclave:

```swift
let attributes: [String: Any] = [
    kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
    // Key never leaves secure hardware
]
```

### Biometric Protection

Keys bound to biometric authentication:

```swift
let accessControl = SecAccessControlCreateWithFlags(
    kCFAllocatorDefault,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.privateKeyUsage, .biometryCurrentSet], // Invalidates on biometric change
    nil
)
```

### Data Protection

iOS automatically encrypts data when device is locked:

```swift
// Data accessible only when unlocked
kSecAttrAccessibleWhenUnlockedThisDeviceOnly
```

---

## 🧪 Testing

### Unit Tests

```swift
func testAESEncryption() {
    let cryptoManager = CryptoManager()
    let key = cryptoManager.generateAESKey()
    let plainData = "Hello, World!".data(using: .utf8)!
    
    XCTAssertNoThrow(try {
        let encrypted = try cryptoManager.encryptAESGCM(data: plainData, key: key)
        let decrypted = try cryptoManager.decryptAESGCM(sealedBox: encrypted, key: key)
        XCTAssertEqual(plainData, decrypted)
    }())
}
```

### UI Tests

```swift
func testBiometricAuthentication() {
    let app = XCUIApplication()
    app.launch()
    
    // Simulate Touch ID success
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    // Test biometric flow
}
```

### Network Security Testing

```bash
# Test certificate pinning
# Should fail to connect through proxy
curl --proxy http://localhost:8080 https://api.example.com
```

---

## 🍎 App Store Requirements

### Required Entitlements

Add to `YourApp.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.device-information.user-assigned-device-name</key>
    <false/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.yourapp.identifier</string>
    </array>
</dict>
</plist>
```

### Privacy Manifest Requirements (iOS 17+)

Declare API usage in `PrivacyInfo.xcprivacy`:

```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>CA92.1</string>
        </array>
    </dict>
</array>
```

### Export Compliance

If using encryption:

1. Add to `Info.plist`:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

2. Or complete encryption export compliance in App Store Connect

### App Review Guidelines

- ✅ Face ID permission clearly explained
- ✅ Alternative authentication method provided
- ✅ Sensitive data encrypted
- ✅ No hardcoded secrets
- ✅ Privacy policy linked

---

## ✅ Production Checklist

### Security

- [ ] All keys stored in Secure Enclave
- [ ] Biometric invalidation enabled
- [ ] Certificate pinning with backup pins
- [ ] TLS 1.3 enforced
- [ ] Request signing implemented
- [ ] No hardcoded secrets
- [ ] Keychain access control configured

### Code Quality

- [ ] Error handling comprehensive
- [ ] Logging disabled in production
- [ ] Code obfuscated if necessary
- [ ] Dependencies up to date
- [ ] Memory leaks checked (Instruments)
- [ ] Performance optimized

### Testing

- [ ] Unit tests passing
- [ ] UI tests passing
- [ ] Certificate pinning tested
- [ ] Biometric tested on multiple devices (Touch ID & Face ID)
- [ ] Network security tested
- [ ] TestFlight beta testing complete

### Compliance

- [ ] Privacy manifest complete
- [ ] Export compliance addressed
- [ ] GDPR compliance
- [ ] Privacy policy updated
- [ ] Terms of service updated

### App Store

- [ ] Entitlements configured
- [ ] Face ID usage description clear
- [ ] Screenshots prepared
- [ ] App review notes complete
- [ ] Contact information current

---

## 📚 Additional Resources

### Apple Documentation
- [LocalAuthentication](https://developer.apple.com/documentation/localauthentication)
- [CryptoKit](https://developer.apple.com/documentation/cryptokit)
- [Security Framework](https://developer.apple.com/documentation/security)
- [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)

### WWDC Sessions
- [Introducing CryptoKit](https://developer.apple.com/videos/play/wwdc2019/709/)
- [What's New in Secure Enclave](https://developer.apple.com/videos/play/wwdc2023/10125/)

### Security Guides
- [iOS Security Guide](https://support.apple.com/guide/security/welcome/web)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)

### Tools
- [Xcode Instruments](https://developer.apple.com/xcode/features/)
- [Network Link Conditioner](https://developer.apple.com/download/all/)
- [Proxyman](https://proxyman.io/) (for network testing)

---

## 🐛 Troubleshooting

### Face ID Not Working

```swift
// Check specific error
var error: NSError?
if !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
    switch error?.code {
    case LAError.biometryNotAvailable.rawValue:
        print("Face ID not available on this device")
    case LAError.biometryNotEnrolled.rawValue:
        print("Face ID not set up")
    default:
        print("Other error: \(error?.localizedDescription ?? "")")
    }
}
```

### Certificate Pinning Fails

```swift
// Enable logging to check certificate hash
URLSession.shared.dataTask(with: url) { data, response, error in
    if let error = error as NSError?, 
       error.domain == NSURLErrorDomain,
       error.code == NSURLErrorServerCertificateUntrusted {
        print("Certificate validation failed")
    }
}
```

### Keychain Access Denied

```swift
// Check access control
let query: [String: Any] = [
    kSecClass as String: kSecClassKey,
    kSecAttrApplicationTag as String: tag,
    kSecReturnRef as String: true
]

var item: CFTypeRef?
let status = SecItemCopyMatching(query as CFDictionary, &item)

if status == errSecItemNotFound {
    print("Key not found in Keychain")
} else if status == errSecAuthFailed {
    print("Authentication required")
}
```

---

## 📄 License

See main project LICENSE file.

---

## 🤝 Contributing

See main project CONTRIBUTING.md.

---

**Note**: This implementation follows Apple's security best practices and App Store guidelines as of 2024. Always test on physical devices and keep frameworks updated.
