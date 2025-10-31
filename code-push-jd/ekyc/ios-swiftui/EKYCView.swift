import SwiftUI
import Combine

/**
 * Main eKYC view with SwiftUI
 * Implements adaptive layout and accessibility
 */
struct EKYCView: View {
    @StateObject private var viewModel = EKYCViewModel()
    @StateObject private var nfcReader = NFCReader()
    @State private var showCamera = false
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Status card
                        statusCard
                        
                        // Progress indicator
                        if viewModel.state == .readingNFC {
                            progressView
                        }
                        
                        // Main content
                        mainContent
                    }
                    .padding()
                }
            }
            .navigationTitle("eKYC Verification")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $showError) {
                Button("Retry") {
                    viewModel.reset()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if case .error(let message) = viewModel.state {
                    Text(message)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView { mrzData in
                    viewModel.onMRZScanned(mrzData)
                    showCamera = false
                }
            }
        }
        .onChange(of: viewModel.state) { state in
            handleStateChange(state)
        }
        .onChange(of: nfcReader.nfcState) { state in
            handleNFCStateChange(state)
        }
    }
    
    // MARK: - View Components
    
    private var statusCard: some View {
        HStack(spacing: 16) {
            statusIcon
                .font(.system(size: 32))
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(statusBackgroundColor)
        .cornerRadius(12)
    }
    
    private var statusIcon: Image {
        switch viewModel.state {
        case .success:
            return Image(systemName: "checkmark.circle.fill")
        case .error:
            return Image(systemName: "xmark.circle.fill")
        case .readingNFC:
            return Image(systemName: "wave.3.right")
        default:
            return Image(systemName: "antenna.radiowaves.left.and.right")
        }
    }
    
    private var statusColor: Color {
        switch viewModel.state {
        case .success:
            return .green
        case .error:
            return .red
        default:
            return .blue
        }
    }
    
    private var statusBackgroundColor: Color {
        switch viewModel.state {
        case .success:
            return Color.green.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        default:
            return Color.blue.opacity(0.1)
        }
    }
    
    private var statusTitle: String {
        switch viewModel.state {
        case .initial:
            return "Ready"
        case .scanningMRZ:
            return "Scanning"
        case .mrzScanned:
            return "MRZ Scanned"
        case .readingNFC:
            return "Reading NFC"
        case .success:
            return "Verified"
        case .submitting:
            return "Submitting"
        case .submitted:
            return "Complete"
        case .error:
            return "Error"
        }
    }
    
    private var statusMessage: String {
        switch viewModel.state {
        case .initial:
            return "Ready to start verification"
        case .scanningMRZ:
            return "Scanning ID card MRZ"
        case .mrzScanned:
            return "Prepare to scan NFC chip"
        case .readingNFC:
            return "Reading chip data..."
        case .success:
            return "Verification successful"
        case .submitting:
            return "Submitting data..."
        case .submitted:
            return "eKYC completed"
        case .error(let msg):
            return msg
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 12) {
            ProgressView(value: nfcReader.readProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            Text("Reading chip data... \(Int(nfcReader.readProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.state {
        case .initial:
            initialView
        case .mrzScanned:
            nfcScanView
        case .success:
            successView
        case .submitted:
            completedView
        default:
            EmptyView()
        }
    }
    
    private var initialView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Ready to Start")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("First, we'll scan the MRZ code on your ID card")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.state = .scanningMRZ
                showCamera = true
            }) {
                Label("Start MRZ Scan", systemImage: "camera")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var nfcScanView: some View {
        VStack(spacing: 20) {
            if !nfcReader.isNFCAvailable() {
                errorMessageView(
                    icon: "xmark.circle",
                    message: "NFC not available on this device"
                )
            } else {
                Image(systemName: "wave.3.right.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                    .symbolEffect(.variableColor.iterative)
                
                Text("Hold ID Near iPhone")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Place your ID card on the back of your iPhone and keep it steady")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    Task {
                        await startNFCReading()
                    }
                }) {
                    Label("Start NFC Reading", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Verification Successful")
                .font(.title2)
                .fontWeight(.bold)
            
            if let chipData = viewModel.chipData {
                VStack(alignment: .leading, spacing: 12) {
                    dataRow(label: "Name", value: "\(chipData.lastName) \(chipData.firstName)")
                    dataRow(label: "Document", value: chipData.documentNumber)
                    dataRow(label: "Date of Birth", value: chipData.dateOfBirth)
                    dataRow(label: "Expiry Date", value: chipData.dateOfExpiry)
                    dataRow(label: "Nationality", value: chipData.nationality)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            Button(action: {
                viewModel.submitEKYC()
            }) {
                Label("Submit Verification", systemImage: "paperplane")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("eKYC Completed")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your identity has been successfully verified")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                // Handle completion
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Helper Views
    
    private func errorMessageView(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func dataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleStateChange(_ state: EKYCState) {
        if case .error = state {
            showError = true
        }
    }
    
    private func handleNFCStateChange(_ state: NFCState) {
        // Handle NFC state changes if needed
    }
    
    private func startNFCReading() async {
        guard let mrzData = viewModel.mrzData else { return }
        
        let mrzKey = MRZKey(
            documentNumber: mrzData.documentNumber,
            dateOfBirth: mrzData.dateOfBirth,
            dateOfExpiry: mrzData.dateOfExpiry
        )
        
        do {
            viewModel.state = .readingNFC
            let chipData = try await nfcReader.startReading(with: mrzKey)
            await viewModel.onChipDataRead(chipData)
        } catch {
            viewModel.state = .error(error.localizedDescription)
        }
    }
}

// MARK: - Camera View Placeholder

struct CameraView: View {
    let onMRZScanned: (MRZData) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Camera view for MRZ scanning")
                Text("Use Vision framework + AVFoundation")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Simulate Scan") {
                    // Simulate MRZ scan for demo
                    let mockData = MRZData(
                        documentNumber: "C06123456",
                        dateOfBirth: "900101",
                        dateOfExpiry: "300101",
                        firstName: "NGUYEN",
                        lastName: "VAN A"
                    )
                    onMRZScanned(mockData)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .navigationTitle("Scan MRZ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct EKYCView_Previews: PreviewProvider {
    static var previews: some View {
        EKYCView()
    }
}
