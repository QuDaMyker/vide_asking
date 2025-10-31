# eKYC NFC Integration - Code Examples

This folder contains complete code examples for implementing eKYC features with chip-based national ID (CCCD/C06/VNeID) and NFC integration across multiple mobile platforms.

## Structure

```
code-push-jd/
├── android-jetpack-compose/     # Android implementation
├── ios-swiftui/                 # iOS implementation
├── flutter/                     # Flutter cross-platform
└── shared/                      # Shared utilities and models
```

## Platforms Covered

- **Android**: Jetpack Compose + Kotlin Coroutines + NFC Reader Mode
- **iOS**: SwiftUI + CoreNFC + Combine
- **Flutter**: Platform Channels + Riverpod + MLKit

## Key Features Implemented

1. ✅ NFC chip reading for CCCD/C06/VNeID
2. ✅ MRZ (Machine Readable Zone) scanning
3. ✅ Document authentication & SOD verification
4. ✅ Secure storage (Keystore/Keychain)
5. ✅ Biometric authentication
6. ✅ Privacy-compliant data handling
7. ✅ Offline-first architecture
8. ✅ Error handling & retry logic

## Getting Started

Navigate to the specific platform folder for detailed implementation guides and runnable code examples.
