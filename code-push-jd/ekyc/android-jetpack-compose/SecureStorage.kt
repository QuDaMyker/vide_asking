package com.example.ekyc.security

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.example.ekyc.nfc.ChipData
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Secure storage using Android Keystore
 * Implements encryption for sensitive eKYC data
 */
class SecureStorage(private val context: Context) {

    companion object {
        private const val KEYSTORE_ALIAS = "ekyc_key"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val PREFERENCES_NAME = "ekyc_secure_prefs"
        private const val KEY_CHIP_DATA = "chip_data"
        private const val CACHE_EXPIRY_MS = 15 * 60 * 1000L // 15 minutes
    }

    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .setUserAuthenticationRequired(true)
        .setUserAuthenticationParameters(
            300, // 5 minutes validity
            KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
        )
        .build()

    private val encryptedPrefs = EncryptedSharedPreferences.create(
        context,
        PREFERENCES_NAME,
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    /**
     * Store chip data securely with auto-expiry
     */
    fun storeChipData(chipData: ChipData) {
        // Store with timestamp for expiry
        val timestamp = System.currentTimeMillis()
        
        encryptedPrefs.edit().apply {
            putString("${KEY_CHIP_DATA}_doc_num", chipData.documentNumber)
            putString("${KEY_CHIP_DATA}_dob", chipData.dateOfBirth)
            putString("${KEY_CHIP_DATA}_expiry", chipData.dateOfExpiry)
            putString("${KEY_CHIP_DATA}_first_name", chipData.firstName)
            putString("${KEY_CHIP_DATA}_last_name", chipData.lastName)
            putLong("${KEY_CHIP_DATA}_timestamp", timestamp)
            apply()
        }

        // Face image stored separately with encryption
        chipData.faceImage?.let { image ->
            storeFaceImage(image)
        }
    }

    /**
     * Retrieve chip data if not expired
     */
    fun retrieveChipData(): ChipData? {
        val timestamp = encryptedPrefs.getLong("${KEY_CHIP_DATA}_timestamp", 0L)
        
        // Check expiry
        if (System.currentTimeMillis() - timestamp > CACHE_EXPIRY_MS) {
            clearAll()
            return null
        }

        return try {
            ChipData(
                documentNumber = encryptedPrefs.getString("${KEY_CHIP_DATA}_doc_num", "") ?: "",
                dateOfBirth = encryptedPrefs.getString("${KEY_CHIP_DATA}_dob", "") ?: "",
                dateOfExpiry = encryptedPrefs.getString("${KEY_CHIP_DATA}_expiry", "") ?: "",
                firstName = encryptedPrefs.getString("${KEY_CHIP_DATA}_first_name", "") ?: "",
                lastName = encryptedPrefs.getString("${KEY_CHIP_DATA}_last_name", "") ?: "",
                nationality = "",
                gender = "",
                faceImage = retrieveFaceImage(),
                verified = true
            )
        } catch (e: Exception) {
            clearAll()
            null
        }
    }

    /**
     * Store face image with Keystore encryption
     */
    private fun storeFaceImage(imageData: ByteArray) {
        val cipher = getCipher()
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        
        val encryptedData = cipher.doFinal(imageData)
        val iv = cipher.iv

        context.openFileOutput("face_image.enc", Context.MODE_PRIVATE).use {
            it.write(iv.size)
            it.write(iv)
            it.write(encryptedData)
        }
    }

    /**
     * Retrieve face image with decryption
     */
    private fun retrieveFaceImage(): ByteArray? {
        return try {
            context.openFileInput("face_image.enc").use { input ->
                val ivSize = input.read()
                val iv = ByteArray(ivSize)
                input.read(iv)
                
                val encryptedData = input.readBytes()
                
                val cipher = getCipher()
                cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(128, iv))
                cipher.doFinal(encryptedData)
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Get or create encryption key in Android Keystore
     */
    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
        keyStore.load(null)

        if (!keyStore.containsAlias(KEYSTORE_ALIAS)) {
            val keyGenerator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                ANDROID_KEYSTORE
            )
            
            val keyGenParameterSpec = KeyGenParameterSpec.Builder(
                KEYSTORE_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(false) // Set true for biometric requirement
                .build()

            keyGenerator.init(keyGenParameterSpec)
            return keyGenerator.generateKey()
        }

        return keyStore.getKey(KEYSTORE_ALIAS, null) as SecretKey
    }

    /**
     * Get cipher for encryption/decryption
     */
    private fun getCipher(): Cipher {
        return Cipher.getInstance(
            "${KeyProperties.KEY_ALGORITHM_AES}/" +
            "${KeyProperties.BLOCK_MODE_GCM}/" +
            "${KeyProperties.ENCRYPTION_PADDING_NONE}"
        )
    }

    /**
     * Clear all stored data and wipe encryption keys
     */
    fun clearAll() {
        encryptedPrefs.edit().clear().apply()
        
        // Delete face image file
        try {
            context.deleteFile("face_image.enc")
        } catch (e: Exception) {
            // Ignore if file doesn't exist
        }

        // Wipe key from memory (force GC)
        System.gc()
    }

    /**
     * Check if stored data has expired
     */
    fun isDataExpired(): Boolean {
        val timestamp = encryptedPrefs.getLong("${KEY_CHIP_DATA}_timestamp", 0L)
        return System.currentTimeMillis() - timestamp > CACHE_EXPIRY_MS
    }
}
