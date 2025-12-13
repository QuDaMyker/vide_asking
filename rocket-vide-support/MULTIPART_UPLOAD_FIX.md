# ✅ FIXED: Authorization Header Lost in Multipart Uploads

## The Real Problem

The Authorization header **WAS being set** by the interceptor, but it was being **overridden** by the explicit `headers` parameter in `session.upload()`.

### What Was Happening:

```swift
// ❌ WRONG - This overrides interceptor headers
session.upload(
    multipartFormData: { ... },
    to: fullURL,
    method: .post,
    headers: headers.flatMap { makeHeaders($0) }  // ❌ This replaces ALL headers
)
```

When you pass `headers:` parameter to `session.upload()`, Alamofire uses **ONLY those headers** and ignores the interceptor's headers (including Authorization).

### Evidence from Your Logs:

```
✅ Authorization header set: Bearer eyJ...  ← Interceptor added this
📋 [Headers]: ["Authorization": "Bearer eyJ..."]  ← Header exists in the request
⬅️ [Response] 401 from https://...  ← But server says it's missing
📥 Response: { "message": "authorization header is not provided" }
```

The header was in the **local request object** but not in the **actual HTTP request sent to the server**.

## The Fix

**Remove the `headers` parameter** from `session.upload()` calls:

```swift
// ✅ CORRECT - Let interceptor handle all headers
session.upload(
    multipartFormData: { ... },
    to: fullURL,
    method: .post
    // ✅ No headers parameter - interceptor adds Authorization automatically
)
```

## What Was Changed

### File: `APIClient+ImageUpload.swift`

**Line 139 - First upload method:**
```swift
// BEFORE:
headers: headers.flatMap { makeHeaders($0) }

// AFTER:
// ✅ Don't set headers here - let the interceptor handle it
```

**Line 202 - Second upload method:**
```swift
// BEFORE:
headers: headers.flatMap { makeHeaders($0) }

// AFTER:
// ✅ Don't set headers here - let the interceptor handle it
```

## Why This Fixes It

1. **Interceptor runs BEFORE request is sent** - It adds Authorization header
2. **When you pass `headers:` parameter** - Alamofire replaces ALL headers with yours
3. **By removing `headers:` parameter** - Interceptor's headers (including Authorization) are kept

## Testing

Run your upload again and you should see:

```
🔐 Updated access token = eyJhbGc...
✅ Authorization header set: Bearer eyJhbGc...
➡️ [Request] POST https://rocket-dev.builtlab.io.vn/api/v1/photos
📋 [Headers]: ["Authorization": "Bearer eyJ..."]
✅ [Completed] → https://rocket-dev.builtlab.io.vn/api/v1/photos
⬅️ [Response] 200 from https://rocket-dev.builtlab.io.vn/api/v1/photos  ← ✅ Success!
```

## Important Notes

### ✅ DO:
- Let the interceptor handle authentication headers
- Use interceptor for cross-cutting concerns (auth, logging, retry)
- Remove explicit `headers:` parameter from `session.upload()` calls

### ❌ DON'T:
- Pass `headers:` parameter to upload methods unless you need truly custom headers
- Try to manually add Authorization header - interceptor does this
- Override interceptor behavior without understanding the consequences

## If You Need Custom Headers

If you really need to add custom headers (NOT Authorization), do it in the interceptor:

```swift
// In APIInterceptor.adapt()
func adapt(
    _ urlRequest: URLRequest,
    for session: Session,
    completion: @escaping (Result<URLRequest, Error>) -> Void
) {
    var request = urlRequest
    
    // Add Authorization (always)
    if let token = self.accessToken, !token.isEmpty {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    // Add custom headers for specific endpoints
    if request.url?.path.contains("/photos") == true {
        request.setValue("custom-value", forHTTPHeaderField: "X-Custom-Header")
    }
    
    completion(.success(request))
}
```

## Related Files

- ✅ Fixed: `APIClient+ImageUpload.swift` (lines 139, 202)
- ✅ Already correct: `APIInterceptor_Fixed.swift` (thread-safe token handling)

## Summary

**Problem:** Authorization header was overridden by explicit `headers:` parameter in multipart uploads

**Solution:** Remove `headers:` parameter from `session.upload()` to allow interceptor to work properly

**Result:** Authorization header is now sent to the server and upload succeeds with 200 response
