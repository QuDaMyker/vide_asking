import Foundation
import Amplify
import AWSS3StoragePlugin
import Combine

/// AWS S3 Storage Manager for SwiftUI
/// Handles file uploads, downloads, and management in Amazon S3
@MainActor
class S3Manager: ObservableObject {
    static let shared = S3Manager()
    
    @Published var uploadProgress: [String: Double] = [:]
    @Published var downloadProgress: [String: Double] = [:]
    
    private var uploadTasks: [String: Task<String, Error>] = [:]
    private var downloadTasks: [String: Task<URL, Error>] = [:]
    
    private init() {}
    
    /// Upload file to S3
    func uploadFile(
        from url: URL,
        key: String,
        accessLevel: StorageAccessLevel = .guest,
        metadata: [String: String] = [:],
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> String {
        let options = StorageUploadFileRequest.Options(
            accessLevel: accessLevel,
            metadata: metadata
        )
        
        let uploadTask = Amplify.Storage.uploadFile(
            key: key,
            local: url,
            options: options
        )
        
        // Monitor progress
        Task {
            for await progress in await uploadTask.progress {
                let fractionCompleted = progress.fractionCompleted
                uploadProgress[key] = fractionCompleted
                onProgress?(fractionCompleted)
            }
        }
        
        let uploadedKey = try await uploadTask.value
        uploadProgress.removeValue(forKey: key)
        
        print("Upload successful: \(uploadedKey)")
        return uploadedKey
    }
    
    /// Upload data to S3
    func uploadData(
        _ data: Data,
        key: String,
        accessLevel: StorageAccessLevel = .guest,
        contentType: String? = nil,
        metadata: [String: String] = [:],
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> String {
        var options = StorageUploadDataRequest.Options(
            accessLevel: accessLevel,
            metadata: metadata
        )
        
        if let contentType = contentType {
            options.contentType = contentType
        }
        
        let uploadTask = Amplify.Storage.uploadData(
            key: key,
            data: data,
            options: options
        )
        
        // Monitor progress
        Task {
            for await progress in await uploadTask.progress {
                let fractionCompleted = progress.fractionCompleted
                uploadProgress[key] = fractionCompleted
                onProgress?(fractionCompleted)
            }
        }
        
        let uploadedKey = try await uploadTask.value
        uploadProgress.removeValue(forKey: key)
        
        return uploadedKey
    }
    
    /// Upload file with automatic retry
    func uploadFileWithRetry(
        from url: URL,
        key: String,
        maxRetries: Int = 3,
        accessLevel: StorageAccessLevel = .guest,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> String {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await uploadFile(
                    from: url,
                    key: key,
                    accessLevel: accessLevel,
                    onProgress: onProgress
                )
            } catch {
                lastError = error
                
                if attempt < maxRetries - 1 {
                    // Exponential backoff
                    let delay = UInt64((attempt + 1) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delay)
                    print("Retrying upload (attempt \(attempt + 1))...")
                }
            }
        }
        
        throw lastError ?? StorageError.unknown("Upload failed after \(maxRetries) attempts")
    }
    
    /// Download file from S3
    func downloadFile(
        key: String,
        to localURL: URL,
        accessLevel: StorageAccessLevel = .guest,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let options = StorageDownloadFileRequest.Options(
            accessLevel: accessLevel
        )
        
        let downloadTask = Amplify.Storage.downloadFile(
            key: key,
            local: localURL,
            options: options
        )
        
        // Monitor progress
        Task {
            for await progress in await downloadTask.progress {
                let fractionCompleted = progress.fractionCompleted
                downloadProgress[key] = fractionCompleted
                onProgress?(fractionCompleted)
            }
        }
        
        try await downloadTask.value
        downloadProgress.removeValue(forKey: key)
        
        print("Download successful: \(localURL.path)")
        return localURL
    }
    
    /// Download data from S3
    func downloadData(
        key: String,
        accessLevel: StorageAccessLevel = .guest,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> Data {
        let options = StorageDownloadDataRequest.Options(
            accessLevel: accessLevel
        )
        
        let downloadTask = Amplify.Storage.downloadData(
            key: key,
            options: options
        )
        
        // Monitor progress
        Task {
            for await progress in await downloadTask.progress {
                let fractionCompleted = progress.fractionCompleted
                downloadProgress[key] = fractionCompleted
                onProgress?(fractionCompleted)
            }
        }
        
        let data = try await downloadTask.value
        downloadProgress.removeValue(forKey: key)
        
        return data
    }
    
    /// Get presigned URL for file
    func getURL(
        key: String,
        accessLevel: StorageAccessLevel = .guest,
        expires: Int = 3600
    ) async throws -> URL {
        let options = StorageGetURLRequest.Options(
            accessLevel: accessLevel,
            expires: expires
        )
        
        return try await Amplify.Storage.getURL(
            key: key,
            options: options
        )
    }
    
    /// List files in S3 bucket
    func listFiles(
        path: String? = nil,
        accessLevel: StorageAccessLevel = .guest
    ) async throws -> [StorageListResult.Item] {
        let options = StorageListRequest.Options(
            accessLevel: accessLevel,
            path: path
        )
        
        let result = try await Amplify.Storage.list(options: options)
        return result.items
    }
    
    /// Delete file from S3
    func deleteFile(
        key: String,
        accessLevel: StorageAccessLevel = .guest
    ) async throws {
        let options = StorageRemoveRequest.Options(
            accessLevel: accessLevel
        )
        
        let removedKey = try await Amplify.Storage.remove(
            key: key,
            options: options
        )
        
        print("File deleted: \(removedKey)")
    }
    
    /// Get file properties
    func getProperties(
        key: String,
        accessLevel: StorageAccessLevel = .guest
    ) async throws -> StorageGetPropertiesResult {
        let options = StorageGetPropertiesRequest.Options(
            accessLevel: accessLevel
        )
        
        return try await Amplify.Storage.getProperties(
            key: key,
            options: options
        )
    }
    
    /// Cancel upload operation
    func cancelUpload(key: String) {
        uploadTasks[key]?.cancel()
        uploadTasks.removeValue(forKey: key)
        uploadProgress.removeValue(forKey: key)
    }
    
    /// Cancel download operation
    func cancelDownload(key: String) {
        downloadTasks[key]?.cancel()
        downloadTasks.removeValue(forKey: key)
        downloadProgress.removeValue(forKey: key)
    }
    
    /// Upload image with compression
    func uploadImage(
        _ image: UIImage,
        key: String,
        compressionQuality: CGFloat = 0.8,
        accessLevel: StorageAccessLevel = .guest,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            throw StorageError.unknown("Failed to convert image to data")
        }
        
        return try await uploadData(
            imageData,
            key: key,
            accessLevel: accessLevel,
            contentType: "image/jpeg",
            onProgress: onProgress
        )
    }
}

/// Storage item model
struct StorageItem: Identifiable {
    let id: String
    let key: String
    let size: Int64?
    let lastModified: Date?
    
    init(from item: StorageListResult.Item) {
        self.id = item.key
        self.key = item.key
        self.size = item.size
        self.lastModified = item.lastModified
    }
}

#if canImport(UIKit)
import UIKit
#endif
