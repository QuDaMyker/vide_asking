import 'package:flutter/foundation.dart';
import 'nfc_reader.dart';
import 'secure_storage.dart';

/// ViewModel for eKYC flow using ChangeNotifier
/// Orchestrates NFC reading, data verification, and submission
class EKYCViewModel extends ChangeNotifier {
  final NFCReader _nfcReader = NFCReader();
  final SecureStorage _secureStorage = SecureStorage();

  EKYCState _state = EKYCState.initial();
  MRZData? _mrzData;
  ChipData? _chipData;

  EKYCState get state => _state;
  MRZData? get mrzData => _mrzData;
  ChipData? get chipData => _chipData;

  /// Process scanned MRZ data
  void onMRZScanned(MRZData data) {
    _mrzData = data;
    _state = EKYCState.mrzScanned(data);
    notifyListeners();
  }

  /// Start NFC reading with scanned MRZ
  Future<void> readNFCChip() async {
    if (_mrzData == null) {
      _state = EKYCState.error('Please scan MRZ first');
      notifyListeners();
      return;
    }

    try {
      _state = EKYCState.readingNFC();
      notifyListeners();

      final mrzKey = MRZKey(
        documentNumber: _mrzData!.documentNumber,
        dateOfBirth: _mrzData!.dateOfBirth,
        dateOfExpiry: _mrzData!.dateOfExpiry,
      );

      final chipData = await _nfcReader.startReading(mrzKey);

      // Verify data consistency
      if (_verifyDataConsistency(_mrzData!, chipData)) {
        _chipData = chipData;

        // Store securely
        await _secureStorage.storeChipData(chipData);

        _state = EKYCState.success(chipData);
      } else {
        _state = EKYCState.error('Data mismatch between MRZ and chip');
      }
    } catch (e) {
      _state = EKYCState.error(e.toString());
    } finally {
      notifyListeners();
    }
  }

  /// Submit eKYC data to backend
  Future<void> submitEKYC() async {
    if (_chipData == null) {
      _state = EKYCState.error('No chip data available');
      notifyListeners();
      return;
    }

    try {
      _state = EKYCState.submitting();
      notifyListeners();

      // TODO: Implement actual API call with mutual TLS
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      // Clear sensitive data after submission
      await _clearSensitiveData();

      _state = EKYCState.submitted();
    } catch (e) {
      _state = EKYCState.error('Submission failed: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Reset to initial state
  Future<void> reset() async {
    await _clearSensitiveData();
    _state = EKYCState.initial();
    notifyListeners();
  }

  /// Check if NFC is available
  Future<bool> isNFCAvailable() => _nfcReader.isNFCAvailable();

  /// Check if NFC is enabled
  Future<bool> isNFCEnabled() => _nfcReader.isNFCEnabled();

  /// Verify consistency between MRZ and chip data
  bool _verifyDataConsistency(MRZData mrz, ChipData chip) {
    return mrz.documentNumber == chip.documentNumber &&
        mrz.dateOfBirth == chip.dateOfBirth &&
        mrz.dateOfExpiry == chip.dateOfExpiry;
  }

  /// Clear sensitive data from memory and storage
  Future<void> _clearSensitiveData() async {
    _mrzData = null;
    _chipData = null;
    await _secureStorage.clearAll();
  }

  @override
  void dispose() {
    _clearSensitiveData();
    super.dispose();
  }
}

/// UI States for eKYC flow
class EKYCState {
  final EKYCStateType type;
  final String? errorMessage;
  final MRZData? mrzData;
  final ChipData? chipData;

  const EKYCState._({
    required this.type,
    this.errorMessage,
    this.mrzData,
    this.chipData,
  });

  factory EKYCState.initial() =>
      const EKYCState._(type: EKYCStateType.initial);

  factory EKYCState.scanningMRZ() =>
      const EKYCState._(type: EKYCStateType.scanningMRZ);

  factory EKYCState.mrzScanned(MRZData data) =>
      EKYCState._(type: EKYCStateType.mrzScanned, mrzData: data);

  factory EKYCState.readingNFC() =>
      const EKYCState._(type: EKYCStateType.readingNFC);

  factory EKYCState.success(ChipData data) =>
      EKYCState._(type: EKYCStateType.success, chipData: data);

  factory EKYCState.submitting() =>
      const EKYCState._(type: EKYCStateType.submitting);

  factory EKYCState.submitted() =>
      const EKYCState._(type: EKYCStateType.submitted);

  factory EKYCState.error(String message) =>
      EKYCState._(type: EKYCStateType.error, errorMessage: message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EKYCState &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;
}

enum EKYCStateType {
  initial,
  scanningMRZ,
  mrzScanned,
  readingNFC,
  success,
  submitting,
  submitted,
  error,
}

/// MRZ data from OCR scan
class MRZData {
  final String documentNumber;
  final String dateOfBirth;
  final String dateOfExpiry;
  final String firstName;
  final String lastName;

  const MRZData({
    required this.documentNumber,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    required this.firstName,
    required this.lastName,
  });

  Map<String, String> toMap() => {
        'documentNumber': documentNumber,
        'dateOfBirth': dateOfBirth,
        'dateOfExpiry': dateOfExpiry,
        'firstName': firstName,
        'lastName': lastName,
      };

  @override
  String toString() {
    return 'MRZData(documentNumber: $documentNumber, '
        'name: $lastName $firstName)';
  }
}
