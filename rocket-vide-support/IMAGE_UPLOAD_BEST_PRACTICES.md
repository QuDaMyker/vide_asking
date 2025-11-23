# Image Upload Best Practices - Rocket App

## 📚 Overview

This guide demonstrates best practices for implementing image upload functionality using the `APIClient` class with Alamofire multipart/form-data uploads.

## 🏗️ Architecture

### 1. **APIClient Extension** (`APIClient+ImageUpload.swift`)
- Extends `APIClient` with multipart/form-data upload capabilities
- Follows existing patterns from the main `APIClient` class
- Provides two upload methods: with and without typed responses

### 2. **Data Models**
```swift
PhotoUploadRequest      // Request wrapper
PhotoMetadata          // Metadata structure
PhotoUploadResponse    // Response structure
```

### 3. **View Model** (`PhotoUploadViewModel.swift`)
- Handles business logic and state management
- Provides multiple upload strategies
- `@MainActor` for UI thread safety

### 4. **UI Layer** (`PhotoUploadExampleView.swift`)
- SwiftUI view with image picker
- Progress and error handling
- Clean separation of concerns

## 🚀 Usage Examples

### Basic Upload (Auto-generated Metadata)

```swift
func clickUploadImage(_ image: UIImage) {
    Task {
        await viewModel.uploadPhoto(
            image,
            photoId: "00002103-6101-4065-b10a-3eaa12cccefe",
            caption: "Beautiful sunset"
        )
    }
}
```

### Upload with Custom Metadata

```swift
let metadata = PhotoMetadata(
    originalFilename: "vacation_2025.jpg",
    fileSizeBytes: 4500123,
    mimeType: "image/jpeg",
    dimensions: ImageDimensions(width: 1920, height: 1080),
    exifData: EXIFData(
        cameraModel: "Canon EOS R5",
        exposureTime: "1/125",
        fNumber: "f/4.0",
        gpsLatitude: "10.7769° N",
        gpsLongitude: "106.7009° E"
    ),
    uploadSource: "ios_rocket_app"
)

await viewModel.uploadPhotoWithMetadata(
    image,
    photoId: photoId,
    caption: caption,
    metadata: metadata
)
```

### Direct API Call (Advanced)

```swift
let request = PhotoUploadRequest(
    image: image,
    caption: "My photo",
    metadata: image.generateMetadata(),
    compressionQuality: 0.8
)

let response: APIResponse<PhotoUploadResponse> = try await APIClient.shared.uploadImage(
    "/api/v1/photos",
    request: request,
    pathParams: [photoId],
    responseType: PhotoUploadResponse.self
)
```

## 📋 Best Practices

### 1. **Image Compression**
```swift
// Default compression (0.8 quality)
PhotoUploadRequest(image: image)

// Custom compression for better quality
PhotoUploadRequest(image: image, compressionQuality: 0.9)

// High compression for slow networks
PhotoUploadRequest(image: image, compressionQuality: 0.6)
```

**Recommendations:**
- `0.8` - Default, good balance
- `0.9` - High quality photos
- `0.6-0.7` - Slow networks or large images

### 2. **Error Handling**

```swift
@Published var errorMessage: String?
@Published var isUploading = false

do {
    try await apiClient.uploadImage(...)
} catch {
    errorMessage = error.localizedDescription
    // Log to analytics
    // Show user-friendly error
}
```

### 3. **Loading States**

```swift
@Published var isUploading = false

func uploadPhoto() async {
    isUploading = true
    defer { isUploading = false }
    
    // Upload logic
}
```

### 4. **Progress Tracking** (Future Enhancement)

```swift
// Alamofire supports upload progress
.uploadProgress { progress in
    self.uploadProgress = progress.fractionCompleted
}
```

### 5. **Image Size Validation**

```swift
extension UIImage {
    var fileSizeInMB: Double {
        guard let data = self.jpegData(compressionQuality: 1.0) else { return 0 }
        return Double(data.count) / 1_048_576.0
    }
    
    func validateForUpload(maxSizeMB: Double = 10.0) -> Bool {
        return fileSizeInMB <= maxSizeMB
    }
}

// Usage
if !image.validateForUpload(maxSizeMB: 5.0) {
    throw UploadError.fileTooLarge
}
```

### 6. **Metadata Generation**

```swift
// Auto-generate basic metadata
let metadata = image.generateMetadata(
    filename: "photo_\(Date().timeIntervalSince1970).jpg",
    uploadSource: "ios_rocket_app"
)

// Extract EXIF data if available
if let exifData = image.extractEXIFData() {
    // Use EXIF data in metadata
}
```

### 7. **Network Optimization**

```swift
// Batch uploads
Task {
    await withTaskGroup(of: Void.self) { group in
        for image in images {
            group.addTask {
                await uploadPhoto(image)
            }
        }
    }
}

// Or sequential with delay
for image in images {
    await uploadPhoto(image)
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
}
```

### 8. **Memory Management**

```swift
autoreleasepool {
    let compressedData = image.jpegData(compressionQuality: 0.8)
    // Use compressedData
}
```

### 9. **Retry Logic**

```swift
func uploadWithRetry(
    _ image: UIImage,
    maxRetries: Int = 3
) async throws {
    var lastError: Error?
    
    for attempt in 1...maxRetries {
        do {
            try await uploadPhoto(image)
            return // Success
        } catch {
            lastError = error
            if attempt < maxRetries {
                let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
                try await Task.sleep(nanoseconds: delay)
            }
        }
    }
    
    throw lastError ?? UploadError.unknown
}
```

### 10. **Background Upload** (Advanced)

```swift
// Use URLSession for background uploads
let session = URLSession(
    configuration: .background(withIdentifier: "com.rocket.upload")
)
```

## 🔒 Security Best Practices

### 1. **Validate Image Content**
```swift
func validateImage(_ image: UIImage) -> Bool {
    // Check minimum size
    guard image.size.width >= 100, image.size.height >= 100 else {
        return false
    }
    
    // Check maximum size
    guard image.size.width <= 5000, image.size.height <= 5000 else {
        return false
    }
    
    return true
}
```

### 2. **Sanitize File Names**
```swift
func sanitizeFilename(_ filename: String) -> String {
    let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
    return filename
        .components(separatedBy: invalidChars)
        .joined()
}
```

### 3. **Use HTTPS Only**
- Ensure `baseURL` uses HTTPS
- Never send images over unsecured connections

## 📊 Response Handling

### Success Response
```swift
if response.isSuccess, let data = response.data {
    print("Photo URL: \(data.url)")
    print("Thumbnail: \(data.thumbnailUrl ?? "N/A")")
    print("Uploaded at: \(data.uploadedAt)")
}
```

### Error Response
```swift
if !response.isSuccess {
    switch response.statusCode {
    case 400: // Bad request
        print("Invalid image format")
    case 413: // Payload too large
        print("Image too large")
    case 401: // Unauthorized
        print("Authentication required")
    default:
        print("Error: \(response.message ?? "Unknown")")
    }
}
```

## 🧪 Testing

### Unit Tests
```swift
func testImageUpload() async throws {
    let image = UIImage(systemName: "photo")!
    let request = PhotoUploadRequest(
        image: image,
        caption: "Test photo"
    )
    
    let response = try await APIClient.shared.uploadImage(
        "/api/v1/photos",
        request: request,
        pathParams: ["test-id"],
        responseType: PhotoUploadResponse.self
    )
    
    XCTAssertTrue(response.isSuccess)
}
```

### Mock for Testing
```swift
protocol ImageUploadService {
    func uploadImage(_ request: PhotoUploadRequest) async throws -> APIResponse<PhotoUploadResponse>
}

class MockImageUploadService: ImageUploadService {
    func uploadImage(_ request: PhotoUploadRequest) async throws -> APIResponse<PhotoUploadResponse> {
        // Return mock response
    }
}
```

## 📱 UI/UX Recommendations

1. **Show upload progress**: Use `ProgressView` or custom progress indicator
2. **Disable UI during upload**: Prevent multiple uploads
3. **Provide feedback**: Show success/error messages
4. **Allow cancellation**: Implement cancel functionality
5. **Cache failed uploads**: Retry later when network available
6. **Preview before upload**: Let users confirm image
7. **Compress large images**: Warn users about large files

## 🔗 Integration with Existing Code

The implementation follows the exact patterns from your `APIClient`:

✅ Uses `async/await` with continuations  
✅ Follows same error handling  
✅ Consistent logging format  
✅ Uses `@unchecked Sendable`  
✅ Debug logging with `#if DEBUG`  
✅ Path parameters support  
✅ Custom headers support  
✅ Same `APIResponse<T>` wrapper  

## 📝 API Endpoint Format

```
POST /api/v1/photos/{photoId}
Content-Type: multipart/form-data

Fields:
- image: binary (required)
- caption: string (optional)
- metadata: JSON string (optional)
```

## 🎯 Quick Reference

| Task | Method |
|------|--------|
| Simple upload | `uploadPhoto(_:photoId:caption:)` |
| Custom metadata | `uploadPhotoWithMetadata(_:photoId:caption:metadata:)` |
| No response | `uploadPhotoSimple(_:photoId:caption:)` |
| Generate metadata | `image.generateMetadata()` |
| Extract EXIF | `image.extractEXIFData()` |
| Validate size | `image.validateForUpload()` |

## 🚨 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Image too large | Compress before upload |
| Slow upload | Reduce compression quality or resize |
| Memory warning | Use autoreleasepool |
| Upload fails | Check network, retry with backoff |
| Wrong format | Ensure JPEG encoding |
| Missing metadata | Use `generateMetadata()` |

## 📖 Related Documentation

- [Alamofire Multipart Upload](https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md#uploading-multipartformdata)
- [Apple Image I/O](https://developer.apple.com/documentation/imageio)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
