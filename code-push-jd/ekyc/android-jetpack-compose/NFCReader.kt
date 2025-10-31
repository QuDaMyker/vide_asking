package com.example.ekyc.nfc

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Bundle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import net.sf.scuba.smartcards.CardService
import org.jmrtd.BACKey
import org.jmrtd.PassportService
import org.jmrtd.lds.icao.DG1File
import org.jmrtd.lds.icao.DG2File
import java.io.InputStream

/**
 * NFC Reader for Vietnamese CCCD/C06/VNeID cards
 * Implements ICAO 9303 standards with BAC (Basic Access Control)
 */
class NFCReader(private val activity: Activity) {

    private val nfcAdapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(activity)
    
    private val _nfcState = MutableStateFlow<NFCState>(NFCState.Idle)
    val nfcState: StateFlow<NFCState> = _nfcState.asStateFlow()

    private val _readProgress = MutableStateFlow(0)
    val readProgress: StateFlow<Int> = _readProgress.asStateFlow()

    /**
     * Enable NFC reader mode with lifecycle awareness
     * Call this in onResume()
     */
    fun enableReaderMode() {
        val options = Bundle().apply {
            putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250)
        }
        
        nfcAdapter?.enableReaderMode(
            activity,
            { tag -> handleTag(tag) },
            NfcAdapter.FLAG_READER_NFC_A or 
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
            options
        )
        _nfcState.value = NFCState.Scanning
    }

    /**
     * Disable NFC reader mode
     * Call this in onPause()
     */
    fun disableReaderMode() {
        nfcAdapter?.disableReaderMode(activity)
        _nfcState.value = NFCState.Idle
    }

    /**
     * Read chip data with MRZ key (from OCR scan)
     * @param mrzKey BACKey containing document number, birth date, expiry date
     */
    suspend fun readChipData(tag: Tag, mrzKey: BACKey): Result<ChipData> = 
        withContext(Dispatchers.IO) {
            try {
                _nfcState.value = NFCState.Reading
                _readProgress.value = 0

                val isoDep = IsoDep.get(tag)
                isoDep.timeout = 5000
                isoDep.connect()

                val cardService = CardService.getInstance(isoDep)
                val passportService = PassportService(
                    cardService,
                    PassportService.NORMAL_MAX_TRANCEIVE_LENGTH,
                    PassportService.DEFAULT_MAX_BLOCKSIZE,
                    false,
                    false
                )

                passportService.open()
                _readProgress.value = 20

                // Perform BAC (Basic Access Control)
                passportService.sendSelectApplet(false)
                _readProgress.value = 40
                
                passportService.doBAC(mrzKey)
                _readProgress.value = 60

                // Read DG1 (MRZ data)
                val dg1InputStream: InputStream = passportService.getInputStream(
                    PassportService.EF_DG1
                )
                val dg1File = DG1File(dg1InputStream)
                _readProgress.value = 80

                // Read DG2 (Face image)
                val dg2InputStream: InputStream = passportService.getInputStream(
                    PassportService.EF_DG2
                )
                val dg2File = DG2File(dg2InputStream)
                _readProgress.value = 90

                // Extract data
                val mrzInfo = dg1File.mrzInfo
                val faceInfo = dg2File.faceInfos.firstOrNull()
                val faceImage = faceInfo?.faceImageInfos?.firstOrNull()

                _readProgress.value = 100
                _nfcState.value = NFCState.Success

                Result.success(
                    ChipData(
                        documentNumber = mrzInfo.documentNumber,
                        dateOfBirth = mrzInfo.dateOfBirth,
                        dateOfExpiry = mrzInfo.dateOfExpiry,
                        firstName = mrzInfo.secondaryIdentifier,
                        lastName = mrzInfo.primaryIdentifier,
                        nationality = mrzInfo.nationality,
                        gender = mrzInfo.gender.toString(),
                        faceImage = faceImage?.imageData,
                        verified = true
                    )
                )

            } catch (e: Exception) {
                _nfcState.value = NFCState.Error(e.message ?: "NFC read failed")
                Result.failure(e)
            }
        }

    private fun handleTag(tag: Tag) {
        // Tag detected, notify UI to prepare for reading
        _nfcState.value = NFCState.TagDetected(tag)
    }

    /**
     * Check if device supports NFC
     */
    fun isNFCAvailable(): Boolean = nfcAdapter != null

    /**
     * Check if NFC is enabled
     */
    fun isNFCEnabled(): Boolean = nfcAdapter?.isEnabled == true
}

/**
 * NFC Reading States
 */
sealed class NFCState {
    object Idle : NFCState()
    object Scanning : NFCState()
    data class TagDetected(val tag: Tag) : NFCState()
    object Reading : NFCState()
    object Success : NFCState()
    data class Error(val message: String) : NFCState()
}

/**
 * Chip data model
 */
data class ChipData(
    val documentNumber: String,
    val dateOfBirth: String,
    val dateOfExpiry: String,
    val firstName: String,
    val lastName: String,
    val nationality: String,
    val gender: String,
    val faceImage: ByteArray?,
    val verified: Boolean
)
