# Rocket Chat API Implementation Guide

Quick reference for implementing chat features in the Rocket app.

## Table of Contents
1. [Core Endpoints](#core-endpoints)
2. [WebSocket Events](#websocket-events)
3. [Go Implementation Examples](#go-implementation-examples)
4. [Security Middleware](#security-middleware)
5. [Error Handling](#error-handling)

---

## 1. Core Endpoints

### Conversation Management

#### List Conversations
```http
GET /api/v1/conversations?page=1&limit=20
Authorization: Bearer {token}

Response 200:
{
  "conversations": [
    {
      "conversation_id": "uuid",
      "type": "direct|group",
      "name": "Group Name",
      "photo_url": "https://...",
      "last_message": {
        "content": "Last message preview...",
        "created_at": "2025-11-16T10:30:00Z",
        "sender_username": "john_doe"
      },
      "unread_count": 5,
      "is_muted": false,
      "is_pinned": false,
      "participants": [...],
      "other_user": { /* for direct chats */ }
    }
  ],
  "total": 15,
  "page": 1,
  "has_more": false
}
```

#### Create Direct Conversation
```http
POST /api/v1/conversations/direct
Authorization: Bearer {token}
Content-Type: application/json

{
  "user_id": "target-user-uuid"
}

Response 201:
{
  "conversation_id": "uuid",
  "type": "direct",
  "created_at": "2025-11-16T10:30:00Z",
  "participants": [...]
}
```

#### Create Group Conversation
```http
POST /api/v1/conversations/group
Authorization: Bearer {token}

{
  "name": "My Group",
  "description": "Group description",
  "participant_ids": ["uuid1", "uuid2", "uuid3"]
}

Response 201:
{
  "conversation_id": "uuid",
  "type": "group",
  "name": "My Group",
  "created_by": "creator-uuid",
  "participants": [...]
}
```

#### Get Conversation Details
```http
GET /api/v1/conversations/:conversation_id
Authorization: Bearer {token}

Response 200:
{
  "conversation_id": "uuid",
  "type": "group",
  "name": "My Group",
  "photo_url": "https://...",
  "description": "Group description",
  "participant_count": 5,
  "participants": [
    {
      "user_id": "uuid",
      "username": "john_doe",
      "display_name": "John Doe",
      "profile_photo_url": "https://...",
      "role": "admin",
      "is_online": true,
      "last_seen_at": "2025-11-16T10:30:00Z"
    }
  ],
  "settings": {
    "only_admins_can_send": false,
    "disappearing_messages_enabled": false
  }
}
```

### Message Operations

#### Send Text Message
```http
POST /api/v1/conversations/:conversation_id/messages
Authorization: Bearer {token}

{
  "type": "text",
  "content": "Hello everyone!",
  "reply_to_message_id": "uuid-optional",
  "metadata": {
    "mentions": ["@user1", "@user2"]
  }
}

Response 201:
{
  "message_id": "uuid",
  "conversation_id": "uuid",
  "sender_id": "uuid",
  "type": "text",
  "content": "Hello everyone!",
  "created_at": "2025-11-16T10:30:00Z",
  "status": "sent",
  "sender": {...}
}
```

#### Send Image Message
```http
# Step 1: Get upload URL
POST /api/v1/messages/attachments/upload-url
Authorization: Bearer {token}

{
  "conversation_id": "uuid",
  "file_name": "photo.jpg",
  "file_size": 2048000,
  "mime_type": "image/jpeg",
  "attachment_type": "image"
}

Response 200:
{
  "attachment_id": "uuid",
  "upload_url": "https://s3.amazonaws.com/...",
  "expires_in": 900
}

# Step 2: Upload directly to S3
PUT {upload_url}
Content-Type: image/jpeg
[binary data]

# Step 3: Confirm upload and send message
POST /api/v1/conversations/:conversation_id/messages
{
  "type": "image",
  "content": "Caption text",
  "attachment_id": "uuid"
}
```

#### Get Messages (Pagination)
```http
GET /api/v1/conversations/:conversation_id/messages?before_id={uuid}&limit=50
Authorization: Bearer {token}

Response 200:
{
  "messages": [
    {
      "message_id": "uuid",
      "sender": {
        "user_id": "uuid",
        "username": "john_doe",
        "display_name": "John Doe",
        "profile_photo_url": "https://..."
      },
      "type": "text",
      "content": "Hello!",
      "created_at": "2025-11-16T10:30:00Z",
      "is_edited": false,
      "reply_to": null,
      "attachments": [],
      "reactions": [
        {
          "emoji": "👍",
          "user_id": "uuid",
          "username": "jane_doe"
        }
      ],
      "receipt_status": "read"
    }
  ],
  "has_more": true
}
```

#### Edit Message
```http
PUT /api/v1/messages/:message_id
Authorization: Bearer {token}

{
  "content": "Updated message content"
}

Response 200:
{
  "message_id": "uuid",
  "content": "Updated message content",
  "is_edited": true,
  "edited_at": "2025-11-16T10:31:00Z"
}
```

#### Delete Message
```http
DELETE /api/v1/messages/:message_id?delete_for_everyone=true
Authorization: Bearer {token}

Response 204: No Content
```

### Reactions

#### Add Reaction
```http
POST /api/v1/messages/:message_id/reactions
Authorization: Bearer {token}

{
  "emoji": "👍"
}

Response 201:
{
  "reaction_id": "uuid",
  "message_id": "uuid",
  "emoji": "👍",
  "user_id": "uuid",
  "created_at": "2025-11-16T10:30:00Z"
}
```

#### Remove Reaction
```http
DELETE /api/v1/messages/:message_id/reactions/:emoji
Authorization: Bearer {token}

Response 204: No Content
```

### Read Receipts

#### Mark Messages as Read
```http
PUT /api/v1/conversations/:conversation_id/read
Authorization: Bearer {token}

{
  "up_to_message_id": "uuid"
}

Response 200:
{
  "marked_read": 5,
  "unread_count": 0
}
```

#### Get Message Receipts
```http
GET /api/v1/messages/:message_id/receipts
Authorization: Bearer {token}

Response 200:
{
  "receipts": [
    {
      "user_id": "uuid",
      "username": "john_doe",
      "status": "read",
      "delivered_at": "2025-11-16T10:30:00Z",
      "read_at": "2025-11-16T10:31:00Z"
    }
  ]
}
```

### Typing Indicators

#### Start Typing
```http
POST /api/v1/conversations/:conversation_id/typing
Authorization: Bearer {token}

Response 204: No Content
```

#### Stop Typing
```http
DELETE /api/v1/conversations/:conversation_id/typing
Authorization: Bearer {token}

Response 204: No Content
```

### Search

#### Search Messages
```http
GET /api/v1/search/messages?q=hello&limit=20
Authorization: Bearer {token}

Response 200:
{
  "results": [
    {
      "message_id": "uuid",
      "conversation_id": "uuid",
      "conversation_name": "Group Name",
      "sender_username": "john_doe",
      "content": "hello world",
      "created_at": "2025-11-16T10:30:00Z",
      "highlight": "<mark>hello</mark> world"
    }
  ],
  "total": 15
}
```

---

## 2. WebSocket Events

### Connection
```javascript
// Connect to WebSocket
ws = new WebSocket('wss://api.example.com/ws?token={jwt_token}')

// Server confirms connection
{
  "type": "connection.established",
  "data": {
    "user_id": "uuid",
    "connection_id": "conn-uuid"
  }
}
```

### Client -> Server Events

#### Send Message
```json
{
  "type": "message.send",
  "conversation_id": "uuid",
  "data": {
    "content": "Hello!",
    "type": "text",
    "reply_to_message_id": "uuid-optional"
  }
}
```

#### Typing Indicator
```json
{
  "type": "typing.start",
  "conversation_id": "uuid"
}

{
  "type": "typing.stop",
  "conversation_id": "uuid"
}
```

#### Read Receipt
```json
{
  "type": "message.read",
  "message_id": "uuid"
}
```

#### Presence Update
```json
{
  "type": "presence.update",
  "status": "online|away|offline"
}
```

### Server -> Client Events

#### New Message
```json
{
  "type": "message.new",
  "conversation_id": "uuid",
  "data": {
    "message_id": "uuid",
    "sender": {...},
    "content": "Hello!",
    "created_at": "2025-11-16T10:30:00Z",
    ...
  }
}
```

#### Message Edited
```json
{
  "type": "message.edited",
  "conversation_id": "uuid",
  "data": {
    "message_id": "uuid",
    "content": "Updated content",
    "edited_at": "2025-11-16T10:31:00Z"
  }
}
```

#### Message Deleted
```json
{
  "type": "message.deleted",
  "conversation_id": "uuid",
  "data": {
    "message_id": "uuid",
    "deleted_by": "uuid"
  }
}
```

#### New Reaction
```json
{
  "type": "message.reaction",
  "conversation_id": "uuid",
  "data": {
    "message_id": "uuid",
    "user_id": "uuid",
    "username": "john_doe",
    "emoji": "👍",
    "action": "add|remove"
  }
}
```

#### Typing Indicator
```json
{
  "type": "typing.indicator",
  "conversation_id": "uuid",
  "data": {
    "user_id": "uuid",
    "username": "john_doe",
    "is_typing": true
  }
}
```

#### Read Receipt
```json
{
  "type": "message.receipt",
  "conversation_id": "uuid",
  "data": {
    "message_id": "uuid",
    "user_id": "uuid",
    "status": "delivered|read",
    "timestamp": "2025-11-16T10:31:00Z"
  }
}
```

#### User Presence
```json
{
  "type": "user.presence",
  "data": {
    "user_id": "uuid",
    "status": "online|away|offline",
    "last_seen_at": "2025-11-16T10:30:00Z"
  }
}
```

---

## 3. Go Implementation Examples

### Project Structure
```
rocket-chat-api/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── handlers/
│   │   ├── conversation.go
│   │   ├── message.go
│   │   ├── reaction.go
│   │   └── websocket.go
│   ├── models/
│   │   ├── conversation.go
│   │   ├── message.go
│   │   └── user.go
│   ├── repository/
│   │   ├── conversation_repo.go
│   │   └── message_repo.go
│   ├── service/
│   │   ├── conversation_service.go
│   │   ├── message_service.go
│   │   └── notification_service.go
│   ├── middleware/
│   │   ├── auth.go
│   │   ├── ratelimit.go
│   │   └── cors.go
│   └── websocket/
│       ├── hub.go
│       ├── client.go
│       └── manager.go
├── pkg/
│   ├── database/
│   │   └── postgres.go
│   ├── storage/
│   │   └── s3.go
│   └── cache/
│       └── redis.go
└── go.mod
```

### Main Application Setup

```go
// cmd/server/main.go
package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/yourusername/rocket-chat/internal/handlers"
    "github.com/yourusername/rocket-chat/internal/middleware"
    "github.com/yourusername/rocket-chat/internal/repository"
    "github.com/yourusername/rocket-chat/internal/service"
    "github.com/yourusername/rocket-chat/internal/websocket"
    "github.com/yourusername/rocket-chat/pkg/cache"
    "github.com/yourusername/rocket-chat/pkg/database"
    "github.com/yourusername/rocket-chat/pkg/storage"
)

func main() {
    // Initialize database
    db, err := database.NewPostgresDB(os.Getenv("DATABASE_URL"))
    if err != nil {
        log.Fatalf("Failed to connect to database: %v", err)
    }
    defer db.Close()

    // Initialize Redis
    redis := cache.NewRedisClient(os.Getenv("REDIS_URL"))
    defer redis.Close()

    // Initialize S3
    s3Client := storage.NewS3Client(
        os.Getenv("AWS_REGION"),
        os.Getenv("S3_BUCKET"),
    )

    // Initialize repositories
    conversationRepo := repository.NewConversationRepository(db)
    messageRepo := repository.NewMessageRepository(db)

    // Initialize services
    conversationService := service.NewConversationService(conversationRepo, redis)
    messageService := service.NewMessageService(messageRepo, redis, s3Client)
    notificationService := service.NewNotificationService(db, redis)

    // Initialize WebSocket hub
    wsHub := websocket.NewHub()
    go wsHub.Run()

    // Setup router
    router := setupRouter(
        conversationService,
        messageService,
        notificationService,
        wsHub,
    )

    // Start server
    srv := &http.Server{
        Addr:    ":8080",
        Handler: router,
    }

    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("Server failed: %v", err)
        }
    }()

    // Graceful shutdown
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    if err := srv.Shutdown(ctx); err != nil {
        log.Fatalf("Server forced shutdown: %v", err)
    }
}

func setupRouter(
    conversationService *service.ConversationService,
    messageService *service.MessageService,
    notificationService *service.NotificationService,
    wsHub *websocket.Hub,
) *gin.Engine {
    router := gin.Default()

    // Middleware
    router.Use(middleware.CORS())
    router.Use(middleware.RateLimit(redis))

    // Initialize handlers
    conversationHandler := handlers.NewConversationHandler(conversationService)
    messageHandler := handlers.NewMessageHandler(messageService, wsHub)
    wsHandler := handlers.NewWebSocketHandler(wsHub, messageService)

    // Public routes
    router.GET("/health", handlers.HealthCheck)

    // WebSocket
    router.GET("/ws", middleware.AuthRequired(), wsHandler.HandleWebSocket)

    // API routes
    api := router.Group("/api/v1")
    api.Use(middleware.AuthRequired())
    {
        // Conversations
        conversations := api.Group("/conversations")
        {
            conversations.GET("", conversationHandler.ListConversations)
            conversations.POST("/direct", conversationHandler.CreateDirectConversation)
            conversations.POST("/group", conversationHandler.CreateGroupConversation)
            conversations.GET("/:id", conversationHandler.GetConversation)
            conversations.PUT("/:id", conversationHandler.UpdateConversation)
            conversations.DELETE("/:id", conversationHandler.LeaveConversation)
            
            // Messages
            conversations.POST("/:id/messages", messageHandler.SendMessage)
            conversations.GET("/:id/messages", messageHandler.GetMessages)
            
            // Participants
            conversations.POST("/:id/participants", conversationHandler.AddParticipant)
            conversations.DELETE("/:id/participants/:userId", conversationHandler.RemoveParticipant)
            
            // Read receipts
            conversations.PUT("/:id/read", messageHandler.MarkAsRead)
            
            // Typing
            conversations.POST("/:id/typing", messageHandler.StartTyping)
            conversations.DELETE("/:id/typing", messageHandler.StopTyping)
        }

        // Messages
        messages := api.Group("/messages")
        {
            messages.GET("/:id", messageHandler.GetMessage)
            messages.PUT("/:id", messageHandler.EditMessage)
            messages.DELETE("/:id", messageHandler.DeleteMessage)
            
            // Reactions
            messages.POST("/:id/reactions", messageHandler.AddReaction)
            messages.DELETE("/:id/reactions/:emoji", messageHandler.RemoveReaction)
            
            // Receipts
            messages.GET("/:id/receipts", messageHandler.GetReceipts)
            
            // Attachments
            messages.POST("/attachments/upload-url", messageHandler.GetUploadURL)
        }

        // Search
        api.GET("/search/messages", messageHandler.SearchMessages)
    }

    return router
}
```

### Message Handler Example

```go
// internal/handlers/message.go
package handlers

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
    "github.com/yourusername/rocket-chat/internal/models"
    "github.com/yourusername/rocket-chat/internal/service"
    "github.com/yourusername/rocket-chat/internal/websocket"
)

type MessageHandler struct {
    messageService *service.MessageService
    wsHub          *websocket.Hub
}

func NewMessageHandler(messageService *service.MessageService, wsHub *websocket.Hub) *MessageHandler {
    return &MessageHandler{
        messageService: messageService,
        wsHub:          wsHub,
    }
}

type SendMessageRequest struct {
    Type            string                 `json:"type" binding:"required,oneof=text image video"`
    Content         string                 `json:"content"`
    AttachmentID    *string                `json:"attachment_id"`
    ReplyToID       *string                `json:"reply_to_message_id"`
    Metadata        map[string]interface{} `json:"metadata"`
}

func (h *MessageHandler) SendMessage(c *gin.Context) {
    conversationID := c.Param("id")
    userID := c.GetString("user_id") // From auth middleware

    var req SendMessageRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    // Verify user has access to conversation
    if err := h.messageService.VerifyConversationAccess(conversationID, userID); err != nil {
        c.JSON(http.StatusForbidden, gin.H{"error": "Access denied"})
        return
    }

    // Create message
    message := &models.Message{
        ConversationID: conversationID,
        SenderID:       userID,
        Type:           req.Type,
        Content:        req.Content,
        AttachmentID:   req.AttachmentID,
        ReplyToID:      req.ReplyToID,
        Metadata:       req.Metadata,
    }

    createdMessage, err := h.messageService.CreateMessage(c.Request.Context(), message)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create message"})
        return
    }

    // Broadcast via WebSocket
    h.wsHub.BroadcastToConversation(conversationID, websocket.Event{
        Type: "message.new",
        Data: createdMessage,
    })

    // Send push notifications (async)
    go h.messageService.SendPushNotifications(createdMessage)

    c.JSON(http.StatusCreated, createdMessage)
}

func (h *MessageHandler) GetMessages(c *gin.Context) {
    conversationID := c.Param("id")
    userID := c.GetString("user_id")

    beforeID := c.Query("before_id")
    limit := c.DefaultQuery("limit", "50")

    messages, hasMore, err := h.messageService.GetMessages(
        c.Request.Context(),
        conversationID,
        userID,
        beforeID,
        limit,
    )
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "messages":  messages,
        "has_more": hasMore,
    })
}

func (h *MessageHandler) MarkAsRead(c *gin.Context) {
    conversationID := c.Param("id")
    userID := c.GetString("user_id")

    var req struct {
        UpToMessageID string `json:"up_to_message_id"`
    }
    c.ShouldBindJSON(&req)

    count, err := h.messageService.MarkAsRead(
        c.Request.Context(),
        conversationID,
        userID,
        req.UpToMessageID,
    )
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    // Broadcast read receipt
    h.wsHub.BroadcastToConversation(conversationID, websocket.Event{
        Type: "message.receipt",
        Data: map[string]interface{}{
            "user_id":           userID,
            "up_to_message_id":  req.UpToMessageID,
            "status":            "read",
        },
    })

    c.JSON(http.StatusOK, gin.H{
        "marked_read":   count,
        "unread_count":  0,
    })
}

func (h *MessageHandler) AddReaction(c *gin.Context) {
    messageID := c.Param("id")
    userID := c.GetString("user_id")

    var req struct {
        Emoji string `json:"emoji" binding:"required"`
    }
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    reaction, err := h.messageService.AddReaction(
        c.Request.Context(),
        messageID,
        userID,
        req.Emoji,
    )
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    // Broadcast reaction
    message, _ := h.messageService.GetMessageByID(c.Request.Context(), messageID)
    h.wsHub.BroadcastToConversation(message.ConversationID, websocket.Event{
        Type: "message.reaction",
        Data: map[string]interface{}{
            "message_id": messageID,
            "user_id":    userID,
            "emoji":      req.Emoji,
            "action":     "add",
        },
    })

    c.JSON(http.StatusCreated, reaction)
}
```

### WebSocket Hub

```go
// internal/websocket/hub.go
package websocket

import (
    "sync"
)

type Hub struct {
    clients              map[string]*Client          // userID -> Client
    conversations        map[string]map[*Client]bool // conversationID -> clients
    broadcast            chan Event
    register             chan *Client
    unregister           chan *Client
    mu                   sync.RWMutex
}

type Event struct {
    Type string      `json:"type"`
    Data interface{} `json:"data"`
}

func NewHub() *Hub {
    return &Hub{
        clients:       make(map[string]*Client),
        conversations: make(map[string]map[*Client]bool),
        broadcast:     make(chan Event, 256),
        register:      make(chan *Client),
        unregister:    make(chan *Client),
    }
}

func (h *Hub) Run() {
    for {
        select {
        case client := <-h.register:
            h.mu.Lock()
            h.clients[client.UserID] = client
            // Subscribe to user's conversations
            for _, convID := range client.Conversations {
                if h.conversations[convID] == nil {
                    h.conversations[convID] = make(map[*Client]bool)
                }
                h.conversations[convID][client] = true
            }
            h.mu.Unlock()

        case client := <-h.unregister:
            h.mu.Lock()
            if _, ok := h.clients[client.UserID]; ok {
                delete(h.clients, client.UserID)
                // Remove from all conversations
                for convID := range h.conversations {
                    delete(h.conversations[convID], client)
                }
                close(client.Send)
            }
            h.mu.Unlock()

        case event := <-h.broadcast:
            // Handle broadcast
        }
    }
}

func (h *Hub) BroadcastToConversation(conversationID string, event Event) {
    h.mu.RLock()
    defer h.mu.RUnlock()

    if clients, ok := h.conversations[conversationID]; ok {
        for client := range clients {
            select {
            case client.Send <- event:
            default:
                close(client.Send)
                delete(h.clients, client.UserID)
                delete(clients, client)
            }
        }
    }
}

func (h *Hub) SendToUser(userID string, event Event) {
    h.mu.RLock()
    defer h.mu.RUnlock()

    if client, ok := h.clients[userID]; ok {
        select {
        case client.Send <- event:
        default:
            close(client.Send)
            delete(h.clients, userID)
        }
    }
}
```

---

## 4. Security Middleware

### Authentication

```go
// internal/middleware/auth.go
package middleware

import (
    "net/http"
    "strings"

    "github.com/gin-gonic/gin"
    "github.com/golang-jwt/jwt/v5"
)

func AuthRequired() gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
            c.Abort()
            return
        }

        // Extract token
        tokenString := strings.TrimPrefix(authHeader, "Bearer ")
        
        // Verify token
        token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
            return []byte("your-secret-key"), nil
        })

        if err != nil || !token.Valid {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
            c.Abort()
            return
        }

        // Extract claims
        if claims, ok := token.Claims.(jwt.MapClaims); ok {
            c.Set("user_id", claims["user_id"])
            c.Set("username", claims["username"])
            c.Next()
        } else {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
            c.Abort()
        }
    }
}
```

### Rate Limiting

```go
// internal/middleware/ratelimit.go
package middleware

import (
    "fmt"
    "net/http"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/go-redis/redis/v8"
)

func RateLimit(redis *redis.Client) gin.HandlerFunc {
    return func(c *gin.Context) {
        userID := c.GetString("user_id")
        if userID == "" {
            userID = c.ClientIP()
        }

        key := fmt.Sprintf("ratelimit:%s", userID)
        
        // Increment counter
        count, err := redis.Incr(c.Request.Context(), key).Result()
        if err != nil {
            c.Next()
            return
        }

        // Set expiry on first request
        if count == 1 {
            redis.Expire(c.Request.Context(), key, time.Minute)
        }

        // Check limit (100 requests per minute)
        if count > 100 {
            c.JSON(http.StatusTooManyRequests, gin.H{
                "error": "Rate limit exceeded",
            })
            c.Abort()
            return
        }

        c.Next()
    }
}
```

---

## 5. Error Handling

### Standard Error Response

```go
// pkg/errors/errors.go
package errors

type APIError struct {
    Code       string                 `json:"code"`
    Message    string                 `json:"message"`
    Details    map[string]interface{} `json:"details,omitempty"`
    StatusCode int                    `json:"-"`
}

func (e *APIError) Error() string {
    return e.Message
}

var (
    ErrUnauthorized = &APIError{
        Code:       "UNAUTHORIZED",
        Message:    "Authentication required",
        StatusCode: 401,
    }
    
    ErrForbidden = &APIError{
        Code:       "FORBIDDEN",
        Message:    "Access denied",
        StatusCode: 403,
    }
    
    ErrNotFound = &APIError{
        Code:       "NOT_FOUND",
        Message:    "Resource not found",
        StatusCode: 404,
    }
    
    ErrConversationNotFound = &APIError{
        Code:       "CONVERSATION_NOT_FOUND",
        Message:    "Conversation not found",
        StatusCode: 404,
    }
    
    ErrMessageTooLong = &APIError{
        Code:       "MESSAGE_TOO_LONG",
        Message:    "Message exceeds maximum length",
        StatusCode: 400,
    }
    
    ErrRateLimitExceeded = &APIError{
        Code:       "RATE_LIMIT_EXCEEDED",
        Message:    "Too many requests",
        StatusCode: 429,
    }
    
    ErrInvalidAttachment = &APIError{
        Code:       "INVALID_ATTACHMENT",
        Message:    "Invalid attachment",
        StatusCode: 400,
    }
)

// Error handler middleware
func ErrorHandler() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Next()

        if len(c.Errors) > 0 {
            err := c.Errors.Last().Err
            
            if apiErr, ok := err.(*APIError); ok {
                c.JSON(apiErr.StatusCode, apiErr)
            } else {
                c.JSON(500, &APIError{
                    Code:    "INTERNAL_ERROR",
                    Message: "Internal server error",
                })
            }
        }
    }
}
```

---

## Next Steps

1. **Set up the database**: Run `locket_database_chat_enhanced.sql`
2. **Implement Go backend**: Use the examples above as a starting point
3. **Configure S3/Storage**: Set up bucket and CORS
4. **Set up Redis**: For caching and real-time features
5. **Implement WebSocket**: For real-time messaging
6. **Add push notifications**: FCM for Android, APNS for iOS
7. **Testing**: Write unit and integration tests
8. **Monitoring**: Add logging and metrics
9. **Deploy**: Containerize with Docker

For more details, see `CHAT_FEATURE_BEST_PRACTICES.md`.
