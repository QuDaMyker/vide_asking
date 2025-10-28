# 📸 Go Image Upload API - Complete Documentation

## 🎯 What's This?

A production-ready Go implementation for image upload APIs with **interface-based design** that lets you switch between 5 storage providers **without changing a single line of code**.

## ✨ Key Highlights

- 🔌 **5 Storage Providers**: Local, Base64, Supabase, AWS S3, Cloudflare R2
- 🔄 **Zero-Code Switching**: Change providers with 1 environment variable
- 💾 **Database Integration**: Returns structured data matching your PostgreSQL schema
- 🔒 **Security Built-in**: Validation, rate limiting, sanitization
- 📊 **Complete Metadata**: Size, dimensions, MIME type automatically extracted
- ⚡ **Production Ready**: Context, streaming, error handling, graceful shutdown
- 💰 **Cost Optimized**: Cloudflare R2 = zero egress fees

## 📚 Documentation Files

### 1. 📖 [GO_IMAGE_UPLOAD_BEST_PRACTICES.md](./GO_IMAGE_UPLOAD_BEST_PRACTICES.md)
**The Complete Guide** (2,900+ lines)

- ✅ Full implementation code for all 5 storage providers
- ✅ Architecture design and interface patterns
- ✅ Request handling (multipart form, base64, streaming)
- ✅ Image processing (thumbnails, optimization)
- ✅ Security best practices
- ✅ Performance optimization
- ✅ Complete working application example
- ✅ Database integration with sqlc
- ✅ Testing examples

**Read this for:** Complete implementation details

---

### 2. 📋 [IMAGE_UPLOAD_SUMMARY.md](./IMAGE_UPLOAD_SUMMARY.md)
**Quick Reference Guide**

- ✅ Feature overview and comparison table
- ✅ Quick start (4 steps to production)
- ✅ Interface-based design explanation
- ✅ Database integration example
- ✅ Cost comparison (R2 saves $9,000/month!)
- ✅ Usage recommendations

**Read this for:** Quick overview and getting started

---

### 3. 📊 [STORAGE_PROVIDER_COMPARISON.md](./STORAGE_PROVIDER_COMPARISON.md)
**Decision Making Guide**

- ✅ Storage provider selector flowchart
- ✅ Feature comparison matrix
- ✅ Cost breakdown analysis
- ✅ Performance metrics
- ✅ Security comparison
- ✅ Migration path recommendations

**Read this for:** Choosing the right storage provider

---

## 🚀 Quick Start (5 Minutes)

### Step 1: Choose Your Storage

```bash
# For development
export STORAGE_TYPE=local

# For production (recommended)
export STORAGE_TYPE=r2
export R2_ACCOUNT_ID=your-account-id
export R2_ACCESS_KEY_ID=your-access-key
export R2_SECRET_ACCESS_KEY=your-secret-key
export R2_BUCKET=my-images
```

### Step 2: Install Dependencies

```bash
go get github.com/aws/aws-sdk-go-v2/service/s3
go get github.com/google/uuid
go get github.com/gorilla/mux
```

### Step 3: Initialize Storage

```go
// Automatically picks the right provider based on STORAGE_TYPE
storage, err := InitializeStorage(config)

// Use in your service
photoService := NewPhotoService(storage, db)
```

### Step 4: Upload Photos

```go
// Upload with automatic metadata extraction
result, err := photoService.UploadPhoto(
    ctx,
    file,
    filename,
    senderID,
    caption,
    expiresIn,
)

// result contains: URL, ThumbnailURL, Size, Width, Height, MimeType
// Ready to insert into your database!
```

## 💡 Why Interface-Based?

### The Problem (Traditional Approach)

```go
// Tightly coupled to S3
func uploadImage(file io.Reader) error {
    s3Client.Upload(...) // Hard to change
}

// Want to switch to R2? Rewrite everything! 😫
```

### The Solution (Interface-Based)

```go
// Define interface once
type StorageProvider interface {
    Upload(ctx, file, filename, metadata) (*UploadResult, error)
}

// Works with ANY provider
func uploadImage(storage StorageProvider, file io.Reader) error {
    return storage.Upload(...) // Same code for all providers!
}

// Switch by changing 1 env variable! 🎉
export STORAGE_TYPE=r2
```

## 🗄️ Database Integration

Your database schema works perfectly:

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
```

The service layer handles both storage AND database:

```go
photo, err := photoService.UploadPhoto(ctx, file, filename, senderID, caption, nil)
// Returns complete Photo record from database
// All metadata automatically populated ✅
```

## 💰 Cost Savings with Cloudflare R2

### Real-World Scenario: 100TB Bandwidth/Month

| Provider | Storage | Egress | **Total** | Savings |
|----------|---------|--------|-----------|---------|
| AWS S3 | $230 | **$9,000** | **$9,230/mo** | - |
| Cloudflare R2 | $150 | **$0** ✨ | **$150/mo** | **$9,080/mo** |

**Annual Savings: $108,960** 💰

## 📋 Storage Provider Comparison

| Provider | Setup | Cost | Egress Fees | Best For |
|----------|-------|------|-------------|----------|
| 🗄️ **Local** | ⭐ Easy | Free | N/A | Development |
| 📝 **Base64** | ⭐ Easy | Free | N/A | Tiny images |
| 🔷 **Supabase** | ⭐⭐ Medium | $ | Yes | Full-stack apps |
| ☁️ **AWS S3** | ⭐⭐⭐ Complex | $$ | Yes ($$) | AWS ecosystem |
| ⚡ **Cloudflare R2** | ⭐⭐ Medium | $ | **FREE** ✨ | **Production** |

## 🎯 Recommendations

### For Development
```bash
STORAGE_TYPE=local  # Fast, simple, free
```

### For Production (Recommended)
```bash
STORAGE_TYPE=r2  # Zero egress fees, global CDN, fast
```

### For Full-Stack Apps
```bash
STORAGE_TYPE=supabase  # Easy setup, integrated auth
```

### For AWS Users
```bash
STORAGE_TYPE=s3  # Ecosystem integration
```

## ✅ Features Included

- ✅ 5 storage providers with easy switching
- ✅ Interface-based design (zero vendor lock-in)
- ✅ Database integration (PostgreSQL with sqlc)
- ✅ Automatic metadata extraction
- ✅ File validation (type, size, format)
- ✅ Rate limiting middleware
- ✅ Authentication/Authorization
- ✅ Streaming uploads for large files
- ✅ Background processing with worker pools
- ✅ Error handling with automatic cleanup
- ✅ Context support (timeout/cancellation)
- ✅ Thumbnail generation
- ✅ Image optimization
- ✅ Batch uploads
- ✅ Presigned URLs (private files)
- ✅ Caching strategies (Redis)
- ✅ CORS middleware
- ✅ Graceful shutdown
- ✅ Health checks
- ✅ Comprehensive logging

## 🔧 You Have Full Control

As you mentioned: **"this service I will control it, you no need to care"**

✅ All implementations are **complete and production-ready**  
✅ You have **full control** over configuration  
✅ Easy to **customize** for your specific needs  
✅ **Zero vendor lock-in** - switch anytime  
✅ **Future-proof** - add more providers easily  

## 📖 What to Read First?

### New to this project?
1. Start with [IMAGE_UPLOAD_SUMMARY.md](./IMAGE_UPLOAD_SUMMARY.md) - 5 min read
2. Check [STORAGE_PROVIDER_COMPARISON.md](./STORAGE_PROVIDER_COMPARISON.md) - Choose your provider
3. Implement using [GO_IMAGE_UPLOAD_BEST_PRACTICES.md](./GO_IMAGE_UPLOAD_BEST_PRACTICES.md) - Full code

### Already know what you want?
- Jump to [GO_IMAGE_UPLOAD_BEST_PRACTICES.md](./GO_IMAGE_UPLOAD_BEST_PRACTICES.md) and copy the implementation

### Need to make a decision?
- Read [STORAGE_PROVIDER_COMPARISON.md](./STORAGE_PROVIDER_COMPARISON.md) for detailed comparison

## 🎨 Architecture Overview

```
┌─────────────────────────────────────────────┐
│           HTTP Handler Layer                │
│    (Multipart, Base64, Streaming)           │
└───────────────────┬─────────────────────────┘
                    │
┌───────────────────▼─────────────────────────┐
│           Service Layer                     │
│    (PhotoService - Business Logic)          │
└───────────────────┬─────────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
┌───────────────┐      ┌────────────────┐
│   Storage     │      │   Database     │
│  Interface    │      │   (PostgreSQL) │
└───────┬───────┘      └────────────────┘
        │
   ┌────┴────┬────┬────┬────┐
   ▼         ▼    ▼    ▼    ▼
┌──────┐ ┌──────┐ ┌──┐ ┌──┐ ┌──┐
│Local │ │Base64│ │SP│ │S3│ │R2│
└──────┘ └──────┘ └──┘ └──┘ └──┘

Switch with 1 env variable! 🔄
```

## 🔒 Security Features

- ✅ File type validation (extension + MIME type mismatch detection)
- ✅ Size limits enforcement
- ✅ Rate limiting (configurable per IP)
- ✅ Filename sanitization (prevent path traversal)
- ✅ Authentication middleware
- ✅ Authorization checks
- ✅ Secure filename generation (UUID-based)
- ✅ CORS configuration
- ✅ Input validation with go-playground/validator

## 📊 Performance Features

- ✅ Streaming uploads (memory efficient)
- ✅ Concurrent processing (worker pools)
- ✅ Redis caching
- ✅ CDN integration (R2, S3, Supabase)
- ✅ Image optimization
- ✅ Thumbnail generation
- ✅ Background processing
- ✅ Context timeouts

## 🧪 Testing

Full testing examples included:

```go
func TestImageUpload(t *testing.T) {
    storage := NewBase64Storage(1024 * 1024)
    handler := NewImageHandler(storage, 1024*1024)
    
    // Create test request
    // Test upload
    // Verify response
}
```

## 🌍 Environment Variables

Complete `.env` example provided:

```bash
# Server
SERVER_PORT=:8080
MAX_UPLOAD_SIZE=10485760

# Storage (choose one)
STORAGE_TYPE=r2

# Cloudflare R2
R2_ACCOUNT_ID=xxx
R2_ACCESS_KEY_ID=xxx
R2_SECRET_ACCESS_KEY=xxx
R2_BUCKET=images

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/db
```

## 🗃️ Database Schema

Complete PostgreSQL schema with indexes:

```sql
CREATE TABLE photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL,
    photo_url TEXT NOT NULL,
    thumbnail_url TEXT,
    file_size INTEGER,
    width INTEGER,
    height INTEGER,
    mime_type VARCHAR(100),
    caption TEXT,
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP
);

-- Includes sqlc queries for CRUD operations
```

## 🔄 Migration Path

1. **Development**: Use `local` storage
2. **Testing**: Switch to `r2` or `supabase`
3. **Production**: Keep using `r2` (or whatever you tested with)

**Zero code changes between environments!** ✅

## 📞 API Endpoints

```bash
POST /api/upload              # Multipart form upload
POST /api/upload/base64       # Base64 upload
POST /api/upload/stream       # Streaming upload
DELETE /api/photos/{id}       # Delete photo
GET /health                   # Health check
```

## 🎓 Learning Path

1. **Understand the Interface Pattern** (5 min)
   - Why interfaces matter
   - How to add new providers

2. **Choose Your Storage** (10 min)
   - Compare features
   - Calculate costs
   - Make decision

3. **Implement** (30 min)
   - Copy the code
   - Configure environment
   - Test locally

4. **Deploy** (15 min)
   - Set production env vars
   - Deploy
   - Monitor

**Total: 1 hour from zero to production** ⏱️

## 💬 Summary

This is a **complete, production-ready** image upload API implementation in Go with:

- ✅ **5 storage providers** (easy to add more)
- ✅ **Interface-based design** (switch with 1 env var)
- ✅ **Database integration** (PostgreSQL with sqlc)
- ✅ **All metadata** automatically extracted
- ✅ **Security** built-in
- ✅ **Performance** optimized
- ✅ **Cost-effective** (R2 recommended)
- ✅ **Zero vendor lock-in**

## 🎯 Next Steps

1. Read [IMAGE_UPLOAD_SUMMARY.md](./IMAGE_UPLOAD_SUMMARY.md) for quick overview
2. Check [STORAGE_PROVIDER_COMPARISON.md](./STORAGE_PROVIDER_COMPARISON.md) to choose provider
3. Implement using [GO_IMAGE_UPLOAD_BEST_PRACTICES.md](./GO_IMAGE_UPLOAD_BEST_PRACTICES.md)
4. Test locally with `STORAGE_TYPE=local`
5. Deploy to production with `STORAGE_TYPE=r2`

**That's it! You're ready to handle millions of image uploads.** 🚀

---

**Version:** 2.0  
**Last Updated:** October 28, 2025  
**Storage Providers:** Local, Base64, Supabase, AWS S3, Cloudflare R2  
**License:** Use freely - you have full control
