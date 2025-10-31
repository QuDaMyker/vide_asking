# Biometric Authentication & Cryptography - Flutter

Complete cross-platform implementation of biometric authentication, encryption, and secure communication for Flutter applications.

## 📋 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Platform Setup](#platform-setup)
- [Usage](#usage)
- [Security](#security)
- [Testing](#testing)

---

## ✨ Features

### Biometric Authentication
- ✅ Fingerprint, Face ID, Touch ID support
- ✅ Cross-platform (Android & iOS)
- ✅ Graceful fallback to device credentials
- ✅ Availability checking
- ✅ Comprehensive error handling

### Encryption
- ✅ AES-256-GCM authenticated encryption
- ✅ RSA asymmetric encryption
- ✅ PBKDF2 key derivation
- ✅ Digital signatures (RSA, ECDSA)
- ✅ SHA-256/512 hashing
- ✅ HMAC support

### Secure Storage
- ✅ flutter_secure_storage (iOS Keychain, Android Keystore)
- ✅ Encrypted database support
- ✅ Automatic data encryption

---

## 📦 Requirements

### Flutter SDK
```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.10.0'
```

### Platform Requirements

**Android:**
- minSdkVersion: 23 (Android 6.0)
- compileSdkVersion: 34 (Android 14)

**iOS:**
- iOS 14.0+
- Xcode 15.0+

---

## 🚀 Installation

### 1. Add Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Biometric Authentication
  local_auth: ^2.2.0
  local_auth_android: ^1.0.38
  local_auth_ios: ^1.1.8
  
  # Cryptography
  encrypt: ^5.0.3
  crypto: ^3.0.3
  pointycastle: ^3.7.4
  
  # Secure Storage
  flutter_secure_storage: ^9.0.0
  
  # Platform Channels
  flutter/services.dart
```

Then run:

```bash
flutter pub get
```

---

## 🔧 Platform Setup

### Android Setup

#### 1. Update `android/app/build.gradle`:

```gradle
android {
    compileSdk 34
    
    defaultConfig {
        minSdkVersion 23
        targetSdkVersion 34
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
```

#### 2. Add Permissions to `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Biometric -->
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />
    <uses-permission android:name="android.permission.USE_FINGERPRINT" />
    
    <!-- Network -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- Optional: StrongBox support -->
    <uses-feature
        android:name="android.hardware.strongbox_keystore"
        android:required="false" />
</manifest>
```

#### 3. MainActivity Configuration:

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import io.flutter.embedding.android.FlutterFragmentActivity
import androidx.annotation.NonNull

class MainActivity: FlutterFragmentActivity() {
    // Using FragmentActivity for biometric prompt
}
```

### iOS Setup

#### 1. Update `ios/Podfile`:

```ruby
platform :ios, '14.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
```

#### 2. Add to `Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>We use Face ID to secure your data</string>

<key>CADisableMinimumFrameDurationOnPhone</key>
<true/>
```

#### 3. Install Pods:

```bash
cd ios
pod install
cd ..
```

---

## 💻 Usage

### Copy Implementation Files

Add these files to your project:

```
lib/security/
├── biometric_auth.dart
├── crypto_manager.dart
└── secure_storage.dart (optional)
```

### Biometric Authentication

#### Check Availability

```dart
import 'security/biometric_auth.dart';

final biometricAuth = BiometricAuth();

// Check if biometric authentication is available
final isAvailable = await biometricAuth.isAvailable();
if (isAvailable) {
  print('Biometric authentication available');
}

// Get available biometric types
final biometrics = await biometricAuth.getAvailableBiometrics();
for (final biometric in biometrics) {
  print('Available: ${biometric.displayName}');
}
```

#### Authenticate User

```dart
// Simple authentication
final result = await biometricAuth.authenticate(
  localizedReason: 'Please authenticate to access your data',
  useErrorDialogs: true,
  stickyAuth: true,
);

if (result.isSuccess) {
  // Authentication successful
  print('Authenticated successfully!');
} else {
  // Authentication failed
  print('Failed: ${result.message}');
}
```

#### Handle Different Authentication States

```dart
final result = await biometricAuth.authenticate(
  localizedReason: 'Authenticate to continue',
);

if (result.isSuccess) {
  // Proceed with authenticated action
  navigateToSecureScreen();
} else if (result.error == BiometricAuthError.notEnrolled) {
  // Show enrollment prompt
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Biometric Not Set Up'),
      content: Text('Please set up biometric authentication in device settings'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
} else if (result.error == BiometricAuthError.userCanceled) {
  // User canceled, maybe show alternative
  print('User canceled authentication');
}
```

### Encryption

#### AES-256-GCM Encryption

```dart
import 'security/crypto_manager.dart';

final cryptoManager = CryptoManager();

// Generate key
final key = cryptoManager.generateAESKey();

// Encrypt data
final plainData = Uint8List.fromList(utf8.encode('Hello, World!'));
final encrypted = cryptoManager.encryptAES(plainData, key);

// Decrypt data
final decrypted = cryptoManager.decryptAES(encrypted, key);
final plainText = utf8.decode(decrypted);
print('Decrypted: $plainText');
```

#### RSA Encryption

```dart
// Generate RSA key pair
final keyPair = cryptoManager.generateRSAKeyPair(bitLength: 2048);

// Encrypt with public key
final encrypted = cryptoManager.encryptRSA(
  plainData,
  keyPair.publicKey,
);

// Decrypt with private key
final decrypted = cryptoManager.decryptRSA(
  encrypted,
  keyPair.privateKey,
);
```

#### Key Derivation from Password

```dart
// Derive encryption key from user password
final salt = cryptoManager.generateSalt(length: 32);
final key = cryptoManager.deriveKeyFromPassword(
  'user_password',
  salt,
  iterations: 100000,
  keyLength: 32,
);

// Store salt securely for later use
await secureStorage.write(key: 'salt', value: base64.encode(salt));
```

#### Digital Signatures

```dart
// Sign data
final signature = cryptoManager.signData(
  plainData,
  keyPair.privateKey,
);

// Verify signature
final isValid = cryptoManager.verifySignature(
  plainData,
  signature,
  keyPair.publicKey,
);
print('Signature valid: $isValid');
```

#### Hashing

```dart
// SHA-256
final hash256 = cryptoManager.hashSHA256(plainData);

// SHA-512
final hash512 = cryptoManager.hashSHA512(plainData);

// HMAC-SHA256
final hmac = cryptoManager.hmacSHA256(plainData, key);
```

### Complete Secure Data Flow

```dart
import 'dart:convert';
import 'package:flutter/material.dart';

class SecureDataManager {
  final BiometricAuth _biometricAuth = BiometricAuth();
  final CryptoManager _cryptoManager = CryptoManager();
  
  Future<void> saveSecureData(String data) async {
    // 1. Authenticate user
    final authResult = await _biometricAuth.authenticate(
      localizedReason: 'Authenticate to save data',
    );
    
    if (!authResult.isSuccess) {
      throw Exception('Authentication failed');
    }
    
    // 2. Generate/retrieve encryption key
    final key = _cryptoManager.generateAESKey();
    
    // 3. Encrypt data
    final plainBytes = Uint8List.fromList(utf8.encode(data));
    final encrypted = _cryptoManager.encryptAES(plainBytes, key);
    
    // 4. Store encrypted data
    await _secureStorage.write(
      key: 'encrypted_data',
      value: jsonEncode(encrypted.toJson()),
    );
    
    // 5. Store key securely
    await _secureStorage.write(
      key: 'encryption_key',
      value: base64.encode(key.bytes),
    );
  }
  
  Future<String> retrieveSecureData() async {
    // 1. Authenticate user
    final authResult = await _biometricAuth.authenticate(
      localizedReason: 'Authenticate to access data',
    );
    
    if (!authResult.isSuccess) {
      throw Exception('Authentication failed');
    }
    
    // 2. Retrieve key
    final keyString = await _secureStorage.read(key: 'encryption_key');
    if (keyString == null) throw Exception('Key not found');
    final key = encrypt.Key(base64.decode(keyString));
    
    // 3. Retrieve encrypted data
    final encryptedJson = await _secureStorage.read(key: 'encrypted_data');
    if (encryptedJson == null) throw Exception('Data not found');
    final encrypted = EncryptedDataModel.fromJson(jsonDecode(encryptedJson));
    
    // 4. Decrypt data
    final decrypted = _cryptoManager.decryptAES(encrypted, key);
    
    // 5. Return plain text
    return utf8.decode(decrypted);
  }
}
```

---

## 🔒 Security Best Practices

### Key Storage

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Initialize secure storage
const secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
    keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

// Store key
await secureStorage.write(key: 'encryption_key', value: keyBase64);

// Retrieve key
final keyString = await secureStorage.read(key: 'encryption_key');
```

### Secure Random Generation

```dart
// Always use cryptographically secure random
final randomBytes = cryptoManager.generateRandomBytes(32);
```

### Memory Security

```dart
// Wipe sensitive data from memory
cryptoManager.secureWipe(sensitiveData);
```

---

## 🧪 Testing

### Unit Tests

Create `test/security_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/security/crypto_manager.dart';

void main() {
  group('CryptoManager Tests', () {
    late CryptoManager cryptoManager;
    
    setUp(() {
      cryptoManager = CryptoManager();
    });
    
    test('AES encryption and decryption', () {
      final key = cryptoManager.generateAESKey();
      final plainData = Uint8List.fromList(utf8.encode('Test Data'));
      
      final encrypted = cryptoManager.encryptAES(plainData, key);
      final decrypted = cryptoManager.decryptAES(encrypted, key);
      
      expect(decrypted, equals(plainData));
    });
    
    test('RSA key generation', () {
      final keyPair = cryptoManager.generateRSAKeyPair();
      
      expect(keyPair.publicKey, isNotNull);
      expect(keyPair.privateKey, isNotNull);
    });
    
    test('Digital signature verification', () {
      final keyPair = cryptoManager.generateRSAKeyPair();
      final data = Uint8List.fromList(utf8.encode('Test'));
      
      final signature = cryptoManager.signData(data, keyPair.privateKey);
      final isValid = cryptoManager.verifySignature(
        data,
        signature,
        keyPair.publicKey,
      );
      
      expect(isValid, isTrue);
    });
  });
}
```

### Integration Tests

Create `integration_test/biometric_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:your_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('Biometric authentication flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    // Find and tap biometric auth button
    final authButton = find.text('Authenticate');
    expect(authButton, findsOneWidget);
    
    await tester.tap(authButton);
    await tester.pumpAndSettle();
    
    // Verify authentication prompt appears
    // Note: Actual biometric auth requires manual testing on device
  });
}
```

### Run Tests

```bash
# Unit tests
flutter test

# Integration tests (requires device/emulator)
flutter test integration_test/
```

---

## ✅ Production Checklist

### Security
- [ ] All keys stored in secure storage (Keychain/Keystore)
- [ ] Sensitive data encrypted
- [ ] Biometric authentication tested on multiple devices
- [ ] Certificate pinning configured (if applicable)
- [ ] No hardcoded secrets
- [ ] ProGuard/R8 configured for Android
- [ ] Secure random used for all crypto operations

### Code Quality
- [ ] Error handling comprehensive
- [ ] Logging disabled in production
- [ ] Dependencies up to date
- [ ] Code obfuscated
- [ ] Memory leaks checked

### Testing
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Tested on Android (multiple versions)
- [ ] Tested on iOS (Touch ID & Face ID devices)
- [ ] Edge cases tested (no biometric, lockout, etc.)

### Platform-Specific
**Android:**
- [ ] ProGuard rules configured
- [ ] Permissions declared
- [ ] Fragment Activity used

**iOS:**
- [ ] Face ID usage description
- [ ] Privacy manifest (iOS 17+)
- [ ] Minimum iOS version set

---

## 📚 Additional Resources

### Flutter Packages
- [local_auth](https://pub.dev/packages/local_auth)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [encrypt](https://pub.dev/packages/encrypt)
- [pointycastle](https://pub.dev/packages/pointycastle)

### Documentation
- [Flutter Security](https://docs.flutter.dev/security)
- [Android Biometric API](https://developer.android.com/training/sign-in/biometric-auth)
- [iOS LocalAuthentication](https://developer.apple.com/documentation/localauthentication)

### Security Guides
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Flutter Security Best Practices](https://docs.flutter.dev/security/security-best-practices)

---

## 🐛 Troubleshooting

### Android Issues

**BiometricPrompt not showing:**
```kotlin
// Ensure MainActivity extends FlutterFragmentActivity
class MainActivity: FlutterFragmentActivity()
```

**Keystore errors:**
```bash
# Clear app data and reinstall
adb shell pm clear com.yourapp.package
```

### iOS Issues

**Face ID not working:**
```xml
<!-- Check Info.plist has usage description -->
<key>NSFaceIDUsageDescription</key>
<string>Required description</string>
```

**Keychain errors:**
```bash
# Reset simulator
xcrun simctl erase all
```

### Common Errors

**PlatformException: biometric authentication not available:**
- Check device has biometric hardware
- Verify biometric enrolled in settings
- Ensure permissions granted

**Cipher initialization failed:**
- Key may be invalidated
- Regenerate key and re-encrypt data

---

## 📄 License

See main project LICENSE file.

---

**Note**: Always test biometric authentication on physical devices. Emulators/simulators have limited biometric support.
