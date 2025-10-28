# Image Upload API - Quick Reference

## 🎯 Overview

A complete Go implementation for image upload APIs with **5 storage providers** and **interface-based design** for easy switching.

## 📦 Supported Storage Providers

| Provider | Setup Complexity | Cost | Egress Fees | Best For |
|----------|-----------------|------|-------------|----------|
| 🗄️ **Local** | ⭐ Easy | Free | N/A | Development |
| 📝 **Base64** | ⭐ Easy | Free | N/A | Small embedded images |
| 🔷 **Supabase** | ⭐⭐ Medium | $ | Yes | Full-stack apps |
| ☁️ **AWS S3** | ⭐⭐⭐ Complex | $$ | Yes ($$) | Enterprise AWS |
| ⚡ **Cloudflare R2** | ⭐⭐ Medium | $ | **FREE** ✨ | High traffic, cost optimization |

## 🎨 Key Features

### ✅ Interface-Based Design
- Switch storage providers with **zero code changes**
- Just change environment variable: `STORAGE_TYPE=r2`
- Use multiple providers simultaneously (primary + backup)

### ✅ Database Integration
- Returns structured data matching your database schema
- Works seamlessly with your `CreatePhotoParams` struct
- Automatic cleanup on errors

### ✅ Complete Metadata Extraction
```go
type UploadResult struct {
    URL          string  // Full public URL
    ThumbnailURL string  // Optional thumbnail URL
    Key          string  // Storage key for deletion
    Size         int32   // File size in bytes
    Width        int32   // Image width
    Height       int32   // Image height
    MimeType     string  // Detected MIME type
}
```

### ✅ Security Built-In
- File type validation (extension + MIME type)
- Size limits
- Rate limiting
- Filename sanitization
- Path traversal prevention

### ✅ Production Ready
- Context support (timeout/cancellation)
- Error handling with cleanup
- Streaming uploads for large files
- Background processing
- Graceful shutdown

## 🚀 Quick Start

### 1. Install Dependencies
```bash
go get github.com/aws/aws-sdk-go-v2/service/s3
go get github.com/google/uuid
go get github.com/gorilla/mux
```

### 2. Choose Storage (Example: Cloudflare R2)
```bash
export STORAGE_TYPE=r2
export R2_ACCOUNT_ID=your-account-id
export R2_ACCESS_KEY_ID=your-access-key
export R2_SECRET_ACCESS_KEY=your-secret-key
export R2_BUCKET=my-images
```

### 3. Initialize Storage
```go
// Automatically initializes based on STORAGE_TYPE env var
storage, err := InitializeStorage(config)

// Use in your service
photoService := NewPhotoService(storage, db)
```

### 4. Upload Photo
```go
result, err := photoService.UploadPhoto(
    ctx,
    file,
    filename,
    senderID,
    caption,
    expiresIn,
)

// result automatically contains:
// - URL, ThumbnailURL, Size, Width, Height, MimeType
// - Ready to insert into database
```

## 💡 Why Interface-Based?

### Before (Tightly Coupled)
```go
// Hard to change storage provider
func uploadToS3(file io.Reader) error {
    // S3-specific code
    s3Client.Upload(...)
}

// Need to rewrite code to switch to R2
```

### After (Interface-Based)
```go
// Define once
type StorageProvider interface {
    Upload(ctx, file, filename, metadata) (*UploadResult, error)
}

// Use anywhere
func upload(storage StorageProvider, file io.Reader) error {
    return storage.Upload(...) // Works with ANY provider
}

// Switch providers by changing 1 env var!
```

## 🔄 Easy Switching Example

```bash
# Development
export STORAGE_TYPE=local

# Staging
export STORAGE_TYPE=supabase

# Production
export STORAGE_TYPE=r2

# No code changes needed! 🎉
```

## 🗄️ Database Integration

Your existing database struct works perfectly:

```go
type CreatePhotoParams struct {
    SenderID     pgtype.UUID      `json:"sender_id"`
    PhotoUrl     string           `json:"photo_url"`      // ← result.URL
    ThumbnailUrl *string          `json:"thumbnail_url"`  // ← result.ThumbnailURL
    FileSize     *int32           `json:"file_size"`      // ← result.Size
    Width        *int32           `json:"width"`          // ← result.Width
    Height       *int32           `json:"height"`         // ← result.Height
    MimeType     *string          `json:"mime_type"`      // ← result.MimeType
    Caption      *string          `json:"caption"`
    ExpiresAt    pgtype.Timestamp `json:"expires_at"`
}

// Service layer handles both storage AND database
photo, err := photoService.UploadPhoto(ctx, file, filename, senderID, caption, nil)
// Returns complete Photo record from database
```

## 💰 Cost Comparison: Why Cloudflare R2?

### Scenario: 100TB egress per month

| Provider | Storage | Egress | Total |
|----------|---------|--------|-------|
| AWS S3 | $230/mo | **$9,000/mo** | **$9,230/mo** |
| Cloudflare R2 | $150/mo | **$0/mo** ✨ | **$150/mo** |

**Savings with R2: $9,080/month = $108,960/year** 💰

## 📋 Complete Features

- ✅ 5 storage providers (Local, Base64, Supabase, S3, R2)
- ✅ Interface-based design (easy switching)
- ✅ Database integration (sqlc compatible)
- ✅ Automatic metadata extraction (size, dimensions, MIME)
- ✅ File validation (type, size, format)
- ✅ Rate limiting
- ✅ Authentication/Authorization middleware
- ✅ Streaming uploads
- ✅ Background processing
- ✅ Error handling with cleanup
- ✅ Context support (timeout/cancellation)
- ✅ Thumbnail generation
- ✅ Image optimization
- ✅ Batch uploads
- ✅ Presigned URLs (for private files)
- ✅ Caching strategies
- ✅ Production-ready logging
- ✅ Graceful shutdown
- ✅ Health checks
- ✅ CORS middleware

## 🎯 Recommendations

### Development
```bash
STORAGE_TYPE=local  # Simple, fast, free
```

### Production (Low-Medium Traffic)
```bash
STORAGE_TYPE=supabase  # Easy setup, includes CDN
```

### Production (High Traffic)
```bash
STORAGE_TYPE=r2  # Zero egress fees, fast, global CDN
```

### Enterprise (Already on AWS)
```bash
STORAGE_TYPE=s3  # Ecosystem integration
```

## 📖 Documentation

See [GO_IMAGE_UPLOAD_BEST_PRACTICES.md](./GO_IMAGE_UPLOAD_BEST_PRACTICES.md) for:
- Complete implementation code
- Security best practices
- Performance optimization
- Image processing
- Testing examples
- Environment setup
- Database schema
- API endpoints

## 🔧 You Control Everything

As you mentioned: **"this service I will control it, you no need to care"**

✅ All implementations provided are **complete and ready to use**  
✅ You have **full control** over configuration  
✅ Easy to **customize** for your specific needs  
✅ **Zero vendor lock-in** - switch anytime with 1 env var  

---

**Version:** 2.0  
**Last Updated:** October 28, 2025  
**Storage Options:** 5 providers with easy switching
