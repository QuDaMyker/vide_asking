package com.example.security.biometric

import android.content.Context
import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.*
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import java.util.concurrent.Executor
import javax.crypto.Cipher

/**
 * Comprehensive Biometric Authentication Manager
 * Supports fingerprint, face, and iris authentication with hardware-backed crypto
 */
class BiometricAuthenticator(private val activity: FragmentActivity) {

    private val executor: Executor = ContextCompat.getMainExecutor(activity)
    private val biometricManager = BiometricManager.from(activity)

    /**
     * Check biometric availability
     */
    fun canAuthenticate(): BiometricAvailability {
        return when (biometricManager.canAuthenticate(BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS ->
                BiometricAvailability.Available

            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE ->
                BiometricAvailability.NoHardware

            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE ->
                BiometricAvailability.HardwareUnavailable

            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED ->
                BiometricAvailability.NoneEnrolled

            BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED ->
                BiometricAvailability.SecurityUpdateRequired

            BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED ->
                BiometricAvailability.Unsupported

            BiometricManager.BIOMETRIC_STATUS_UNKNOWN ->
                BiometricAvailability.Unknown

            else -> BiometricAvailability.Unknown
        }
    }

    /**
     * Authenticate with biometric
     * @param cryptoObject Optional CryptoObject for key-bound authentication
     */
    fun authenticate(
        title: String,
        subtitle: String = "",
        description: String = "",
        negativeButtonText: String = "Cancel",
        cryptoObject: BiometricPrompt.CryptoObject? = null,
        onSuccess: (BiometricPrompt.AuthenticationResult) -> Unit,
        onError: (Int, String) -> Unit,
        onFailed: () -> Unit = {}
    ) {
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .apply {
                if (subtitle.isNotEmpty()) setSubtitle(subtitle)
                if (description.isNotEmpty()) setDescription(description)
            }
            .setNegativeButtonText(negativeButtonText)
            .setAllowedAuthenticators(BIOMETRIC_STRONG)
            .setConfirmationRequired(true)
            .build()

        val biometricPrompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    result: BiometricPrompt.AuthenticationResult
                ) {
                    super.onAuthenticationSucceeded(result)
                    onSuccess(result)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    onError(errorCode, errString.toString())
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    onFailed()
                }
            }
        )

        if (cryptoObject != null) {
            biometricPrompt.authenticate(promptInfo, cryptoObject)
        } else {
            biometricPrompt.authenticate(promptInfo)
        }
    }

    /**
     * Authenticate with device credential fallback
     */
    fun authenticateWithDeviceCredential(
        title: String,
        subtitle: String = "",
        description: String = "",
        cryptoObject: BiometricPrompt.CryptoObject? = null,
        onSuccess: (BiometricPrompt.AuthenticationResult) -> Unit,
        onError: (Int, String) -> Unit
    ) {
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .apply {
                if (subtitle.isNotEmpty()) setSubtitle(subtitle)
                if (description.isNotEmpty()) setDescription(description)
            }
            .setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
            .build()

        val biometricPrompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    result: BiometricPrompt.AuthenticationResult
                ) {
                    super.onAuthenticationSucceeded(result)
                    onSuccess(result)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    onError(errorCode, errString.toString())
                }
            }
        )

        if (cryptoObject != null) {
            biometricPrompt.authenticate(promptInfo, cryptoObject)
        } else {
            biometricPrompt.authenticate(promptInfo)
        }
    }

    /**
     * Create CryptoObject with cipher for encryption
     */
    fun createEncryptCryptoObject(cipher: Cipher): BiometricPrompt.CryptoObject {
        return BiometricPrompt.CryptoObject(cipher)
    }

    /**
     * Create CryptoObject with cipher for decryption
     */
    fun createDecryptCryptoObject(cipher: Cipher): BiometricPrompt.CryptoObject {
        return BiometricPrompt.CryptoObject(cipher)
    }

    /**
     * Get supported biometric types
     */
    fun getSupportedBiometricTypes(): Set<BiometricType> {
        val types = mutableSetOf<BiometricType>()

        // Check fingerprint
        if (biometricManager.canAuthenticate(BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS) {
            types.add(BiometricType.FINGERPRINT)
        }

        // Check face (Android 10+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Face authentication available on some devices
            types.add(BiometricType.FACE)
        }

        // Check iris (Samsung devices)
        if (Build.MANUFACTURER.equals("samsung", ignoreCase = true)) {
            types.add(BiometricType.IRIS)
        }

        return types
    }

    /**
     * Check if device has StrongBox support
     */
    fun hasStrongBox(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            activity.packageManager.hasSystemFeature("android.hardware.strongbox_keystore")
        } else {
            false
        }
    }
}

/**
 * Biometric availability states
 */
sealed class BiometricAvailability {
    object Available : BiometricAvailability()
    object NoHardware : BiometricAvailability()
    object HardwareUnavailable : BiometricAvailability()
    object NoneEnrolled : BiometricAvailability()
    object SecurityUpdateRequired : BiometricAvailability()
    object Unsupported : BiometricAvailability()
    object Unknown : BiometricAvailability()

    fun isAvailable(): Boolean = this is Available

    fun getUserMessage(): String = when (this) {
        is Available -> "Biometric authentication available"
        is NoHardware -> "No biometric hardware detected"
        is HardwareUnavailable -> "Biometric hardware unavailable"
        is NoneEnrolled -> "No biometrics enrolled. Please add fingerprint or face in settings"
        is SecurityUpdateRequired -> "Security update required"
        is Unsupported -> "Biometric authentication not supported"
        is Unknown -> "Biometric status unknown"
    }
}

/**
 * Biometric types
 */
enum class BiometricType {
    FINGERPRINT,
    FACE,
    IRIS,
    VOICE // Future support
}

/**
 * Authentication result with metadata
 */
data class AuthenticationMetadata(
    val authenticationType: Int,
    val timestamp: Long = System.currentTimeMillis(),
    val cryptoObject: BiometricPrompt.CryptoObject?
)
