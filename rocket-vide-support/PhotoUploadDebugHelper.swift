//
//  PhotoUploadDebugHelper.swift
//  Rocket
//
//  Created by AI Assistant on 11/18/25.
//

import Foundation
import UIKit
import Alamofire

// MARK: - Debug Helper for Upload Issues

extension PhotoUploadViewModel {
    
    /// Debug upload to print all headers being sent
    func debugUpload(_ image: UIImage, photoId: String) async {
        #if DEBUG
        print("\n========== DEBUG UPLOAD ==========")
        print("PhotoID: \(photoId)")
        print("Image size: \(image.size)")
        
        // Try standard upload method
        print("\n--- Testing Standard Upload Method ---")
        await testStandardUpload(image, photoId: photoId)
        
        // Try direct upload method
        print("\n--- Testing Direct Upload Method ---")
        await testDirectUpload(image, photoId: photoId)
        
        print("\n==================================\n")
        #endif
    }
    
    #if DEBUG
    private func testStandardUpload(_ image: UIImage, photoId: String) async {
        let metadata = image.generateMetadata()
        let request = PhotoUploadRequest(
            image: image,
            caption: "Debug test",
            metadata: metadata
        )
        
        do {
            let response: APIResponse<PhotoUploadResponse> = try await apiClient.uploadImage(
                "/api/v1/photos",
                request: request,
                pathParams: [photoId],
                responseType: PhotoUploadResponse.self
            )
            print("✅ Standard upload success: \(response.isSuccess)")
            print("Status: \(response.statusCode)")
            print("Message: \(response.message ?? "N/A")")
        } catch {
            print("❌ Standard upload failed: \(error)")
        }
    }
    
    private func testDirectUpload(_ image: UIImage, photoId: String) async {
        let metadata = image.generateMetadata()
        let request = PhotoUploadRequest(
            image: image,
            caption: "Debug test direct",
            metadata: metadata
        )
        
        do {
            let response: APIResponse<PhotoUploadResponse> = try await apiClient.uploadImageDirect(
                "/api/v1/photos",
                request: request,
                pathParams: [photoId],
                responseType: PhotoUploadResponse.self
            )
            print("✅ Direct upload success: \(response.isSuccess)")
            print("Status: \(response.statusCode)")
            print("Message: \(response.message ?? "N/A")")
        } catch {
            print("❌ Direct upload failed: \(error)")
        }
    }
    #endif
}

// MARK: - Custom Request Modifier for Alamofire

class MultipartRequestDebugAdapter: RequestInterceptor {
    
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        
        #if DEBUG
        print("\n📤 [Request Debug]")
        print("URL: \(request.url?.absoluteString ?? "N/A")")
        print("Method: \(request.httpMethod ?? "N/A")")
        print("Headers:")
        request.allHTTPHeaderFields?.forEach { key, value in
            print("  \(key): \(value)")
        }
        if let bodyData = request.httpBody {
            print("Body size: \(bodyData.count) bytes")
            // Print first 500 bytes to see structure
            if let preview = String(data: bodyData.prefix(500), encoding: .utf8) {
                print("Body preview:\n\(preview)")
            }
        }
        print("---")
        #endif
        
        completion(.success(request))
    }
}

// MARK: - Usage Instructions

/*
 
 ## How to Debug Upload Issues:
 
 1. Add debug adapter to your APIClient:
 
 ```swift
 // In APIClient initialization
 let debugAdapter = MultipartRequestDebugAdapter()
 session = Session(
     configuration: configuration,
     interceptor: RequestInterceptor.multiple([interceptor, debugAdapter]),
     eventMonitors: [interceptor]
 )
 ```
 
 2. Call debug upload:
 
 ```swift
 await viewModel.debugUpload(image, photoId: "test-id")
 ```
 
 3. Check console output for:
    - Content-Type header value
    - Multipart boundary
    - Body structure
 
 ## Common Issues:
 
 ❌ Content-Type: application/json
    → Wrong header, should be multipart/form-data
 
 ❌ Content-Type: multipart/form-data (without boundary)
    → Missing boundary parameter
 
 ✅ Content-Type: multipart/form-data; boundary=----WebKit...
    → Correct format
 
 ## If Interceptor is Overriding Headers:
 
 Use the direct upload method:
 ```swift
 try await apiClient.uploadImageDirect(...)
 ```
 
 This bypasses Alamofire's session and interceptors.
 
 */
