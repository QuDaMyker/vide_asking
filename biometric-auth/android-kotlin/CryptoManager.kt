package com.example.security.crypto

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.*
import javax.crypto.*
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Comprehensive Cryptography Manager
 * Handles encryption, decryption, key generation, and secure storage
 */
class CryptoManager {

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val AES_MODE = "AES/GCM/NoPadding"
        private const val RSA_MODE = "RSA/ECB/OAEPWithSHA-256AndMGF1Padding"
        private const val KEY_SIZE = 256
        private const val GCM_TAG_LENGTH = 128
        private const val IV_SIZE = 12
        private const val PBKDF2_ITERATIONS = 100000
    }

    private val keyStore: KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply {
        load(null)
    }

    // ==================== AES Symmetric Encryption ====================

    /**
     * Generate AES key in Android Keystore
     * @param keyAlias Unique identifier for the key
     * @param requireBiometric Whether key requires biometric authentication
     * @param userAuthenticationValiditySeconds How long key is valid after auth (0 = always require)
     */
    fun generateAESKey(
        keyAlias: String,
        requireBiometric: Boolean = false,
        userAuthenticationValiditySeconds: Int = 0,
        useStrongBox: Boolean = false
    ): SecretKey {
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE
        )

        val builder = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(KEY_SIZE)
            .setRandomizedEncryptionRequired(true)

        // Biometric authentication
        if (requireBiometric && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(
                userAuthenticationValiditySeconds,
                KeyProperties.AUTH_BIOMETRIC_STRONG
            )
        } else if (requireBiometric && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            builder.setUserAuthenticationRequired(true)
            if (userAuthenticationValiditySeconds > 0) {
                builder.setUserAuthenticationValidityDurationSeconds(
                    userAuthenticationValiditySeconds
                )
            }
        }

        // StrongBox support (Android 9+)
        if (useStrongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setIsStrongBoxBacked(true)
        }

        keyGenerator.init(builder.build())
        return keyGenerator.generateKey()
    }

    /**
     * Get AES cipher for encryption
     */
    fun getEncryptCipher(keyAlias: String): Cipher {
        val key = keyStore.getKey(keyAlias, null) as SecretKey
        val cipher = Cipher.getInstance(AES_MODE)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        return cipher
    }

    /**
     * Get AES cipher for decryption
     */
    fun getDecryptCipher(keyAlias: String, iv: ByteArray): Cipher {
        val key = keyStore.getKey(keyAlias, null) as SecretKey
        val cipher = Cipher.getInstance(AES_MODE)
        val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)
        return cipher
    }

    /**
     * Encrypt data with AES-GCM
     */
    fun encryptAES(data: ByteArray, cipher: Cipher): EncryptedData {
        val encryptedBytes = cipher.doFinal(data)
        return EncryptedData(
            ciphertext = encryptedBytes,
            iv = cipher.iv
        )
    }

    /**
     * Decrypt data with AES-GCM
     */
    fun decryptAES(encryptedData: EncryptedData, cipher: Cipher): ByteArray {
        return cipher.doFinal(encryptedData.ciphertext)
    }

    // ==================== RSA Asymmetric Encryption ====================

    /**
     * Generate RSA key pair in Android Keystore
     */
    fun generateRSAKeyPair(
        keyAlias: String,
        keySize: Int = 2048,
        useStrongBox: Boolean = false
    ): KeyPair {
        val keyPairGenerator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_RSA,
            ANDROID_KEYSTORE
        )

        val builder = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setKeySize(keySize)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            .setDigests(
                KeyProperties.DIGEST_SHA256,
                KeyProperties.DIGEST_SHA512
            )

        if (useStrongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setIsStrongBoxBacked(true)
        }

        keyPairGenerator.initialize(builder.build())
        return keyPairGenerator.generateKeyPair()
    }

    /**
     * Encrypt data with RSA public key
     */
    fun encryptRSA(data: ByteArray, publicKey: PublicKey): ByteArray {
        val cipher = Cipher.getInstance(RSA_MODE)
        cipher.init(Cipher.ENCRYPT_MODE, publicKey)
        return cipher.doFinal(data)
    }

    /**
     * Decrypt data with RSA private key
     */
    fun decryptRSA(encryptedData: ByteArray, privateKey: PrivateKey): ByteArray {
        val cipher = Cipher.getInstance(RSA_MODE)
        cipher.init(Cipher.DECRYPT_MODE, privateKey)
        return cipher.doFinal(encryptedData)
    }

    // ==================== Key Derivation ====================

    /**
     * Derive key from password using PBKDF2
     */
    fun deriveKeyFromPassword(
        password: CharArray,
        salt: ByteArray,
        iterations: Int = PBKDF2_ITERATIONS,
        keyLength: Int = KEY_SIZE
    ): SecretKey {
        val spec = PBEKeySpec(password, salt, iterations, keyLength)
        val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val key = factory.generateSecret(spec)
        return SecretKeySpec(key.encoded, "AES")
    }

    /**
     * Generate cryptographically secure random salt
     */
    fun generateSalt(size: Int = 32): ByteArray {
        val salt = ByteArray(size)
        SecureRandom().nextBytes(salt)
        return salt
    }

    // ==================== Digital Signatures ====================

    /**
     * Generate key pair for signing
     */
    fun generateSigningKeyPair(
        keyAlias: String,
        useECC: Boolean = true
    ): KeyPair {
        val algorithm = if (useECC) {
            KeyProperties.KEY_ALGORITHM_EC
        } else {
            KeyProperties.KEY_ALGORITHM_RSA
        }

        val keyPairGenerator = KeyPairGenerator.getInstance(
            algorithm,
            ANDROID_KEYSTORE
        )

        val builder = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        )
            .setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)

        if (useECC) {
            // Use P-256 curve for ECC
        } else {
            builder.setKeySize(2048)
                .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PSS)
        }

        keyPairGenerator.initialize(builder.build())
        return keyPairGenerator.generateKeyPair()
    }

    /**
     * Sign data
     */
    fun signData(data: ByteArray, privateKey: PrivateKey, useECC: Boolean = true): ByteArray {
        val algorithm = if (useECC) "SHA256withECDSA" else "SHA256withRSA/PSS"
        val signature = Signature.getInstance(algorithm)
        signature.initSign(privateKey)
        signature.update(data)
        return signature.sign()
    }

    /**
     * Verify signature
     */
    fun verifySignature(
        data: ByteArray,
        signatureBytes: ByteArray,
        publicKey: PublicKey,
        useECC: Boolean = true
    ): Boolean {
        val algorithm = if (useECC) "SHA256withECDSA" else "SHA256withRSA/PSS"
        val signature = Signature.getInstance(algorithm)
        signature.initVerify(publicKey)
        signature.update(data)
        return signature.verify(signatureBytes)
    }

    // ==================== Hashing ====================

    /**
     * Hash data with SHA-256
     */
    fun hashSHA256(data: ByteArray): ByteArray {
        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(data)
    }

    /**
     * Hash data with SHA-512
     */
    fun hashSHA512(data: ByteArray): ByteArray {
        val digest = MessageDigest.getInstance("SHA-512")
        return digest.digest(data)
    }

    /**
     * HMAC-SHA256
     */
    fun hmacSHA256(data: ByteArray, key: SecretKey): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(key)
        return mac.doFinal(data)
    }

    // ==================== Key Management ====================

    /**
     * Check if key exists
     */
    fun keyExists(keyAlias: String): Boolean {
        return keyStore.containsAlias(keyAlias)
    }

    /**
     * Delete key
     */
    fun deleteKey(keyAlias: String) {
        if (keyExists(keyAlias)) {
            keyStore.deleteEntry(keyAlias)
        }
    }

    /**
     * Get all key aliases
     */
    fun getAllKeyAliases(): List<String> {
        return keyStore.aliases().toList()
    }

    /**
     * Get public key
     */
    fun getPublicKey(keyAlias: String): PublicKey? {
        return (keyStore.getEntry(keyAlias, null) as? KeyStore.PrivateKeyEntry)?.certificate?.publicKey
    }

    /**
     * Get private key
     */
    fun getPrivateKey(keyAlias: String): PrivateKey? {
        return keyStore.getKey(keyAlias, null) as? PrivateKey
    }

    // ==================== Utility Functions ====================

    /**
     * Secure wipe byte array
     */
    fun secureWipe(data: ByteArray) {
        data.fill(0)
    }

    /**
     * Generate random bytes
     */
    fun generateRandomBytes(size: Int): ByteArray {
        val bytes = ByteArray(size)
        SecureRandom().nextBytes(bytes)
        return bytes
    }
}

/**
 * Encrypted data container
 */
data class EncryptedData(
    val ciphertext: ByteArray,
    val iv: ByteArray,
    val authTag: ByteArray? = null
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as EncryptedData

        if (!ciphertext.contentEquals(other.ciphertext)) return false
        if (!iv.contentEquals(other.iv)) return false
        if (authTag != null) {
            if (other.authTag == null) return false
            if (!authTag.contentEquals(other.authTag)) return false
        } else if (other.authTag != null) return false

        return true
    }

    override fun hashCode(): Int {
        var result = ciphertext.contentHashCode()
        result = 31 * result + iv.contentHashCode()
        result = 31 * result + (authTag?.contentHashCode() ?: 0)
        return result
    }
}
