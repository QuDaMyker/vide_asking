import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Firebase Authentication Manager for Flutter
/// Handles user authentication with Firebase Auth
class FirebaseAuthManager {
  static final FirebaseAuthManager _instance = FirebaseAuthManager._internal();
  factory FirebaseAuthManager() => _instance;
  FirebaseAuthManager._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final ValueNotifier<User?> currentUser = ValueNotifier(null);

  /// Initialize auth state listener
  void initialize() {
    _auth.authStateChanges().listen((User? user) {
      currentUser.value = user;
      debugPrint('Auth state changed: ${user?.uid}');
    });

    // Set initial user
    currentUser.value = _auth.currentUser;
  }

  /// Sign up with email and password
  Future<User> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user!;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error signing up: ${e.message}');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user!;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error signing in: ${e.message}');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<User> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign in aborted');
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      return userCredential.user!;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Sign in with Apple
  Future<User> signInWithApple() async {
    try {
      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create OAuth credential
      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      return userCredential.user!;
    } catch (e) {
      debugPrint('Error signing in with Apple: $e');
      rethrow;
    }
  }

  /// Sign in with Facebook
  /// Note: Requires facebook_auth package
  Future<User> signInWithFacebook(String accessToken) async {
    try {
      final credential = FacebookAuthProvider.credential(accessToken);
      final userCredential = await _auth.signInWithCredential(credential);

      return userCredential.user!;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error signing in with Facebook: ${e.message}');
      rethrow;
    }
  }

  /// Sign in with phone number
  Future<void> signInWithPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(PhoneAuthCredential credential) onAutoVerify,
    required Function(FirebaseAuthException error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerify,
      verificationFailed: onError,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('Auto retrieval timeout');
      },
    );
  }

  /// Verify phone code
  Future<User> verifyPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user!;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error verifying phone code: ${e.message}');
      rethrow;
    }
  }

  /// Sign in anonymously
  Future<User> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user!;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error signing in anonymously: ${e.message}');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  /// Get current user
  User? getCurrentUser() => _auth.currentUser;

  /// Check if user is authenticated
  bool isAuthenticated() => _auth.currentUser != null;

  /// Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      debugPrint('Error sending email verification: ${e.message}');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      debugPrint('Error sending password reset: ${e.message}');
      rethrow;
    }
  }

  /// Update email
  Future<void> updateEmail({
    required String newEmail,
  }) async {
    try {
      await _auth.currentUser?.updateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      debugPrint('Error updating email: ${e.message}');
      rethrow;
    }
  }

  /// Update password
  Future<void> updatePassword({
    required String newPassword,
  }) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      debugPrint('Error updating password: ${e.message}');
      rethrow;
    }
  }

  /// Update profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.updatePhotoURL(photoURL);
      await _auth.currentUser?.reload();
    } on FirebaseAuthException catch (e) {
      debugPrint('Error updating profile: ${e.message}');
      rethrow;
    }
  }

  /// Delete account
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      debugPrint('Error deleting account: ${e.message}');
      rethrow;
    }
  }

  /// Get ID token
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      return await _auth.currentUser?.getIdToken(forceRefresh);
    } on FirebaseAuthException catch (e) {
      debugPrint('Error getting ID token: ${e.message}');
      rethrow;
    }
  }

  /// Link email credential
  Future<User> linkEmailCredential({
    required String email,
    required String password,
  }) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      final userCredential =
          await _auth.currentUser?.linkWithCredential(credential);

      return userCredential!.user!;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error linking email: ${e.message}');
      rethrow;
    }
  }

  /// Re-authenticate user
  Future<void> reauthenticate({
    required String email,
    required String password,
  }) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await _auth.currentUser?.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint('Error reauthenticating: ${e.message}');
      rethrow;
    }
  }

  /// Reload user data
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
      currentUser.value = _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error reloading user: ${e.message}');
      rethrow;
    }
  }

  /// Check if email is verified
  bool isEmailVerified() => _auth.currentUser?.emailVerified ?? false;

  /// Get user metadata
  UserMetadata? getUserMetadata() => _auth.currentUser?.metadata;
}
