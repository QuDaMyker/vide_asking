//
//  APIClient+ImageUpload.swift
//  Rocket
//
//  Created by AI Assistant on 11/18/25.
//

import Alamofire
import Foundation
import UIKit

// MARK: - Image Upload Models

/// Metadata structure matching your API format
struct PhotoMetadata: Encodable {
    let originalFilename: String
    let fileSizeBytes: Int
    let mimeType: String
    let dimensions: ImageDimensions
    let exifData: EXIFData?
    let uploadSource: String
    
    enum CodingKeys: String, CodingKey {
        case originalFilename = "original_filename"
        case fileSizeBytes = "file_size_bytes"
        case mimeType = "mime_type"
        case dimensions
        case exifData = "exif_data"
        case uploadSource = "upload_source"
    }
}

struct ImageDimensions: Encodable {
    let width: Int
    let height: Int
}

struct EXIFData: Encodable {
    let cameraModel: String?
    let exposureTime: String?
    let fNumber: String?
    let gpsLatitude: String?
    let gpsLongitude: String?
    
    enum CodingKeys: String, CodingKey {
        case cameraModel = "camera_model"
        case exposureTime = "exposure_time"
        case fNumber = "f_number"
        case gpsLatitude = "gps_latitude"
        case gpsLongitude = "gps_longitude"
    }
}

/// Upload request parameters
struct PhotoUploadRequest {
    let image: UIImage
    let caption: String?
    let metadata: PhotoMetadata?
    let compressionQuality: CGFloat
    
    init(
        image: UIImage,
        caption: String? = nil,
        metadata: PhotoMetadata? = nil,
        compressionQuality: CGFloat = 0.8
    ) {
        self.image = image
        self.caption = caption
        self.metadata = metadata
        self.compressionQuality = compressionQuality
    }
}

// MARK: - APIClient Image Upload Extension

extension APIClient {
    
    /// Upload image with metadata using multipart/form-data
    /// - Parameters:
    ///   - path: API endpoint path (e.g., "/api/v1/photos/{photoId}")
    ///   - request: Upload request containing image, caption, and metadata
    ///   - pathParams: Path parameters (e.g., photoId)
    ///   - headers: Additional headers
    ///   - responseType: Expected response type
    /// - Returns: API response
    func uploadImage<T: Decodable>(
        _ path: String,
        request: PhotoUploadRequest,
        pathParams: [CustomStringConvertible] = [],
        headers: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        let finalPath = buildPath(path, with: pathParams)
        let fullURL = "\(baseURL)\(finalPath)"
        
        logImageUploadRequest(
            url: fullURL,
            caption: request.caption,
            imageSize: request.image.size
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            session.upload(
                multipartFormData: { formData in
                    // Add image data
                    if let imageData = request.image.jpegData(
                        compressionQuality: request.compressionQuality
                    ) {
                        formData.append(
                            imageData,
                            withName: "image",
                            fileName: "photo.jpg",
                            mimeType: "image/jpeg"
                        )
                    }
                    
                    // Add caption if provided
                    if let caption = request.caption,
                       let captionData = caption.data(using: .utf8) {
                        formData.append(captionData, withName: "caption")
                    }
                    
                    // Add metadata if provided
                    if let metadata = request.metadata {
                        do {
                            let encoder = JSONEncoder()
                            encoder.keyEncodingStrategy = .convertToSnakeCase
                            let metadataJSON = try encoder.encode(metadata)
                            formData.append(metadataJSON, withName: "metadata")
                        } catch {
                            #if DEBUG
                            debugPrint("⚠️ Failed to encode metadata: \(error)")
                            #endif
                        }
                    }
                },
                to: fullURL,
                method: .post
                // ✅ Don't set headers here - let the interceptor handle it
                // The interceptor will add Authorization header automatically
            )
            .validate(statusCode: 200..<600)
            .responseDecodable(
                of: APIResponse<T>.self,
                decoder: JSONDecoder.rocketDecoder
            ) { response in
                self.handleResponse(response, continuation: continuation)
            }
        }
    }
    
    /// Upload image without expecting a typed response
    /// Useful for fire-and-forget uploads
    func uploadImage(
        _ path: String,
        request: PhotoUploadRequest,
        pathParams: [CustomStringConvertible] = [],
        headers: [String: String]? = nil
    ) async throws {
        let finalPath = buildPath(path, with: pathParams)
        let fullURL = "\(baseURL)\(finalPath)"
        
        logImageUploadRequest(
            url: fullURL,
            caption: request.caption,
            imageSize: request.image.size
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            session.upload(
                multipartFormData: { formData in
                    if let imageData = request.image.jpegData(
                        compressionQuality: request.compressionQuality
                    ) {
                        formData.append(
                            imageData,
                            withName: "image",
                            fileName: "photo.jpg",
                            mimeType: "image/jpeg"
                        )
                    }
                    
                    if let caption = request.caption,
                       let captionData = caption.data(using: .utf8) {
                        formData.append(captionData, withName: "caption")
                    }
                    
                    if let metadata = request.metadata {
                        do {
                            let encoder = JSONEncoder()
                            encoder.keyEncodingStrategy = .convertToSnakeCase
                            let metadataJSON = try encoder.encode(metadata)
                            formData.append(metadataJSON, withName: "metadata")
                        } catch {
                            #if DEBUG
                            debugPrint("⚠️ Failed to encode metadata: \(error)")
                            #endif
                        }
                    }
                },
                to: fullURL,
                method: .post
                // ✅ Don't set headers here - let the interceptor handle it
                // The interceptor will add Authorization header automatically
            )
            .validate(statusCode: 200..<600)
            .response { response in
                switch response.result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func logImageUploadRequest(
        url: String,
        caption: String?,
        imageSize: CGSize
    ) {
        #if DEBUG
        print("🚀 [Image Upload] POST \(url)")
        print("📸 Image size: \(imageSize.width)x\(imageSize.height)")
        if let caption = caption {
            print("📝 Caption: \(caption)")
        }
        print("⚠️ Note: Content-Type will be set automatically by Alamofire with multipart boundary")
        #endif
    }
}

// MARK: - Alternative Upload Method (If Interceptor Issues Persist)

extension APIClient {
    
    /// Upload image using URLSession directly (bypasses Alamofire interceptor)
    /// Use this if the main upload method has Content-Type header conflicts
    func uploadImageDirect<T: Decodable>(
        _ path: String,
        request: PhotoUploadRequest,
        pathParams: [CustomStringConvertible] = [],
        headers: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        let finalPath = buildPath(path, with: pathParams)
        let fullURL = "\(baseURL)\(finalPath)"
        
        guard let url = URL(string: fullURL) else {
            throw URLError(.badURL)
        }
        
        // Create multipart form data manually
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        
        // Add image
        if let imageData = request.image.jpegData(compressionQuality: request.compressionQuality) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add caption
        if let caption = request.caption {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
            body.append(caption.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add metadata
        if let metadata = request.metadata {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            if let metadataJSON = try? encoder.encode(metadata),
               let metadataString = String(data: metadataJSON, encoding: .utf8) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"metadata\"\r\n\r\n".data(using: .utf8)!)
                body.append(metadataString.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers
        headers?.forEach { key, value in
            if key.lowercased() != "content-type" {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        urlRequest.httpBody = body
        
        #if DEBUG
        print("🚀 [Direct Upload] POST \(fullURL)")
        print("📋 Content-Type: multipart/form-data; boundary=\(boundary)")
        print("📦 Body size: \(body.count) bytes")
        #endif
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder.rocketDecoder
        let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
        
        #if DEBUG
        print("📩 [Response] Status: \(httpResponse.statusCode)")
        print("✅ Upload completed")
        #endif
        
        return apiResponse
    }
}

// MARK: - UIImage Extension for Metadata

extension UIImage {
    
    /// Generate basic metadata from UIImage
    func generateMetadata(
        filename: String = "photo.jpg",
        uploadSource: String = "ios_app"
    ) -> PhotoMetadata {
        let imageData = self.jpegData(compressionQuality: 1.0) ?? Data()
        
        return PhotoMetadata(
            originalFilename: filename,
            fileSizeBytes: imageData.count,
            mimeType: "image/jpeg",
            dimensions: ImageDimensions(
                width: Int(self.size.width * self.scale),
                height: Int(self.size.height * self.scale)
            ),
            exifData: nil,
            uploadSource: uploadSource
        )
    }
    
    /// Extract EXIF data from image if available
    func extractEXIFData() -> EXIFData? {
        guard let imageData = self.jpegData(compressionQuality: 1.0),
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        
        return EXIFData(
            cameraModel: tiff?[kCGImagePropertyTIFFModel as String] as? String,
            exposureTime: exif?[kCGImagePropertyExifExposureTime as String] as? String,
            fNumber: exif?[kCGImagePropertyExifFNumber as String] as? String,
            gpsLatitude: gps?[kCGImagePropertyGPSLatitude as String] as? String,
            gpsLongitude: gps?[kCGImagePropertyGPSLongitude as String] as? String
        )
    }
}
