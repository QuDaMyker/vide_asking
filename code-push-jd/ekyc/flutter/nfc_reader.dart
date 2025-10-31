import 'dart:typed_data';
import 'package:flutter/services.dart';

/// NFC Reader for Vietnamese CCCD/C06/VNeID cards
/// Uses platform channels to access native NFC APIs
class NFCReader {
  static const _channel = MethodChannel('com.example.ekyc/nfc');
  static const _eventChannel = EventChannel('com.example.ekyc/nfc_events');

  Stream<NFCState>? _nfcStateStream;
  Stream<double>? _progressStream;

  /// Check if NFC is available on device
  Future<bool> isNFCAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isNFCAvailable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if NFC is enabled
  Future<bool> isNFCEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isNFCEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Start NFC reading with MRZ key
  Future<ChipData> startReading(MRZKey mrzKey) async {
    try {
      final result = await _channel.invokeMethod('startReading', {
        'documentNumber': mrzKey.documentNumber,
        'dateOfBirth': mrzKey.dateOfBirth,
        'dateOfExpiry': mrzKey.dateOfExpiry,
      });

      if (result == null) {
        throw NFCException('No data received from chip');
      }

      return ChipData.fromMap(result);
    } on PlatformException catch (e) {
      throw NFCException(e.message ?? 'NFC read failed');
    }
  }

  /// Get NFC state stream
  Stream<NFCState> getNFCStateStream() {
    _nfcStateStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => _parseNFCState(event))
        .handleError((error) => NFCState.error(error.toString()));
    return _nfcStateStream!;
  }

  /// Get reading progress stream
  Stream<double> getProgressStream() {
    _progressStream ??= _eventChannel
        .receiveBroadcastStream('progress')
        .map((event) => (event as num).toDouble())
        .handleError((error) => 0.0);
    return _progressStream!;
  }

  /// Cancel ongoing NFC reading
  Future<void> cancelReading() async {
    try {
      await _channel.invokeMethod('cancelReading');
    } catch (e) {
      // Ignore cancellation errors
    }
  }

  NFCState _parseNFCState(dynamic event) {
    if (event is Map) {
      final state = event['state'] as String?;
      switch (state) {
        case 'idle':
          return NFCState.idle();
        case 'scanning':
          return NFCState.scanning();
        case 'reading':
          return NFCState.reading();
        case 'success':
          return NFCState.success();
        case 'error':
          return NFCState.error(event['message'] as String? ?? 'Unknown error');
        default:
          return NFCState.idle();
      }
    }
    return NFCState.idle();
  }
}

/// NFC reading states
class NFCState {
  final NFCStateType type;
  final String? errorMessage;

  const NFCState._(this.type, [this.errorMessage]);

  factory NFCState.idle() => const NFCState._(NFCStateType.idle);
  factory NFCState.scanning() => const NFCState._(NFCStateType.scanning);
  factory NFCState.reading() => const NFCState._(NFCStateType.reading);
  factory NFCState.success() => const NFCState._(NFCStateType.success);
  factory NFCState.error(String message) =>
      NFCState._(NFCStateType.error, message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NFCState &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => type.hashCode ^ errorMessage.hashCode;
}

enum NFCStateType { idle, scanning, reading, success, error }

/// MRZ key for BAC authentication
class MRZKey {
  final String documentNumber;
  final String dateOfBirth;
  final String dateOfExpiry;

  const MRZKey({
    required this.documentNumber,
    required this.dateOfBirth,
    required this.dateOfExpiry,
  });

  Map<String, String> toMap() => {
        'documentNumber': documentNumber,
        'dateOfBirth': dateOfBirth,
        'dateOfExpiry': dateOfExpiry,
      };
}

/// Chip data model
class ChipData {
  final String documentNumber;
  final String dateOfBirth;
  final String dateOfExpiry;
  final String firstName;
  final String lastName;
  final String nationality;
  final String gender;
  final Uint8List? faceImage;
  final bool verified;

  const ChipData({
    required this.documentNumber,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    required this.firstName,
    required this.lastName,
    required this.nationality,
    required this.gender,
    this.faceImage,
    required this.verified,
  });

  factory ChipData.fromMap(Map<dynamic, dynamic> map) {
    return ChipData(
      documentNumber: map['documentNumber'] as String? ?? '',
      dateOfBirth: map['dateOfBirth'] as String? ?? '',
      dateOfExpiry: map['dateOfExpiry'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      nationality: map['nationality'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      faceImage: map['faceImage'] as Uint8List?,
      verified: map['verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'documentNumber': documentNumber,
        'dateOfBirth': dateOfBirth,
        'dateOfExpiry': dateOfExpiry,
        'firstName': firstName,
        'lastName': lastName,
        'nationality': nationality,
        'gender': gender,
        'faceImage': faceImage,
        'verified': verified,
      };

  @override
  String toString() {
    return 'ChipData(documentNumber: $documentNumber, '
        'name: $lastName $firstName, verified: $verified)';
  }
}

/// NFC Exception
class NFCException implements Exception {
  final String message;
  const NFCException(this.message);

  @override
  String toString() => 'NFCException: $message';
}
