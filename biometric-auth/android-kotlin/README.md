# Biometric Authentication & Cryptography - Android (Kotlin)

Complete implementation of biometric authentication, encryption, and secure communication for Android using Kotlin and Jetpack libraries.

## 📋 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Security Features](#security-features)
- [Testing](#testing)
- [Production Checklist](#production-checklist)

---

## ✨ Features

### Biometric Authentication
- ✅ Fingerprint, Face, Iris recognition
- ✅ BiometricPrompt integration
- ✅ StrongBox hardware security support
- ✅ Biometric-bound cryptographic keys
- ✅ Fallback to device credentials

### Encryption
- ✅ AES-256-GCM authenticated encryption
- ✅ RSA-2048/4096 asymmetric encryption
- ✅ ECC (Elliptic Curve Cryptography)
- ✅ PBKDF2 key derivation
- ✅ Digital signatures (ECDSA, RSA-PSS)
- ✅ HMAC-SHA256/512

### Secure Networking
- ✅ TLS 1.3 support
- ✅ Certificate pinning (SHA-256)
- ✅ Mutual TLS (mTLS)
- ✅ Request signing
- ✅ Retry with exponential backoff
- ✅ Security headers

---

## 📦 Requirements

### Minimum SDK
```gradle
minSdk = 23  // Android 6.0 (Marshmallow)
targetSdk = 34  // Android 14
compileSdk = 34
```

### Dependencies

Add to your `build.gradle.kts`:

```kotlin
dependencies {
    // AndroidX Core
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    
    // Biometric
    implementation("androidx.biometric:biometric:1.2.0-alpha05")
    
    // Security & Crypto
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    
    // Networking
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    
    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    
    // Lifecycle
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.6.2")
}
```

---

## 🚀 Installation

### 1. Add Permissions

Add to `AndroidManifest.xml`:

```xml
<!-- Biometric -->
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />

<!-- Network -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Optional: StrongBox hardware security -->
<uses-feature
    android:name="android.hardware.strongbox_keystore"
    android:required="false" />
```

### 2. ProGuard Rules

Add to `proguard-rules.pro`:

```proguard
# Android Keystore
-keep class android.security.keystore.** { *; }

# Biometric
-keep class androidx.biometric.** { *; }

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# Security
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }
```

### 3. Copy Implementation Files

Copy these files to your project:

```
app/src/main/java/com/yourapp/security/
├── BiometricAuthenticator.kt
├── CryptoManager.kt
└── SecureNetworkManager.kt
```

---

## 💻 Usage

### Biometric Authentication

#### Check Availability

```kotlin
val biometricAuth = BiometricAuthenticator(context)

when (biometricAuth.canAuthenticate()) {
    BiometricAvailability.AVAILABLE -> {
        // Biometric available
    }
    BiometricAvailability.NO_HARDWARE -> {
        // Device doesn't support biometric
    }
    BiometricAvailability.NONE_ENROLLED -> {
        // No biometrics enrolled
    }
    else -> {
        // Other errors
    }
}
```

#### Authenticate

```kotlin
// Simple authentication
lifecycleScope.launch {
    val result = biometricAuth.authenticate(
        activity = this@MainActivity,
        title = "Authenticate",
        subtitle = "Use biometric to continue",
        negativeButtonText = "Cancel"
    )
    
    when (result) {
        is AuthenticationResult.Success -> {
            // Authentication successful
        }
        is AuthenticationResult.Error -> {
            // Handle error: result.error
        }
        is AuthenticationResult.Failed -> {
            // Authentication failed
        }
    }
}
```

#### Biometric-Bound Encryption

```kotlin
// Generate key that requires biometric authentication
val key = biometricAuth.generateBiometricKey("my_secure_key")

// Encrypt data with biometric prompt
val cipher = biometricAuth.getEncryptCipher("my_secure_key")
val result = biometricAuth.authenticate(
    activity = this,
    title = "Encrypt Data",
    cryptoObject = BiometricPrompt.CryptoObject(cipher)
)

if (result is AuthenticationResult.Success) {
    val authenticatedCipher = result.cryptoObject?.cipher
    val encryptedData = authenticatedCipher?.doFinal(plainData)
}
```

### Encryption

#### AES-256-GCM

```kotlin
val cryptoManager = CryptoManager()

// Generate key
val key = cryptoManager.generateAESKey()

// Encrypt
val encryptedData = cryptoManager.encryptAES(plainData, key)

// Decrypt
val decryptedData = cryptoManager.decryptAES(
    encryptedData.ciphertext,
    encryptedData.iv,
    encryptedData.tag,
    key
)
```

#### RSA Encryption

```kotlin
// Generate key pair
val keyPair = cryptoManager.generateRSAKeyPair(keySize = 2048)

// Encrypt with public key
val encrypted = cryptoManager.encryptRSA(data, keyPair.public)

// Decrypt with private key
val decrypted = cryptoManager.decryptRSA(encrypted, keyPair.private)
```

#### Key Derivation (PBKDF2)

```kotlin
// Derive key from password
val salt = cryptoManager.generateSalt()
val key = cryptoManager.deriveKeyFromPassword(
    password = "user_password",
    salt = salt,
    iterations = 100_000,
    keyLength = 32
)
```

#### Digital Signatures

```kotlin
// Sign data
val signature = cryptoManager.signData(data, privateKey, SignatureAlgorithm.ECDSA)

// Verify signature
val isValid = cryptoManager.verifySignature(
    data = data,
    signature = signature,
    publicKey = publicKey,
    algorithm = SignatureAlgorithm.ECDSA
)
```

### Secure Networking

#### Basic Setup

```kotlin
val networkManager = SecureNetworkManager.Builder()
    .baseUrl("https://api.example.com")
    .certificatePins(
        mapOf(
            "api.example.com" to setOf(
                "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
                "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" // Backup
            )
        )
    )
    .enableTLS13()
    .enableRetry(maxRetries = 3)
    .build()
```

#### Making Requests

```kotlin
lifecycleScope.launch {
    try {
        // GET request
        val response = networkManager.get("/users")
        val users = response.body<List<User>>()
        
        // POST request
        val newUser = User(name = "John", email = "john@example.com")
        val createResponse = networkManager.post(
            path = "/users",
            body = newUser
        )
        
    } catch (e: Exception) {
        // Handle error
    }
}
```

#### Mutual TLS (mTLS)

```kotlin
val clientCert = loadClientCertificate("client.p12", "password")

val networkManager = SecureNetworkManager.Builder()
    .baseUrl("https://api.example.com")
    .clientCertificate(clientCert)
    .build()
```

#### Request Signing

```kotlin
// Sign requests with private key
val networkManager = SecureNetworkManager.Builder()
    .baseUrl("https://api.example.com")
    .requestSigning(privateKey)
    .build()

// Signature automatically added to X-Signature header
```

---

## 🔒 Security Features

### Android Keystore

All cryptographic keys are stored in Android Keystore:

```kotlin
// Keys never leave secure hardware
val keyStore = KeyStore.getInstance("AndroidKeyStore")
keyStore.load(null)
```

### StrongBox Support

For devices with dedicated security chip:

```kotlin
val builder = KeyGenParameterSpec.Builder(keyAlias, purpose)
    .setIsStrongBoxBacked(true) // Use StrongBox if available
```

### Key Invalidation

Keys automatically invalidate when biometrics change:

```kotlin
.setInvalidatedByBiometricEnrollment(true)
```

### Secure Memory Wiping

```kotlin
// Wipe sensitive data from memory
cryptoManager.secureWipe(sensitiveData)
```

---

## 🧪 Testing

### Unit Tests

```kotlin
@Test
fun testAESEncryptionDecryption() {
    val cryptoManager = CryptoManager()
    val key = cryptoManager.generateAESKey()
    val plainData = "Hello, World!".toByteArray()
    
    val encrypted = cryptoManager.encryptAES(plainData, key)
    val decrypted = cryptoManager.decryptAES(
        encrypted.ciphertext,
        encrypted.iv,
        encrypted.tag,
        key
    )
    
    assertArrayEquals(plainData, decrypted)
}
```

### Instrumented Tests

```kotlin
@Test
fun testBiometricAvailability() {
    val context = InstrumentationRegistry.getInstrumentation().targetContext
    val biometricAuth = BiometricAuthenticator(context)
    
    val availability = biometricAuth.canAuthenticate()
    assertNotEquals(BiometricAvailability.UNKNOWN, availability)
}
```

### Certificate Pinning Test

```bash
# Test certificate pinning with Charles Proxy or Burp Suite
# Expected: Connection should fail with SSLPeerUnverifiedException
```

---

## ✅ Production Checklist

### Security

- [ ] All keys stored in Android Keystore
- [ ] StrongBox enabled for supported devices
- [ ] Biometric invalidation on enrollment change
- [ ] Certificate pinning configured with backup pins
- [ ] TLS 1.3 enforced
- [ ] Request signing implemented
- [ ] Sensitive data wiped from memory
- [ ] ProGuard rules configured

### Code Quality

- [ ] All error cases handled
- [ ] Logging disabled in production
- [ ] No hardcoded secrets
- [ ] Code obfuscated
- [ ] Dependencies up to date
- [ ] Security patches applied

### Testing

- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Certificate pinning tested
- [ ] Biometric authentication tested on multiple devices
- [ ] Network security tested (MITM, SSL stripping)
- [ ] Key rotation tested

### Compliance

- [ ] GDPR compliance (data encryption, erasure)
- [ ] PCI DSS compliance (if handling payments)
- [ ] Local regulations compliance
- [ ] Privacy policy updated
- [ ] Terms of service updated

### Monitoring

- [ ] Crash reporting configured
- [ ] Security event logging
- [ ] Certificate expiration monitoring
- [ ] Key rotation alerts

---

## 📚 Additional Resources

### Documentation
- [Android Biometric Guide](https://developer.android.com/training/sign-in/biometric-auth)
- [Android Keystore System](https://developer.android.com/training/articles/keystore)
- [OkHttp Documentation](https://square.github.io/okhttp/)

### Security Best Practices
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Android Security](https://source.android.com/docs/security)

### Tools
- [Android Studio Profiler](https://developer.android.com/studio/profile)
- [Frida](https://frida.re/) (for security testing)
- [MobSF](https://github.com/MobSF/Mobile-Security-Framework-MobSF)

---

## 🐛 Troubleshooting

### Biometric Not Working

```kotlin
// Check detailed error
val biometricManager = BiometricManager.from(context)
when (biometricManager.canAuthenticate(BIOMETRIC_STRONG)) {
    BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> {
        // Hardware temporarily unavailable
    }
    BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> {
        // Security update required
    }
}
```

### Certificate Pinning Fails

```kotlin
// Add logging interceptor
val loggingInterceptor = HttpLoggingInterceptor().apply {
    level = HttpLoggingInterceptor.Level.HEADERS
}

// Check certificate hash matches
```

### Key Not Found

```kotlin
// Key might be invalidated - regenerate
if (!keyStore.containsAlias(keyAlias)) {
    generateKey(keyAlias)
}
```

---

## 📄 License

See main project LICENSE file.

---

## 🤝 Contributing

See main project CONTRIBUTING.md.

---

**Note**: This implementation follows Android security best practices as of 2024. Always keep dependencies updated and monitor security advisories.
