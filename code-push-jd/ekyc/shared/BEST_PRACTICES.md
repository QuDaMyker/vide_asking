# eKYC & NFC Integration - Best Practices Guide

## Table of Contents

1. [Regulatory Compliance](#regulatory-compliance)
2. [Security Architecture](#security-architecture)
3. [NFC Implementation](#nfc-implementation)
4. [Data Privacy](#data-privacy)
5. [User Experience](#user-experience)
6. [Testing Strategy](#testing-strategy)
7. [Performance](#performance)
8. [Incident Response](#incident-response)

---

## Regulatory Compliance

### Vietnam Specifications

#### CCCD (Căn cước công dân)
- **Format**: ICAO 9303 compliant ID card
- **Chip**: ISO/IEC 14443 contactless chip
- **Data Groups**: DG1 (MRZ), DG2 (Face), DG13 (Optional data)
- **Authentication**: BAC (Basic Access Control)

#### C06 National ID
- Legacy format being phased out
- Similar chip structure to CCCD
- May have different data group availability

#### VNeID (Digital Identity)
- QR code + NFC combination
- Additional encryption layers
- Real-time verification with government servers

### Legal Requirements

1. **User Consent**
   - Explicit opt-in for biometric data collection
   - Clear privacy policy disclosure
   - Right to data deletion

2. **Data Retention**
   - Maximum retention period: As specified by regulation
   - Automatic data deletion after purpose fulfilled
   - Audit trail for compliance

3. **Cross-Border Data Transfer**
   - Ensure compliance with local data residency laws
   - Use appropriate legal frameworks (adequacy decisions)

---

## Security Architecture

### Defense in Depth

```
┌─────────────────────────────────────┐
│     Application Layer Security      │
│  - Input validation                 │
│  - Output encoding                  │
│  - Session management               │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│     Data Security Layer             │
│  - Encryption at rest               │
│  - Encryption in transit            │
│  - Key management                   │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│     Platform Security Layer         │
│  - Keystore/Keychain                │
│  - Biometric authentication         │
│  - Secure Enclave                   │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│     Network Security Layer          │
│  - TLS 1.3                          │
│  - Certificate pinning              │
│  - Request signing                  │
└─────────────────────────────────────┘
```

### Cryptographic Standards

#### Hashing
- **Algorithm**: SHA-256 minimum
- **Usage**: Audit logs, integrity checks
- **Salt**: Unique per user, cryptographically random

#### Encryption
- **Symmetric**: AES-256-GCM
- **Asymmetric**: RSA-2048 or ECC P-256
- **Key Derivation**: PBKDF2 or Argon2

#### Digital Signatures
- **Algorithm**: ECDSA with P-256 or RSA-PSS
- **Usage**: Document verification, request signing

### Key Management

#### Mobile Key Storage

**Android**:
```kotlin
// Generate key in Keystore
val keyGenerator = KeyGenerator.getInstance(
    KeyProperties.KEY_ALGORITHM_AES,
    "AndroidKeyStore"
)

val keyGenParameterSpec = KeyGenParameterSpec.Builder(
    ALIAS,
    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
)
    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
    .setKeySize(256)
    .setUserAuthenticationRequired(true)
    .setUserAuthenticationParameters(
        300, // Timeout in seconds
        KeyProperties.AUTH_BIOMETRIC_STRONG
    )
    .build()

keyGenerator.init(keyGenParameterSpec)
val key = keyGenerator.generateKey()
```

**iOS**:
```swift
// Store in Keychain with Secure Enclave
let query: [String: Any] = [
    kSecClass as String: kSecClassKey,
    kSecAttrApplicationTag as String: tag,
    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
    kSecAttrKeySizeInBits as String: 256,
    kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
    kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrAccessControl as String: accessControl
    ]
]

SecItemAdd(query as CFDictionary, nil)
```

---

## NFC Implementation

### ICAO 9303 Standards

#### Document Structure
```
EF.COM (Common Data Elements)
EF.SOD (Document Security Object)
EF.DG1 (MRZ Data)
EF.DG2 (Face Image)
EF.DG3 (Fingerprints) - Optional
EF.DG7 (Signature) - Optional
EF.DG11 (Additional Personal Details)
EF.DG12 (Additional Document Details)
EF.DG13 (Optional Details)
```

#### BAC (Basic Access Control)

**Key Derivation**:
```
MRZ Information:
- Document Number (9 chars)
- Date of Birth (YYMMDD)
- Date of Expiry (YYMMDD)

K_seed = SHA-1(MRZ_Info)
K_enc = SHA-1(K_seed || 00000001)[:16]
K_mac = SHA-1(K_seed || 00000002)[:16]
```

**Authentication Flow**:
```
1. Reader → Card: GET CHALLENGE
2. Card → Reader: RND.IC (8 bytes)
3. Reader generates RND.IFD (8 bytes) and K.IFD (16 bytes)
4. Reader → Card: EXTERNAL AUTHENTICATE (encrypted)
5. Card validates and responds with encrypted K.IC
6. Both derive session keys KS.enc and KS.mac
```

### Platform-Specific Implementations

#### Android NFC Reader Mode

**Best Practices**:
- Use `enableReaderMode()` instead of intent filters
- Set appropriate polling options
- Handle tag removal gracefully
- Implement timeout mechanism

```kotlin
val options = Bundle().apply {
    putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250)
}

nfcAdapter.enableReaderMode(
    activity,
    { tag -> handleTag(tag) },
    NfcAdapter.FLAG_READER_NFC_A or 
    NfcAdapter.FLAG_READER_NFC_B or
    NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
    options
)
```

#### iOS CoreNFC

**Best Practices**:
- Request NFC session only when needed
- Provide clear user messages
- Handle session invalidation
- Implement retry logic

```swift
let session = NFCTagReaderSession(
    pollingOption: [.iso14443],
    delegate: self,
    queue: .main
)
session?.alertMessage = "Hold your ID card near iPhone"
session?.begin()
```

### Error Handling

#### Common NFC Errors

| Error | Cause | Solution |
|-------|-------|----------|
| **Timeout** | Card removed too early | Increase timeout, guide user |
| **BAC Failed** | Wrong MRZ data | Validate MRZ before NFC |
| **Read Error** | Interference | Ask user to retry in better location |
| **Tag Lost** | Card moved | Implement automatic retry |

#### Retry Strategy

```kotlin
suspend fun readWithRetry(
    maxAttempts: Int = 3,
    delayMs: Long = 1000
): Result<ChipData> {
    repeat(maxAttempts) { attempt ->
        try {
            return readChipData()
        } catch (e: Exception) {
            if (attempt == maxAttempts - 1) throw e
            delay(delayMs * (attempt + 1)) // Exponential backoff
        }
    }
    throw IllegalStateException("Should not reach here")
}
```

---

## Data Privacy

### GDPR/PDPA Compliance

#### Data Minimization
- Collect only necessary data
- Delete data after verification
- Don't log sensitive information

#### User Rights
- **Right to Access**: Provide data export
- **Right to Erasure**: Immediate deletion
- **Right to Rectification**: Allow corrections
- **Right to Portability**: Standard format export

### Privacy-Preserving Techniques

#### Data Hashing for Audit
```kotlin
// Hash for audit trail without storing actual data
fun hashForAudit(data: String): String {
    val salt = generateSalt()
    val hash = sha256(data + salt)
    return "$salt:$hash" // Store salt:hash
}

// Verify without storing original
fun verifyAudit(data: String, stored: String): Boolean {
    val (salt, hash) = stored.split(":")
    return sha256(data + salt) == hash
}
```

#### Differential Privacy
```kotlin
// Add noise to aggregate statistics
fun addLaplaceNoise(value: Double, sensitivity: Double, epsilon: Double): Double {
    val scale = sensitivity / epsilon
    val noise = Random.nextDouble() - 0.5
    return value + scale * sign(noise) * ln(1 - 2 * abs(noise))
}
```

### Secure Data Deletion

#### Android
```kotlin
// Overwrite memory before clearing
fun secureWipe(data: ByteArray) {
    // Overwrite with zeros
    data.fill(0)
    // Overwrite with ones
    data.fill(0xFF.toByte())
    // Overwrite with random
    SecureRandom().nextBytes(data)
    // Clear reference
    data.fill(0)
}
```

#### iOS
```swift
// Zero out memory
func secureWipe(data: inout Data) {
    data.withUnsafeMutableBytes { ptr in
        memset(ptr.baseAddress, 0, data.count)
    }
    data.removeAll()
}
```

---

## User Experience

### Progressive Disclosure

```
1. Introduction Screen
   ↓
2. Consent & Privacy Policy
   ↓
3. Prepare ID Card Instructions
   ↓
4. MRZ Scanning with Guidance
   ↓
5. NFC Reading Instructions
   ↓
6. NFC Reading Progress
   ↓
7. Verification Result
   ↓
8. Completion
```

### Visual Guidance

#### MRZ Scanning
- Show overlay with MRZ area highlighted
- Real-time feedback on detection
- Auto-capture when valid MRZ detected
- Torch/flash toggle for low light

#### NFC Reading
- Animated illustration of card placement
- Progress indicator with steps
- Keep phone steady message
- Success/failure animations

### Accessibility

#### Requirements
- **Screen Readers**: All interactive elements labeled
- **Dynamic Type**: Support text scaling
- **Color Contrast**: WCAG AA minimum
- **Voice Control**: Alternative input methods
- **Reduced Motion**: Respect system preferences

#### Implementation

**Android**:
```kotlin
Text(
    text = "Scan your ID card",
    modifier = Modifier.semantics {
        contentDescription = "Scan your national ID card using the camera"
        role = Role.Button
    }
)
```

**iOS**:
```swift
Text("Scan your ID card")
    .accessibilityLabel("Scan your national ID card")
    .accessibilityHint("Opens camera to scan ID card")
```

**Flutter**:
```dart
Semantics(
  label: 'Scan your ID card',
  hint: 'Opens camera to scan ID card',
  button: true,
  child: Text('Scan your ID card'),
)
```

### Multi-language Support

```json
{
  "en": {
    "scan_mrz": "Scan MRZ code",
    "hold_card_steady": "Hold card steady",
    "reading_chip": "Reading chip data..."
  },
  "vi": {
    "scan_mrz": "Quét mã MRZ",
    "hold_card_steady": "Giữ thẻ cố định",
    "reading_chip": "Đang đọc dữ liệu chip..."
  }
}
```

---

## Testing Strategy

### Test Pyramid

```
        /\
       /  \       E2E Tests (5%)
      /    \      - Full flow on real devices
     /------\     - Real NFC cards
    /        \    
   /  Integr  \   Integration Tests (15%)
  /   ation    \  - API integration
 /    Tests     \ - NFC simulation
/----------------\
|                | Unit Tests (80%)
|  Unit Tests    | - Business logic
|                | - Data validation
|                | - Crypto functions
------------------
```

### Unit Testing

#### Test Coverage Targets
- **Critical Paths**: 100% (authentication, encryption)
- **Business Logic**: 90%
- **UI Components**: 70%
- **Overall**: 80% minimum

#### Example Tests

```kotlin
class NFCReaderTest {
    @Test
    fun `BAC key derivation produces correct keys`() {
        val mrzKey = BACKey(
            documentNumber = "12345678",
            dateOfBirth = "900101",
            dateOfExpiry = "301231"
        )
        
        val kSeed = deriveKeySeed(mrzKey)
        val kEnc = deriveKey(kSeed, 1)
        val kMac = deriveKey(kSeed, 2)
        
        assertEquals(20, kSeed.size)
        assertEquals(16, kEnc.size)
        assertEquals(16, kMac.size)
    }
    
    @Test
    fun `data consistency verification works correctly`() {
        val mrz = MRZData(...)
        val chip = ChipData(...)
        
        assertTrue(verifyConsistency(mrz, chip))
    }
}
```

### Integration Testing

#### Mock NFC Cards
```kotlin
class MockNFCTag : Tag {
    override fun getId(): ByteArray = byteArrayOf(0x01, 0x02, 0x03, 0x04)
    // Implement other methods...
}

@Test
fun `read chip data from mock tag`() = runTest {
    val mockTag = MockNFCTag()
    val reader = NFCReader(context)
    
    val result = reader.readChipData(mockTag, mockBACKey)
    
    assertTrue(result.isSuccess)
}
```

### End-to-End Testing

#### Test Scenarios
1. **Happy Path**: Complete flow with valid card
2. **Invalid MRZ**: Wrong document number
3. **Card Removed**: Tag lost during read
4. **Network Failure**: Server unavailable
5. **Expired Card**: Past expiry date
6. **Damaged Chip**: Unreadable data

#### Automated E2E

```dart
testWidgets('Complete eKYC flow', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Accept consent
  await tester.tap(find.text('Accept'));
  await tester.pumpAndSettle();
  
  // Start MRZ scan
  await tester.tap(find.text('Scan ID'));
  await tester.pumpAndSettle();
  
  // Simulate successful scan
  final viewModel = tester.widget<Provider>(
    find.byType(Provider)
  ).value as EKYCViewModel;
  viewModel.onMRZScanned(mockMRZ);
  
  // Verify NFC screen
  expect(find.text('Hold card near phone'), findsOneWidget);
  
  // Simulate NFC read
  await mockNFCRead();
  await tester.pumpAndSettle();
  
  // Verify success
  expect(find.text('Verification Successful'), findsOneWidget);
});
```

---

## Performance

### Optimization Targets

| Metric | Target | Critical |
|--------|--------|----------|
| **MRZ Scan Time** | < 2 seconds | < 5 seconds |
| **NFC Read Time** | < 5 seconds | < 10 seconds |
| **UI Response** | < 100ms | < 300ms |
| **Memory Usage** | < 100MB | < 200MB |
| **App Size** | < 50MB | < 100MB |

### Memory Management

#### Avoid Memory Leaks

**Android**:
```kotlin
class EKYCViewModel : ViewModel() {
    private val _state = MutableStateFlow<State>(State.Initial)
    
    override fun onCleared() {
        super.onCleared()
        clearSensitiveData()
        // Cancel all coroutines
        viewModelScope.cancel()
    }
}
```

**iOS**:
```swift
class EKYCViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.forEach { $0.cancel() }
        clearSensitiveData()
    }
}
```

#### Image Processing
```kotlin
// Downscale images before processing
fun downscaleImage(bitmap: Bitmap, maxSize: Int): Bitmap {
    val ratio = min(
        maxSize.toFloat() / bitmap.width,
        maxSize.toFloat() / bitmap.height
    )
    
    if (ratio >= 1) return bitmap
    
    val width = (bitmap.width * ratio).toInt()
    val height = (bitmap.height * ratio).toInt()
    
    return Bitmap.createScaledBitmap(bitmap, width, height, true)
}
```

### Network Optimization

#### Request Batching
```kotlin
// Batch multiple data points into single request
data class EKYCSubmission(
    val personalData: PersonalData,
    val documentData: DocumentData,
    val biometricData: BiometricData,
    val timestamp: Long,
    val signature: String
)

suspend fun submitBatch(submission: EKYCSubmission): Result<Response> {
    return withContext(Dispatchers.IO) {
        api.submitEKYC(submission)
    }
}
```

#### Compression
```kotlin
// Compress images before upload
fun compressImage(image: ByteArray): ByteArray {
    val bitmap = BitmapFactory.decodeByteArray(image, 0, image.size)
    val stream = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
    return stream.toByteArray()
}
```

---

## Incident Response

### Incident Categories

#### Security Incidents
- Data breach
- Unauthorized access
- Man-in-the-middle attack
- Certificate compromise

#### Operational Incidents
- Service outage
- Data corruption
- Performance degradation
- Integration failure

### Response Procedures

#### 1. Detection & Identification
```
- Monitor security logs
- Alert on anomalies
- User reports
- Automated detection
```

#### 2. Containment
```
- Isolate affected systems
- Revoke compromised credentials
- Enable fallback mechanisms
- Notify stakeholders
```

#### 3. Eradication
```
- Remove threat
- Patch vulnerabilities
- Update security rules
- Rotate keys/certificates
```

#### 4. Recovery
```
- Restore services
- Verify data integrity
- Monitor for recurrence
- Gradual rollout
```

#### 5. Post-Incident
```
- Document lessons learned
- Update procedures
- Train team
- Implement preventive measures
```

### Emergency Contacts

```json
{
  "security_team": "security@company.com",
  "on_call": "+1-XXX-XXX-XXXX",
  "escalation": [
    {
      "level": 1,
      "contact": "team-lead@company.com",
      "response_time": "15 minutes"
    },
    {
      "level": 2,
      "contact": "director@company.com",
      "response_time": "1 hour"
    }
  ]
}
```

### Communication Templates

#### User Notification
```
Subject: Important Security Update

Dear [User],

We recently identified and resolved a security issue that may have 
affected your account. Out of an abundance of caution, we have:

1. Reset your session
2. Required re-verification
3. Enhanced monitoring

No action is required on your part. If you have concerns, please 
contact our support team.

Thank you for your understanding.
[Company Name] Security Team
```

---

## Additional Resources

### Standards & Specifications
- [ICAO 9303](https://www.icao.int/publications/pages/publication.aspx?docnum=9303)
- [ISO/IEC 14443](https://www.iso.org/standard/73596.html)
- [NIST Cryptographic Standards](https://www.nist.gov/cryptography)

### Libraries & Tools
- **Android**: JMRTD, Scuba, Bouncy Castle
- **iOS**: OpenSSL, CryptoKit
- **Flutter**: pointycastle, encrypt

### Community
- [Stack Overflow - NFC](https://stackoverflow.com/questions/tagged/nfc)
- [GitHub - JMRTD](https://github.com/jmrtd/jmrtd)
- [ICAO Technical Reports](https://www.icao.int/Security/FAL/Pages/technical-reports.aspx)

---

## Changelog

- **2025-10-30**: Initial version
- Document version: 1.0.0
- Last updated: October 30, 2025
