# iOS SwiftUI - eKYC Implementation Guide

## Overview

Production-ready eKYC implementation for iOS using SwiftUI and CoreNFC to read Vietnamese CCCD/C06/VNeID cards.

## Architecture

```
eKYC/
├── NFCReader.swift         # CoreNFC integration
├── EKYCView.swift          # SwiftUI views
├── EKYCViewModel.swift     # Business logic
└── SecureStorage.swift     # Keychain storage
```

## Key Features

### 1. CoreNFC Integration
- **Tag Reader Session**: Modern CoreNFC APIs
- **MainActor Updates**: Thread-safe UI updates
- **Async/Await**: Modern Swift concurrency

### 2. SwiftUI Best Practices
- **ObservableObject**: Reactive state management
- **Structured Concurrency**: Task-based async operations
- **Accessibility**: VoiceOver support

### 3. Secure Enclave Storage
- **Keychain**: Hardware-backed security
- **Biometric Protection**: FaceID/TouchID
- **Auto-expiry**: 15-minute data lifetime

## Requirements

### Xcode Configuration

**Info.plist**:
```xml
<key>NFCReaderUsageDescription</key>
<string>We need to read your ID card chip for verification</string>

<key>NSCameraUsageDescription</key>
<string>We need camera access to scan your ID card</string>

<key>NSFaceIDUsageDescription</key>
<string>We use Face ID to protect your identity data</string>

<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>TAG</string>
</array>
```

**Capabilities**:
- Near Field Communication Tag Reading
- Keychain Sharing (optional)

**Entitlements** (`YourApp.entitlements`):
```xml
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>TAG</string>
</array>

<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
    <string>A0000002471001</string>
</array>
```

## Dependencies

**Package.swift** or SPM:
```swift
dependencies: [
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
    // Or use built-in CryptoKit
]
```

## Usage

### 1. Initialize in App

```swift
import SwiftUI

@main
struct EKYCApp: App {
    var body: some Scene {
        WindowGroup {
            EKYCView()
        }
    }
}
```

### 2. Handle NFC Reading

```swift
// Automatic after MRZ scan
// Just show the view:
struct ContentView: View {
    var body: some View {
        EKYCView()
    }
}
```

### 3. MRZ Scanning

Use Vision framework:

```swift
import Vision
import AVFoundation

class MRZScanner: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let textRecognition = VNRecognizeTextRequest()
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleDetectedText(request: request, error: error)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    
    private func handleDetectedText(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        let text = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        
        // Parse MRZ from text
        parseMRZ(from: text)
    }
    
    private func parseMRZ(from lines: [String]) {
        // TODO: Implement MRZ parsing logic
        // ICAO 9303 format: 3 lines for ID cards
    }
}
```

## Security Implementation

### 1. Keychain Storage

```swift
// Data automatically stored with biometric protection
SecureStorage.shared.storeChipData(chipData)

// Retrieval requires biometric authentication
let data = try await SecureStorage.shared.retrieveChipData()
```

### 2. Network Security

```swift
// TODO: Implement in production
import Security

class NetworkManager {
    func setupSSLPinning() {
        let session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: nil
        )
    }
}

extension NetworkManager: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Implement certificate pinning
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Validate certificate
        // ...
    }
}
```

### 3. Jailbreak Detection

```swift
func isJailbroken() -> Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    let paths = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt"
    ]
    
    for path in paths {
        if FileManager.default.fileExists(atPath: path) {
            return true
        }
    }
    
    // Check if app can write outside sandbox
    let testPath = "/private/test_jailbreak.txt"
    do {
        try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(atPath: testPath)
        return true
    } catch {
        return false
    }
    #endif
}
```

## Testing

### Unit Tests

```swift
import XCTest
@testable import YourApp

class EKYCViewModelTests: XCTestCase {
    var viewModel: EKYCViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = EKYCViewModel()
    }
    
    func testMRZScanning() {
        let mrzData = MRZData(
            documentNumber: "C06123456",
            dateOfBirth: "900101",
            dateOfExpiry: "300101",
            firstName: "VAN A",
            lastName: "NGUYEN"
        )
        
        viewModel.onMRZScanned(mrzData)
        
        XCTAssertNotNil(viewModel.mrzData)
        XCTAssertEqual(viewModel.state, .mrzScanned(mrzData))
    }
    
    func testDataConsistency() async {
        let mrz = MRZData(...)
        let chip = ChipData(...)
        
        await viewModel.onMRZScanned(mrz)
        await viewModel.onChipDataRead(chip)
        
        XCTAssertEqual(viewModel.state, .success(chip))
    }
}
```

### UI Tests

```swift
import XCTest

class EKYCUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launch()
    }
    
    func testEKYCFlow() {
        // Tap start button
        app.buttons["Start MRZ Scan"].tap()
        
        // Wait for camera view
        XCTAssertTrue(app.otherElements["Camera View"].waitForExistence(timeout: 2))
        
        // Simulate scan
        app.buttons["Simulate Scan"].tap()
        
        // Verify NFC instructions appear
        XCTAssertTrue(app.staticTexts["Hold ID Near iPhone"].exists)
    }
}
```

## Performance Optimization

### 1. SwiftUI Performance

```swift
// Use @StateObject for view models
@StateObject private var viewModel = EKYCViewModel()

// Use @Published only for UI-relevant state
@Published var state: EKYCState

// Use Task.detached for heavy operations
Task.detached(priority: .userInitiated) {
    let result = await heavyComputation()
    await MainActor.run {
        self.updateUI(with: result)
    }
}
```

### 2. Memory Management

```swift
// Properly clean up NFC session
deinit {
    session?.invalidate()
}

// Clear sensitive data
func clearSensitiveData() {
    mrzData = nil
    chipData = nil
    SecureStorage.shared.clearAll()
}
```

## Error Handling

### Common Issues

1. **NFC Not Available**
```swift
if !NFCTagReaderSession.readingAvailable {
    showAlert("NFC not available on this device")
}
```

2. **User Cancelled**
```swift
// Gracefully handle cancellation
if let nfcError = error as? NFCReaderError,
   nfcError.code == .readerSessionInvalidationErrorUserCanceled {
    // User cancelled - no error message needed
}
```

3. **Read Timeout**
```swift
// Implement retry logic
var retryCount = 0
let maxRetries = 3

func readWithRetry() async throws -> ChipData {
    do {
        return try await nfcReader.startReading(with: mrzKey)
    } catch {
        retryCount += 1
        if retryCount < maxRetries {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return try await readWithRetry()
        }
        throw error
    }
}
```

## Best Practices

1. ✅ Use MainActor for UI updates
2. ✅ Implement structured concurrency
3. ✅ Store minimal data in Keychain
4. ✅ Clear data after submission
5. ✅ Test on physical devices
6. ✅ Support VoiceOver
7. ✅ Handle low memory warnings
8. ✅ Implement proper error messages

## Production Checklist

- [ ] Enable bitcode (if required)
- [ ] Configure App Transport Security
- [ ] Implement certificate pinning
- [ ] Add App Attest for device verification
- [ ] Enable Data Protection
- [ ] Test with TestFlight beta
- [ ] Prepare privacy policy
- [ ] Document user flows
- [ ] Train support team
- [ ] Set up monitoring (Sentry, etc.)

## App Store Requirements

1. **Privacy Manifest** (`PrivacyInfo.xcprivacy`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

2. **Privacy Nutrition Labels**: Document data collection

## References

- [CoreNFC Documentation](https://developer.apple.com/documentation/corenfc)
- [SwiftUI Best Practices](https://developer.apple.com/documentation/swiftui)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [ICAO 9303](https://www.icao.int/publications/pages/publication.aspx?docnum=9303)
