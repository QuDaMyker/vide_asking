import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'nfc_reader.dart';

/// Secure storage for sensitive eKYC data
/// Uses flutter_secure_storage with encryption
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.whenUnlockedThisDeviceOnly,
    ),
  );

  static const _cacheExpiryMs = 15 * 60 * 1000; // 15 minutes
  static const _keyPrefix = 'ekyc_';
  static const _timestampKey = '${_keyPrefix}timestamp';
  static const _encryptionKeyKey = '${_keyPrefix}encryption_key';

  /// Store chip data securely with auto-expiry
  Future<void> storeChipData(ChipData data) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Store basic data
    await _storage.write(
      key: '${_keyPrefix}doc_num',
      value: data.documentNumber,
    );
    await _storage.write(
      key: '${_keyPrefix}dob',
      value: data.dateOfBirth,
    );
    await _storage.write(
      key: '${_keyPrefix}expiry',
      value: data.dateOfExpiry,
    );
    await _storage.write(
      key: '${_keyPrefix}first_name',
      value: data.firstName,
    );
    await _storage.write(
      key: '${_keyPrefix}last_name',
      value: data.lastName,
    );
    await _storage.write(
      key: '${_keyPrefix}nationality',
      value: data.nationality,
    );
    await _storage.write(
      key: '${_keyPrefix}gender',
      value: data.gender,
    );
    await _storage.write(
      key: _timestampKey,
      value: timestamp.toString(),
    );

    // Store face image with additional encryption
    if (data.faceImage != null) {
      await _storeFaceImage(data.faceImage!);
    }
  }

  /// Retrieve chip data if not expired
  Future<ChipData?> retrieveChipData() async {
    // Check expiry
    final timestampStr = await _storage.read(key: _timestampKey);
    if (timestampStr == null) return null;

    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - timestamp > _cacheExpiryMs) {
      await clearAll();
      return null;
    }

    // Retrieve data
    try {
      final documentNumber = await _storage.read(key: '${_keyPrefix}doc_num');
      final dateOfBirth = await _storage.read(key: '${_keyPrefix}dob');
      final dateOfExpiry = await _storage.read(key: '${_keyPrefix}expiry');
      final firstName = await _storage.read(key: '${_keyPrefix}first_name');
      final lastName = await _storage.read(key: '${_keyPrefix}last_name');
      final nationality = await _storage.read(key: '${_keyPrefix}nationality');
      final gender = await _storage.read(key: '${_keyPrefix}gender');
      final faceImage = await _retrieveFaceImage();

      if (documentNumber == null || dateOfBirth == null || dateOfExpiry == null) {
        return null;
      }

      return ChipData(
        documentNumber: documentNumber,
        dateOfBirth: dateOfBirth,
        dateOfExpiry: dateOfExpiry,
        firstName: firstName ?? '',
        lastName: lastName ?? '',
        nationality: nationality ?? '',
        gender: gender ?? '',
        faceImage: faceImage,
        verified: true,
      );
    } catch (e) {
      await clearAll();
      return null;
    }
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Check if stored data has expired
  Future<bool> isDataExpired() async {
    final timestampStr = await _storage.read(key: _timestampKey);
    if (timestampStr == null) return true;

    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) return true;

    final now = DateTime.now().millisecondsSinceEpoch;
    return now - timestamp > _cacheExpiryMs;
  }

  /// Store face image with encryption
  Future<void> _storeFaceImage(Uint8List imageData) async {
    // Generate or retrieve encryption key
    final key = await _getOrCreateEncryptionKey();
    
    // Encrypt image data
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final iv = encrypt.IV.fromSecureRandom(16);
    
    final encrypted = encrypter.encryptBytes(imageData, iv: iv);
    
    // Store encrypted data and IV
    await _storage.write(
      key: '${_keyPrefix}face_image',
      value: encrypted.base64,
    );
    await _storage.write(
      key: '${_keyPrefix}face_image_iv',
      value: iv.base64,
    );
  }

  /// Retrieve and decrypt face image
  Future<Uint8List?> _retrieveFaceImage() async {
    try {
      final encryptedStr = await _storage.read(key: '${_keyPrefix}face_image');
      final ivStr = await _storage.read(key: '${_keyPrefix}face_image_iv');

      if (encryptedStr == null || ivStr == null) return null;

      final key = await _getOrCreateEncryptionKey();
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final iv = encrypt.IV.fromBase64(ivStr);
      final encrypted = encrypt.Encrypted.fromBase64(encryptedStr);

      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      return null;
    }
  }

  /// Get or create encryption key
  Future<encrypt.Key> _getOrCreateEncryptionKey() async {
    var keyStr = await _storage.read(key: _encryptionKeyKey);
    
    if (keyStr == null) {
      // Generate new key
      final key = encrypt.Key.fromSecureRandom(32);
      keyStr = key.base64;
      await _storage.write(key: _encryptionKeyKey, value: keyStr);
      return key;
    }
    
    return encrypt.Key.fromBase64(keyStr);
  }

  /// Hash sensitive data for audit logs (one-way)
  String hashForAudit(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
