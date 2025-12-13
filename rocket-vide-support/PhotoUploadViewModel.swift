//
//  PhotoUploadViewModel.swift
//  Rocket
//
//  Created by AI Assistant on 11/18/25.
//

import Foundation
import UIKit

// MARK: - Photo Upload Response Model

struct PhotoUploadResponse: Decodable {
    let photoId: String
    let url: String
    let thumbnailUrl: String?
    let uploadedAt: String
    
    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case url
        case thumbnailUrl = "thumbnail_url"
        case uploadedAt = "uploaded_at"
    }
}

// MARK: - View Model for Photo Upload

// MARK: - Upload Error Type

enum UploadErrorType {
    case networkError
    case serverError(statusCode: Int)
    case validationError
    case unauthorized
    case fileTooLarge
    case invalidFormat
    case unknown
    
    var userFriendlyMessage: String {
        switch self {
        case .networkError:
            return "Network connection failed. Please check your internet."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .validationError:
            return "Invalid image or data. Please check and try again."
        case .unauthorized:
            return "Authentication required. Please log in."
        case .fileTooLarge:
            return "Image is too large. Please select a smaller image."
        case .invalidFormat:
            return "Invalid image format. Please use JPEG or PNG."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
}

@MainActor
final class PhotoUploadViewModel: ObservableObject {
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var errorType: UploadErrorType?
    @Published var uploadedPhotoURL: String?
    @Published var statusCode: Int?
    
    private let apiClient = APIClient.shared
    
    /// Upload a photo with caption and auto-generated metadata
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - photoId: The photo ID from your API
    ///   - caption: Optional caption for the photo
    func uploadPhoto(
        _ image: UIImage,
        photoId: String,
        caption: String? = nil
    ) async {
        isUploading = true
        errorMessage = nil
        errorType = nil
        uploadedPhotoURL = nil
        statusCode = nil
        
        defer { isUploading = false }
        
        do {
            // Generate metadata from image
            let metadata = image.generateMetadata(
                filename: "photo_\(Date().timeIntervalSince1970).jpg",
                uploadSource: "ios_rocket_app"
            )
            
            // Create upload request
            let request = PhotoUploadRequest(
                image: image,
                caption: caption,
                metadata: metadata,
                compressionQuality: 0.8
            )
            
            // Upload to API (using direct method to bypass interceptor)
            let response: APIResponse<PhotoUploadResponse> = try await apiClient.uploadImageDirect(
                "/api/v1/photos",
                request: request,
                pathParams: [photoId],
                responseType: PhotoUploadResponse.self
            )
            
            statusCode = response.statusCode
            
            if response.isSuccess, let data = response.data {
                uploadedPhotoURL = data.url
                print("✅ Photo uploaded successfully: \(data.url)")
            } else {
                handleServerError(response: response)
            }
            
        } catch {
            handleNetworkError(error)
        }
    }
    
    /// Upload photo with custom metadata
    func uploadPhotoWithMetadata(
        _ image: UIImage,
        photoId: String,
        caption: String?,
        metadata: PhotoMetadata
    ) async {
        isUploading = true
        errorMessage = nil
        errorType = nil
        uploadedPhotoURL = nil
        statusCode = nil
        
        defer { isUploading = false }
        
        do {
            let request = PhotoUploadRequest(
                image: image,
                caption: caption,
                metadata: metadata,
                compressionQuality: 0.8
            )
            
            let response: APIResponse<PhotoUploadResponse> = try await apiClient.uploadImage(
                "/api/v1/photos",
                request: request,
                pathParams: [photoId],
                responseType: PhotoUploadResponse.self
            )
            
            statusCode = response.statusCode
            
            if response.isSuccess, let data = response.data {
                uploadedPhotoURL = data.url
                print("✅ Photo uploaded successfully: \(data.url)")
            } else {
                handleServerError(response: response)
            }
            
        } catch {
            handleNetworkError(error)
        }
    }
    
    /// Simple upload without response handling (fire and forget)
    func uploadPhotoSimple(
        _ image: UIImage,
        photoId: String,
        caption: String? = nil
    ) async {
        isUploading = true
        errorMessage = nil
        errorType = nil
        statusCode = nil
        
        defer { isUploading = false }
        
        do {
            let metadata = image.generateMetadata()
            let request = PhotoUploadRequest(
                image: image,
                caption: caption,
                metadata: metadata
            )
            
            try await apiClient.uploadImage(
                "/api/v1/photos",
                request: request,
                pathParams: [photoId]
            )
            
            print("✅ Photo uploaded successfully")
            
        } catch {
            handleNetworkError(error)
        }
    }
    
    // MARK: - Error Handling Helpers
    
    private func handleServerError<T>(response: APIResponse<T>) {
        let code = response.statusCode
        statusCode = code
        
        // Categorize error by status code
        switch code {
        case 400:
            errorType = .validationError
            errorMessage = response.message ?? "Invalid request. Please check your data."
            
        case 401, 403:
            errorType = .unauthorized
            errorMessage = response.message ?? "Authentication required."
            
        case 413:
            errorType = .fileTooLarge
            errorMessage = response.message ?? "Image file is too large."
            
        case 415:
            errorType = .invalidFormat
            errorMessage = response.message ?? "Unsupported image format."
            
        case 500...599:
            errorType = .serverError(statusCode: code)
            errorMessage = response.message ?? "Server error. Please try again later."
            
        default:
            errorType = .unknown
            errorMessage = response.message ?? "Upload failed with code \(code)."
        }
        
        print("❌ Upload failed [\(code)]: \(errorMessage ?? "Unknown error")")
    }
    
    private func handleNetworkError(_ error: Error) {
        errorType = .networkError
        errorMessage = error.localizedDescription
        
        // Check for specific network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                errorMessage = "No internet connection. Please check your network."
            case .timedOut:
                errorMessage = "Request timed out. Please try again."
            case .cannotFindHost, .cannotConnectToHost:
                errorMessage = "Cannot reach server. Please try again later."
            default:
                errorMessage = "Network error: \(urlError.localizedDescription)"
            }
        }
        
        print("❌ Network error: \(error)")
    }
}
