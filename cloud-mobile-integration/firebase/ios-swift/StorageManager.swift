import Foundation
import FirebaseStorage
import UIKit
import Combine

/// Firebase Storage Manager for SwiftUI
/// Handles file uploads, downloads, and management
@MainActor
class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    private let storage = Storage.storage()
    @Published var uploadProgress: [String: Double] = [:]
    @Published var downloadProgress: [String: Double] = [:]
    
    private var uploadTasks: [String: StorageUploadTask] = [:]
    private var downloadTasks: [String: StorageDownloadTask] = [:]
    
    private init() {}
    
    /// Get storage reference
    func getReference(path: String) -> StorageReference {
        return storage.reference().child(path)
    }
    
    // MARK: - Upload Operations
    
    /// Upload file
    func uploadFile(
        localURL: URL,
        storagePath: String,
        metadata: StorageMetadata? = nil
    ) async throws -> String {
        let ref = storage.reference().child(storagePath)
        let uploadTask = ref.putFile(from: localURL, metadata: metadata)
        
        // Store task for potential cancellation
        uploadTasks[storagePath] = uploadTask
        
        // Observe upload progress
        for await progress in uploadTask.progress {
            uploadProgress[storagePath] = progress.fractionCompleted
        }
        
        // Wait for completion
        _ = try await uploadTask
        uploadTasks.removeValue(forKey: storagePath)
        uploadProgress.removeValue(forKey: storagePath)
        
        // Get download URL
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
    }
    
    /// Upload data
    func uploadData(
        data: Data,
        storagePath: String,
        metadata: StorageMetadata? = nil
    ) async throws -> String {
        let ref = storage.reference().child(storagePath)
        let uploadTask = ref.putData(data, metadata: metadata)
        
        uploadTasks[storagePath] = uploadTask
        
        for await progress in uploadTask.progress {
            uploadProgress[storagePath] = progress.fractionCompleted
        }
        
        _ = try await uploadTask
        uploadTasks.removeValue(forKey: storagePath)
        uploadProgress.removeValue(forKey: storagePath)
        
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
    }
    
    /// Upload image
    func uploadImage(
        image: UIImage,
        storagePath: String,
        compressionQuality: CGFloat = 0.8
    ) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            throw NSError(
                domain: "StorageManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"]
            )
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        return try await uploadData(
            data: imageData,
            storagePath: storagePath,
            metadata: metadata
        )
    }
    
    /// Upload with retry
    func uploadWithRetry(
        localURL: URL,
        storagePath: String,
        maxRetries: Int = 3
    ) async throws -> String {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await uploadFile(
                    localURL: localURL,
                    storagePath: storagePath
                )
            } catch {
                lastError = error
                print("Upload attempt \(attempt + 1) failed: \(error)")
                
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                }
            }
        }
        
        throw lastError ?? NSError(
            domain: "StorageManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Upload failed after \(maxRetries) attempts"]
        )
    }
    
    // MARK: - Download Operations
    
    /// Download file
    func downloadFile(
        storagePath: String,
        destinationURL: URL
    ) async throws {
        let ref = storage.reference().child(storagePath)
        let downloadTask = ref.write(toFile: destinationURL)
        
        downloadTasks[storagePath] = downloadTask
        
        for await progress in downloadTask.progress {
            downloadProgress[storagePath] = progress.fractionCompleted
        }
        
        _ = try await downloadTask
        downloadTasks.removeValue(forKey: storagePath)
        downloadProgress.removeValue(forKey: storagePath)
    }
    
    /// Download data
    func downloadData(
        storagePath: String,
        maxSize: Int64 = 10 * 1024 * 1024 // 10MB
    ) async throws -> Data {
        let ref = storage.reference().child(storagePath)
        return try await ref.data(maxSize: maxSize)
    }
    
    /// Download image
    func downloadImage(
        storagePath: String
    ) async throws -> UIImage {
        let data = try await downloadData(storagePath: storagePath)
        
        guard let image = UIImage(data: data) else {
            throw NSError(
                domain: "StorageManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"]
            )
        }
        
        return image
    }
    
    // MARK: - URL Operations
    
    /// Get download URL
    func getDownloadURL(storagePath: String) async throws -> String {
        let ref = storage.reference().child(storagePath)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
    
    // MARK: - Metadata Operations
    
    /// Get metadata
    func getMetadata(storagePath: String) async throws -> StorageMetadata {
        let ref = storage.reference().child(storagePath)
        return try await ref.getMetadata()
    }
    
    /// Update metadata
    func updateMetadata(
        storagePath: String,
        metadata: StorageMetadata
    ) async throws -> StorageMetadata {
        let ref = storage.reference().child(storagePath)
        return try await ref.updateMetadata(metadata)
    }
    
    /// Set custom metadata
    func setCustomMetadata(
        storagePath: String,
        customMetadata: [String: String]
    ) async throws {
        let metadata = StorageMetadata()
        metadata.customMetadata = customMetadata
        
        let ref = storage.reference().child(storagePath)
        _ = try await ref.updateMetadata(metadata)
    }
    
    // MARK: - Delete Operations
    
    /// Delete file
    func deleteFile(storagePath: String) async throws {
        let ref = storage.reference().child(storagePath)
        try await ref.delete()
    }
    
    /// Delete multiple files
    func deleteFiles(storagePaths: [String]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for path in storagePaths {
                group.addTask {
                    try await self.deleteFile(storagePath: path)
                }
            }
            
            try await group.waitForAll()
        }
    }
    
    // MARK: - List Operations
    
    /// List files in directory
    func listFiles(
        path: String,
        maxResults: Int = 100
    ) async throws -> [StorageReference] {
        let ref = storage.reference().child(path)
        let result = try await ref.list(maxResults: Int64(maxResults))
        return result.items
    }
    
    /// List all files in directory
    func listAllFiles(path: String) async throws -> [StorageReference] {
        let ref = storage.reference().child(path)
        let result = try await ref.listAll()
        return result.items
    }
    
    /// List with pagination
    func listWithPagination(
        path: String,
        pageToken: String? = nil,
        maxResults: Int = 100
    ) async throws -> (items: [StorageReference], nextPageToken: String?) {
        let ref = storage.reference().child(path)
        
        let result: StorageListResult
        if let pageToken = pageToken {
            result = try await ref.list(maxResults: Int64(maxResults), pageToken: pageToken)
        } else {
            result = try await ref.list(maxResults: Int64(maxResults))
        }
        
        return (result.items, result.pageToken)
    }
    
    // MARK: - Task Management
    
    /// Cancel upload
    func cancelUpload(storagePath: String) {
        uploadTasks[storagePath]?.cancel()
        uploadTasks.removeValue(forKey: storagePath)
        uploadProgress.removeValue(forKey: storagePath)
    }
    
    /// Cancel download
    func cancelDownload(storagePath: String) {
        downloadTasks[storagePath]?.cancel()
        downloadTasks.removeValue(forKey: storagePath)
        downloadProgress.removeValue(forKey: storagePath)
    }
    
    /// Pause upload
    func pauseUpload(storagePath: String) {
        uploadTasks[storagePath]?.pause()
    }
    
    /// Resume upload
    func resumeUpload(storagePath: String) {
        uploadTasks[storagePath]?.resume()
    }
    
    /// Cancel all uploads
    func cancelAllUploads() {
        uploadTasks.values.forEach { $0.cancel() }
        uploadTasks.removeAll()
        uploadProgress.removeAll()
    }
    
    /// Cancel all downloads
    func cancelAllDownloads() {
        downloadTasks.values.forEach { $0.cancel() }
        downloadTasks.removeAll()
        downloadProgress.removeAll()
    }
    
    // MARK: - Helper Methods
    
    /// Check if file exists
    func fileExists(storagePath: String) async throws -> Bool {
        do {
            _ = try await getMetadata(storagePath: storagePath)
            return true
        } catch {
            let nsError = error as NSError
            if nsError.domain == StorageErrorDomain,
               nsError.code == StorageErrorCode.objectNotFound.rawValue {
                return false
            }
            throw error
        }
    }
    
    /// Get file size
    func getFileSize(storagePath: String) async throws -> Int64 {
        let metadata = try await getMetadata(storagePath: storagePath)
        return metadata.size
    }
    
    /// Generate unique path
    func generateUniquePath(
        directory: String,
        fileName: String,
        userId: String? = nil
    ) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString
        
        if let userId = userId {
            return "\(directory)/\(userId)/\(timestamp)_\(uuid)_\(fileName)"
        } else {
            return "\(directory)/\(timestamp)_\(uuid)_\(fileName)"
        }
    }
}

// MARK: - Progress Extensions

extension StorageUploadTask {
    var progress: AsyncStream<Progress> {
        AsyncStream { continuation in
            let observer = observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    continuation.yield(progress)
                }
            }
            
            _ = observe(.success) { _ in
                continuation.finish()
            }
            
            _ = observe(.failure) { _ in
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                observer.remove()
            }
        }
    }
}

extension StorageDownloadTask {
    var progress: AsyncStream<Progress> {
        AsyncStream { continuation in
            let observer = observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    continuation.yield(progress)
                }
            }
            
            _ = observe(.success) { _ in
                continuation.finish()
            }
            
            _ = observe(.failure) { _ in
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                observer.remove()
            }
        }
    }
}

/// Storage item model
struct StorageItem: Identifiable, Codable {
    let id: String
    let name: String
    let path: String
    let url: String?
    let size: Int64
    let contentType: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    init(reference: StorageReference, metadata: StorageMetadata? = nil) {
        self.id = reference.fullPath
        self.name = reference.name
        self.path = reference.fullPath
        self.url = nil
        self.size = metadata?.size ?? 0
        self.contentType = metadata?.contentType
        self.createdAt = metadata?.timeCreated
        self.updatedAt = metadata?.updated
    }
}
