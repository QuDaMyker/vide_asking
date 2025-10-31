import Foundation
import Combine

/**
 * ViewModel for eKYC flow
 * Orchestrates NFC reading, data verification, and submission
 */
@MainActor
class EKYCViewModel: ObservableObject {
    
    @Published var state: EKYCState = .initial
    @Published var mrzData: MRZData?
    @Published var chipData: ChipData?
    
    private let secureStorage = SecureStorage.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /**
     * Process scanned MRZ data
     */
    func onMRZScanned(_ data: MRZData) {
        self.mrzData = data
        self.state = .mrzScanned(data)
    }
    
    /**
     * Process chip data after NFC read
     */
    func onChipDataRead(_ data: ChipData) async {
        guard let mrz = mrzData else {
            state = .error("No MRZ data available")
            return
        }
        
        // Verify data consistency
        if verifyDataConsistency(mrz: mrz, chip: data) {
            self.chipData = data
            
            // Store securely
            do {
                try await secureStorage.storeChipData(data)
                state = .success(data)
            } catch {
                state = .error("Failed to secure data: \(error.localizedDescription)")
            }
        } else {
            state = .error("Data mismatch between MRZ and chip")
        }
    }
    
    /**
     * Submit eKYC data to backend
     */
    func submitEKYC() {
        guard let chip = chipData else {
            state = .error("No chip data available")
            return
        }
        
        state = .submitting
        
        Task {
            do {
                // TODO: Implement actual API call with mutual TLS
                try await submitToBackend(chip)
                
                // Clear sensitive data
                await clearSensitiveData()
                
                state = .submitted
            } catch {
                state = .error("Submission failed: \(error.localizedDescription)")
            }
        }
    }
    
    /**
     * Reset to initial state
     */
    func reset() {
        Task {
            await clearSensitiveData()
            state = .initial
        }
    }
    
    // MARK: - Private Methods
    
    private func verifyDataConsistency(mrz: MRZData, chip: ChipData) -> Bool {
        return mrz.documentNumber == chip.documentNumber &&
               mrz.dateOfBirth == chip.dateOfBirth &&
               mrz.dateOfExpiry == chip.dateOfExpiry
    }
    
    private func submitToBackend(_ data: ChipData) async throws {
        // TODO: Implement actual submission
        // This should include:
        // - Mutual TLS connection
        // - Certificate pinning
        // - Request signing
        // - Retry logic with exponential backoff
        
        try await Task.sleep(nanoseconds: 2_000_000_000) // Simulate network delay
    }
    
    private func clearSensitiveData() async {
        mrzData = nil
        chipData = nil
        secureStorage.clearAll()
    }
}

// MARK: - Data Models

enum EKYCState: Equatable {
    case initial
    case scanningMRZ
    case mrzScanned(MRZData)
    case readingNFC
    case success(ChipData)
    case submitting
    case submitted
    case error(String)
    
    static func == (lhs: EKYCState, rhs: EKYCState) -> Bool {
        switch (lhs, rhs) {
        case (.initial, .initial),
             (.scanningMRZ, .scanningMRZ),
             (.readingNFC, .readingNFC),
             (.submitting, .submitting),
             (.submitted, .submitted):
            return true
        case (.mrzScanned(let lData), .mrzScanned(let rData)):
            return lData.documentNumber == rData.documentNumber
        case (.success(let lData), .success(let rData)):
            return lData.documentNumber == rData.documentNumber
        case (.error(let lMsg), .error(let rMsg)):
            return lMsg == rMsg
        default:
            return false
        }
    }
}

struct MRZData {
    let documentNumber: String
    let dateOfBirth: String
    let dateOfExpiry: String
    let firstName: String
    let lastName: String
}
