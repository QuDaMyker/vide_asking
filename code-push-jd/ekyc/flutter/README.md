# Flutter - eKYC Cross-Platform Implementation Guide

## Overview

Cross-platform eKYC implementation using Flutter with platform channels for native NFC access on both Android and iOS.

## Architecture

```
lib/
├── nfc_reader.dart         # Platform channel wrapper
├── ekyc_viewmodel.dart     # Business logic
├── ekyc_screen.dart        # Flutter UI
└── secure_storage.dart     # Encrypted storage

android/
└── app/src/main/kotlin/
    └── NfcHandler.kt       # Android NFC implementation

ios/
└── Runner/
    └── NfcHandler.swift    # iOS CoreNFC implementation
```

## Key Features

### 1. Platform Channels
- **Method Channel**: Bidirectional communication
- **Event Channel**: Stream-based updates
- **Type Safety**: Strong typing across platforms

### 2. State Management
- **Provider/Riverpod**: Reactive state management
- **ChangeNotifier**: Simple and effective
- **Isolated Business Logic**: Platform-agnostic

### 3. Secure Storage
- **flutter_secure_storage**: Native keychain/keystore
- **Encryption**: AES-256-GCM for images
- **Auto-expiry**: Time-based data cleanup

## Dependencies

**pubspec.yaml**:
```yaml
name: ekyc_app
description: eKYC implementation with NFC

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.1.1
  # Or use riverpod: ^2.4.9
  
  # Secure Storage
  flutter_secure_storage: ^9.0.0
  
  # Encryption
  encrypt: ^5.0.3
  crypto: ^3.0.3
  
  # ML Kit for MRZ scanning
  google_mlkit_text_recognition: ^0.11.0
  
  # Camera
  camera: ^0.10.5
  
  # Permissions
  permission_handler: ^11.0.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

## Platform Setup

### Android Configuration

**android/app/src/main/AndroidManifest.xml**:
```xml
<manifest>
    <uses-permission android:name="android.permission.NFC" />
    <uses-permission android:name="android.permission.CAMERA" />
    
    <uses-feature
        android:name="android.hardware.nfc"
        android:required="false" />
    
    <application>
        <!-- ... -->
    </application>
</manifest>
```

**android/app/build.gradle**:
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}

dependencies {
    implementation "org.jmrtd:jmrtd:0.7.34"
    implementation "net.sf.scuba:scuba-sc-android:0.0.23"
}
```

**android/app/src/main/kotlin/.../NfcHandler.kt**:
```kotlin
package com.example.ekyc

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class NfcHandler(private val activity: Activity) {
    private val CHANNEL = "com.example.ekyc/nfc"
    private val EVENT_CHANNEL = "com.example.ekyc/nfc_events"
    
    private var nfcAdapter: NfcAdapter? = null
    private var eventSink: EventChannel.EventSink? = null
    
    fun register(flutterEngine: FlutterEngine) {
        nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
        
        // Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNFCAvailable" -> {
                        result.success(nfcAdapter != null)
                    }
                    "isNFCEnabled" -> {
                        result.success(nfcAdapter?.isEnabled == true)
                    }
                    "startReading" -> {
                        val docNum = call.argument<String>("documentNumber")
                        val dob = call.argument<String>("dateOfBirth")
                        val expiry = call.argument<String>("dateOfExpiry")
                        
                        if (docNum != null && dob != null && expiry != null) {
                            startNFCReading(docNum, dob, expiry, result)
                        } else {
                            result.error("INVALID_ARGS", "Missing arguments", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Event Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }
    
    private fun startNFCReading(
        docNum: String,
        dob: String,
        expiry: String,
        result: MethodChannel.Result
    ) {
        // Implement NFC reading logic
        // Similar to Android example
        
        eventSink?.success(mapOf(
            "state" to "scanning",
            "message" to "Scanning for NFC tag"
        ))
        
        // ... NFC reading implementation ...
    }
}
```

### iOS Configuration

**ios/Runner/Info.plist**:
```xml
<dict>
    <key>NFCReaderUsageDescription</key>
    <string>We need NFC access to read your ID card</string>
    
    <key>NSCameraUsageDescription</key>
    <string>We need camera access to scan your ID</string>
    
    <key>com.apple.developer.nfc.readersession.formats</key>
    <array>
        <string>TAG</string>
    </array>
</dict>
```

**ios/Runner/Runner.entitlements**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.nfc.readersession.formats</key>
    <array>
        <string>TAG</string>
    </array>
    <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
    <array>
        <string>A0000002471001</string>
    </array>
</dict>
</plist>
```

**ios/Runner/AppDelegate.swift**:
```swift
import UIKit
import Flutter
import CoreNFC

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var nfcHandler: NfcHandler?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        
        nfcHandler = NfcHandler()
        nfcHandler?.register(with: controller.engine!)
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

**ios/Runner/NfcHandler.swift**:
```swift
import CoreNFC
import Flutter

class NfcHandler: NSObject {
    private let CHANNEL = "com.example.ekyc/nfc"
    private let EVENT_CHANNEL = "com.example.ekyc/nfc_events"
    
    private var session: NFCTagReaderSession?
    private var eventSink: FlutterEventSink?
    
    func register(with engine: FlutterEngine) {
        let messenger = engine.binaryMessenger
        
        // Method Channel
        let methodChannel = FlutterMethodChannel(
            name: CHANNEL,
            binaryMessenger: messenger
        )
        
        methodChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "isNFCAvailable":
                result(NFCTagReaderSession.readingAvailable)
            case "isNFCEnabled":
                result(NFCTagReaderSession.readingAvailable)
            case "startReading":
                if let args = call.arguments as? [String: Any],
                   let docNum = args["documentNumber"] as? String,
                   let dob = args["dateOfBirth"] as? String,
                   let expiry = args["dateOfExpiry"] as? String {
                    self?.startReading(docNum: docNum, dob: dob, expiry: expiry, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        // Event Channel
        let eventChannel = FlutterEventChannel(
            name: EVENT_CHANNEL,
            binaryMessenger: messenger
        )
        
        eventChannel.setStreamHandler(self)
    }
    
    private func startReading(
        docNum: String,
        dob: String,
        expiry: String,
        result: @escaping FlutterResult
    ) {
        // Implement NFC reading
        // Similar to iOS example
        
        eventSink?(["state": "scanning", "message": "Hold card near iPhone"])
    }
}

extension NfcHandler: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
```

## Usage

### 1. Initialize App

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ekyc_screen.dart';
import 'ekyc_viewmodel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eKYC Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const EKYCScreen(),
    );
  }
}
```

### 2. MRZ Scanning

```dart
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MRZScanner extends StatefulWidget {
  final Function(MRZData) onMRZDetected;
  
  const MRZScanner({Key? key, required this.onMRZDetected}) : super(key: key);
  
  @override
  State<MRZScanner> createState() => _MRZScannerState();
}

class _MRZScannerState extends State<MRZScanner> {
  CameraController? _controller;
  final _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;
    
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    
    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);
    setState(() {});
  }
  
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    
    try {
      final inputImage = _convertToInputImage(image);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      final mrzData = _parseMRZ(recognizedText.text);
      if (mrzData != null) {
        widget.onMRZDetected(mrzData);
      }
    } finally {
      _isProcessing = false;
    }
  }
  
  InputImage _convertToInputImage(CameraImage image) {
    // Convert CameraImage to InputImage
    // Implementation details...
    throw UnimplementedError();
  }
  
  MRZData? _parseMRZ(String text) {
    // Parse MRZ text
    // ICAO 9303 format
    // Implementation details...
    return null;
  }
  
  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return CameraPreview(_controller!);
  }
  
  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }
}
```

## Testing

### Unit Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ekyc_app/ekyc_viewmodel.dart';
import 'package:ekyc_app/nfc_reader.dart';

void main() {
  group('EKYCViewModel', () {
    late EKYCViewModel viewModel;
    
    setUp(() {
      viewModel = EKYCViewModel();
    });
    
    test('onMRZScanned updates state', () {
      final mrzData = MRZData(
        documentNumber: 'C06123456',
        dateOfBirth: '900101',
        dateOfExpiry: '300101',
        firstName: 'VAN A',
        lastName: 'NGUYEN',
      );
      
      viewModel.onMRZScanned(mrzData);
      
      expect(viewModel.mrzData, equals(mrzData));
      expect(viewModel.state.type, equals(EKYCStateType.mrzScanned));
    });
    
    test('verifyDataConsistency works correctly', () {
      final mrz = MRZData(...);
      final chip = ChipData(...);
      
      final result = viewModel._verifyDataConsistency(mrz, chip);
      
      expect(result, isTrue);
    });
  });
}
```

### Widget Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ekyc_app/ekyc_screen.dart';
import 'package:ekyc_app/ekyc_viewmodel.dart';

void main() {
  testWidgets('EKYCScreen shows initial state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => EKYCViewModel(),
          child: const EKYCScreen(),
        ),
      ),
    );
    
    expect(find.text('Ready to start eKYC verification'), findsOneWidget);
    expect(find.text('Start MRZ Scan'), findsOneWidget);
  });
  
  testWidgets('Tapping start button triggers MRZ scan', (tester) async {
    final viewModel = EKYCViewModel();
    
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: viewModel,
          child: const EKYCScreen(),
        ),
      ),
    );
    
    await tester.tap(find.text('Start MRZ Scan'));
    await tester.pump();
    
    expect(viewModel.state.type, equals(EKYCStateType.mrzScanned));
  });
}
```

### Integration Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ekyc_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('Complete eKYC flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    // Start MRZ scan
    await tester.tap(find.text('Start MRZ Scan'));
    await tester.pumpAndSettle();
    
    // Verify NFC instructions
    expect(find.text('Hold your ID card near your phone'), findsOneWidget);
    
    // Start NFC reading
    await tester.tap(find.text('Start NFC Reading'));
    await tester.pumpAndSettle();
    
    // Wait for completion
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
```

## Performance Optimization

### 1. Flutter Performance

```dart
// Use const constructors
const Text('Hello')

// Avoid rebuilds with keys
ListView.builder(
  key: const PageStorageKey('list'),
  itemBuilder: (context, index) => ...,
)

// Use RepaintBoundary for expensive widgets
RepaintBoundary(
  child: ComplexWidget(),
)

// Lazy load images
Image.network(
  url,
  cacheWidth: 800,
  cacheHeight: 600,
)
```

### 2. Platform Channel Optimization

```dart
// Batch method calls
Future<void> performBatch() async {
  await Future.wait([
    methodChannel.invokeMethod('method1'),
    methodChannel.invokeMethod('method2'),
    methodChannel.invokeMethod('method3'),
  ]);
}

// Use compute for heavy operations
final result = await compute(parseData, largeData);
```

## Best Practices

1. ✅ Use platform channels for native features
2. ✅ Implement proper error handling
3. ✅ Clear sensitive data after use
4. ✅ Test on both platforms
5. ✅ Use const constructors
6. ✅ Implement proper loading states
7. ✅ Handle permissions correctly
8. ✅ Support offline mode when possible

## Production Checklist

- [ ] Enable code obfuscation (`--obfuscate`)
- [ ] Implement certificate pinning
- [ ] Add crash reporting (Sentry, Firebase)
- [ ] Test on multiple devices
- [ ] Implement analytics (without PII)
- [ ] Configure ProGuard (Android)
- [ ] Enable bitcode (iOS)
- [ ] Test with real NFC cards
- [ ] Prepare privacy policy
- [ ] Document user flows

## References

- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [Provider Documentation](https://pub.dev/packages/provider)
- [ICAO 9303](https://www.icao.int/publications/pages/publication.aspx?docnum=9303)
