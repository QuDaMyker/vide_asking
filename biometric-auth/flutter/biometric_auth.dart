import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Comprehensive Biometric Authentication for Flutter
/// Supports fingerprint, face, and iris recognition cross-platform
class BiometricAuth {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device supports biometric authentication
  Future<bool> isAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.map((biometric) {
        switch (biometric) {
          case BiometricType.face:
            return BiometricAuthType.face;
          case BiometricType.fingerprint:
            return BiometricAuthType.fingerprint;
          case BiometricType.iris:
            return BiometricAuthType.iris;
          default:
            return BiometricAuthType.unknown;
        }
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Authenticate with biometric
  Future<AuthenticationResult> authenticate({
    required String localizedReason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
    bool biometricOnly = false,
  }) async {
    try {
      // Check availability
      if (!await isAvailable()) {
        return AuthenticationResult.notAvailable();
      }

      // Authenticate
      final authenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: biometricOnly,
        ),
      );

      if (authenticated) {
        return AuthenticationResult.success();
      } else {
        return AuthenticationResult.failed();
      }
    } on PlatformException catch (e) {
      return AuthenticationResult.error(_mapPlatformException(e));
    } catch (e) {
      return AuthenticationResult.error(
        BiometricAuthError.unknown(e.toString()),
      );
    }
  }

  /// Stop biometric authentication
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      // Ignore errors when stopping
    }
  }

  /// Check biometric enrollment status
  Future<BiometricEnrollmentStatus> getEnrollmentStatus() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      
      if (!isSupported) {
        return BiometricEnrollmentStatus.notSupported;
      }
      
      if (!canCheck) {
        return BiometricEnrollmentStatus.notAvailable;
      }
      
      final biometrics = await _localAuth.getAvailableBiometrics();
      if (biometrics.isEmpty) {
        return BiometricEnrollmentStatus.notEnrolled;
      }
      
      return BiometricEnrollmentStatus.enrolled;
    } catch (e) {
      return BiometricEnrollmentStatus.unknown;
    }
  }

  /// Map platform exception to auth error
  BiometricAuthError _mapPlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return BiometricAuthError.notAvailable;
      case 'NotEnrolled':
        return BiometricAuthError.notEnrolled;
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return BiometricAuthError.lockedOut;
      case 'PasscodeNotSet':
        return BiometricAuthError.passcodeNotSet;
      case 'AuthenticationFailed':
        return BiometricAuthError.failed;
      case 'UserCancel':
        return BiometricAuthError.userCanceled;
      default:
        return BiometricAuthError.unknown(e.message ?? 'Unknown error');
    }
  }
}

/// Authentication result
class AuthenticationResult {
  final bool isSuccess;
  final BiometricAuthError? error;

  AuthenticationResult._({
    required this.isSuccess,
    this.error,
  });

  factory AuthenticationResult.success() =>
      AuthenticationResult._(isSuccess: true);

  factory AuthenticationResult.failed() =>
      AuthenticationResult._(isSuccess: false);

  factory AuthenticationResult.notAvailable() => AuthenticationResult._(
        isSuccess: false,
        error: BiometricAuthError.notAvailable,
      );

  factory AuthenticationResult.error(BiometricAuthError error) =>
      AuthenticationResult._(
        isSuccess: false,
        error: error,
      );

  String get message {
    if (isSuccess) return 'Authentication successful';
    return error?.message ?? 'Authentication failed';
  }
}

/// Biometric authentication errors
enum BiometricAuthError {
  notAvailable,
  notEnrolled,
  lockedOut,
  passcodeNotSet,
  failed,
  userCanceled,
  unknown(String message);

  String get message {
    switch (this) {
      case BiometricAuthError.notAvailable:
        return 'Biometric authentication not available';
      case BiometricAuthError.notEnrolled:
        return 'No biometrics enrolled. Please set up in settings';
      case BiometricAuthError.lockedOut:
        return 'Too many failed attempts. Try again later';
      case BiometricAuthError.passcodeNotSet:
        return 'Device passcode not set';
      case BiometricAuthError.failed:
        return 'Authentication failed';
      case BiometricAuthError.userCanceled:
        return 'Authentication canceled by user';
      case BiometricAuthError.unknown:
        return 'Unknown error occurred';
    }
  }
}

/// Biometric types
enum BiometricAuthType {
  face,
  fingerprint,
  iris,
  unknown;

  String get displayName {
    switch (this) {
      case BiometricAuthType.face:
        return 'Face Recognition';
      case BiometricAuthType.fingerprint:
        return 'Fingerprint';
      case BiometricAuthType.iris:
        return 'Iris Scan';
      case BiometricAuthType.unknown:
        return 'Biometric';
    }
  }
}

/// Biometric enrollment status
enum BiometricEnrollmentStatus {
  enrolled,
  notEnrolled,
  notAvailable,
  notSupported,
  unknown;

  String get userMessage {
    switch (this) {
      case BiometricEnrollmentStatus.enrolled:
        return 'Biometric authentication is ready';
      case BiometricEnrollmentStatus.notEnrolled:
        return 'Please enroll biometrics in device settings';
      case BiometricEnrollmentStatus.notAvailable:
        return 'Biometric authentication not available';
      case BiometricEnrollmentStatus.notSupported:
        return 'Device does not support biometric authentication';
      case BiometricEnrollmentStatus.unknown:
        return 'Unable to determine biometric status';
    }
  }

  bool get canAuthenticate =>
      this == BiometricEnrollmentStatus.enrolled;
}
