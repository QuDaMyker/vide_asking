# Chat Feature Best Practices for Rocket App

## Overview
This document outlines best practices for implementing P2P (peer-to-peer) and group chat features in the Rocket app, including text messages, image attachments, and message reactions.

## Table of Contents
1. [Architecture Design](#architecture-design)
2. [Database Schema Design](#database-schema-design)
3. [Message Types & Structure](#message-types--structure)
4. [Real-time Communication](#real-time-communication)
5. [Storage Strategy](#storage-strategy)
6. [Security & Privacy](#security--privacy)
7. [Performance Optimization](#performance-optimization)
8. [Scalability Considerations](#scalability-considerations)
9. [API Design](#api-design)
10. [Implementation Checklist](#implementation-checklist)

---

## 1. Architecture Design

### Message Flow Architecture
```
User A                    Backend                     User B
  |                          |                          |
  |---> Send Message ------->|                          |
  |      (HTTP/WS)           |                          |
  |                          |----> Store in DB         |
  |                          |----> Push Notification   |
  |                          |----> WebSocket Push ---->|
  |<---- Confirmation -------|                          |
  |                          |<---- Read Receipt -------|
```

### Key Design Principles

#### 1.1 Separate Concerns
- **Photos**: Keep existing photo sharing separate
- **Chat**: New dedicated chat tables
- **Shared**: Reuse users, friendships, notifications

#### 1.2 Conversation-Centric Design
- Every message belongs to a conversation
- Conversations can be P2P or group
- Maintain conversation metadata separately

#### 1.3 Message Delivery Tracking
- Track delivery status per recipient
- Support read receipts
- Handle offline message queuing

---

## 2. Database Schema Design

### 2.1 Core Tables

#### conversations
```sql
- conversation_id: Primary identifier
- type: ENUM('direct', 'group')
- name: For group chats only
- photo_url: Group avatar
- created_by: Creator user_id
- created_at, updated_at
- last_message_at: For sorting conversations
- is_archived: Soft delete
```

**Best Practice**: Use composite indexes on (user_id, last_message_at) for fast conversation listing.

#### conversation_participants
```sql
- participant_id: Primary key
- conversation_id: Foreign key
- user_id: Foreign key
- role: ENUM('owner', 'admin', 'member')
- joined_at: When user joined
- left_at: NULL if active
- is_muted: Notification preference
- last_read_message_id: For unread count
```

**Best Practice**: Always validate participant membership before allowing message access.

#### messages
```sql
- message_id: UUID primary key
- conversation_id: Foreign key
- sender_id: Foreign key to users
- message_type: ENUM('text', 'image', 'system')
- content: TEXT for text messages
- metadata: JSONB for attachments, mentions, etc.
- reply_to_message_id: For threaded replies
- is_edited: Track if message was edited
- edited_at: Timestamp of last edit
- is_deleted: Soft delete
- deleted_at: Deletion timestamp
- created_at: Message timestamp
```

**Best Practice**: Use JSONB for flexible metadata while maintaining queryable structure.

#### message_attachments
```sql
- attachment_id: UUID
- message_id: Foreign key
- file_type: ENUM('image', 'video', 'document')
- file_url: Storage URL
- thumbnail_url: For images/videos
- file_name: Original filename
- file_size: In bytes
- mime_type: Content type
- width, height: For images/videos
- duration: For videos
- upload_status: ENUM('uploading', 'completed', 'failed')
```

**Best Practice**: Store attachments separately for easier management and CDN integration.

#### message_receipts
```sql
- receipt_id: UUID
- message_id: Foreign key
- user_id: Foreign key
- delivered_at: When message was delivered
- read_at: When message was read
- status: ENUM('sent', 'delivered', 'read', 'failed')
```

**Best Practice**: Batch receipt updates to reduce database load.

#### message_reactions
```sql
- reaction_id: UUID
- message_id: Foreign key
- user_id: Foreign key
- emoji: VARCHAR(10)
- created_at: Timestamp
- UNIQUE(message_id, user_id, emoji)
```

**Best Practice**: Limit to 6-8 unique emojis per message to prevent abuse.

### 2.2 Indexes Strategy

```sql
-- Fast conversation lookup
CREATE INDEX idx_conversations_participants 
ON conversation_participants(user_id, left_at, conversation_id);

-- Message pagination
CREATE INDEX idx_messages_conversation_time 
ON messages(conversation_id, created_at DESC) 
WHERE is_deleted = FALSE;

-- Unread messages
CREATE INDEX idx_message_receipts_unread 
ON message_receipts(user_id, read_at) 
WHERE read_at IS NULL;

-- Search messages
CREATE INDEX idx_messages_content_gin 
ON messages USING gin(to_tsvector('english', content));
```

### 2.3 Partitioning Strategy

For high-scale applications:

```sql
-- Partition messages by month
CREATE TABLE messages (
    message_id UUID,
    created_at TIMESTAMP,
    ...
) PARTITION BY RANGE (created_at);

CREATE TABLE messages_2025_01 PARTITION OF messages
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
```

---

## 3. Message Types & Structure

### 3.1 Text Message
```json
{
  "message_id": "uuid",
  "type": "text",
  "content": "Hello world!",
  "metadata": {
    "mentions": ["@user123"],
    "links": ["https://example.com"]
  }
}
```

### 3.2 Image Message
```json
{
  "message_id": "uuid",
  "type": "image",
  "content": "Optional caption",
  "metadata": {
    "attachment_id": "uuid",
    "image_url": "https://cdn.../image.jpg",
    "thumbnail_url": "https://cdn.../thumb.jpg",
    "width": 1920,
    "height": 1080,
    "file_size": 2048000
  }
}
```

### 3.3 System Message
```json
{
  "message_id": "uuid",
  "type": "system",
  "content": "John added Sarah to the group",
  "metadata": {
    "action": "member_added",
    "actor_id": "john_uuid",
    "target_id": "sarah_uuid"
  }
}
```

---

## 4. Real-time Communication

### 4.1 Technology Stack Options

#### Option 1: WebSocket (Recommended)
- **Pros**: True bidirectional, low latency, efficient
- **Cons**: More complex infrastructure
- **Use**: Socket.io, Gorilla WebSocket (Go)

```go
// Example WebSocket event structure
type MessageEvent struct {
    Type          string    `json:"type"` // "message.new", "message.read"
    ConversationID string   `json:"conversation_id"`
    Message       Message   `json:"message"`
    Timestamp     time.Time `json:"timestamp"`
}
```

#### Option 2: Server-Sent Events (SSE)
- **Pros**: Simpler than WebSocket, HTTP-based
- **Cons**: One-way only, less efficient
- **Use**: Notifications, updates

#### Option 3: Long Polling
- **Pros**: Maximum compatibility
- **Cons**: Inefficient, high latency
- **Use**: Fallback only

### 4.2 Connection Management

```go
// Best Practice: Connection pool per user
type ConnectionManager struct {
    connections map[string][]*WebSocketConn // userID -> connections
    mutex       sync.RWMutex
}

// Handle multiple devices per user
func (cm *ConnectionManager) BroadcastToUser(userID string, message []byte) {
    cm.mutex.RLock()
    defer cm.mutex.RUnlock()
    
    for _, conn := range cm.connections[userID] {
        conn.WriteMessage(websocket.TextMessage, message)
    }
}
```

### 4.3 Presence System

```sql
CREATE TABLE user_presence (
    user_id UUID PRIMARY KEY,
    status VARCHAR(20), -- 'online', 'away', 'offline'
    last_seen_at TIMESTAMP,
    device_count INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Best Practice**: Update presence every 30-60 seconds, not on every message.

---

## 5. Storage Strategy

### 5.1 Image Storage Architecture

```
Upload Flow:
1. Client -> Generate pre-signed URL from server
2. Client -> Direct upload to S3/Cloud Storage
3. Client -> Notify server upload complete
4. Server -> Create message with attachment reference
```

### 5.2 Storage Options

#### AWS S3 (Recommended)
```go
type StorageConfig struct {
    Bucket         string
    Region         string
    CDNDomain      string // CloudFront
    UploadTimeout  time.Duration
    MaxFileSize    int64 // 10MB for images
}

// Generate pre-signed URL
func GenerateUploadURL(filename string, contentType string) (string, error) {
    key := fmt.Sprintf("messages/%s/%s", uuid.New(), filename)
    req, _ := s3Client.PutObjectRequest(&s3.PutObjectInput{
        Bucket:      aws.String(bucket),
        Key:         aws.String(key),
        ContentType: aws.String(contentType),
    })
    return req.Presign(15 * time.Minute)
}
```

#### Alternative: MinIO (Self-hosted)
- Compatible with S3 API
- Full control over data
- Lower costs for high volume

### 5.3 Image Processing Pipeline

```go
type ImageProcessor struct {
    // 1. Validate image
    // 2. Generate thumbnail (200x200)
    // 3. Optimize original (reduce quality if needed)
    // 4. Upload both to storage
    // 5. Return URLs
}

// Best Practice: Process async with job queue
func ProcessImageAsync(imageID string) {
    job := &ImageProcessJob{
        ImageID: imageID,
        Priority: "normal",
    }
    queue.Enqueue(job)
}
```

### 5.4 Retention Policy

```sql
-- Auto-delete old message attachments
CREATE OR REPLACE FUNCTION cleanup_old_attachments()
RETURNS void AS $$
BEGIN
    -- Mark for deletion (process by background worker)
    UPDATE message_attachments
    SET deleted_at = CURRENT_TIMESTAMP
    WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '90 days'
    AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql;
```

---

## 6. Security & Privacy

### 6.1 Access Control

```go
// Middleware to verify conversation access
func VerifyConversationAccess(conversationID, userID string) error {
    var exists bool
    err := db.QueryRow(`
        SELECT EXISTS(
            SELECT 1 FROM conversation_participants
            WHERE conversation_id = $1 
            AND user_id = $2 
            AND left_at IS NULL
        )
    `, conversationID, userID).Scan(&exists)
    
    if !exists {
        return errors.New("unauthorized access")
    }
    return nil
}
```

### 6.2 Content Moderation

```go
type ContentModerator interface {
    CheckText(content string) (bool, error)
    CheckImage(imageURL string) (bool, error)
}

// Integrate with services like:
// - AWS Rekognition
// - Google Cloud Vision API
// - Azure Content Moderator
```

### 6.3 Rate Limiting

```go
// Redis-based rate limiter
type RateLimiter struct {
    MaxMessagesPerMinute int
    MaxImagesPerHour     int
}

// Example: 60 messages/min, 20 images/hour
func (rl *RateLimiter) CheckLimit(userID string, messageType string) bool {
    key := fmt.Sprintf("ratelimit:%s:%s", userID, messageType)
    count := redis.Incr(key)
    
    if count == 1 {
        redis.Expire(key, 60*time.Second)
    }
    
    return count <= rl.MaxMessagesPerMinute
}
```

### 6.4 Encryption

```go
// End-to-end encryption for sensitive chats
type MessageEncryption struct {
    Algorithm string // "AES-256-GCM"
}

// Store only encrypted content
message.Content = encrypt(plaintext, conversationKey)
message.Metadata["encrypted"] = true
```

**Best Practice**: For true E2E encryption, use Signal Protocol or similar.

---

## 7. Performance Optimization

### 7.1 Pagination Strategy

```go
// Cursor-based pagination (recommended)
type MessagePagination struct {
    ConversationID string    `json:"conversation_id"`
    BeforeID       string    `json:"before_id"`  // Get messages before this
    Limit          int       `json:"limit"`      // Default 50
}

// Query
SELECT * FROM messages
WHERE conversation_id = $1
AND ($2 = '' OR created_at < (
    SELECT created_at FROM messages WHERE message_id = $2
))
ORDER BY created_at DESC
LIMIT $3
```

### 7.2 Caching Strategy

```go
// Redis cache for hot data
type ConversationCache struct {
    // Recent messages (last 50)
    Key: "conv:{conversation_id}:messages"
    TTL: 1 hour
    
    // Unread counts
    Key: "user:{user_id}:unread"
    TTL: 5 minutes
    
    // Typing indicators
    Key: "conv:{conversation_id}:typing"
    TTL: 10 seconds
}
```

### 7.3 Database Query Optimization

```sql
-- Bad: N+1 query problem
SELECT * FROM messages WHERE conversation_id = $1;
-- Then for each message: SELECT * FROM users WHERE user_id = sender_id

-- Good: Join in single query
SELECT 
    m.*,
    u.username,
    u.display_name,
    u.profile_photo_url,
    COUNT(mr.reaction_id) as reaction_count
FROM messages m
JOIN users u ON m.sender_id = u.user_id
LEFT JOIN message_reactions mr ON m.message_id = mr.message_id
WHERE m.conversation_id = $1
GROUP BY m.message_id, u.user_id
ORDER BY m.created_at DESC
LIMIT 50;
```

### 7.4 Connection Pooling

```go
// PostgreSQL connection pool
db, err := sql.Open("postgres", connStr)
db.SetMaxOpenConns(25)
db.SetMaxIdleConns(5)
db.SetConnMaxLifetime(5 * time.Minute)
```

---

## 8. Scalability Considerations

### 8.1 Horizontal Scaling

```
Load Balancer
    |
    ├── API Server 1 ──┐
    ├── API Server 2 ──┤
    └── API Server 3 ──┤
                       ├── Redis (Session/Cache)
                       ├── PostgreSQL (Primary)
                       ├── PostgreSQL (Read Replicas)
                       └── S3/Storage
```

### 8.2 Message Queue for Async Tasks

```go
// Use RabbitMQ, Redis Queue, or AWS SQS
type MessageQueue struct {
    Tasks []AsyncTask
}

type AsyncTask struct {
    Type string // "send_notification", "process_image", "update_receipt"
    Data map[string]interface{}
}

// Example: Send push notifications async
queue.Publish("notifications", NotificationTask{
    UserIDs: recipients,
    Message: "New message from John",
})
```

### 8.3 Database Sharding Strategy

```
Shard by conversation_id hash:
- Shard 1: conversations 0-999999
- Shard 2: conversations 1000000-1999999
- Shard 3: conversations 2000000+

Or shard by user_id for better data locality
```

### 8.4 WebSocket Scaling with Redis Pub/Sub

```go
// When user sends message on Server 1,
// broadcast to other servers via Redis
redis.Publish("chat:broadcast", MessageEvent{
    ConversationID: convID,
    Message: message,
})

// All servers subscribe and forward to their connected clients
redis.Subscribe("chat:broadcast", func(msg string) {
    var event MessageEvent
    json.Unmarshal([]byte(msg), &event)
    
    // Forward to local WebSocket connections
    connectionManager.BroadcastToConversation(
        event.ConversationID, 
        event.Message,
    )
})
```

---

## 9. API Design

### 9.1 RESTful Endpoints

```
POST   /api/v1/conversations                    # Create conversation
GET    /api/v1/conversations                    # List user's conversations
GET    /api/v1/conversations/:id                # Get conversation details
PUT    /api/v1/conversations/:id                # Update conversation
DELETE /api/v1/conversations/:id                # Delete/leave conversation

POST   /api/v1/conversations/:id/messages       # Send message
GET    /api/v1/conversations/:id/messages       # Get messages (paginated)
GET    /api/v1/messages/:id                     # Get specific message
PUT    /api/v1/messages/:id                     # Edit message
DELETE /api/v1/messages/:id                     # Delete message

POST   /api/v1/messages/:id/reactions           # Add reaction
DELETE /api/v1/messages/:id/reactions/:emoji    # Remove reaction

POST   /api/v1/conversations/:id/participants   # Add participant
DELETE /api/v1/conversations/:id/participants/:userId  # Remove participant

POST   /api/v1/messages/attachments/upload-url  # Get pre-signed URL
POST   /api/v1/messages/attachments/complete    # Confirm upload complete

PUT    /api/v1/messages/:id/read                # Mark as read
PUT    /api/v1/conversations/:id/read-all       # Mark all as read

GET    /api/v1/conversations/:id/typing         # Get typing users
POST   /api/v1/conversations/:id/typing         # Start typing
DELETE /api/v1/conversations/:id/typing         # Stop typing
```

### 9.2 Request/Response Examples

#### Send Text Message
```http
POST /api/v1/conversations/123/messages
Content-Type: application/json

{
  "type": "text",
  "content": "Hello everyone!",
  "reply_to": "message-uuid-optional"
}

Response 201:
{
  "message_id": "msg-uuid",
  "conversation_id": "123",
  "sender_id": "user-uuid",
  "type": "text",
  "content": "Hello everyone!",
  "created_at": "2025-11-16T10:30:00Z",
  "sender": {
    "user_id": "user-uuid",
    "username": "john_doe",
    "display_name": "John Doe",
    "profile_photo_url": "https://..."
  }
}
```

#### Send Image Message
```http
# Step 1: Get upload URL
POST /api/v1/messages/attachments/upload-url
{
  "filename": "photo.jpg",
  "content_type": "image/jpeg",
  "file_size": 2048000
}

Response 200:
{
  "attachment_id": "attach-uuid",
  "upload_url": "https://s3.../presigned-url",
  "expires_in": 900
}

# Step 2: Upload to S3 directly
PUT [upload_url]
Content-Type: image/jpeg
[binary data]

# Step 3: Send message with attachment
POST /api/v1/conversations/123/messages
{
  "type": "image",
  "content": "Check this out!",
  "attachment_id": "attach-uuid"
}
```

### 9.3 WebSocket Events

```javascript
// Client -> Server
{
  "type": "message.send",
  "data": {
    "conversation_id": "123",
    "content": "Hello",
    "type": "text"
  }
}

{
  "type": "typing.start",
  "data": {
    "conversation_id": "123"
  }
}

{
  "type": "message.read",
  "data": {
    "message_id": "msg-uuid"
  }
}

// Server -> Client
{
  "type": "message.new",
  "data": {
    "conversation_id": "123",
    "message": { /* full message object */ }
  }
}

{
  "type": "message.reaction",
  "data": {
    "message_id": "msg-uuid",
    "user_id": "user-uuid",
    "emoji": "👍"
  }
}

{
  "type": "typing.indicator",
  "data": {
    "conversation_id": "123",
    "user_id": "user-uuid",
    "username": "john_doe",
    "is_typing": true
  }
}
```

---

## 10. Implementation Checklist

### Phase 1: Core Infrastructure (Week 1-2)
- [ ] Create database tables (conversations, messages, participants)
- [ ] Set up indexes and constraints
- [ ] Implement basic CRUD operations
- [ ] Create API endpoints for conversations
- [ ] Add message sending/receiving endpoints
- [ ] Set up WebSocket server
- [ ] Implement connection management

### Phase 2: Image Attachments (Week 3)
- [ ] Set up S3/storage bucket
- [ ] Implement pre-signed URL generation
- [ ] Create attachment upload flow
- [ ] Add image processing pipeline
- [ ] Generate thumbnails
- [ ] Update message API for attachments

### Phase 3: Message Features (Week 4)
- [ ] Implement message reactions
- [ ] Add message editing
- [ ] Implement message deletion
- [ ] Add reply/threading support
- [ ] Create read receipts
- [ ] Add delivery status tracking

### Phase 4: Group Chat (Week 5)
- [ ] Create group conversation logic
- [ ] Implement participant management
- [ ] Add admin roles and permissions
- [ ] Create group naming/avatars
- [ ] Add system messages for events

### Phase 5: Real-time Features (Week 6)
- [ ] Implement typing indicators
- [ ] Add presence system
- [ ] Create online/offline status
- [ ] Add last seen timestamp
- [ ] Implement push notifications

### Phase 6: Performance & Scale (Week 7-8)
- [ ] Add Redis caching
- [ ] Implement message pagination
- [ ] Optimize database queries
- [ ] Add connection pooling
- [ ] Set up CDN for images
- [ ] Implement rate limiting
- [ ] Add monitoring and logging

### Phase 7: Security & Privacy (Week 9)
- [ ] Implement content moderation
- [ ] Add encryption options
- [ ] Create access control checks
- [ ] Add audit logging
- [ ] Implement user blocking
- [ ] Add conversation muting

### Phase 8: Polish & Testing (Week 10)
- [ ] Write unit tests
- [ ] Create integration tests
- [ ] Load testing
- [ ] Security audit
- [ ] Documentation
- [ ] Deploy to production

---

## Additional Best Practices

### Error Handling
```go
type APIError struct {
    Code    string `json:"code"`
    Message string `json:"message"`
    Details map[string]interface{} `json:"details,omitempty"`
}

// Standard error codes
const (
    ErrUnauthorized        = "UNAUTHORIZED"
    ErrConversationNotFound = "CONVERSATION_NOT_FOUND"
    ErrMessageTooLong      = "MESSAGE_TOO_LONG"
    ErrRateLimitExceeded   = "RATE_LIMIT_EXCEEDED"
    ErrInvalidAttachment   = "INVALID_ATTACHMENT"
)
```

### Logging Strategy
```go
// Structured logging with context
logger.Info("message_sent",
    zap.String("message_id", msgID),
    zap.String("conversation_id", convID),
    zap.String("sender_id", senderID),
    zap.String("type", messageType),
    zap.Int("recipients", len(recipients)),
)
```

### Monitoring Metrics
```
- messages_sent_total (counter)
- messages_delivered_total (counter)
- message_send_duration_seconds (histogram)
- websocket_connections_active (gauge)
- api_request_duration_seconds (histogram)
- database_query_duration_seconds (histogram)
- storage_upload_duration_seconds (histogram)
```

### Testing Strategy
```go
// Unit tests for business logic
func TestSendMessage(t *testing.T) { /* ... */ }

// Integration tests for API
func TestSendMessageAPI(t *testing.T) { /* ... */ }

// Load tests
// - 1000 concurrent users
// - 100 messages/second
// - Measure latency and throughput
```

---

## Conclusion

This architecture provides a solid foundation for a scalable, real-time chat system. Key takeaways:

1. **Start Simple**: Implement P2P chat first, then add group features
2. **Plan for Scale**: Design database schema and APIs with growth in mind
3. **Async Everything**: Use queues for heavy operations
4. **Cache Wisely**: Cache frequently accessed data
5. **Monitor Always**: Track metrics from day one
6. **Secure by Default**: Implement auth, rate limiting, and validation early

For questions or improvements, refer to the enhanced database schema in `locket_database_chat_enhanced.sql`.
