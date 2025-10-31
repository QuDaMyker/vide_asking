package com.example.ekyc.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Nfc
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.ekyc.nfc.NFCReader
import com.example.ekyc.nfc.NFCState
import com.example.ekyc.viewmodel.EKYCUiState
import com.example.ekyc.viewmodel.EKYCViewModel

/**
 * Main eKYC screen with Jetpack Compose
 * Implements material design 3 with accessibility support
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EKYCScreen(
    viewModel: EKYCViewModel = viewModel(),
    nfcReader: NFCReader,
    onComplete: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val nfcState by nfcReader.nfcState.collectAsStateWithLifecycle()
    val readProgress by nfcReader.readProgress.collectAsStateWithLifecycle()

    // Handle NFC tag detection
    LaunchedEffect(nfcState) {
        if (nfcState is NFCState.TagDetected) {
            val tag = (nfcState as NFCState.TagDetected).tag
            viewModel.readNFCChip(nfcReader, tag)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("eKYC Verification") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Status indicator
            StatusCard(uiState = uiState, nfcState = nfcState)

            Spacer(modifier = Modifier.height(16.dp))

            // Progress indicator for NFC reading
            AnimatedVisibility(visible = uiState is EKYCUiState.ReadingNFC) {
                NFCReadingProgress(progress = readProgress)
            }

            // Main content based on state
            when (uiState) {
                is EKYCUiState.Initial -> {
                    InitialContent(
                        onStartScan = { /* Start camera for MRZ scan */ }
                    )
                }
                is EKYCUiState.MRZScanned -> {
                    MRZScannedContent(
                        nfcAvailable = nfcReader.isNFCAvailable(),
                        nfcEnabled = nfcReader.isNFCEnabled()
                    )
                }
                is EKYCUiState.Success -> {
                    val chipData = (uiState as EKYCUiState.Success).chipData
                    SuccessContent(
                        chipData = chipData,
                        onSubmit = { viewModel.submitEKYC() }
                    )
                }
                is EKYCUiState.Submitted -> {
                    SubmittedContent(onComplete = onComplete)
                }
                is EKYCUiState.Error -> {
                    val message = (uiState as EKYCUiState.Error).message
                    ErrorContent(
                        message = message,
                        onRetry = { viewModel.reset() }
                    )
                }
                else -> {}
            }
        }
    }
}

@Composable
private fun StatusCard(
    uiState: EKYCUiState,
    nfcState: NFCState
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = when {
                uiState is EKYCUiState.Success -> MaterialTheme.colorScheme.primaryContainer
                uiState is EKYCUiState.Error -> MaterialTheme.colorScheme.errorContainer
                else -> MaterialTheme.colorScheme.surfaceVariant
            }
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = when {
                    uiState is EKYCUiState.Success -> Icons.Default.CheckCircle
                    uiState is EKYCUiState.Error -> Icons.Default.Error
                    else -> Icons.Default.Nfc
                },
                contentDescription = null,
                modifier = Modifier.size(32.dp)
            )
            Column {
                Text(
                    text = getStatusTitle(uiState, nfcState),
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = getStatusMessage(uiState, nfcState),
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}

@Composable
private fun NFCReadingProgress(progress: Int) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        LinearProgressIndicator(
            progress = progress / 100f,
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Reading chip data... $progress%",
            style = MaterialTheme.typography.bodyMedium
        )
    }
}

@Composable
private fun InitialContent(onStartScan: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Ready to start eKYC verification",
            style = MaterialTheme.typography.headlineSmall,
            textAlign = TextAlign.Center
        )
        Text(
            text = "First, we'll scan the MRZ code on your ID card",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center
        )
        Button(
            onClick = onStartScan,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Start MRZ Scan")
        }
    }
}

@Composable
private fun MRZScannedContent(
    nfcAvailable: Boolean,
    nfcEnabled: Boolean
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        if (!nfcAvailable) {
            Text(
                text = "NFC not available on this device",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.error
            )
        } else if (!nfcEnabled) {
            Text(
                text = "Please enable NFC in settings",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.error
            )
        } else {
            Icon(
                imageVector = Icons.Default.Nfc,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.primary
            )
            Text(
                text = "Hold your ID card near the back of your phone",
                style = MaterialTheme.typography.headlineSmall,
                textAlign = TextAlign.Center
            )
            Text(
                text = "Keep the card steady until reading is complete",
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun SuccessContent(
    chipData: com.example.ekyc.nfc.ChipData,
    onSubmit: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.CheckCircle,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        Text(
            text = "Verification Successful",
            style = MaterialTheme.typography.headlineSmall
        )
        Card(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Name: ${chipData.lastName} ${chipData.firstName}")
                Text("Document: ${chipData.documentNumber}")
                Text("DOB: ${chipData.dateOfBirth}")
                Text("Expiry: ${chipData.dateOfExpiry}")
            }
        }
        Button(
            onClick = onSubmit,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Submit Verification")
        }
    }
}

@Composable
private fun SubmittedContent(onComplete: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "eKYC completed successfully",
            style = MaterialTheme.typography.headlineSmall
        )
        Button(onClick = onComplete) {
            Text("Continue")
        }
    }
}

@Composable
private fun ErrorContent(
    message: String,
    onRetry: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Error",
            style = MaterialTheme.typography.headlineSmall,
            color = MaterialTheme.colorScheme.error
        )
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center
        )
        Button(onClick = onRetry) {
            Text("Retry")
        }
    }
}

private fun getStatusTitle(uiState: EKYCUiState, nfcState: NFCState): String {
    return when {
        uiState is EKYCUiState.Success -> "Verified"
        uiState is EKYCUiState.Error -> "Error"
        uiState is EKYCUiState.ReadingNFC -> "Reading NFC"
        nfcState is NFCState.Scanning -> "Ready to scan"
        else -> "In Progress"
    }
}

private fun getStatusMessage(uiState: EKYCUiState, nfcState: NFCState): String {
    return when {
        uiState is EKYCUiState.Success -> "ID verification completed"
        uiState is EKYCUiState.ReadingNFC -> "Reading chip data..."
        nfcState is NFCState.Scanning -> "Hold card near device"
        else -> "Follow the instructions"
    }
}
