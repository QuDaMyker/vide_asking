# Biometric Authentication & Encryption - Best Practices

## Table of Contents

1. [Introduction](#introduction)
2. [Biometric Authentication](#biometric-authentication)
3. [Encryption Standards](#encryption-standards)
4. [Secure Communication](#secure-communication)
5. [Key Management](#key-management)
6. [Security Architecture](#security-architecture)
7. [Implementation Patterns](#implementation-patterns)
8. [Testing & Validation](#testing--validation)
9. [Compliance & Regulations](#compliance--regulations)
10. [Common Pitfalls](#common-pitfalls)

---

## Introduction

This guide provides comprehensive best practices for implementing biometric authentication, encryption, and secure communication protocols in mobile applications.

### Security Principles

1. **Defense in Depth**: Multiple layers of security
2. **Least Privilege**: Minimum necessary permissions
3. **Secure by Default**: Security enabled out of the box
4. **Fail Securely**: Graceful degradation on failure
5. **Zero Trust**: Verify everything, trust nothing

---

## Biometric Authentication

### Types of Biometric Authentication

| Type | Accuracy | Speed | User Acceptance | Platform Support |
|------|----------|-------|-----------------|------------------|
| **Fingerprint** | High (99%) | Fast (< 1s) | Very High | Android, iOS, Windows |
| **Face Recognition** | Very High (99.9%) | Fast (< 1s) | High | iOS (Face ID), Android 10+ |
| **Iris Scan** | Highest (99.99%) | Medium (1-2s) | Medium | Samsung, some Android |
| **Voice** | Medium (95%) | Medium (2-3s) | Medium | Limited |

### Implementation Best Practices

#### 1. Availability Check

```kotlin
// Android
fun canAuthenticate(): BiometricAvailability {
    return when (biometricManager.canAuthenticate(BIOMETRIC_STRONG)) {
        BiometricManager.BIOMETRIC_SUCCESS -> Available
        BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> NoHardware
        BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> NoneEnrolled
        else -> Unavailable
    }
}
```

```swift
// iOS
func canAuthenticate() -> BiometricAvailability {
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        return mapError(error)
    }
    return .available(context.biometryType)
}
```

#### 2. Graceful Fallback

Always provide alternative authentication methods:

- **Primary**: Biometric (fingerprint/face)
- **Secondary**: Device PIN/Password
- **Tertiary**: Account password

```kotlin
// Android - Allow device credential fallback
val promptInfo = BiometricPrompt.PromptInfo.Builder()
    .setTitle("Authenticate")
    .setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
    .build()
```

#### 3. User Experience

**DO:**
- ✅ Clear messaging: "Use fingerprint to unlock"
- ✅ Show biometric icon matching device type
- ✅ Provide cancel option
- ✅ Handle "too many attempts" gracefully
- ✅ Support accessibility (VoiceOver/TalkBack)

**DON'T:**
- ❌ Force biometric without alternative
- ❌ Store biometric data locally
- ❌ Use weak biometric (Android BIOMETRIC_WEAK)
- ❌ Authenticate on every screen
- ❌ Ignore biometric changes (new fingerprint enrolled)

#### 4. Security Considerations

```kotlin
// Invalidate keys when biometrics change
val keyGenParameterSpec = KeyGenParameterSpec.Builder(keyAlias, purpose)
    .setUserAuthenticationRequired(true)
    .setInvalidatedByBiometricEnrollment(true) // Important!
    .build()
```

### Biometric-Bound Cryptographic Keys

#### Android

```kotlin
// Generate key that requires biometric authentication
fun generateBiometricKey(keyAlias: String): SecretKey {
    val keyGenerator = KeyGenerator.getInstance(
        KeyProperties.KEY_ALGORITHM_AES,
        "AndroidKeyStore"
    )
    
    val builder = KeyGenParameterSpec.Builder(
        keyAlias,
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
    )
        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
        .setUserAuthenticationRequired(true)
        .setInvalidatedByBiometricEnrollment(true)
    
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        builder.setUserAuthenticationParameters(
            0, // Require auth every time
            KeyProperties.AUTH_BIOMETRIC_STRONG
        )
    }
    
    keyGenerator.init(builder.build())
    return keyGenerator.generateKey()
}

// Use with BiometricPrompt
val cipher = getEncryptCipher(keyAlias)
val cryptoObject = BiometricPrompt.CryptoObject(cipher)

biometricPrompt.authenticate(promptInfo, cryptoObject)
```

#### iOS

```swift
// Generate key in Secure Enclave requiring biometry
func generateBiometricKey(tag: String) throws -> SecKey {
    let accessControl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        [.privateKeyUsage, .biometryCurrentSet],
        nil
    )!
    
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
        throw error!.takeRetainedValue()
    }
    
    return privateKey
}
```

---

## Encryption Standards

### Symmetric Encryption

#### AES-256-GCM (Recommended)

**Advantages:**
- Authenticated encryption (integrity + confidentiality)
- Parallel processing
- NIST approved

```kotlin
// Android
fun encryptAESGCM(data: ByteArray, key: SecretKey): EncryptedData {
    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
    cipher.init(Cipher.ENCRYPT_MODE, key)
    
    val ciphertext = cipher.doFinal(data)
    val iv = cipher.iv
    
    return EncryptedData(ciphertext, iv)
}
```

#### ChaCha20-Poly1305 (Mobile Optimized)

**Advantages:**
- Faster on mobile processors
- No timing attacks
- Modern alternative to AES

```swift
// iOS
func encryptChaCha20(data: Data, key: SymmetricKey) throws -> Data {
    let sealed = try ChaChaPoly.seal(data, using: key)
    return sealed.combined!
}
```

### Asymmetric Encryption

#### RSA-2048/4096

**Use Cases:**
- Key exchange
- Digital signatures
- Small data encryption

**DO NOT:**
- ❌ Encrypt large data directly with RSA
- ❌ Use RSA without padding (use OAEP)
- ❌ Use key size < 2048 bits

#### ECC (Elliptic Curve Cryptography)

**Advantages:**
- Smaller key sizes (256-bit ECC ≈ 3072-bit RSA)
- Faster operations
- Lower bandwidth

```kotlin
// Generate ECC key pair
val keyPairGenerator = KeyPairGenerator.getInstance(
    KeyProperties.KEY_ALGORITHM_EC,
    "AndroidKeyStore"
)

val builder = KeyGenParameterSpec.Builder(keyAlias, purpose)
    .setDigests(KeyProperties.DIGEST_SHA256)
    // Uses P-256 curve by default

keyPairGenerator.initialize(builder.build())
val keyPair = keyPairGenerator.generateKeyPair()
```

### Encryption Mode Comparison

| Mode | Integrity | Parallelizable | Padding | Use Case |
|------|-----------|----------------|---------|----------|
| **GCM** | ✅ | ✅ | No | General purpose (recommended) |
| **CBC** | ❌ | ❌ | Yes | Legacy systems |
| **CTR** | ❌ | ✅ | No | Streaming |
| **CCM** | ✅ | ❌ | No | Low memory devices |

---

## Secure Communication

### TLS 1.3

**Improvements over TLS 1.2:**
- Faster handshake (1-RTT vs 2-RTT)
- Mandatory forward secrecy
- Removed weak ciphers

```kotlin
// Android - Force TLS 1.3
val connectionSpec = ConnectionSpec.Builder(ConnectionSpec.MODERN_TLS)
    .tlsVersions(TlsVersion.TLS_1_3)
    .cipherSuites(
        CipherSuite.TLS_AES_128_GCM_SHA256,
        CipherSuite.TLS_AES_256_GCM_SHA384,
        CipherSuite.TLS_CHACHA20_POLY1305_SHA256
    )
    .build()

val client = OkHttpClient.Builder()
    .connectionSpecs(listOf(connectionSpec))
    .build()
```

### Certificate Pinning

**Purpose:** Prevent MITM attacks by validating server certificates

```kotlin
// Pin certificates
val certificatePinner = CertificatePinner.Builder()
    .add("api.example.com", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
    .add("api.example.com", "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=") // Backup pin
    .build()

val client = OkHttpClient.Builder()
    .certificatePinner(certificatePinner)
    .build()
```

**How to get certificate pins:**

```bash
# Using OpenSSL
openssl s_client -connect api.example.com:443 | \
openssl x509 -pubkey -noout | \
openssl rsa -pubin -outform der | \
openssl dgst -sha256 -binary | \
openssl enc -base64
```

### Mutual TLS (mTLS)

**Purpose:** Both client and server authenticate each other

```kotlin
// Android mTLS
fun createMTLSClient(
    clientCert: String,
    clientKey: String,
    serverCert: String
): OkHttpClient {
    val keyStore = loadClientKeyStore(clientCert, clientKey)
    val trustStore = loadTrustStore(serverCert)
    
    val keyManagerFactory = KeyManagerFactory.getInstance(
        KeyManagerFactory.getDefaultAlgorithm()
    )
    keyManagerFactory.init(keyStore, "".toCharArray())
    
    val trustManagerFactory = TrustManagerFactory.getInstance(
        TrustManagerFactory.getDefaultAlgorithm()
    )
    trustManagerFactory.init(trustStore)
    
    val sslContext = SSLContext.getInstance("TLS")
    sslContext.init(
        keyManagerFactory.keyManagers,
        trustManagerFactory.trustManagers,
        null
    )
    
    return OkHttpClient.Builder()
        .sslSocketFactory(
            sslContext.socketFactory,
            trustManagerFactory.trustManagers[0] as X509TrustManager
        )
        .build()
}
```

### Request Signing

**Purpose:** Verify request integrity and authenticity

```kotlin
// Sign API requests
class RequestSigningInterceptor(
    private val privateKey: PrivateKey
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        
        // Get request body
        val buffer = Buffer()
        request.body?.writeTo(buffer)
        val bodyBytes = buffer.readByteArray()
        
        // Sign
        val signature = signData(bodyBytes, privateKey)
        val signatureBase64 = Base64.encodeToString(signature, Base64.NO_WRAP)
        
        // Add signature header
        val signedRequest = request.newBuilder()
            .header("X-Signature", signatureBase64)
            .header("X-Signature-Algorithm", "SHA256withECDSA")
            .header("X-Timestamp", System.currentTimeMillis().toString())
            .build()
        
        return chain.proceed(signedRequest)
    }
    
    private fun signData(data: ByteArray, privateKey: PrivateKey): ByteArray {
        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initSign(privateKey)
        signature.update(data)
        return signature.sign()
    }
}
```

---

## Key Management

### Key Lifecycle

```
┌─────────────┐
│  Generate   │ ← Creation with strong entropy
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Storage   │ ← Hardware keystore/Secure Enclave
└──────┬──────┘
       │
       ▼
┌─────────────┐
│     Use     │ ← Authenticated access only
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Rotate    │ ← Regular rotation (90-365 days)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Destroy   │ ← Secure deletion
└─────────────┘
```

### Key Storage Hierarchy

```
Best: Hardware Security Module (HSM)
  ↓
Good: Secure Enclave / StrongBox (Mobile)
  ↓
OK: Software Keystore (Android Keystore / iOS Keychain)
  ↓
Bad: Encrypted file
  ↓
Worst: Plain text (NEVER DO THIS!)
```

### Key Rotation

```kotlin
// Implement key rotation
class KeyRotationManager(
    private val keyStore: KeyStore,
    private val rotationIntervalDays: Int = 90
) {
    fun rotateKeyIfNeeded(keyAlias: String) {
        val lastRotation = getLastRotationDate(keyAlias)
        val daysSinceRotation = ChronoUnit.DAYS.between(lastRotation, LocalDate.now())
        
        if (daysSinceRotation >= rotationIntervalDays) {
            rotateKey(keyAlias)
        }
    }
    
    private fun rotateKey(keyAlias: String) {
        // 1. Generate new key
        val newKeyAlias = "${keyAlias}_${System.currentTimeMillis()}"
        generateKey(newKeyAlias)
        
        // 2. Re-encrypt data with new key
        reEncryptData(oldKeyAlias = keyAlias, newKeyAlias = newKeyAlias)
        
        // 3. Delete old key
        keyStore.deleteEntry(keyAlias)
        
        // 4. Rename new key to standard alias
        // (Implementation depends on storage mechanism)
        
        // 5. Update rotation date
        saveRotationDate(keyAlias, LocalDate.now())
    }
}
```

---

## Security Architecture

### Layered Security Model

```
┌──────────────────────────────────────────┐
│         Application Layer                │
│  - Input validation                      │
│  - Output encoding                       │
│  - Session management                    │
└──────────────────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│     Authentication Layer                 │
│  - Biometric authentication              │
│  - Multi-factor authentication           │
│  - Token management                      │
└──────────────────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│      Encryption Layer                    │
│  - Data encryption at rest               │
│  - Key derivation                        │
│  - Secure key storage                    │
└──────────────────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│     Transport Layer                      │
│  - TLS 1.3                               │
│  - Certificate pinning                   │
│  - Request signing                       │
└──────────────────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│      Storage Layer                       │
│  - Hardware keystore                     │
│  - Secure Enclave                        │
│  - Encrypted database                    │
└──────────────────────────────────────────┘
```

### Zero Trust Architecture

**Principles:**
1. Verify explicitly
2. Use least privilege access
3. Assume breach

**Implementation:**

```kotlin
// Every request requires authentication and authorization
class ZeroTrustInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        
        // 1. Verify authentication token
        val token = getAuthToken()
        if (!isTokenValid(token)) {
            throw UnauthorizedException()
        }
        
        // 2. Check device integrity
        if (!verifyDeviceIntegrity()) {
            throw DeviceCompromisedException()
        }
        
        // 3. Add security headers
        val secureRequest = request.newBuilder()
            .header("Authorization", "Bearer $token")
            .header("X-Device-ID", getDeviceId())
            .header("X-App-Version", getAppVersion())
            .header("X-Platform", "Android")
            .build()
        
        // 4. Execute request
        val response = chain.proceed(secureRequest)
        
        // 5. Verify response integrity
        verifyResponseSignature(response)
        
        return response
    }
}
```

---

## Implementation Patterns

### Secure Data Flow

```kotlin
// Complete secure data flow example
class SecureDataManager(
    private val biometricAuth: BiometricAuthenticator,
    private val cryptoManager: CryptoManager,
    private val networkManager: SecureNetworkManager
) {
    suspend fun saveSecureData(data: ByteArray): Result<Unit> {
        return withContext(Dispatchers.IO) {
            try {
                // 1. Authenticate user
                val authResult = biometricAuth.authenticate("Secure your data")
                if (!authResult.isSuccess) {
                    return@withContext Result.failure(AuthenticationException())
                }
                
                // 2. Generate/get encryption key
                val key = cryptoManager.getOrGenerateBiometricKey("data_key")
                
                // 3. Encrypt data
                val encryptedData = cryptoManager.encryptAES(data, key)
                
                // 4. Store locally
                secureStorage.save("encrypted_data", encryptedData)
                
                // 5. Backup to server (optional)
                val response = networkManager.post(
                    url = "https://api.example.com/backup",
                    body = encryptedData.toJson()
                )
                
                // 6. Wipe sensitive data from memory
                cryptoManager.secureWipe(data)
                
                Result.success(Unit)
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
    }
    
    suspend fun retrieveSecureData(): Result<ByteArray> {
        return withContext(Dispatchers.IO) {
            try {
                // 1. Authenticate user
                val authResult = biometricAuth.authenticate("Access your data")
                if (!authResult.isSuccess) {
                    return@withContext Result.failure(AuthenticationException())
                }
                
                // 2. Get encryption key
                val key = cryptoManager.getBiometricKey("data_key")
                    ?: return@withContext Result.failure(KeyNotFoundException())
                
                // 3. Retrieve encrypted data
                val encryptedData = secureStorage.get("encrypted_data")
                    ?: return@withContext Result.failure(DataNotFoundException())
                
                // 4. Decrypt data
                val decryptedData = cryptoManager.decryptAES(encryptedData, key)
                
                Result.success(decryptedData)
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
    }
}
```

---

## Testing & Validation

### Security Testing Checklist

#### Biometric Authentication
- [ ] Test with no biometrics enrolled
- [ ] Test with biometric hardware unavailable
- [ ] Test biometric lockout (too many attempts)
- [ ] Test fallback to PIN/password
- [ ] Test biometric change invalidates keys
- [ ] Test on multiple device types

#### Encryption
- [ ] Verify AES-256-GCM implementation
- [ ] Test key rotation
- [ ] Verify secure key deletion
- [ ] Test with corrupted ciphertext
- [ ] Verify IV uniqueness
- [ ] Test encryption/decryption performance

#### Network Security
- [ ] Test certificate pinning
- [ ] Test with invalid certificates
- [ ] Test with proxy/MITM tools (should fail)
- [ ] Verify TLS 1.3 usage
- [ ] Test request signing
- [ ] Test replay attack prevention

### Penetration Testing

```bash
# SSL/TLS testing
testssl.sh --full https://api.example.com

# Certificate pinning bypass attempt
frida -U -f com.example.app -l ssl-pinning-bypass.js

# Root detection bypass
frida -U -f com.example.app -l root-detection-bypass.js
```

---

## Compliance & Regulations

### GDPR Requirements
- ✅ Encryption of personal data
- ✅ Right to erasure (secure deletion)
- ✅ Data minimization
- ✅ Consent management
- ✅ Data breach notification

### PCI DSS (Payment Card Industry)
- ✅ Strong cryptography (AES-256)
- ✅ Key management
- ✅ Secure transmission
- ✅ Access control
- ✅ Regular security testing

### FIPS 140-2 (Federal Information Processing Standards)
- ✅ Approved algorithms (AES, SHA-256, RSA)
- ✅ Key generation
- ✅ Self-tests
- ✅ Physical security (hardware modules)

---

## Common Pitfalls

### ❌ DON'T Do These

1. **Storing Keys in Code**
```kotlin
// BAD!
val SECRET_KEY = "my_super_secret_key_12345"
```

2. **Using ECB Mode**
```kotlin
// BAD! ECB mode is insecure
Cipher.getInstance("AES/ECB/PKCS5Padding")
```

3. **Hardcoded IVs**
```kotlin
// BAD! IV must be random for each encryption
val iv = ByteArray(16) { 0 }
```

4. **Ignoring Certificate Errors**
```kotlin
// BAD! Never ignore SSL errors
trustManager.checkServerTrusted(chain, authType) // Empty implementation
```

5. **Logging Sensitive Data**
```kotlin
// BAD!
Log.d("Auth", "Password: $password")
```

### ✅ DO These Instead

1. **Use Hardware Keystore**
```kotlin
// GOOD!
val keyStore = KeyStore.getInstance("AndroidKeyStore")
```

2. **Use Authenticated Encryption**
```kotlin
// GOOD!
Cipher.getInstance("AES/GCM/NoPadding")
```

3. **Generate Random IVs**
```kotlin
// GOOD!
val iv = ByteArray(12)
SecureRandom().nextBytes(iv)
```

4. **Implement Certificate Pinning**
```kotlin
// GOOD!
.certificatePinner(certificatePinner)
```

5. **Redact Sensitive Logs**
```kotlin
// GOOD!
Log.d("Auth", "Authentication successful for user: ${userId.take(4)}***")
```

---

## Additional Resources

### Standards & Specifications
- [NIST Cryptographic Standards](https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [FIDO Alliance](https://fidoalliance.org/)

### Tools
- **Android**: Keystore, BiometricPrompt, SafetyNet
- **iOS**: Keychain, LocalAuthentication, App Attest
- **Testing**: Frida, Objection, MobSF, testssl.sh

### Documentation
- [Android Security](https://developer.android.com/topic/security)
- [iOS Security](https://developer.apple.com/documentation/security)
- [Flutter Security](https://docs.flutter.dev/security)
