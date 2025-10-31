import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/foundation.dart';

/// AWS Cognito Authentication Manager for Flutter
/// Handles user authentication with AWS Cognito
class CognitoAuthManager {
  static final CognitoAuthManager _instance = CognitoAuthManager._internal();
  factory CognitoAuthManager() => _instance;
  CognitoAuthManager._internal();

  final ValueNotifier<AuthState> authState =
      ValueNotifier(AuthState.unauthenticated());

  /// Initialize auth state listener
  void initialize() {
    // Listen to auth hub events
    Amplify.Hub.listen(HubChannel.Auth, (hubEvent) {
      switch (hubEvent.eventName) {
        case 'SIGNED_IN':
          _updateAuthState();
          break;
        case 'SIGNED_OUT':
          authState.value = AuthState.unauthenticated();
          break;
        case 'SESSION_EXPIRED':
          authState.value = AuthState.unauthenticated();
          break;
      }
    });

    // Check initial auth state
    _updateAuthState();
  }

  Future<void> _updateAuthState() async {
    try {
      final user = await getCurrentUser();
      if (user != null) {
        authState.value = AuthState.authenticated(user);
      }
    } catch (e) {
      authState.value = AuthState.unauthenticated();
    }
  }

  /// Sign up a new user
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    Map<String, String>? userAttributes,
  }) async {
    try {
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: userAttributes?.map(
            (key, value) => MapEntry(
              CognitoUserAttributeKey.parse(key),
              value,
            ),
          ),
        ),
      );

      return result;
    } on AuthException catch (e) {
      debugPrint('Error signing up: ${e.message}');
      rethrow;
    }
  }

  /// Confirm sign up with verification code
  Future<SignUpResult> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: confirmationCode,
      );

      return result;
    } on AuthException catch (e) {
      debugPrint('Error confirming sign up: ${e.message}');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      if (result.isSignedIn) {
        await _updateAuthState();
      }

      return result;
    } on AuthException catch (e) {
      debugPrint('Error signing in: ${e.message}');
      authState.value = AuthState.error(e.message);
      rethrow;
    }
  }

  /// Sign in with social provider
  Future<SignInResult> signInWithSocialProvider({
    required AuthProvider provider,
  }) async {
    try {
      final result = await Amplify.Auth.signInWithWebUI(
        provider: _mapAuthProvider(provider),
      );

      if (result.isSignedIn) {
        await _updateAuthState();
      }

      return result;
    } on AuthException catch (e) {
      debugPrint('Error signing in with social: ${e.message}');
      rethrow;
    }
  }

  AuthProvider _mapAuthProvider(AuthProvider provider) {
    switch (provider) {
      case AuthProvider.google:
        return AuthProvider.google;
      case AuthProvider.facebook:
        return AuthProvider.facebook;
      case AuthProvider.amazon:
        return AuthProvider.amazon;
      case AuthProvider.apple:
        return AuthProvider.apple;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
      authState.value = AuthState.unauthenticated();
    } on AuthException catch (e) {
      debugPrint('Error signing out: ${e.message}');
      rethrow;
    }
  }

  /// Get current user
  Future<AuthUser?> getCurrentUser() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user;
    } on AuthException {
      return null;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final user = await getCurrentUser();
    return user != null;
  }

  /// Fetch user attributes
  Future<List<AuthUserAttribute>> fetchUserAttributes() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      return attributes;
    } on AuthException catch (e) {
      debugPrint('Error fetching attributes: ${e.message}');
      rethrow;
    }
  }

  /// Update user attribute
  Future<UpdateUserAttributeResult> updateUserAttribute({
    required String key,
    required String value,
  }) async {
    try {
      final result = await Amplify.Auth.updateUserAttribute(
        userAttribute: AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.parse(key),
          value: value,
        ),
      );

      return result;
    } on AuthException catch (e) {
      debugPrint('Error updating attribute: ${e.message}');
      rethrow;
    }
  }

  /// Reset password
  Future<ResetPasswordResult> resetPassword({
    required String email,
  }) async {
    try {
      final result = await Amplify.Auth.resetPassword(username: email);
      return result;
    } on AuthException catch (e) {
      debugPrint('Error resetting password: ${e.message}');
      rethrow;
    }
  }

  /// Confirm reset password
  Future<void> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
    } on AuthException catch (e) {
      debugPrint('Error confirming reset password: ${e.message}');
      rethrow;
    }
  }

  /// Update password
  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await Amplify.Auth.updatePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
    } on AuthException catch (e) {
      debugPrint('Error updating password: ${e.message}');
      rethrow;
    }
  }

  /// Get access token
  Future<String> getAccessToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession(
        options: CognitoSessionOptions(getAWSCredentials: true),
      ) as CognitoAuthSession;

      return session.userPoolTokensResult.value.accessToken.raw;
    } on AuthException catch (e) {
      debugPrint('Error getting access token: ${e.message}');
      rethrow;
    }
  }

  /// Get ID token
  Future<String> getIdToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession(
        options: CognitoSessionOptions(getAWSCredentials: true),
      ) as CognitoAuthSession;

      return session.userPoolTokensResult.value.idToken.raw;
    } on AuthException catch (e) {
      debugPrint('Error getting ID token: ${e.message}');
      rethrow;
    }
  }

  /// Resend sign up code
  Future<ResendSignUpCodeResult> resendSignUpCode({
    required String email,
  }) async {
    try {
      final result = await Amplify.Auth.resendSignUpCode(username: email);
      return result;
    } on AuthException catch (e) {
      debugPrint('Error resending code: ${e.message}');
      rethrow;
    }
  }
}

/// Authentication state
class AuthState {
  final bool isAuthenticated;
  final AuthUser? user;
  final String? error;

  AuthState._({
    required this.isAuthenticated,
    this.user,
    this.error,
  });

  factory AuthState.authenticated(AuthUser user) {
    return AuthState._(
      isAuthenticated: true,
      user: user,
    );
  }

  factory AuthState.unauthenticated() {
    return AuthState._(
      isAuthenticated: false,
    );
  }

  factory AuthState.error(String message) {
    return AuthState._(
      isAuthenticated: false,
      error: message,
    );
  }

  @override
  String toString() {
    return 'AuthState(isAuthenticated: $isAuthenticated, '
        'user: ${user?.username}, error: $error)';
  }
}
