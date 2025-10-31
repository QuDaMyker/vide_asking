package com.example.ekyc.viewmodel

import android.app.Application
import android.nfc.Tag
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.ekyc.nfc.ChipData
import com.example.ekyc.nfc.NFCReader
import com.example.ekyc.security.SecureStorage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.jmrtd.BACKey

/**
 * ViewModel for eKYC flow
 * Orchestrates NFC reading, OCR scanning, and secure storage
 */
class EKYCViewModel(application: Application) : AndroidViewModel(application) {

    private val secureStorage = SecureStorage(application)
    
    private val _uiState = MutableStateFlow<EKYCUiState>(EKYCUiState.Initial)
    val uiState: StateFlow<EKYCUiState> = _uiState.asStateFlow()

    private val _mrzData = MutableStateFlow<MRZData?>(null)
    val mrzData: StateFlow<MRZData?> = _mrzData.asStateFlow()

    private val _chipData = MutableStateFlow<ChipData?>(null)
    val chipData: StateFlow<ChipData?> = _chipData.asStateFlow()

    /**
     * Process MRZ data from OCR scan
     */
    fun onMRZScanned(mrzData: MRZData) {
        _mrzData.value = mrzData
        _uiState.value = EKYCUiState.MRZScanned(mrzData)
    }

    /**
     * Start NFC reading with scanned MRZ data
     */
    fun readNFCChip(nfcReader: NFCReader, tag: Tag) {
        val mrz = _mrzData.value
        if (mrz == null) {
            _uiState.value = EKYCUiState.Error("Please scan MRZ first")
            return
        }

        viewModelScope.launch {
            _uiState.value = EKYCUiState.ReadingNFC

            // Create BAC key from MRZ
            val bacKey = BACKey(
                mrz.documentNumber,
                mrz.dateOfBirth,
                mrz.dateOfExpiry
            )

            val result = nfcReader.readChipData(tag, bacKey)
            
            result.onSuccess { data ->
                _chipData.value = data
                
                // Verify MRZ matches chip data
                if (verifyDataConsistency(mrz, data)) {
                    // Securely store sensitive data
                    secureStorage.storeChipData(data)
                    _uiState.value = EKYCUiState.Success(data)
                } else {
                    _uiState.value = EKYCUiState.Error("Data mismatch between MRZ and chip")
                }
            }.onFailure { error ->
                _uiState.value = EKYCUiState.Error(error.message ?: "NFC read failed")
            }
        }
    }

    /**
     * Verify consistency between scanned MRZ and chip data
     */
    private fun verifyDataConsistency(mrz: MRZData, chip: ChipData): Boolean {
        return mrz.documentNumber == chip.documentNumber &&
               mrz.dateOfBirth == chip.dateOfBirth &&
               mrz.dateOfExpiry == chip.dateOfExpiry
    }

    /**
     * Submit eKYC data to backend
     */
    fun submitEKYC() {
        val chip = _chipData.value
        if (chip == null) {
            _uiState.value = EKYCUiState.Error("No chip data available")
            return
        }

        viewModelScope.launch {
            _uiState.value = EKYCUiState.Submitting

            try {
                // TODO: Implement actual API call with mutual TLS
                // val response = ekycRepository.submit(chip)
                
                // Clear sensitive data after submission
                clearSensitiveData()
                
                _uiState.value = EKYCUiState.Submitted
            } catch (e: Exception) {
                _uiState.value = EKYCUiState.Error(e.message ?: "Submission failed")
            }
        }
    }

    /**
     * Clear all sensitive data from memory and storage
     */
    private fun clearSensitiveData() {
        _mrzData.value = null
        _chipData.value = null
        secureStorage.clearAll()
    }

    /**
     * Reset to initial state
     */
    fun reset() {
        clearSensitiveData()
        _uiState.value = EKYCUiState.Initial
    }

    override fun onCleared() {
        super.onCleared()
        clearSensitiveData()
    }
}

/**
 * UI States for eKYC flow
 */
sealed class EKYCUiState {
    object Initial : EKYCUiState()
    object ScanningMRZ : EKYCUiState()
    data class MRZScanned(val data: MRZData) : EKYCUiState()
    object ReadingNFC : EKYCUiState()
    data class Success(val chipData: ChipData) : EKYCUiState()
    object Submitting : EKYCUiState()
    object Submitted : EKYCUiState()
    data class Error(val message: String) : EKYCUiState()
}

/**
 * MRZ data from OCR scan
 */
data class MRZData(
    val documentNumber: String,
    val dateOfBirth: String,
    val dateOfExpiry: String,
    val firstName: String,
    val lastName: String
)
