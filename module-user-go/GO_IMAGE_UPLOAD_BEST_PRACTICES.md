# Go Image Upload API Best Practices

## Table of Contents
1. [Overview](#overview)
2. [Architecture Design](#architecture-design)
3. [Storage Options](#storage-options)
4. [Request Handling](#request-handling)
5. [Image Processing](#image-processing)
6. [Security Best Practices](#security-best-practices)
7. [Implementation Examples](#implementation-examples)
8. [Performance Optimization](#performance-optimization)

---

## Overview

This guide covers best practices for implementing image upload APIs in Go with support for:
- **Base64** encoding
- **Supabase** storage
- **Local storage** (Ubuntu server)
- **AWS S3** storage
- **Cloudflare R2** storage (S3-compatible)

### Key Considerations
- File size limits
- Image validation and sanitization
- Concurrent uploads
- Error handling
- Progress tracking
- Security measures
- Easy storage provider switching via interface
- Database integration for metadata

---

## Architecture Design

### 1. Layered Architecture

```
┌─────────────────────────────────────┐
│         HTTP Handler Layer          │
│  (Routing, Request Validation)      │
└────────────────┬────────────────────┘
                 │
┌────────────────▼────────────────────┐
│         Service Layer               │
│  (Business Logic, Orchestration)    │
└────────────────┬────────────────────┘
                 │
┌────────────────▼────────────────────┐
│       Storage Interface Layer       │
│  (Abstract Storage Operations)      │
└────────────────┬────────────────────┘
                 │
      ┌──────────┴──────────┬──────────┬──────────┬──────────┐
      ▼                     ▼          ▼          ▼          ▼
┌──────────┐    ┌──────────────┐  ┌───────┐  ┌───────┐  ┌───────┐
│  Base64  │    │   Supabase   │  │ Local │  │  S3   │  │  R2   │
│ Storage  │    │   Storage    │  │Storage│  │Storage│  │Storage│
└──────────┘    └──────────────┘  └───────┘  └───────┘  └───────┘
```

### 2. Storage Interface Pattern

```go
type StorageProvider interface {
    Upload(ctx context.Context, file io.Reader, filename string, metadata map[string]string) (*UploadResult, error)
    Download(ctx context.Context, key string) (io.ReadCloser, error)
    Delete(ctx context.Context, key string) error
    GetURL(ctx context.Context, key string, expiry time.Duration) (string, error)
}

// UploadResult contains all information about the uploaded file
type UploadResult struct {
    URL          string
    ThumbnailURL string
    Key          string
    Size         int64
    Width        int32
    Height       int32
    MimeType     string
}
```

### 3. Database Integration

The interface design allows seamless integration with your database layer. All upload functions return structured data that maps directly to your database schema:

```go
// Your database model (using pgtype for PostgreSQL)
type CreatePhotoParams struct {
    SenderID     pgtype.UUID      `json:"sender_id"`
    PhotoUrl     string           `json:"photo_url"`
    ThumbnailUrl *string          `json:"thumbnail_url"`
    FileSize     *int32           `json:"file_size"`
    Width        *int32           `json:"width"`
    Height       *int32           `json:"height"`
    MimeType     *string          `json:"mime_type"`
    Caption      *string          `json:"caption"`
    ExpiresAt    pgtype.Timestamp `json:"expires_at"`
}

// Service layer that bridges storage and database
type PhotoService struct {
    storage StorageProvider
    db      *sql.DB
    queries *Queries // sqlc generated queries
}

func (s *PhotoService) UploadPhoto(ctx context.Context, file io.Reader, filename string, senderID uuid.UUID, caption *string) (*Photo, error) {
    // Upload to storage
    result, err := s.storage.Upload(ctx, file, filename, map[string]string{
        "sender_id": senderID.String(),
    })
    if err != nil {
        return nil, fmt.Errorf("storage upload failed: %w", err)
    }

    // Prepare database parameters
    params := CreatePhotoParams{
        SenderID:     pgtype.UUID{Bytes: senderID, Valid: true},
        PhotoUrl:     result.URL,
        ThumbnailUrl: &result.ThumbnailURL,
        FileSize:     &result.Size,
        Width:        &result.Width,
        Height:       &result.Height,
        MimeType:     &result.MimeType,
        Caption:      caption,
    }

    // Save to database
    photo, err := s.queries.CreatePhoto(ctx, params)
    if err != nil {
        // Cleanup uploaded file on database error
        s.storage.Delete(ctx, result.Key)
        return nil, fmt.Errorf("database insert failed: %w", err)
    }

    return photo, nil
}
```

### 4. Easy Storage Provider Switching

The interface pattern makes it trivial to switch between storage providers or even use multiple providers simultaneously:

```go
// Configuration-based initialization
func InitializeStorage(config *Config) (StorageProvider, error) {
    switch config.StorageProvider {
    case "s3":
        return NewS3Storage(config.S3Bucket, config.S3Region)
    case "r2":
        return NewR2Storage(config.R2AccountID, config.R2AccessKey, config.R2SecretKey, config.R2Bucket)
    case "supabase":
        return NewSupabaseStorage(config.SupabaseURL, config.SupabaseKey, config.SupabaseBucket), nil
    case "local":
        return NewLocalStorage(config.LocalPath, config.LocalBaseURL, config.MaxFileSize)
    case "base64":
        return NewBase64Storage(config.MaxFileSize), nil
    default:
        return nil, fmt.Errorf("unsupported storage provider: %s", config.StorageProvider)
    }
}

// Multi-provider setup (e.g., primary + backup)
type MultiStorage struct {
    primary StorageProvider
    backup  StorageProvider
}

func (m *MultiStorage) Upload(ctx context.Context, file io.Reader, filename string, metadata map[string]string) (*UploadResult, error) {
    // Try primary first
    result, err := m.primary.Upload(ctx, file, filename, metadata)
    if err == nil {
        return result, nil
    }

    // Fallback to backup
    log.Printf("Primary storage failed, using backup: %v", err)
    return m.backup.Upload(ctx, file, filename, metadata)
}
```

---

## Storage Options

### 1. Base64 Storage

**Use Cases:**
- Small images (< 100KB)
- Embedded in JSON responses
- No separate file management needed

**Pros:**
✅ Simple implementation
✅ No external dependencies
✅ Immediate availability

**Cons:**
❌ 33% size overhead
❌ Not suitable for large files
❌ Database bloat
❌ Slower parsing

**Implementation:**

```go
package storage

import (
    "context"
    "encoding/base64"
    "fmt"
    "io"
)

type Base64Storage struct {
    maxSize int64 // Maximum file size in bytes
}

func NewBase64Storage(maxSize int64) *Base64Storage {
    return &Base64Storage{
        maxSize: maxSize,
    }
}

func (s *Base64Storage) Upload(ctx context.Context, file io.Reader, filename string, metadata map[string]string) (*UploadResult, error) {
    // Read file content
    data, err := io.ReadAll(io.LimitReader(file, s.maxSize))
    if err != nil {
        return nil, fmt.Errorf("failed to read file: %w", err)
    }

    // Encode to base64
    encoded := base64.StdEncoding.EncodeToString(data)
    
    // Get image dimensions if it's an image
    width, height := int32(0), int32(0)
    mimeType := http.DetectContentType(data)
    
    if strings.HasPrefix(mimeType, "image/") {
        w, h, err := getImageDimensions(bytes.NewReader(data))
        if err == nil {
            width, height = int32(w), int32(h)
        }
    }
    
    return &UploadResult{
        URL:      encoded, // Base64 string stored directly
        Key:      filename,
        Size:     int32(len(data)),
        Width:    width,
        Height:   height,
        MimeType: mimeType,
    }, nil
}

func (s *Base64Storage) Decode(encoded string) ([]byte, error) {
    return base64.StdEncoding.DecodeString(encoded)
}
```

**Best Practices:**
- Limit size to 100KB maximum
- Store metadata separately (mime type, dimensions)
- Use with caching strategy
- Consider lazy loading

---

### 2. Supabase Storage

**Use Cases:**
- Full-stack applications using Supabase
- Need for CDN distribution
- Built-in authentication integration

**Pros:**
✅ CDN integration
✅ Access control policies
✅ Automatic image transformations
✅ RESTful API

**Cons:**
❌ Vendor lock-in
❌ Cost considerations
❌ Region limitations

**Implementation:**

```go
package storage

import (
    "bytes"
    "context"
    "fmt"
    "io"
    "mime/multipart"
    "net/http"
    "path/filepath"
    "time"

    "github.com/google/uuid"
)

type SupabaseStorage struct {
    projectURL string
    apiKey     string
    bucket     string
    httpClient *http.Client
}

func NewSupabaseStorage(projectURL, apiKey, bucket string) *SupabaseStorage {
    return &SupabaseStorage{
        projectURL: projectURL,
        apiKey:     apiKey,
        bucket:     bucket,
        httpClient: &http.Client{
            Timeout: 30 * time.Second,
        },
    }
}

func (s *SupabaseStorage) Upload(ctx context.Context, file io.Reader, filename string, metadata map[string]string) (*UploadResult, error) {
    // Generate unique filename
    ext := filepath.Ext(filename)
    uniqueName := fmt.Sprintf("%s%s", uuid.New().String(), ext)
    
    // Read file content
    fileContent, err := io.ReadAll(file)
    if err != nil {
        return nil, fmt.Errorf("failed to read file: %w", err)
    }

    fileSize := int32(len(fileContent))
    
    // Get image dimensions
    width, height := int32(0), int32(0)
    mimeType := metadata["content-type"]
    if mimeType == "" {
        mimeType = http.DetectContentType(fileContent)
    }
    
    if strings.HasPrefix(mimeType, "image/") {
        w, h, err := getImageDimensions(bytes.NewReader(fileContent))
        if err == nil {
            width, height = int32(w), int32(h)
        }
    }

    // Prepare upload URL
    uploadURL := fmt.Sprintf("%s/storage/v1/object/%s/%s", 
        s.projectURL, s.bucket, uniqueName)

    // Create request
    req, err := http.NewRequestWithContext(ctx, "POST", uploadURL, bytes.NewReader(fileContent))
    if err != nil {
        return nil, fmt.Errorf("failed to create request: %w", err)
    }

    // Set headers
    req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", s.apiKey))
    req.Header.Set("Content-Type", mimeType)
    
    // Add custom metadata
    for key, value := range metadata {
        if key != "content-type" {
            req.Header.Set(fmt.Sprintf("x-upsert-%s", key), value)
        }
    }

    // Execute request
    resp, err := s.httpClient.Do(req)
    if err != nil {
        return nil, fmt.Errorf("upload failed: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
        body, _ := io.ReadAll(resp.Body)
        return nil, fmt.Errorf("upload failed with status %d: %s", resp.StatusCode, string(body))
    }

    // Return public URL
    publicURL := fmt.Sprintf("%s/storage/v1/object/public/%s/%s", 
        s.projectURL, s.bucket, uniqueName)
    
    return &UploadResult{
        URL:      publicURL,
        Key:      uniqueName,
        Size:     fileSize,
        Width:    width,
        Height:   height,
        MimeType: mimeType,
    }, nil
}

func (s *SupabaseStorage) GetURL(ctx context.Context, key string, expiry time.Duration) (string, error) {
    // For private buckets, generate signed URL
    signedURL := fmt.Sprintf("%s/storage/v1/object/sign/%s/%s?expiresIn=%d",
        s.projectURL, s.bucket, key, int(expiry.Seconds()))
    
    return signedURL, nil
}

func (s *SupabaseStorage) Delete(ctx context.Context, key string) error {
    deleteURL := fmt.Sprintf("%s/storage/v1/object/%s/%s", 
        s.projectURL, s.bucket, key)

    req, err := http.NewRequestWithContext(ctx, "DELETE", deleteURL, nil)
    if err != nil {
        return fmt.Errorf("failed to create delete request: %w", err)
    }

    req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", s.apiKey))

    resp, err := s.httpClient.Do(req)
    if err != nil {
        return fmt.Errorf("delete failed: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
        return fmt.Errorf("delete failed with status %d", resp.StatusCode)
    }

    return nil
}
```

**Best Practices:**
- Use bucket policies for access control
- Enable RLS (Row Level Security)
- Configure CORS properly
- Use image transformation parameters
- Implement retry logic for uploads

---

### 3. Local Storage (Ubuntu Server)

**Use Cases:**
- Development environment
- Full control over storage
- No external costs
- Private/sensitive data

**Pros:**
✅ No external costs
✅ Full control
✅ Fast for local access
✅ Simple implementation

**Cons:**
❌ No CDN
❌ Scaling challenges
❌ Backup responsibility
❌ No built-in redundancy

**Implementation:**

```go
package storage

import (
    "context"
    "crypto/sha256"
    "encoding/hex"
    "fmt"
    "io"
    "os"
    "path/filepath"
    "time"

    "github.com/google/uuid"
)

type LocalStorage struct {
    basePath    string
    baseURL     string
    maxSize     int64
    permissions os.FileMode
}

func NewLocalStorage(basePath, baseURL string, maxSize int64) (*LocalStorage, error) {
    // Create base directory if it doesn't exist
    if err := os.MkdirAll(basePath, 0755); err != nil {
        return nil, fmt.Errorf("failed to create base path: %w", err)
    }

    return &LocalStorage{
        basePath:    basePath,
        baseURL:     baseURL,
        maxSize:     maxSize,
        permissions: 0644,
    }, nil
}

func (s *LocalStorage) Upload(ctx context.Context, file io.Reader, filename string, metadata map[string]string) (*UploadResult, error) {
    // Generate unique filename
    ext := filepath.Ext(filename)
    uniqueID := uuid.New().String()
    
    // Create date-based subdirectory (YYYY/MM/DD)
    now := time.Now()
    subDir := filepath.Join(
        fmt.Sprintf("%04d", now.Year()),
        fmt.Sprintf("%02d", now.Month()),
        fmt.Sprintf("%02d", now.Day()),
    )
    
    fullDir := filepath.Join(s.basePath, subDir)
    if err := os.MkdirAll(fullDir, 0755); err != nil {
        return nil, fmt.Errorf("failed to create directory: %w", err)
    }

    // Create filename
    uniqueName := fmt.Sprintf("%s%s", uniqueID, ext)
    fullPath := filepath.Join(fullDir, uniqueName)

    // Create file
    outFile, err := os.OpenFile(fullPath, os.O_WRONLY|os.O_CREATE|os.O_EXCL, s.permissions)
    if err != nil {
        return nil, fmt.Errorf("failed to create file: %w", err)
    }
    defer outFile.Close()

    // Copy with size limit
    limitedReader := io.LimitReader(file, s.maxSize)
    written, err := io.Copy(outFile, limitedReader)
    if err != nil {
        os.Remove(fullPath) // Cleanup on error
        return nil, fmt.Errorf("failed to write file: %w", err)
    }

    // Check if file exceeded size limit
    if written >= s.maxSize {
        os.Remove(fullPath)
        return nil, fmt.Errorf("file size exceeds maximum allowed size")
    }

    // Get image dimensions
    width, height := int32(0), int32(0)
    mimeType := metadata["content-type"]
    if mimeType == "" {
        // Re-open file to detect content type
        fileForDetection, _ := os.Open(fullPath)
        defer fileForDetection.Close()
        buffer := make([]byte, 512)
        n, _ := fileForDetection.Read(buffer)
        mimeType = http.DetectContentType(buffer[:n])
    }
    
    if strings.HasPrefix(mimeType, "image/") {
        fileForDimensions, _ := os.Open(fullPath)
        defer fileForDimensions.Close()
        w, h, err := getImageDimensions(fileForDimensions)
        if err == nil {
            width, height = int32(w), int32(h)
        }
    }

    // Generate public URL
    relativePath := filepath.Join(subDir, uniqueName)
    publicURL := fmt.Sprintf("%s/%s", s.baseURL, filepath.ToSlash(relativePath))
    
    return &UploadResult{
        URL:      publicURL,
        Key:      relativePath,
        Size:     int32(written),
        Width:    width,
        Height:   height,
        MimeType: mimeType,
    }, nil
}

func (s *LocalStorage) Download(ctx context.Context, key string) (io.ReadCloser, error) {
    fullPath := filepath.Join(s.basePath, key)
    
    // Security check: prevent path traversal
    if !filepath.HasPrefix(filepath.Clean(fullPath), s.basePath) {
        return nil, fmt.Errorf("invalid file path")
    }

    file, err := os.Open(fullPath)
    if err != nil {
        return nil, fmt.Errorf("failed to open file: %w", err)
    }

    return file, nil
}

func (s *LocalStorage) Delete(ctx context.Context, key string) error {
    fullPath := filepath.Join(s.basePath, key)
    
    // Security check
    if !filepath.HasPrefix(filepath.Clean(fullPath), s.basePath) {
        return fmt.Errorf("invalid file path")
    }

    if err := os.Remove(fullPath); err != nil {
        return fmt.Errorf("failed to delete file: %w", err)
    }

    return nil
}

// GetFileHash generates SHA256 hash for file verification
func (s *LocalStorage) GetFileHash(filePath string) (string, error) {
    file, err := os.Open(filePath)
    if err != nil {
        return "", err
    }
    defer file.Close()

    hash := sha256.New()
    if _, err := io.Copy(hash, file); err != nil {
        return "", err
    }

    return hex.EncodeToString(hash.Sum(nil)), nil
}
```

**Best Practices:**
- Use date-based directory structure (YYYY/MM/DD)
- Implement disk space monitoring
- Set up log rotation
- Configure proper file permissions (0644 for files, 0755 for directories)
- Use symbolic links for moved files
- Implement cleanup jobs for orphaned files
- Set up automated backups
- Use nginx for serving static files

**Nginx Configuration:**

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    # Upload size limit
    client_max_body_size 10M;

    # Image serving location
    location /uploads/ {
        alias /var/www/uploads/;
        
        # Security headers
        add_header X-Content-Type-Options nosniff;
        add_header X-Frame-Options DENY;
        
        # Cache control
        expires 1y;
        add_header Cache-Control "public, immutable";
        
        # Enable compression
        gzip on;
        gzip_types image/jpeg image/png image/webp;
    }

    # API endpoint
    location /api/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

### 4. AWS S3 Storage

**Use Cases:**
- Production environments
- High availability needed
- Global distribution
- Large scale applications

**Pros:**
✅ Highly scalable
✅ Global CDN (CloudFront)
✅ 99.999999999% durability
✅ Lifecycle policies
✅ Versioning support

**Cons:**
❌ Cost considerations
❌ Complexity
❌ External dependency

**Implementation:**

```go
package storage

import (
    "context"
    "fmt"
    "io"
    "path/filepath"
    "time"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/s3"
    "github.com/aws/aws-sdk-go-v2/service/s3/types"
    "github.com/google/uuid"
)

type S3Storage struct {
    client *s3.Client
    bucket string
    region string
    cdnURL string // Optional CloudFront URL
}

func NewS3Storage(bucket, region string) (*S3Storage, error) {
    cfg, err := config.LoadDefaultConfig(context.TODO(),
        config.WithRegion(region),
    )
    if err != nil {
        return nil, fmt.Errorf("failed to load AWS config: %w", err)
    }

    return &S3Storage{
        client: s3.NewFromConfig(cfg),
        bucket: bucket,
        region: region,
    }, nil
}

func (s *S3Storage) Upload(ctx context.Context, file io.Reader, filename string, metadata map[string]string) (*UploadResult, error) {
    // Generate unique key
    ext := filepath.Ext(filename)
    now := time.Now()
    key := fmt.Sprintf("images/%d/%02d/%02d/%s%s",
        now.Year(), now.Month(), now.Day(),
        uuid.New().String(), ext)

    // Read file to get size and dimensions
    fileData, err := io.ReadAll(file)
    if err != nil {
        return nil, fmt.Errorf("failed to read file: %w", err)
    }

    fileSize := int32(len(fileData))
    
    // Get image dimensions
    width, height := int32(0), int32(0)
    mimeType := metadata["content-type"]
    if mimeType == "" {
        mimeType = http.DetectContentType(fileData)
    }
    
    if strings.HasPrefix(mimeType, "image/") {
        w, h, err := getImageDimensions(bytes.NewReader(fileData))
        if err == nil {
            width, height = int32(w), int32(h)
        }
    }

    // Prepare upload input
    input := &s3.PutObjectInput{
        Bucket:      aws.String(s.bucket),
        Key:         aws.String(key),
        Body:        bytes.NewReader(fileData),
        ContentType: aws.String(mimeType),
        Metadata:    metadata,
        ACL:         types.ObjectCannedACLPublicRead, // Or private with signed URLs
    }

    // Add cache control
    if cacheControl, ok := metadata["cache-control"]; ok {
        input.CacheControl = aws.String(cacheControl)
    } else {
        input.CacheControl = aws.String("public, max-age=31536000") // 1 year
    }

    // Upload file
    _, err = s.client.PutObject(ctx, input)
    if err != nil {
        return nil, fmt.Errorf("failed to upload to S3: %w", err)
    }

    // Generate URL
    var publicURL string
    if s.cdnURL != "" {
        publicURL = fmt.Sprintf("%s/%s", s.cdnURL, key)
    } else {
        publicURL = fmt.Sprintf("https://%s.s3.%s.amazonaws.com/%s", 
            s.bucket, s.region, key)
    }

    return &UploadResult{
        URL:      publicURL,
        Key:      key,
        Size:     fileSize,
        Width:    width,
        Height:   height,
        MimeType: mimeType,
    }, nil
}

func (s *S3Storage) GetPresignedURL(ctx context.Context, key string, expiry time.Duration) (string, error) {
    presignClient := s3.NewPresignClient(s.client)

    presignedURL, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
        Bucket: aws.String(s.bucket),
        Key:    aws.String(key),
    }, s3.WithPresignExpires(expiry))

    if err != nil {
        return "", fmt.Errorf("failed to generate presigned URL: %w", err)
    }

    return presignedURL.URL, nil
}

func (s *S3Storage) Delete(ctx context.Context, key string) error {
    _, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
        Bucket: aws.String(s.bucket),
        Key:    aws.String(key),
    })

    if err != nil {
        return fmt.Errorf("failed to delete from S3: %w", err)
    }

    return nil
}

// MultipartUpload for large files (> 5GB)
func (s *S3Storage) MultipartUpload(ctx context.Context, file io.Reader, filename string, partSize int64) (string, error) {
    ext := filepath.Ext(filename)
    key := fmt.Sprintf("images/%s%s", uuid.New().String(), ext)

    // Create multipart upload
    createResp, err := s.client.CreateMultipartUpload(ctx, &s3.CreateMultipartUploadInput{
        Bucket: aws.String(s.bucket),
        Key:    aws.String(key),
    })
    if err != nil {
        return "", fmt.Errorf("failed to create multipart upload: %w", err)
    }

    uploadID := createResp.UploadId
    var completedParts []types.CompletedPart
    partNumber := int32(1)

    // Upload parts
    buffer := make([]byte, partSize)
    for {
        n, err := io.ReadFull(file, buffer)
        if err == io.EOF {
            break
        }
        if err != nil && err != io.ErrUnexpectedEOF {
            // Abort upload on error
            s.client.AbortMultipartUpload(ctx, &s3.AbortMultipartUploadInput{
                Bucket:   aws.String(s.bucket),
                Key:      aws.String(key),
                UploadId: uploadID,
            })
            return "", fmt.Errorf("failed to read file: %w", err)
        }

        // Upload part
        uploadResp, err := s.client.UploadPart(ctx, &s3.UploadPartInput{
            Bucket:     aws.String(s.bucket),
            Key:        aws.String(key),
            UploadId:   uploadID,
            PartNumber: aws.Int32(partNumber),
            Body:       io.NopCloser(io.LimitReader(file, int64(n))),
        })
        if err != nil {
            s.client.AbortMultipartUpload(ctx, &s3.AbortMultipartUploadInput{
                Bucket:   aws.String(s.bucket),
                Key:      aws.String(key),
                UploadId: uploadID,
            })
            return "", fmt.Errorf("failed to upload part: %w", err)
        }

        completedParts = append(completedParts, types.CompletedPart{
            ETag:       uploadResp.ETag,
            PartNumber: aws.Int32(partNumber),
        })

        partNumber++
    }

    // Complete multipart upload
    _, err = s.client.CompleteMultipartUpload(ctx, &s3.CompleteMultipartUploadInput{
        Bucket:   aws.String(s.bucket),
        Key:      aws.String(key),
        UploadId: uploadID,
        MultipartUpload: &types.CompletedMultipartUpload{
            Parts: completedParts,
        },
    })
    if err != nil {
        return "", fmt.Errorf("failed to complete multipart upload: %w", err)
    }

    publicURL := fmt.Sprintf("https://%s.s3.%s.amazonaws.com/%s", 
        s.bucket, s.region, key)

    return publicURL, nil
}
```

**Best Practices:**
- Use CloudFront for CDN
- Enable versioning for important files
- Set up lifecycle policies for old files
- Use S3 Transfer Acceleration for global uploads
- Implement multipart uploads for large files (> 100MB)
- Use IAM roles instead of access keys
- Enable server-side encryption
- Set up CloudWatch alarms for monitoring
- Use S3 Intelligent-Tiering for cost optimization

---

### 5. Cloudflare R2 Storage

**Use Cases:**
- Cost-effective alternative to S3
- Zero egress fees
- Global edge network
- S3-compatible API

**Pros:**
✅ No egress fees (major cost savings)
✅ S3-compatible API
✅ Global Cloudflare network
✅ Automatic caching at edge
✅ Lower storage costs than S3
✅ Built-in CDN

**Cons:**
❌ Newer service (less mature than S3)
❌ Fewer features than S3
❌ No lifecycle policies yet
❌ Limited regions

**Implementation:**

```go
package storage

import (
    "context"
    "fmt"
    "io"
    "path/filepath"
    "time"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/credentials"
    "github.com/aws/aws-sdk-go-v2/service/s3"
    "github.com/aws/aws-sdk-go-v2/service/s3/types"
    "github.com/google/uuid"
)

type R2Storage struct {
    client    *s3.Client
    bucket    string
    accountID string
    publicURL string // Custom domain or R2.dev URL
}

func NewR2Storage(accountID, accessKeyID, secretAccessKey, bucket string) (*R2Storage, error) {
    // R2 uses S3-compatible API with custom endpoint
    r2Resolver := aws.EndpointResolverWithOptionsFunc(func(service, region string, options ...interface{}) (aws.Endpoint, error) {
        return aws.Endpoint{
            URL: fmt.Sprintf("https://%s.r2.cloudflarestorage.com", accountID),
        }, nil
    })

    cfg, err := config.LoadDefaultConfig(context.TODO(),
        config.WithEndpointResolverWithOptions(r2Resolver),
        config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(
            accessKeyID,
            secretAccessKey,
            "",
        )),
        config.WithRegion("auto"), // R2 uses "auto" as region
    )
    if err != nil {
        return nil, fmt.Errorf("failed to load R2 config: %w", err)
    }

    return &R2Storage{
        client:    s3.NewFromConfig(cfg),
        bucket:    bucket,
        accountID: accountID,
        publicURL: fmt.Sprintf("https://pub-%s.r2.dev", accountID), // Or use custom domain
    }, nil
}

// SetCustomDomain sets a custom domain for public URLs
func (r *R2Storage) SetCustomDomain(domain string) {
    r.publicURL = domain
}

func (r *R2Storage) Upload(ctx context.Context, file io.Reader, filename string, metadata map[string]string) (*UploadResult, error) {
    // Generate unique key
    ext := filepath.Ext(filename)
    now := time.Now()
    key := fmt.Sprintf("images/%d/%02d/%02d/%s%s",
        now.Year(), now.Month(), now.Day(),
        uuid.New().String(), ext)

    // Read file to get size and detect content type
    fileData, err := io.ReadAll(file)
    if err != nil {
        return nil, fmt.Errorf("failed to read file: %w", err)
    }

    fileSize := int64(len(fileData))
    
    // Get dimensions if image
    width, height := int32(0), int32(0)
    if isImage(ext) {
        w, h, err := getImageDimensions(fileData)
        if err == nil {
            width, height = int32(w), int32(h)
        }
    }

    mimeType := metadata["content-type"]
    if mimeType == "" {
        mimeType = http.DetectContentType(fileData)
    }

    // Prepare upload input
    input := &s3.PutObjectInput{
        Bucket:      aws.String(r.bucket),
        Key:         aws.String(key),
        Body:        bytes.NewReader(fileData),
        ContentType: aws.String(mimeType),
        Metadata:    metadata,
        ACL:         types.ObjectCannedACLPublicRead,
    }

    // Add cache control
    if cacheControl, ok := metadata["cache-control"]; ok {
        input.CacheControl = aws.String(cacheControl)
    } else {
        input.CacheControl = aws.String("public, max-age=31536000") // 1 year
    }

    // Upload file
    _, err = r.client.PutObject(ctx, input)
    if err != nil {
        return nil, fmt.Errorf("failed to upload to R2: %w", err)
    }

    // Generate public URL
    publicURL := fmt.Sprintf("%s/%s", r.publicURL, key)

    // Generate thumbnail URL if applicable
    thumbnailURL := ""
    if isImage(ext) {
        thumbnailURL = fmt.Sprintf("%s/thumbnail/%s", r.publicURL, key)
    }

    return &UploadResult{
        URL:          publicURL,
        ThumbnailURL: thumbnailURL,
        Key:          key,
        Size:         int32(fileSize),
        Width:        width,
        Height:       height,
        MimeType:     mimeType,
    }, nil
}

func (r *R2Storage) Download(ctx context.Context, key string) (io.ReadCloser, error) {
    result, err := r.client.GetObject(ctx, &s3.GetObjectInput{
        Bucket: aws.String(r.bucket),
        Key:    aws.String(key),
    })
    if err != nil {
        return nil, fmt.Errorf("failed to download from R2: %w", err)
    }

    return result.Body, nil
}

func (r *R2Storage) Delete(ctx context.Context, key string) error {
    _, err := r.client.DeleteObject(ctx, &s3.DeleteObjectInput{
        Bucket: aws.String(r.bucket),
        Key:    aws.String(key),
    })

    if err != nil {
        return fmt.Errorf("failed to delete from R2: %w", err)
    }

    return nil
}

func (r *R2Storage) GetPresignedURL(ctx context.Context, key string, expiry time.Duration) (string, error) {
    presignClient := s3.NewPresignClient(r.client)

    presignedURL, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
        Bucket: aws.String(r.bucket),
        Key:    aws.String(key),
    }, s3.WithPresignExpires(expiry))

    if err != nil {
        return "", fmt.Errorf("failed to generate presigned URL: %w", err)
    }

    return presignedURL.URL, nil
}

// BatchUpload uploads multiple files concurrently to R2
func (r *R2Storage) BatchUpload(ctx context.Context, files []FileUpload) ([]*UploadResult, error) {
    results := make([]*UploadResult, len(files))
    errors := make([]error, len(files))

    var wg sync.WaitGroup
    semaphore := make(chan struct{}, 10) // Limit to 10 concurrent uploads

    for i, file := range files {
        wg.Add(1)
        go func(idx int, f FileUpload) {
            defer wg.Done()
            semaphore <- struct{}{}
            defer func() { <-semaphore }()

            result, err := r.Upload(ctx, f.Reader, f.Filename, f.Metadata)
            results[idx] = result
            errors[idx] = err
        }(i, file)
    }

    wg.Wait()

    // Check for errors
    var uploadErrors []error
    for _, err := range errors {
        if err != nil {
            uploadErrors = append(uploadErrors, err)
        }
    }

    if len(uploadErrors) > 0 {
        return results, fmt.Errorf("batch upload completed with %d errors", len(uploadErrors))
    }

    return results, nil
}

type FileUpload struct {
    Reader   io.Reader
    Filename string
    Metadata map[string]string
}
```

**R2-Specific Features:**

```go
// R2 Image Transformations using Cloudflare's built-in features
func (r *R2Storage) GetTransformedURL(key string, transformations ImageTransform) string {
    // R2 integrates with Cloudflare Images for transformations
    // Example: resize, format conversion, quality adjustment
    params := url.Values{}
    
    if transformations.Width > 0 {
        params.Add("width", fmt.Sprintf("%d", transformations.Width))
    }
    if transformations.Height > 0 {
        params.Add("height", fmt.Sprintf("%d", transformations.Height))
    }
    if transformations.Format != "" {
        params.Add("format", transformations.Format)
    }
    if transformations.Quality > 0 {
        params.Add("quality", fmt.Sprintf("%d", transformations.Quality))
    }

    return fmt.Sprintf("%s/%s?%s", r.publicURL, key, params.Encode())
}

type ImageTransform struct {
    Width   int
    Height  int
    Format  string // "webp", "avif", "jpeg", "png"
    Quality int    // 1-100
    Fit     string // "scale-down", "contain", "cover", "crop", "pad"
}

// Set up R2 bucket with public access via Cloudflare Workers
func (r *R2Storage) SetupPublicBucket() error {
    // Note: This requires Cloudflare Workers to be set up
    // Workers can handle image transformations and caching
    
    // Example Worker route: yourdomain.com/images/*
    // Worker code handles R2 access and image transformation
    
    return nil
}
```

**Cloudflare Worker for R2 Access (JavaScript example):**

```javascript
// worker.js - Deploy this to Cloudflare Workers
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const key = url.pathname.slice(1); // Remove leading /

    // Get object from R2
    const object = await env.MY_BUCKET.get(key);
    
    if (object === null) {
      return new Response('Not found', { status: 404 });
    }

    // Apply transformations if requested
    const width = url.searchParams.get('width');
    const height = url.searchParams.get('height');
    const format = url.searchParams.get('format');

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('etag', object.httpEtag);
    headers.set('cache-control', 'public, max-age=31536000');

    return new Response(object.body, {
      headers,
    });
  },
};
```

**Best Practices for R2:**
- Use custom domains for better branding
- Leverage Cloudflare Workers for image transformations
- Enable R2 public access for static assets
- Use presigned URLs for private content
- Implement caching strategies at edge
- Monitor usage through Cloudflare dashboard
- Use batch uploads for multiple files
- Set proper cache headers (1 year for immutable content)
- Use Cloudflare's global network for fast delivery
- Consider using Cloudflare Images for advanced transformations

**Cost Comparison:**

| Feature | AWS S3 | Cloudflare R2 |
|---------|--------|---------------|
| Storage | $0.023/GB/month | $0.015/GB/month |
| Egress | $0.09/GB | **FREE** |
| Operations | $0.005/1K writes | $0.0036/1K writes |
| CDN | CloudFront extra cost | Included |

**R2 is ideal when:**
- High bandwidth/egress traffic
- Global content delivery needed
- Cost optimization is priority
- Already using Cloudflare services

---

## Request Handling

### 1. API Endpoint Design

```go
package handler

import (
    "context"
    "encoding/json"
    "fmt"
    "io"
    "mime/multipart"
    "net/http"
    "path/filepath"
    "strings"
    "time"
)

type UploadRequest struct {
    Image       multipart.File `json:"-"`
    ImageHeader *multipart.FileHeader `json:"-"`
    Caption     string `json:"caption" validate:"required,max=500"`
    AltText     string `json:"alt_text" validate:"max=200"`
    Tags        []string `json:"tags" validate:"max=10"`
}

type UploadResponse struct {
    ID          string    `json:"id"`
    URL         string    `json:"url"`
    ThumbnailURL string   `json:"thumbnail_url,omitempty"`
    Caption     string    `json:"caption"`
    AltText     string    `json:"alt_text"`
    Tags        []string  `json:"tags"`
    Size        int64     `json:"size"`
    MimeType    string    `json:"mime_type"`
    Width       int       `json:"width"`
    Height      int       `json:"height"`
    CreatedAt   time.Time `json:"created_at"`
}

type ImageHandler struct {
    storage    StorageProvider
    maxSize    int64
    allowedExt map[string]bool
    validator  *validator.Validate
}

func NewImageHandler(storage StorageProvider, maxSize int64) *ImageHandler {
    return &ImageHandler{
        storage: storage,
        maxSize: maxSize,
        allowedExt: map[string]bool{
            ".jpg":  true,
            ".jpeg": true,
            ".png":  true,
            ".gif":  true,
            ".webp": true,
        },
        validator: validator.New(),
    }
}

// HandleUpload handles multipart form upload
func (h *ImageHandler) HandleUpload(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    // Parse multipart form (32MB in memory, rest on disk)
    if err := r.ParseMultipartForm(32 << 20); err != nil {
        h.respondError(w, http.StatusBadRequest, "Failed to parse form", err)
        return
    }
    defer r.MultipartForm.RemoveAll()

    // Get image file
    file, header, err := r.FormFile("image")
    if err != nil {
        h.respondError(w, http.StatusBadRequest, "Image file is required", err)
        return
    }
    defer file.Close()

    // Validate file size
    if header.Size > h.maxSize {
        h.respondError(w, http.StatusBadRequest, 
            fmt.Sprintf("File size exceeds maximum of %d bytes", h.maxSize), nil)
        return
    }

    // Validate file extension
    ext := strings.ToLower(filepath.Ext(header.Filename))
    if !h.allowedExt[ext] {
        h.respondError(w, http.StatusBadRequest, 
            "Invalid file type. Allowed: jpg, jpeg, png, gif, webp", nil)
        return
    }

    // Get form values
    caption := r.FormValue("caption")
    altText := r.FormValue("alt_text")
    tags := strings.Split(r.FormValue("tags"), ",")

    // Validate request
    req := &UploadRequest{
        Image:       file,
        ImageHeader: header,
        Caption:     caption,
        AltText:     altText,
        Tags:        tags,
    }

    if err := h.validator.Struct(req); err != nil {
        h.respondError(w, http.StatusBadRequest, "Validation failed", err)
        return
    }

    // Validate image format
    if err := h.validateImage(file); err != nil {
        h.respondError(w, http.StatusBadRequest, "Invalid image format", err)
        return
    }

    // Reset file pointer
    file.Seek(0, io.SeekStart)

    // Get image dimensions
    width, height, err := h.getImageDimensions(file)
    if err != nil {
        h.respondError(w, http.StatusBadRequest, "Failed to read image dimensions", err)
        return
    }

    // Reset file pointer again
    file.Seek(0, io.SeekStart)

    // Prepare metadata
    metadata := map[string]string{
        "content-type": header.Header.Get("Content-Type"),
        "caption":      caption,
        "alt-text":     altText,
        "width":        fmt.Sprintf("%d", width),
        "height":       fmt.Sprintf("%d", height),
    }

    // Upload to storage
    url, err := h.storage.Upload(ctx, file, header.Filename, metadata)
    if err != nil {
        h.respondError(w, http.StatusInternalServerError, "Failed to upload image", err)
        return
    }

    // Create response
    response := &UploadResponse{
        ID:        generateID(),
        URL:       url,
        Caption:   caption,
        AltText:   altText,
        Tags:      tags,
        Size:      header.Size,
        MimeType:  header.Header.Get("Content-Type"),
        Width:     width,
        Height:    height,
        CreatedAt: time.Now(),
    }

    h.respondJSON(w, http.StatusCreated, response)
}

// HandleUploadBase64 handles base64 encoded image upload
func (h *ImageHandler) HandleUploadBase64(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    var req struct {
        ImageData string   `json:"image_data" validate:"required"`
        Filename  string   `json:"filename" validate:"required"`
        Caption   string   `json:"caption" validate:"required,max=500"`
        AltText   string   `json:"alt_text" validate:"max=200"`
        Tags      []string `json:"tags" validate:"max=10"`
    }

    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        h.respondError(w, http.StatusBadRequest, "Invalid JSON", err)
        return
    }

    if err := h.validator.Struct(req); err != nil {
        h.respondError(w, http.StatusBadRequest, "Validation failed", err)
        return
    }

    // Decode base64
    data, err := base64.StdEncoding.DecodeString(req.ImageData)
    if err != nil {
        h.respondError(w, http.StatusBadRequest, "Invalid base64 data", err)
        return
    }

    // Validate size
    if int64(len(data)) > h.maxSize {
        h.respondError(w, http.StatusBadRequest, 
            fmt.Sprintf("File size exceeds maximum of %d bytes", h.maxSize), nil)
        return
    }

    // Upload
    reader := bytes.NewReader(data)
    metadata := map[string]string{
        "content-type": http.DetectContentType(data),
        "caption":      req.Caption,
        "alt-text":     req.AltText,
    }

    url, err := h.storage.Upload(ctx, reader, req.Filename, metadata)
    if err != nil {
        h.respondError(w, http.StatusInternalServerError, "Failed to upload image", err)
        return
    }

    response := &UploadResponse{
        ID:        generateID(),
        URL:       url,
        Caption:   req.Caption,
        AltText:   req.AltText,
        Tags:      req.Tags,
        Size:      int64(len(data)),
        MimeType:  http.DetectContentType(data),
        CreatedAt: time.Now(),
    }

    h.respondJSON(w, http.StatusCreated, response)
}

func (h *ImageHandler) respondJSON(w http.ResponseWriter, status int, data interface{}) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteStatus(status)
    json.NewEncoder(w).Encode(data)
}

func (h *ImageHandler) respondError(w http.ResponseWriter, status int, message string, err error) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(map[string]interface{}{
        "error":   message,
        "details": err.Error(),
    })
}
```

### 2. Validation

```go
package validation

import (
    "bytes"
    "fmt"
    "image"
    _ "image/gif"
    _ "image/jpeg"
    _ "image/png"
    "io"
    "net/http"

    _ "golang.org/x/image/webp"
)

func (h *ImageHandler) validateImage(file io.Reader) error {
    // Read first 512 bytes for content type detection
    buffer := make([]byte, 512)
    n, err := file.Read(buffer)
    if err != nil && err != io.EOF {
        return fmt.Errorf("failed to read file: %w", err)
    }

    // Detect content type
    contentType := http.DetectContentType(buffer[:n])
    
    allowedTypes := map[string]bool{
        "image/jpeg": true,
        "image/png":  true,
        "image/gif":  true,
        "image/webp": true,
    }

    if !allowedTypes[contentType] {
        return fmt.Errorf("invalid content type: %s", contentType)
    }

    return nil
}

func (h *ImageHandler) getImageDimensions(file io.Reader) (int, int, error) {
    // Decode image config (faster than full decode)
    config, _, err := image.DecodeConfig(file)
    if err != nil {
        return 0, 0, fmt.Errorf("failed to decode image: %w", err)
    }

    return config.Width, config.Height, nil
}

func ValidateImageDimensions(file io.Reader, minWidth, minHeight, maxWidth, maxHeight int) error {
    config, _, err := image.DecodeConfig(file)
    if err != nil {
        return fmt.Errorf("failed to decode image: %w", err)
    }

    if config.Width < minWidth || config.Height < minHeight {
        return fmt.Errorf("image too small: minimum %dx%d", minWidth, minHeight)
    }

    if config.Width > maxWidth || config.Height > maxHeight {
        return fmt.Errorf("image too large: maximum %dx%d", maxWidth, maxHeight)
    }

    return nil
}
```

---

## Image Processing

### 1. Thumbnail Generation

```go
package processing

import (
    "bytes"
    "fmt"
    "image"
    "image/jpeg"
    "image/png"
    "io"

    "github.com/disintegration/imaging"
)

type ImageProcessor struct {
    thumbnailWidth  int
    thumbnailHeight int
    quality         int
}

func NewImageProcessor() *ImageProcessor {
    return &ImageProcessor{
        thumbnailWidth:  300,
        thumbnailHeight: 300,
        quality:         85,
    }
}

func (p *ImageProcessor) GenerateThumbnail(file io.Reader, format string) (io.Reader, error) {
    // Decode image
    img, _, err := image.Decode(file)
    if err != nil {
        return nil, fmt.Errorf("failed to decode image: %w", err)
    }

    // Resize image maintaining aspect ratio
    thumbnail := imaging.Fit(img, p.thumbnailWidth, p.thumbnailHeight, imaging.Lanczos)

    // Encode thumbnail
    var buf bytes.Buffer
    switch format {
    case "jpeg", "jpg":
        err = jpeg.Encode(&buf, thumbnail, &jpeg.Options{Quality: p.quality})
    case "png":
        err = png.Encode(&buf, thumbnail)
    default:
        err = jpeg.Encode(&buf, thumbnail, &jpeg.Options{Quality: p.quality})
    }

    if err != nil {
        return nil, fmt.Errorf("failed to encode thumbnail: %w", err)
    }

    return &buf, nil
}

func (p *ImageProcessor) ResizeImage(file io.Reader, width, height int, format string) (io.Reader, error) {
    img, _, err := image.Decode(file)
    if err != nil {
        return nil, fmt.Errorf("failed to decode image: %w", err)
    }

    // Resize
    resized := imaging.Resize(img, width, height, imaging.Lanczos)

    // Encode
    var buf bytes.Buffer
    switch format {
    case "jpeg", "jpg":
        err = jpeg.Encode(&buf, resized, &jpeg.Options{Quality: p.quality})
    case "png":
        err = png.Encode(&buf, resized)
    default:
        return nil, fmt.Errorf("unsupported format: %s", format)
    }

    if err != nil {
        return nil, fmt.Errorf("failed to encode image: %w", err)
    }

    return &buf, nil
}

func (p *ImageProcessor) OptimizeImage(file io.Reader, format string) (io.Reader, error) {
    img, _, err := image.Decode(file)
    if err != nil {
        return nil, fmt.Errorf("failed to decode image: %w", err)
    }

    // Apply sharpening
    sharpened := imaging.Sharpen(img, 0.5)

    // Adjust brightness if needed
    adjusted := imaging.AdjustBrightness(sharpened, 0)

    var buf bytes.Buffer
    switch format {
    case "jpeg", "jpg":
        err = jpeg.Encode(&buf, adjusted, &jpeg.Options{Quality: p.quality})
    case "png":
        err = png.Encode(&buf, adjusted)
    default:
        return nil, fmt.Errorf("unsupported format: %s", format)
    }

    if err != nil {
        return nil, fmt.Errorf("failed to encode optimized image: %w", err)
    }

    return &buf, nil
}
```

### 2. Background Processing with Worker Queue

```go
package worker

import (
    "context"
    "fmt"
    "log"
    "sync"
)

type ImageJob struct {
    ID       string
    FilePath string
    Operations []string
}

type Worker struct {
    id         int
    jobQueue   chan ImageJob
    processor  *ImageProcessor
    storage    StorageProvider
    wg         *sync.WaitGroup
}

type WorkerPool struct {
    workers    []*Worker
    jobQueue   chan ImageJob
    numWorkers int
    wg         sync.WaitGroup
}

func NewWorkerPool(numWorkers int, processor *ImageProcessor, storage StorageProvider) *WorkerPool {
    jobQueue := make(chan ImageJob, 100)
    
    pool := &WorkerPool{
        workers:    make([]*Worker, numWorkers),
        jobQueue:   jobQueue,
        numWorkers: numWorkers,
    }

    // Create workers
    for i := 0; i < numWorkers; i++ {
        pool.workers[i] = &Worker{
            id:        i,
            jobQueue:  jobQueue,
            processor: processor,
            storage:   storage,
            wg:        &pool.wg,
        }
    }

    return pool
}

func (p *WorkerPool) Start(ctx context.Context) {
    for _, worker := range p.workers {
        p.wg.Add(1)
        go worker.start(ctx)
    }
}

func (p *WorkerPool) Stop() {
    close(p.jobQueue)
    p.wg.Wait()
}

func (p *WorkerPool) Submit(job ImageJob) {
    p.jobQueue <- job
}

func (w *Worker) start(ctx context.Context) {
    defer w.wg.Done()

    for {
        select {
        case job, ok := <-w.jobQueue:
            if !ok {
                return
            }
            w.processJob(ctx, job)
        case <-ctx.Done():
            return
        }
    }
}

func (w *Worker) processJob(ctx context.Context, job ImageJob) {
    log.Printf("Worker %d processing job %s", w.id, job.ID)

    // Process image operations
    for _, op := range job.Operations {
        switch op {
        case "thumbnail":
            // Generate thumbnail
        case "optimize":
            // Optimize image
        case "watermark":
            // Add watermark
        }
    }

    log.Printf("Worker %d completed job %s", w.id, job.ID)
}
```

---

## Security Best Practices

### 1. Input Validation

```go
package security

import (
    "crypto/rand"
    "encoding/hex"
    "fmt"
    "io"
    "net/http"
    "path/filepath"
    "strings"
)

// ValidateFileUpload performs comprehensive file validation
func ValidateFileUpload(file io.Reader, filename string, maxSize int64) error {
    // Check file extension
    ext := strings.ToLower(filepath.Ext(filename))
    allowedExts := map[string]bool{
        ".jpg":  true,
        ".jpeg": true,
        ".png":  true,
        ".gif":  true,
        ".webp": true,
    }

    if !allowedExts[ext] {
        return fmt.Errorf("file extension not allowed: %s", ext)
    }

    // Read first 512 bytes for magic number validation
    buffer := make([]byte, 512)
    n, err := file.Read(buffer)
    if err != nil {
        return fmt.Errorf("failed to read file: %w", err)
    }

    // Validate MIME type
    mimeType := http.DetectContentType(buffer[:n])
    allowedMimes := map[string]bool{
        "image/jpeg": true,
        "image/png":  true,
        "image/gif":  true,
        "image/webp": true,
    }

    if !allowedMimes[mimeType] {
        return fmt.Errorf("invalid MIME type: %s", mimeType)
    }

    // Validate that extension matches MIME type
    extToMime := map[string]string{
        ".jpg":  "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png":  "image/png",
        ".gif":  "image/gif",
        ".webp": "image/webp",
    }

    if extToMime[ext] != mimeType {
        return fmt.Errorf("file extension %s does not match MIME type %s", ext, mimeType)
    }

    return nil
}

// SanitizeFilename removes dangerous characters from filename
func SanitizeFilename(filename string) string {
    // Remove path separators
    filename = filepath.Base(filename)
    
    // Remove dangerous characters
    dangerous := []string{"..", "/", "\\", "\x00"}
    for _, char := range dangerous {
        filename = strings.ReplaceAll(filename, char, "")
    }

    return filename
}

// GenerateSecureFilename generates a random secure filename
func GenerateSecureFilename(originalFilename string) (string, error) {
    ext := filepath.Ext(originalFilename)
    
    // Generate 16 random bytes
    randomBytes := make([]byte, 16)
    if _, err := rand.Read(randomBytes); err != nil {
        return "", fmt.Errorf("failed to generate random bytes: %w", err)
    }

    // Convert to hex string
    randomName := hex.EncodeToString(randomBytes)
    
    return randomName + ext, nil
}
```

### 2. Rate Limiting

```go
package middleware

import (
    "net/http"
    "sync"
    "time"

    "golang.org/x/time/rate"
)

type RateLimiter struct {
    visitors map[string]*rate.Limiter
    mu       sync.RWMutex
    rate     rate.Limit
    burst    int
}

func NewRateLimiter(r rate.Limit, b int) *RateLimiter {
    return &RateLimiter{
        visitors: make(map[string]*rate.Limiter),
        rate:     r,
        burst:    b,
    }
}

func (rl *RateLimiter) getVisitor(ip string) *rate.Limiter {
    rl.mu.Lock()
    defer rl.mu.Unlock()

    limiter, exists := rl.visitors[ip]
    if !exists {
        limiter = rate.NewLimiter(rl.rate, rl.burst)
        rl.visitors[ip] = limiter
    }

    return limiter
}

func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        ip := r.RemoteAddr
        limiter := rl.getVisitor(ip)

        if !limiter.Allow() {
            http.Error(w, "Rate limit exceeded", http.StatusTooManyRequests)
            return
        }

        next.ServeHTTP(w, r)
    })
}

// Cleanup old visitors periodically
func (rl *RateLimiter) Cleanup(interval time.Duration) {
    ticker := time.NewTicker(interval)
    go func() {
        for range ticker.C {
            rl.mu.Lock()
            for ip, limiter := range rl.visitors {
                if limiter.Tokens() == float64(rl.burst) {
                    delete(rl.visitors, ip)
                }
            }
            rl.mu.Unlock()
        }
    }()
}
```

### 3. Authentication & Authorization

```go
package middleware

import (
    "context"
    "net/http"
    "strings"
)

type contextKey string

const UserContextKey contextKey = "user"

func AuthMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Get token from Authorization header
        authHeader := r.Header.Get("Authorization")
        if authHeader == "" {
            http.Error(w, "Authorization header required", http.StatusUnauthorized)
            return
        }

        // Extract bearer token
        parts := strings.Split(authHeader, " ")
        if len(parts) != 2 || parts[0] != "Bearer" {
            http.Error(w, "Invalid authorization header format", http.StatusUnauthorized)
            return
        }

        token := parts[1]

        // Validate token (implement your token validation logic)
        user, err := validateToken(token)
        if err != nil {
            http.Error(w, "Invalid token", http.StatusUnauthorized)
            return
        }

        // Add user to context
        ctx := context.WithValue(r.Context(), UserContextKey, user)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func validateToken(token string) (*User, error) {
    // Implement JWT validation or session validation
    return nil, nil
}
```

---

## Performance Optimization

### 1. Streaming Upload

```go
package handler

import (
    "context"
    "io"
    "net/http"
)

// StreamUpload handles large file uploads with streaming
func (h *ImageHandler) StreamUpload(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    // Get content type
    contentType := r.Header.Get("Content-Type")
    
    // Get filename from header
    filename := r.Header.Get("X-Filename")
    if filename == "" {
        filename = "upload"
    }

    // Create pipe for streaming
    pr, pw := io.Pipe()

    // Start upload in goroutine
    errChan := make(chan error, 1)
    urlChan := make(chan string, 1)

    go func() {
        defer pw.Close()
        
        metadata := map[string]string{
            "content-type": contentType,
        }

        url, err := h.storage.Upload(ctx, pr, filename, metadata)
        if err != nil {
            errChan <- err
            return
        }

        urlChan <- url
    }()

    // Copy request body to pipe
    go func() {
        defer pw.Close()
        io.Copy(pw, r.Body)
    }()

    // Wait for upload to complete
    select {
    case err := <-errChan:
        h.respondError(w, http.StatusInternalServerError, "Upload failed", err)
        return
    case url := <-urlChan:
        h.respondJSON(w, http.StatusCreated, map[string]string{"url": url})
        return
    case <-ctx.Done():
        h.respondError(w, http.StatusRequestTimeout, "Upload timeout", ctx.Err())
        return
    }
}
```

### 2. Concurrent Processing

```go
package processing

import (
    "context"
    "fmt"
    "sync"
)

type BatchProcessor struct {
    processor *ImageProcessor
    storage   StorageProvider
    maxWorkers int
}

func NewBatchProcessor(processor *ImageProcessor, storage StorageProvider, maxWorkers int) *BatchProcessor {
    return &BatchProcessor{
        processor:  processor,
        storage:    storage,
        maxWorkers: maxWorkers,
    }
}

func (bp *BatchProcessor) ProcessBatch(ctx context.Context, files []UploadFile) ([]string, error) {
    var (
        wg      sync.WaitGroup
        mu      sync.Mutex
        results []string
        errors  []error
    )

    // Create semaphore to limit concurrent workers
    semaphore := make(chan struct{}, bp.maxWorkers)

    for _, file := range files {
        wg.Add(1)
        
        go func(f UploadFile) {
            defer wg.Done()

            // Acquire semaphore
            semaphore <- struct{}{}
            defer func() { <-semaphore }()

            // Process file
            url, err := bp.processFile(ctx, f)
            
            mu.Lock()
            if err != nil {
                errors = append(errors, err)
            } else {
                results = append(results, url)
            }
            mu.Unlock()
        }(file)
    }

    wg.Wait()

    if len(errors) > 0 {
        return results, fmt.Errorf("batch processing completed with %d errors", len(errors))
    }

    return results, nil
}

func (bp *BatchProcessor) processFile(ctx context.Context, file UploadFile) (string, error) {
    // Process and upload file
    // Implementation details...
    return "", nil
}
```

### 3. Caching Strategy

```go
package cache

import (
    "context"
    "fmt"
    "time"

    "github.com/go-redis/redis/v8"
)

type ImageCache struct {
    client *redis.Client
    ttl    time.Duration
}

func NewImageCache(addr string, ttl time.Duration) *ImageCache {
    client := redis.NewClient(&redis.Options{
        Addr: addr,
    })

    return &ImageCache{
        client: client,
        ttl:    ttl,
    }
}

func (c *ImageCache) Set(ctx context.Context, key string, url string) error {
    return c.client.Set(ctx, key, url, c.ttl).Err()
}

func (c *ImageCache) Get(ctx context.Context, key string) (string, error) {
    val, err := c.client.Get(ctx, key).Result()
    if err == redis.Nil {
        return "", fmt.Errorf("key not found")
    }
    return val, err
}

func (c *ImageCache) Delete(ctx context.Context, key string) error {
    return c.client.Del(ctx, key).Err()
}

func (c *ImageCache) GetOrSet(ctx context.Context, key string, fn func() (string, error)) (string, error) {
    // Try to get from cache
    val, err := c.Get(ctx, key)
    if err == nil {
        return val, nil
    }

    // Generate value
    val, err = fn()
    if err != nil {
        return "", err
    }

    // Store in cache
    if err := c.Set(ctx, key, val); err != nil {
        // Log error but don't fail
        fmt.Printf("Failed to cache value: %v\n", err)
    }

    return val, nil
}
```

---

## Complete Example Application

```go
package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/gorilla/mux"
    "golang.org/x/time/rate"
)

func main() {
    // Configuration
    config := &Config{
        ServerPort:       ":8080",
        MaxUploadSize:    10 * 1024 * 1024, // 10MB
        StorageType:      os.Getenv("STORAGE_TYPE"), // "local", "s3", "r2", "supabase", "base64"
        LocalStoragePath: "/var/www/uploads",
        LocalBaseURL:     "http://localhost:8080/uploads",
        S3Bucket:         os.Getenv("S3_BUCKET"),
        S3Region:         os.Getenv("S3_REGION"),
        R2AccountID:      os.Getenv("R2_ACCOUNT_ID"),
        R2AccessKey:      os.Getenv("R2_ACCESS_KEY_ID"),
        R2SecretKey:      os.Getenv("R2_SECRET_ACCESS_KEY"),
        R2Bucket:         os.Getenv("R2_BUCKET"),
        SupabaseURL:      os.Getenv("SUPABASE_URL"),
        SupabaseKey:      os.Getenv("SUPABASE_KEY"),
        SupabaseBucket:   os.Getenv("SUPABASE_BUCKET"),
    }

    // Initialize storage based on configuration
    var storage StorageProvider
    var err error

    switch config.StorageType {
    case "local":
        storage, err = NewLocalStorage(config.LocalStoragePath, config.LocalBaseURL, config.MaxUploadSize)
    case "s3":
        storage, err = NewS3Storage(config.S3Bucket, config.S3Region)
    case "r2":
        storage, err = NewR2Storage(config.R2AccountID, config.R2AccessKey, config.R2SecretKey, config.R2Bucket)
    case "supabase":
        storage = NewSupabaseStorage(config.SupabaseURL, config.SupabaseKey, config.SupabaseBucket)
    case "base64":
        storage = NewBase64Storage(config.MaxUploadSize)
    default:
        log.Fatal("Invalid storage type")
    }

    if err != nil {
        log.Fatalf("Failed to initialize storage: %v", err)
    }

    // Initialize handler
    handler := NewImageHandler(storage, config.MaxUploadSize)

    // Initialize rate limiter (5 requests per second, burst of 10)
    rateLimiter := NewRateLimiter(rate.Limit(5), 10)
    rateLimiter.Cleanup(5 * time.Minute)

    // Setup router
    router := mux.NewRouter()

    // Apply middleware
    router.Use(rateLimiter.Middleware)
    router.Use(LoggingMiddleware)
    router.Use(CORSMiddleware)

    // Routes
    router.HandleFunc("/api/upload", handler.HandleUpload).Methods("POST")
    router.HandleFunc("/api/upload/base64", handler.HandleUploadBase64).Methods("POST")
    router.HandleFunc("/api/upload/stream", handler.StreamUpload).Methods("POST")
    
    // Health check
    router.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    }).Methods("GET")

    // Serve uploaded files (for local storage)
    if config.StorageType == "local" {
        router.PathPrefix("/uploads/").Handler(
            http.StripPrefix("/uploads/", 
                http.FileServer(http.Dir(config.LocalStoragePath)),
            ),
        )
    }

    // Create server
    srv := &http.Server{
        Addr:         config.ServerPort,
        Handler:      router,
        ReadTimeout:  30 * time.Second,
        WriteTimeout: 30 * time.Second,
        IdleTimeout:  60 * time.Second,
    }

    // Start server
    go func() {
        log.Printf("Server starting on %s", config.ServerPort)
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("Server error: %v", err)
        }
    }()

    // Graceful shutdown
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("Shutting down server...")

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatalf("Server forced to shutdown: %v", err)
    }

    log.Println("Server exited")
}

func LoggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        next.ServeHTTP(w, r)
        log.Printf("%s %s %v", r.Method, r.URL.Path, time.Since(start))
    })
}

func CORSMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }

        next.ServeHTTP(w, r)
    })
}

type Config struct {
    ServerPort       string
    MaxUploadSize    int64
    StorageType      string
    LocalStoragePath string
    LocalBaseURL     string
    S3Bucket         string
    S3Region         string
    R2AccountID      string
    R2AccessKey      string
    R2SecretKey      string
    R2Bucket         string
    SupabaseURL      string
    SupabaseKey      string
    SupabaseBucket   string
}
```

---

## Helper Functions

Add these helper functions used across all storage implementations:

```go
package storage

import (
    "bytes"
    "image"
    _ "image/gif"
    _ "image/jpeg"
    _ "image/png"
    "io"
    "strings"

    _ "golang.org/x/image/webp"
)

// getImageDimensions extracts width and height from image data
func getImageDimensions(data io.Reader) (int, int, error) {
    config, _, err := image.DecodeConfig(data)
    if err != nil {
        return 0, 0, err
    }
    return config.Width, config.Height, nil
}

// isImage checks if the file extension indicates an image
func isImage(ext string) bool {
    ext = strings.ToLower(ext)
    imageExts := map[string]bool{
        ".jpg":  true,
        ".jpeg": true,
        ".png":  true,
        ".gif":  true,
        ".webp": true,
    }
    return imageExts[ext]
}
```

---

## Environment Variables Example

Create a `.env` file for easy configuration:

```bash
# Server Configuration
SERVER_PORT=:8080
MAX_UPLOAD_SIZE=10485760  # 10MB in bytes

# Storage Provider Selection
# Options: local, s3, r2, supabase, base64
STORAGE_TYPE=r2

# Local Storage (for STORAGE_TYPE=local)
LOCAL_STORAGE_PATH=/var/www/uploads
LOCAL_BASE_URL=http://localhost:8080/uploads

# AWS S3 (for STORAGE_TYPE=s3)
S3_BUCKET=my-bucket
S3_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key

# Cloudflare R2 (for STORAGE_TYPE=r2)
R2_ACCOUNT_ID=your-account-id
R2_ACCESS_KEY_ID=your-r2-access-key
R2_SECRET_ACCESS_KEY=your-r2-secret-key
R2_BUCKET=my-r2-bucket

# Supabase (for STORAGE_TYPE=supabase)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_BUCKET=images

# Database Connection
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
```

---

## Database Schema Example

SQL schema for storing image metadata (PostgreSQL with sqlc):

```sql
-- schema.sql
CREATE TABLE IF NOT EXISTS photos (
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
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP,
    
    INDEX idx_sender_id (sender_id),
    INDEX idx_created_at (created_at),
    INDEX idx_expires_at (expires_at) WHERE expires_at IS NOT NULL
);

-- sqlc queries
-- name: CreatePhoto :one
INSERT INTO photos (
    sender_id,
    photo_url,
    thumbnail_url,
    file_size,
    width,
    height,
    mime_type,
    caption,
    expires_at
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9
)
RETURNING *;

-- name: GetPhoto :one
SELECT * FROM photos
WHERE id = $1 AND deleted_at IS NULL;

-- name: GetPhotosBySender :many
SELECT * FROM photos
WHERE sender_id = $1 AND deleted_at IS NULL
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: DeletePhoto :exec
UPDATE photos
SET deleted_at = NOW()
WHERE id = $1;

-- name: CleanupExpiredPhotos :many
SELECT * FROM photos
WHERE expires_at IS NOT NULL 
  AND expires_at < NOW()
  AND deleted_at IS NULL;
```

---

## Dependencies

```go
// go.mod
module imageupload

go 1.21

require (
    github.com/aws/aws-sdk-go-v2 v1.21.0
    github.com/aws/aws-sdk-go-v2/config v1.18.42
    github.com/aws/aws-sdk-go-v2/credentials v1.13.40
    github.com/aws/aws-sdk-go-v2/service/s3 v1.40.0
    github.com/disintegration/imaging v1.6.2
    github.com/go-playground/validator/v10 v10.15.5
    github.com/go-redis/redis/v8 v8.11.5
    github.com/google/uuid v1.3.1
    github.com/gorilla/mux v1.8.0
    github.com/jackc/pgx/v5 v5.5.0
    github.com/joho/godotenv v1.5.1
    golang.org/x/image v0.13.0
    golang.org/x/time v0.3.0
)
```

---

## Quick Start Guide

### 1. Install Dependencies

```bash
go mod init imageupload
go get github.com/aws/aws-sdk-go-v2/service/s3
go get github.com/google/uuid
go get github.com/gorilla/mux
go get github.com/disintegration/imaging
go get golang.org/x/time/rate
```

### 2. Choose Your Storage Provider

**For Cloudflare R2 (Recommended for high traffic):**
```bash
export STORAGE_TYPE=r2
export R2_ACCOUNT_ID=your-account-id
export R2_ACCESS_KEY_ID=your-access-key
export R2_SECRET_ACCESS_KEY=your-secret-key
export R2_BUCKET=my-images
```

**For AWS S3:**
```bash
export STORAGE_TYPE=s3
export S3_BUCKET=my-bucket
export S3_REGION=us-east-1
```

**For Local Development:**
```bash
export STORAGE_TYPE=local
export LOCAL_STORAGE_PATH=/var/www/uploads
export LOCAL_BASE_URL=http://localhost:8080/uploads
```

### 3. Run the Server

```bash
go run main.go
```

### 4. Test Upload

```bash
# Multipart form upload
curl -X POST http://localhost:8080/api/upload \
  -F "image=@photo.jpg" \
  -F "caption=My awesome photo" \
  -F "alt_text=A beautiful landscape"

# Base64 upload
curl -X POST http://localhost:8080/api/upload/base64 \
  -H "Content-Type: application/json" \
  -d '{
    "image_data": "'"$(base64 -i photo.jpg)"'",
    "filename": "photo.jpg",
    "caption": "My awesome photo"
  }'
```

---

## Summary

### Storage Selection Guide

| Storage | Best For | Cost | Complexity | Scalability | Egress Fees |
|---------|----------|------|------------|-------------|-------------|
| **Base64** | Small images, embedded data | Free | Low | Low | N/A |
| **Local** | Development, small apps | Free | Low | Medium | N/A |
| **Supabase** | Full-stack apps, quick setup | Paid | Medium | High | Yes |
| **AWS S3** | Production, enterprise | Paid | High | Very High | Yes (expensive) |
| **Cloudflare R2** | High traffic, cost optimization | Paid | Medium | Very High | **No (FREE)** |

### Key Takeaways

1. **Use interface-based design** for easy storage provider switching
2. **Always validate file types** using both extension and MIME type
3. **Implement rate limiting** to prevent abuse
4. **Use streaming** for large file uploads
5. **Generate unique filenames** to prevent collisions
6. **Process images asynchronously** for better performance
7. **Implement proper error handling** and logging
8. **Use CDN** for serving static files in production (R2/S3/Supabase)
9. **Set appropriate file size limits**
10. **Sanitize filenames** to prevent security issues
11. **Use context for timeout and cancellation**
12. **Store metadata in database** with proper schema design
13. **Choose Cloudflare R2 for cost savings** (zero egress fees)
14. **Return structured results** that map to database schema

### Storage Provider Recommendations

**Development:**
- Use **Local Storage** - Simple, fast, no costs

**Production (Low Traffic):**
- Use **Supabase** - Quick setup, integrated auth, CDN included

**Production (High Traffic):**
- Use **Cloudflare R2** - Zero egress fees, fast global delivery
- Alternative: **AWS S3** (if already in AWS ecosystem)

**Special Cases:**
- **Base64**: Only for very small images (< 50KB) embedded in JSON
- **Multi-Provider**: Use primary + backup for high availability

### Easy Storage Switching Example

```go
// No code changes needed to switch providers!
// Just change environment variable:

// Start with local for development
export STORAGE_TYPE=local

// Move to R2 for production
export STORAGE_TYPE=r2
export R2_ACCOUNT_ID=xxx
export R2_ACCESS_KEY_ID=xxx
export R2_SECRET_ACCESS_KEY=xxx
export R2_BUCKET=production-images

// That's it! Your application code remains unchanged.
```

---

## Testing

### Unit Test Example

```go
package handler

import (
    "bytes"
    "mime/multipart"
    "net/http"
    "net/http/httptest"
    "testing"
)

func TestImageUpload(t *testing.T) {
    // Create a test storage
    storage := NewBase64Storage(1024 * 1024)
    handler := NewImageHandler(storage, 1024*1024)

    // Create a test image
    var buf bytes.Buffer
    writer := multipart.NewWriter(&buf)
    
    part, err := writer.CreateFormFile("image", "test.jpg")
    if err != nil {
        t.Fatal(err)
    }
    
    // Write test image data
    part.Write([]byte("fake-image-data"))
    writer.WriteField("caption", "Test caption")
    writer.Close()

    // Create request
    req := httptest.NewRequest("POST", "/api/upload", &buf)
    req.Header.Set("Content-Type", writer.FormDataContentType())

    // Create response recorder
    rr := httptest.NewRecorder()

    // Call handler
    handler.HandleUpload(rr, req)

    // Check status code
    if status := rr.Code; status != http.StatusCreated {
        t.Errorf("handler returned wrong status code: got %v want %v",
            status, http.StatusCreated)
    }
}
```

---

## Complete Integration Example

Here's a complete example showing how to integrate storage with your database layer:

```go
package main

import (
    "context"
    "database/sql"
    "fmt"
    "io"
    "time"

    "github.com/google/uuid"
    "github.com/jackc/pgx/v5/pgtype"
)

// PhotoService integrates storage and database
type PhotoService struct {
    storage StorageProvider
    queries *Queries // sqlc generated
}

func NewPhotoService(storage StorageProvider, db *sql.DB) *PhotoService {
    return &PhotoService{
        storage: storage,
        queries: New(db),
    }
}

// UploadPhoto handles complete photo upload workflow
func (s *PhotoService) UploadPhoto(
    ctx context.Context,
    file io.Reader,
    filename string,
    senderID uuid.UUID,
    caption *string,
    expiresIn *time.Duration,
) (*Photo, error) {
    // 1. Upload to storage provider (automatically detects dimensions, size, etc.)
    result, err := s.storage.Upload(ctx, file, filename, map[string]string{
        "sender_id": senderID.String(),
    })
    if err != nil {
        return nil, fmt.Errorf("storage upload failed: %w", err)
    }

    // 2. Calculate expiration time if needed
    var expiresAt pgtype.Timestamp
    if expiresIn != nil {
        expireTime := time.Now().Add(*expiresIn)
        expiresAt = pgtype.Timestamp{
            Time:  expireTime,
            Valid: true,
        }
    }

    // 3. Prepare database parameters (maps perfectly to your schema)
    params := CreatePhotoParams{
        SenderID:     pgtype.UUID{Bytes: senderID, Valid: true},
        PhotoUrl:     result.URL,
        ThumbnailUrl: &result.ThumbnailURL,
        FileSize:     &result.Size,
        Width:        &result.Width,
        Height:       &result.Height,
        MimeType:     &result.MimeType,
        Caption:      caption,
        ExpiresAt:    expiresAt,
    }

    // 4. Save to database
    photo, err := s.queries.CreatePhoto(ctx, params)
    if err != nil {
        // Cleanup: Delete uploaded file if database insert fails
        if deleteErr := s.storage.Delete(ctx, result.Key); deleteErr != nil {
            // Log error but don't fail - original error is more important
            fmt.Printf("Failed to cleanup after DB error: %v\n", deleteErr)
        }
        return nil, fmt.Errorf("database insert failed: %w", err)
    }

    return &photo, nil
}

// DeletePhoto removes photo from both storage and database
func (s *PhotoService) DeletePhoto(ctx context.Context, photoID uuid.UUID) error {
    // 1. Get photo from database
    photo, err := s.queries.GetPhoto(ctx, photoID)
    if err != nil {
        return fmt.Errorf("photo not found: %w", err)
    }

    // 2. Extract storage key from URL
    key := extractKeyFromURL(photo.PhotoUrl)

    // 3. Delete from storage
    if err := s.storage.Delete(ctx, key); err != nil {
        // Log but don't fail - continue to mark as deleted in DB
        fmt.Printf("Failed to delete from storage: %v\n", err)
    }

    // 4. Soft delete in database
    if err := s.queries.DeletePhoto(ctx, photoID); err != nil {
        return fmt.Errorf("database delete failed: %w", err)
    }

    return nil
}

// CleanupExpiredPhotos runs periodically to clean up expired photos
func (s *PhotoService) CleanupExpiredPhotos(ctx context.Context) error {
    // 1. Find expired photos
    expiredPhotos, err := s.queries.CleanupExpiredPhotos(ctx)
    if err != nil {
        return fmt.Errorf("failed to find expired photos: %w", err)
    }

    // 2. Delete each photo
    for _, photo := range expiredPhotos {
        if err := s.DeletePhoto(ctx, photo.ID); err != nil {
            // Log but continue with other photos
            fmt.Printf("Failed to delete expired photo %s: %v\n", photo.ID, err)
        }
    }

    return nil
}

// BatchUpload handles multiple file uploads
func (s *PhotoService) BatchUpload(
    ctx context.Context,
    files []FileUploadRequest,
    senderID uuid.UUID,
) ([]*Photo, error) {
    photos := make([]*Photo, 0, len(files))
    
    for _, file := range files {
        photo, err := s.UploadPhoto(
            ctx,
            file.Reader,
            file.Filename,
            senderID,
            file.Caption,
            file.ExpiresIn,
        )
        if err != nil {
            // You can choose to fail all or continue with successful uploads
            return photos, fmt.Errorf("failed to upload %s: %w", file.Filename, err)
        }
        photos = append(photos, photo)
    }

    return photos, nil
}

type FileUploadRequest struct {
    Reader    io.Reader
    Filename  string
    Caption   *string
    ExpiresIn *time.Duration
}

// Helper function to extract storage key from URL
func extractKeyFromURL(url string) string {
    // Implementation depends on your URL structure
    // For date-based: extract "images/2024/10/28/uuid.jpg"
    // For flat: extract "uuid.jpg"
    return url // Simplified
}

// HTTP Handler Integration
type PhotoHandler struct {
    service *PhotoService
}

func (h *PhotoHandler) HandleUpload(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    
    // 1. Parse multipart form
    if err := r.ParseMultipartForm(32 << 20); err != nil {
        respondError(w, http.StatusBadRequest, err)
        return
    }
    defer r.MultipartForm.RemoveAll()

    // 2. Get file
    file, header, err := r.FormFile("image")
    if err != nil {
        respondError(w, http.StatusBadRequest, err)
        return
    }
    defer file.Close()

    // 3. Get sender ID from auth context (set by auth middleware)
    senderID := r.Context().Value(UserContextKey).(uuid.UUID)

    // 4. Get optional caption
    var caption *string
    if c := r.FormValue("caption"); c != "" {
        caption = &c
    }

    // 5. Upload photo (service handles both storage and database)
    photo, err := h.service.UploadPhoto(ctx, file, header.Filename, senderID, caption, nil)
    if err != nil {
        respondError(w, http.StatusInternalServerError, err)
        return
    }

    // 6. Return response
    respondJSON(w, http.StatusCreated, photo)
}
```

### Example Usage in Your Application

```go
func main() {
    // 1. Initialize storage (easy to switch!)
    storage, err := InitializeStorage(config)
    if err != nil {
        log.Fatal(err)
    }

    // 2. Initialize database
    db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        log.Fatal(err)
    }

    // 3. Create service layer
    photoService := NewPhotoService(storage, db)

    // 4. Set up cleanup job for expired photos
    go func() {
        ticker := time.NewTicker(1 * time.Hour)
        for range ticker.C {
            if err := photoService.CleanupExpiredPhotos(context.Background()); err != nil {
                log.Printf("Cleanup failed: %v", err)
            }
        }
    }()

    // 5. Create HTTP handlers
    photoHandler := &PhotoHandler{service: photoService}

    // 6. Set up routes
    router := mux.NewRouter()
    router.HandleFunc("/api/photos", photoHandler.HandleUpload).Methods("POST")
    router.HandleFunc("/api/photos/{id}", photoHandler.HandleDelete).Methods("DELETE")

    // 7. Start server
    log.Fatal(http.ListenAndServe(":8080", router))
}
```

---

**Created:** October 28, 2025  
**Last Updated:** October 28, 2025  
**Version:** 2.0  
**Storage Providers:** Base64, Local, Supabase, AWS S3, Cloudflare R2
