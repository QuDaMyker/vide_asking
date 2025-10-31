# Android Jetpack Compose - eKYC Implementation Guide

## Overview

This implementation demonstrates how to build a production-ready eKYC feature with NFC chip reading for Vietnamese CCCD/C06/VNeID cards using Android Jetpack Compose.

## Architecture

```
ekyc/
├── nfc/
│   └── NFCReader.kt           # NFC reading logic
├── viewmodel/
│   └── EKYCViewModel.kt       # State management
├── ui/
│   └── EKYCScreen.kt          # Compose UI
└── security/
    └── SecureStorage.kt       # Secure data storage
```

## Key Features

### 1. NFC Reading with Lifecycle Awareness
- **Reader Mode**: Uses `NfcAdapter.enableReaderMode()` for better reliability
- **State Management**: `StateFlow` for reactive UI updates
- **Progress Tracking**: Real-time progress from 0-100%

### 2. State-Driven UI
- **Compose Best Practices**: Hoisted state, unidirectional data flow
- **Material Design 3**: Modern UI with proper theming
- **Accessibility**: Semantic content descriptions

### 3. Secure Storage
- **Android Keystore**: Hardware-backed encryption
- **Auto-expiry**: Data cleared after 15 minutes
- **Biometric Protection**: Optional FaceID/fingerprint requirement

## Dependencies

Add to `build.gradle.kts`:

```kotlin
dependencies {
    // Jetpack Compose
    implementation("androidx.compose.ui:ui:1.5.4")
    implementation("androidx.compose.material3:material3:1.1.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.6.2")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.6.2")
    
    // NFC & Passport Reading
    implementation("org.jmrtd:jmrtd:0.7.34")
    implementation("net.sf.scuba:scuba-sc-android:0.0.23")
    
    // Security
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("androidx.biometric:biometric:1.2.0-alpha05")
    
    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
```

## Permissions

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.NFC" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />

<uses-feature
    android:name="android.hardware.nfc"
    android:required="false" />
<uses-feature
    android:name="android.hardware.camera"
    android:required="false" />
```

## Usage

### 1. Initialize in Activity

```kotlin
class MainActivity : ComponentActivity() {
    private lateinit var nfcReader: NFCReader
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        nfcReader = NFCReader(this)
        
        setContent {
            EKYCTheme {
                EKYCScreen(
                    nfcReader = nfcReader,
                    onComplete = { /* Handle completion */ }
                )
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
        nfcReader.enableReaderMode()
    }
    
    override fun onPause() {
        super.onPause()
        nfcReader.disableReaderMode()
    }
}
```

### 2. MRZ Scanning Integration

Use Google ML Kit or similar:

```kotlin
// Add ML Kit dependency
implementation("com.google.mlkit:text-recognition:16.0.0")

// Scan MRZ and extract data
val mrzData = MRZData(
    documentNumber = "C06123456",
    dateOfBirth = "900101",
    dateOfExpiry = "300101",
    firstName = "VAN A",
    lastName = "NGUYEN"
)
viewModel.onMRZScanned(mrzData)
```

### 3. Handle NFC Reading

The NFC reading is automatic once MRZ is scanned. The UI will guide the user.

## Security Considerations

### 1. Data Storage
```kotlin
// Data is encrypted in Android Keystore
// Auto-expires after 15 minutes
// Requires device unlock to access
```

### 2. Network Security
```kotlin
// TODO: Implement in production
// - Mutual TLS with certificate pinning
// - Request signing with session keys
// - Exponential backoff on retries
```

### 3. Device Integrity
```kotlin
// TODO: Add Play Integrity API
implementation("com.google.android.play:integrity:1.2.0")

// Check device integrity before allowing eKYC
val integrityManager = IntegrityManagerFactory.create(context)
```

## Testing

### Unit Tests
```kotlin
@Test
fun `verify MRZ and chip data consistency`() {
    val mrz = MRZData(...)
    val chip = ChipData(...)
    
    val result = viewModel.verifyDataConsistency(mrz, chip)
    
    assertTrue(result)
}
```

### Integration Tests
```kotlin
@Test
fun `complete eKYC flow`() = runTest {
    // 1. Scan MRZ
    viewModel.onMRZScanned(mockMRZ)
    
    // 2. Read NFC
    val result = nfcReader.readChipData(mockTag, mockBACKey)
    
    // 3. Verify success
    assertTrue(result.isSuccess)
}
```

### UI Tests
```kotlin
@Test
fun `display success screen after verification`() {
    composeTestRule.setContent {
        EKYCScreen(...)
    }
    
    // Simulate successful flow
    composeTestRule.onNodeWithText("Verification Successful")
        .assertIsDisplayed()
}
```

## Performance Optimization

### 1. Compose Performance
```kotlin
// Use remember for expensive operations
val expensiveData = remember(key) { computeExpensiveData() }

// Use key for LaunchedEffect
LaunchedEffect(nfcState) { /* ... */ }

// Use derivedStateOf for computed values
val isValid by remember {
    derivedStateOf { mrzData != null && chipData != null }
}
```

### 2. NFC Reading Optimization
```kotlin
// Adjust timeout based on card type
isoDep.timeout = 5000 // milliseconds

// Use appropriate blocksize
val passportService = PassportService(
    cardService,
    PassportService.NORMAL_MAX_TRANCEIVE_LENGTH,
    PassportService.DEFAULT_MAX_BLOCKSIZE,
    false,
    false
)
```

## Error Handling

### Common Issues

1. **NFC Read Timeout**
   - Increase timeout: `isoDep.timeout = 10000`
   - Ask user to hold card steady

2. **BAC Authentication Failed**
   - Verify MRZ data is correct
   - Check document number includes check digits

3. **Card Removed During Read**
   - Implement retry logic
   - Show clear error message

## Best Practices

1. ✅ Always disable NFC reader in `onPause()`
2. ✅ Clear sensitive data immediately after use
3. ✅ Use StateFlow for reactive updates
4. ✅ Implement proper error messages
5. ✅ Test on physical devices with real cards
6. ✅ Monitor memory usage during NFC operations
7. ✅ Implement analytics (without PII)
8. ✅ Support offline verification when possible

## Production Checklist

- [ ] Implement proper error tracking (Firebase Crashlytics)
- [ ] Add certificate pinning for API calls
- [ ] Implement Play Integrity API
- [ ] Enable ProGuard/R8 obfuscation
- [ ] Test with multiple card types (C06, CCCD, VNeID)
- [ ] Implement rate limiting
- [ ] Add user consent screens
- [ ] Prepare rollback mechanism
- [ ] Document incident response procedures
- [ ] Train support team on common issues

## References

- [ICAO 9303 Specifications](https://www.icao.int/publications/pages/publication.aspx?docnum=9303)
- [Android NFC Guide](https://developer.android.com/guide/topics/connectivity/nfc)
- [Jetpack Compose Best Practices](https://developer.android.com/jetpack/compose/performance)
- [Android Keystore System](https://developer.android.com/training/articles/keystore)
