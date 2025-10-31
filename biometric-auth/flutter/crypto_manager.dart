import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:pointycastle/export.dart';

/// Comprehensive Cryptography Manager for Flutter
/// Handles encryption, decryption, key generation, and hashing
class CryptoManager {
  /// Generate AES key
  encrypt.Key generateAESKey() {
    return encrypt.Key.fromSecureRandom(32); // 256-bit
  }

  /// Encrypt data with AES-256-GCM
  EncryptedDataModel encryptAES(Uint8List data, encrypt.Key key) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    
    return EncryptedDataModel(
      ciphertext: encrypted.bytes,
      iv: iv.bytes,
      tag: Uint8List(0), // GCM tag is included in ciphertext
    );
  }

  /// Decrypt data with AES-256-GCM
  Uint8List decryptAES(EncryptedDataModel encryptedData, encrypt.Key key) {
    final iv = encrypt.IV(encryptedData.iv);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    
    final encrypted = encrypt.Encrypted(encryptedData.ciphertext);
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
    
    return Uint8List.fromList(decrypted);
  }

  /// Generate RSA key pair
  RSAKeyPairModel generateRSAKeyPair({int bitLength = 2048}) {
    final keyParams = RSAKeyGeneratorParameters(
      BigInt.parse('65537'), // Public exponent
      bitLength,
      64, // Certainty
    );

    final secureRandom = FortunaRandom();
    final random = SecureRandom('Fortuna')..seed(KeyParameter(
      Uint8List.fromList(List.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256))
    ));

    final generator = RSAKeyGenerator()..init(ParametersWithRandom(keyParams, random));
    final keyPair = generator.generateKeyPair();

    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;

    return RSAKeyPairModel(
      publicKey: RSAPublicKeyModel(
        modulus: publicKey.modulus!,
        exponent: publicKey.exponent!,
      ),
      privateKey: RSAPrivateKeyModel(
        modulus: privateKey.modulus!,
        exponent: privateKey.exponent!,
        p: privateKey.p!,
        q: privateKey.q!,
      ),
    );
  }

  /// Encrypt with RSA public key
  Uint8List encryptRSA(Uint8List data, RSAPublicKeyModel publicKey) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(
        true,
        PublicKeyParameter<RSAPublicKey>(
          RSAPublicKey(publicKey.modulus, publicKey.exponent),
        ),
      );

    return cipher.process(data);
  }

  /// Decrypt with RSA private key
  Uint8List decryptRSA(Uint8List encryptedData, RSAPrivateKeyModel privateKey) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(
        false,
        PrivateKeyParameter<RSAPrivateKey>(
          RSAPrivateKey(
            privateKey.modulus,
            privateKey.exponent,
            privateKey.p,
            privateKey.q,
          ),
        ),
      );

    return cipher.process(encryptedData);
  }

  /// Derive key from password using PBKDF2
  encrypt.Key deriveKeyFromPassword(
    String password,
    Uint8List salt, {
    int iterations = 100000,
    int keyLength = 32,
  }) {
    final generator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, keyLength));

    final key = generator.process(Uint8List.fromList(password.codeUnits));
    return encrypt.Key(key);
  }

  /// Generate cryptographically secure random salt
  Uint8List generateSalt({int length = 32}) {
    final secureRandom = FortunaRandom();
    final random = SecureRandom('Fortuna')..seed(KeyParameter(
      Uint8List.fromList(List.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256))
    ));
    
    return secureRandom.nextBytes(length);
  }

  /// Sign data with RSA private key
  Uint8List signData(Uint8List data, RSAPrivateKeyModel privateKey) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    
    signer.init(
      true,
      PrivateKeyParameter<RSAPrivateKey>(
        RSAPrivateKey(
          privateKey.modulus,
          privateKey.exponent,
          privateKey.p,
          privateKey.q,
        ),
      ),
    );

    final signature = signer.generateSignature(data) as RSASignature;
    return signature.bytes;
  }

  /// Verify signature with RSA public key
  bool verifySignature(
    Uint8List data,
    Uint8List signature,
    RSAPublicKeyModel publicKey,
  ) {
    final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
    
    verifier.init(
      false,
      PublicKeyParameter<RSAPublicKey>(
        RSAPublicKey(publicKey.modulus, publicKey.exponent),
      ),
    );

    try {
      return verifier.verifySignature(data, RSASignature(signature));
    } catch (e) {
      return false;
    }
  }

  /// Hash data with SHA-256
  Uint8List hashSHA256(Uint8List data) {
    return Uint8List.fromList(sha256.convert(data).bytes);
  }

  /// Hash data with SHA-512
  Uint8List hashSHA512(Uint8List data) {
    return Uint8List.fromList(sha512.convert(data).bytes);
  }

  /// HMAC-SHA256
  Uint8List hmacSHA256(Uint8List data, encrypt.Key key) {
    final hmacSha256 = Hmac(sha256, key.bytes);
    return Uint8List.fromList(hmacSha256.convert(data).bytes);
  }

  /// Generate random bytes
  Uint8List generateRandomBytes(int length) {
    final secureRandom = FortunaRandom();
    final seed = Uint8List.fromList(
      List.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256),
    );
    secureRandom.seed(KeyParameter(seed));
    
    return secureRandom.nextBytes(length);
  }

  /// Secure wipe byte array
  void secureWipe(Uint8List data) {
    for (int i = 0; i < data.length; i++) {
      data[i] = 0;
    }
  }

  /// Encode to Base64
  String toBase64(Uint8List data) {
    return base64.encode(data);
  }

  /// Decode from Base64
  Uint8List fromBase64(String encoded) {
    return base64.decode(encoded);
  }
}

/// Encrypted data model
class EncryptedDataModel {
  final Uint8List ciphertext;
  final Uint8List iv;
  final Uint8List tag;

  EncryptedDataModel({
    required this.ciphertext,
    required this.iv,
    required this.tag,
  });

  Map<String, dynamic> toJson() => {
        'ciphertext': base64.encode(ciphertext),
        'iv': base64.encode(iv),
        'tag': base64.encode(tag),
      };

  factory EncryptedDataModel.fromJson(Map<String, dynamic> json) {
    return EncryptedDataModel(
      ciphertext: base64.decode(json['ciphertext']),
      iv: base64.decode(json['iv']),
      tag: base64.decode(json['tag']),
    );
  }
}

/// RSA key pair model
class RSAKeyPairModel {
  final RSAPublicKeyModel publicKey;
  final RSAPrivateKeyModel privateKey;

  RSAKeyPairModel({
    required this.publicKey,
    required this.privateKey,
  });
}

/// RSA public key model
class RSAPublicKeyModel {
  final BigInt modulus;
  final BigInt exponent;

  RSAPublicKeyModel({
    required this.modulus,
    required this.exponent,
  });

  String toBase64() {
    final modulusBytes = _bigIntToBytes(modulus);
    final exponentBytes = _bigIntToBytes(exponent);
    final combined = [...modulusBytes, ...exponentBytes];
    return base64.encode(combined);
  }

  Uint8List _bigIntToBytes(BigInt number) {
    final bytes = <int>[];
    var value = number;
    while (value > BigInt.zero) {
      bytes.insert(0, (value & BigInt.from(0xff)).toInt());
      value = value >> 8;
    }
    return Uint8List.fromList(bytes);
  }
}

/// RSA private key model
class RSAPrivateKeyModel {
  final BigInt modulus;
  final BigInt exponent;
  final BigInt p;
  final BigInt q;

  RSAPrivateKeyModel({
    required this.modulus,
    required this.exponent,
    required this.p,
    required this.q,
  });
}

/// Crypto exceptions
class CryptoException implements Exception {
  final String message;
  const CryptoException(this.message);

  @override
  String toString() => 'CryptoException: $message';
}
