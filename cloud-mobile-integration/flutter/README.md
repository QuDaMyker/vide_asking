# Cloud-Connected Mobile Apps - Flutter Implementation

Complete Flutter implementation for cloud-connected applications using AWS Amplify and Firebase.

## 📦 Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # AWS Amplify
  amplify_flutter: ^2.0.0
  amplify_auth_cognito: ^2.0.0
  amplify_storage_s3: ^2.0.0
  amplify_api: ^2.0.0
  amplify_datastore: ^2.0.0

  # Firebase
  firebase_core: ^2.24.0
  firebase_auth: ^4.15.0
  cloud_firestore: ^4.13.0
  firebase_storage: ^11.5.0
  firebase_messaging: ^14.7.0
  firebase_analytics: ^10.7.0
  
  # Social Sign-In
  google_sign_in: ^6.1.5
  sign_in_with_apple: ^5.0.0
  
  # Utilities
  flutter_secure_storage: ^9.0.0
```

## 🚀 Setup

### AWS Amplify Setup

1. **Install Amplify CLI**:
```bash
npm install -g @aws-amplify/cli
amplify configure
```

2. **Initialize Amplify**:
```bash
amplify init
amplify add auth
amplify add storage
amplify push
```

3. **Configure Flutter App**:

```dart
import 'package:amplify_flutter/amplify_flutter.dart';
import 'amplify_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Amplify
  final amplifyManager = AmplifyManager();
  await amplifyManager.initialize();
  
  runApp(MyApp());
}
```

### Firebase Setup

1. **Add Firebase to Flutter**:
```bash
flutterfire configure
```

2. **Initialize Firebase**:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(MyApp());
}
```

## 💻 Usage Examples

### AWS Cognito Authentication

```dart
import 'cognito_auth_manager.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authManager = CognitoAuthManager();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    authManager.initialize();
  }
  
  Future<void> _signIn() async {
    try {
      final result = await authManager.signIn(
        email: emailController.text,
        password: passwordController.text,
      );
      
      if (result.isSignedIn) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: $e')),
      );
    }
  }
  
  Future<void> _signInWithGoogle() async {
    try {
      await authManager.signInWithSocialProvider(
        provider: AuthProvider.google,
      );
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print('Google sign in failed: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign In')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signIn,
              child: Text('Sign In'),
            ),
            ElevatedButton(
              onPressed: _signInWithGoogle,
              child: Text('Sign In with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### AWS S3 File Upload

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 's3_manager.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final s3Manager = S3Manager();
  double uploadProgress = 0.0;
  
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;
    
    try {
      final file = File(image.path);
      final fileName = 'images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final key = await s3Manager.uploadFile(
        file: file,
        key: fileName,
        accessLevel: StorageAccessLevel.private,
        onProgress: (progress) {
          setState(() {
            uploadProgress = progress.fractionCompleted;
          });
        },
      );
      
      // Get download URL
      final url = await s3Manager.getUrl(key: key);
      print('File uploaded: $url');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload successful!')),
      );
    } catch (e) {
      print('Upload failed: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload File')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (uploadProgress > 0 && uploadProgress < 1)
              LinearProgressIndicator(value: uploadProgress),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.upload_file),
              label: Text('Pick and Upload Image'),
              onPressed: _pickAndUploadImage,
            ),
          ],
        ),
      ),
    );
  }
}
```

### Firebase Authentication

```dart
import 'firebase_auth_manager.dart';

class FirebaseLoginScreen extends StatefulWidget {
  @override
  _FirebaseLoginScreenState createState() => _FirebaseLoginScreenState();
}

class _FirebaseLoginScreenState extends State<FirebaseLoginScreen> {
  final authManager = FirebaseAuthManager();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    authManager.initialize();
  }
  
  Future<void> _signIn() async {
    try {
      await authManager.signInWithEmail(
        email: emailController.text,
        password: passwordController.text,
      );
      
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: $e')),
      );
    }
  }
  
  Future<void> _signInWithGoogle() async {
    try {
      await authManager.signInWithGoogle();
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print('Google sign in failed: $e');
    }
  }
  
  Future<void> _signInWithApple() async {
    try {
      await authManager.signInWithApple();
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print('Apple sign in failed: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Firebase Sign In')),
      body: ValueListenableBuilder<User?>(
        valueListenable: authManager.currentUser,
        builder: (context, user, _) {
          if (user != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Signed in as: ${user.email}'),
                  ElevatedButton(
                    onPressed: () => authManager.signOut(),
                    child: Text('Sign Out'),
                  ),
                ],
              ),
            );
          }
          
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _signIn,
                  child: Text('Sign In'),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.g_mobiledata),
                  onPressed: _signInWithGoogle,
                  label: Text('Sign In with Google'),
                ),
                if (Platform.isIOS)
                  ElevatedButton.icon(
                    icon: Icon(Icons.apple),
                    onPressed: _signInWithApple,
                    label: Text('Sign In with Apple'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

## 🔒 Security Best Practices

1. **Never commit credentials**:
```dart
// Use environment variables
const String apiKey = String.fromEnvironment('API_KEY');
```

2. **Validate user input**:
```dart
bool isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}
```

3. **Use secure storage**:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
await storage.write(key: 'auth_token', value: token);
```

## 🧪 Testing

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseAuthManager Tests', () {
    late FirebaseAuthManager authManager;
    
    setUp(() {
      authManager = FirebaseAuthManager();
    });
    
    test('Sign in with valid credentials', () async {
      // Mock test
      expect(authManager.isAuthenticated(), isFalse);
    });
    
    test('Sign out', () async {
      // Mock test
      await authManager.signOut();
      expect(authManager.getCurrentUser(), isNull);
    });
  });
}
```

## 📱 Platform-Specific Setup

### Android

Add to `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        minSdkVersion 21
        multiDexEnabled true
    }
}

dependencies {
    implementation 'com.android.support:multidex:1.0.3'
}
```

### iOS

Add to `ios/Podfile`:
```ruby
platform :ios, '13.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

## 📖 Additional Resources

- [AWS Amplify Flutter](https://docs.amplify.aws/lib/q/platform/flutter/)
- [Firebase Flutter](https://firebase.google.com/docs/flutter/setup)
- [Flutter Best Practices](https://docs.flutter.dev/perf/best-practices)
