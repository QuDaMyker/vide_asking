# Go WebSocket Chat Best Practices with MongoDB

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Project Structure](#project-structure)
3. [WebSocket Management](#websocket-management)
4. [MongoDB Schema Design](#mongodb-schema-design)
5. [Connection Management](#connection-management)
6. [Message Handling](#message-handling)
7. [Group Chat Implementation](#group-chat-implementation)
8. [Security Best Practices](#security-best-practices)
9. [Performance Optimization](#performance-optimization)
10. [Error Handling](#error-handling)

## Architecture Overview

```
┌─────────────┐         ┌──────────────┐         ┌──────────────┐
│   Client    │◄───────►│  WebSocket   │◄───────►│   Hub/Pool   │
│  (Browser)  │         │   Handler    │         │   Manager    │
└─────────────┘         └──────────────┘         └──────────────┘
                               │                         │
                               ▼                         ▼
                        ┌──────────────┐         ┌──────────────┐
                        │   Message    │◄───────►│   MongoDB    │
                        │   Service    │         │   Database   │
                        └──────────────┘         └──────────────┘
```

## Project Structure

```
chat-app/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── config/
│   │   └── config.go
│   ├── domain/
│   │   ├── user.go
│   │   ├── message.go
│   │   └── room.go
│   ├── handler/
│   │   ├── websocket_handler.go
│   │   └── http_handler.go
│   ├── repository/
│   │   ├── user_repository.go
│   │   ├── message_repository.go
│   │   └── room_repository.go
│   ├── service/
│   │   ├── chat_service.go
│   │   └── auth_service.go
│   └── websocket/
│       ├── client.go
│       ├── hub.go
│       ├── pool.go
│       └── message.go
├── pkg/
│   ├── logger/
│   │   └── logger.go
│   └── middleware/
│       └── auth.go
├── go.mod
└── go.sum
```

## WebSocket Management

### 1. Client Structure

```go
package websocket

import (
    "sync"
    "time"
    "github.com/gorilla/websocket"
)

type Client struct {
    ID         string
    UserID     string
    Conn       *websocket.Conn
    Hub        *Hub
    Send       chan []byte
    Rooms      map[string]bool // Room memberships
    mu         sync.RWMutex
    LastActive time.Time
}

// NewClient creates a new client instance
func NewClient(conn *websocket.Conn, hub *Hub, userID string) *Client {
    return &Client{
        ID:         generateClientID(),
        UserID:     userID,
        Conn:       conn,
        Hub:        hub,
        Send:       make(chan []byte, 256),
        Rooms:      make(map[string]bool),
        LastActive: time.Now(),
    }
}

// ReadPump pumps messages from the websocket connection to the hub
func (c *Client) ReadPump() {
    defer func() {
        c.Hub.Unregister <- c
        c.Conn.Close()
    }()

    c.Conn.SetReadDeadline(time.Now().Add(pongWait))
    c.Conn.SetPongHandler(func(string) error {
        c.Conn.SetReadDeadline(time.Now().Add(pongWait))
        return nil
    })

    for {
        _, message, err := c.Conn.ReadMessage()
        if err != nil {
            if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
                log.Printf("error: %v", err)
            }
            break
        }

        c.LastActive = time.Now()
        
        // Handle message
        c.Hub.Broadcast <- &Message{
            Client:  c,
            Content: message,
        }
    }
}

// WritePump pumps messages from the hub to the websocket connection
func (c *Client) WritePump() {
    ticker := time.NewTicker(pingPeriod)
    defer func() {
        ticker.Stop()
        c.Conn.Close()
    }()

    for {
        select {
        case message, ok := <-c.Send:
            c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
            if !ok {
                // Hub closed the channel
                c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
                return
            }

            w, err := c.Conn.NextWriter(websocket.TextMessage)
            if err != nil {
                return
            }
            w.Write(message)

            // Add queued messages to the current websocket message
            n := len(c.Send)
            for i := 0; i < n; i++ {
                w.Write([]byte{'\n'})
                w.Write(<-c.Send)
            }

            if err := w.Close(); err != nil {
                return
            }

        case <-ticker.C:
            c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
            if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
                return
            }
        }
    }
}

// JoinRoom adds the client to a room
func (c *Client) JoinRoom(roomID string) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.Rooms[roomID] = true
}

// LeaveRoom removes the client from a room
func (c *Client) LeaveRoom(roomID string) {
    c.mu.Lock()
    defer c.mu.Unlock()
    delete(c.Rooms, roomID)
}

// IsInRoom checks if the client is in a room
func (c *Client) IsInRoom(roomID string) bool {
    c.mu.RLock()
    defer c.mu.RUnlock()
    return c.Rooms[roomID]
}
```

### 2. Hub/Pool Manager

```go
package websocket

import (
    "context"
    "encoding/json"
    "log"
    "sync"
    "time"
)

const (
    writeWait      = 10 * time.Second
    pongWait       = 60 * time.Second
    pingPeriod     = (pongWait * 9) / 10
    maxMessageSize = 512
)

type Hub struct {
    // Registered clients
    Clients map[string]*Client
    
    // Clients by user ID for quick lookup
    UserClients map[string]map[string]*Client
    
    // Rooms with their clients
    Rooms map[string]map[string]*Client
    
    // Inbound messages from clients
    Broadcast chan *Message
    
    // Register requests from clients
    Register chan *Client
    
    // Unregister requests from clients
    Unregister chan *Client
    
    // Message service for persistence
    MessageService MessageService
    
    mu sync.RWMutex
}

func NewHub(messageService MessageService) *Hub {
    return &Hub{
        Clients:        make(map[string]*Client),
        UserClients:    make(map[string]map[string]*Client),
        Rooms:          make(map[string]map[string]*Client),
        Broadcast:      make(chan *Message, 256),
        Register:       make(chan *Client),
        Unregister:     make(chan *Client),
        MessageService: messageService,
    }
}

func (h *Hub) Run(ctx context.Context) {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            h.shutdown()
            return

        case client := <-h.Register:
            h.registerClient(client)

        case client := <-h.Unregister:
            h.unregisterClient(client)

        case message := <-h.Broadcast:
            h.handleMessage(message)

        case <-ticker.C:
            h.cleanupStaleConnections()
        }
    }
}

func (h *Hub) registerClient(client *Client) {
    h.mu.Lock()
    defer h.mu.Unlock()

    h.Clients[client.ID] = client
    
    if h.UserClients[client.UserID] == nil {
        h.UserClients[client.UserID] = make(map[string]*Client)
    }
    h.UserClients[client.UserID][client.ID] = client

    log.Printf("Client registered: %s (User: %s)", client.ID, client.UserID)
}

func (h *Hub) unregisterClient(client *Client) {
    h.mu.Lock()
    defer h.mu.Unlock()

    if _, ok := h.Clients[client.ID]; ok {
        // Remove from all rooms
        for roomID := range client.Rooms {
            if room, exists := h.Rooms[roomID]; exists {
                delete(room, client.ID)
                if len(room) == 0 {
                    delete(h.Rooms, roomID)
                }
            }
        }

        // Remove from user clients
        if userClients, exists := h.UserClients[client.UserID]; exists {
            delete(userClients, client.ID)
            if len(userClients) == 0 {
                delete(h.UserClients, client.UserID)
            }
        }

        delete(h.Clients, client.ID)
        close(client.Send)
        
        log.Printf("Client unregistered: %s (User: %s)", client.ID, client.UserID)
    }
}

func (h *Hub) handleMessage(msg *Message) {
    // Parse message
    var msgData MessageData
    if err := json.Unmarshal(msg.Content, &msgData); err != nil {
        log.Printf("Error parsing message: %v", err)
        return
    }

    // Save to database
    savedMsg, err := h.MessageService.SaveMessage(context.Background(), &msgData)
    if err != nil {
        log.Printf("Error saving message: %v", err)
        return
    }

    // Broadcast to appropriate clients
    if msgData.Type == "direct" {
        h.sendDirectMessage(savedMsg)
    } else if msgData.Type == "group" {
        h.sendGroupMessage(savedMsg)
    }
}

func (h *Hub) sendDirectMessage(msg *SavedMessage) {
    h.mu.RLock()
    defer h.mu.RUnlock()

    data, _ := json.Marshal(msg)
    
    // Send to sender
    if clients, ok := h.UserClients[msg.SenderID]; ok {
        for _, client := range clients {
            select {
            case client.Send <- data:
            default:
                // Channel is full, skip
            }
        }
    }

    // Send to recipient
    if clients, ok := h.UserClients[msg.RecipientID]; ok {
        for _, client := range clients {
            select {
            case client.Send <- data:
            default:
                // Channel is full, skip
            }
        }
    }
}

func (h *Hub) sendGroupMessage(msg *SavedMessage) {
    h.mu.RLock()
    defer h.mu.RUnlock()

    room, exists := h.Rooms[msg.RoomID]
    if !exists {
        return
    }

    data, _ := json.Marshal(msg)
    
    for _, client := range room {
        select {
        case client.Send <- data:
        default:
            // Channel is full, skip
        }
    }
}

func (h *Hub) AddClientToRoom(clientID, roomID string) {
    h.mu.Lock()
    defer h.mu.Unlock()

    client, exists := h.Clients[clientID]
    if !exists {
        return
    }

    if h.Rooms[roomID] == nil {
        h.Rooms[roomID] = make(map[string]*Client)
    }
    h.Rooms[roomID][clientID] = client
    client.JoinRoom(roomID)
}

func (h *Hub) RemoveClientFromRoom(clientID, roomID string) {
    h.mu.Lock()
    defer h.mu.Unlock()

    if room, exists := h.Rooms[roomID]; exists {
        if client, ok := room[clientID]; ok {
            delete(room, clientID)
            client.LeaveRoom(roomID)
            
            if len(room) == 0 {
                delete(h.Rooms, roomID)
            }
        }
    }
}

func (h *Hub) cleanupStaleConnections() {
    h.mu.RLock()
    staleClients := make([]*Client, 0)
    now := time.Now()
    
    for _, client := range h.Clients {
        if now.Sub(client.LastActive) > 2*pongWait {
            staleClients = append(staleClients, client)
        }
    }
    h.mu.RUnlock()

    for _, client := range staleClients {
        h.Unregister <- client
    }
}

func (h *Hub) shutdown() {
    h.mu.Lock()
    defer h.mu.Unlock()

    for _, client := range h.Clients {
        close(client.Send)
        client.Conn.Close()
    }
}
```

## MongoDB Schema Design

### 1. Domain Models

```go
package domain

import (
    "time"
    "go.mongodb.org/mongo-driver/bson/primitive"
)

// User represents a chat user
type User struct {
    ID          primitive.ObjectID `bson:"_id,omitempty" json:"id"`
    Username    string             `bson:"username" json:"username"`
    Email       string             `bson:"email" json:"email"`
    Password    string             `bson:"password" json:"-"`
    DisplayName string             `bson:"display_name" json:"displayName"`
    Avatar      string             `bson:"avatar" json:"avatar"`
    Status      string             `bson:"status" json:"status"` // online, offline, away
    LastSeen    time.Time          `bson:"last_seen" json:"lastSeen"`
    CreatedAt   time.Time          `bson:"created_at" json:"createdAt"`
    UpdatedAt   time.Time          `bson:"updated_at" json:"updatedAt"`
}

// Message represents a chat message
type Message struct {
    ID          primitive.ObjectID   `bson:"_id,omitempty" json:"id"`
    Type        string               `bson:"type" json:"type"` // direct, group
    SenderID    primitive.ObjectID   `bson:"sender_id" json:"senderId"`
    RecipientID *primitive.ObjectID  `bson:"recipient_id,omitempty" json:"recipientId,omitempty"`
    RoomID      *primitive.ObjectID  `bson:"room_id,omitempty" json:"roomId,omitempty"`
    Content     string               `bson:"content" json:"content"`
    ContentType string               `bson:"content_type" json:"contentType"` // text, image, file
    Attachments []Attachment         `bson:"attachments,omitempty" json:"attachments,omitempty"`
    ReplyTo     *primitive.ObjectID  `bson:"reply_to,omitempty" json:"replyTo,omitempty"`
    ReadBy      []ReadReceipt        `bson:"read_by" json:"readBy"`
    Delivered   bool                 `bson:"delivered" json:"delivered"`
    CreatedAt   time.Time            `bson:"created_at" json:"createdAt"`
    UpdatedAt   time.Time            `bson:"updated_at" json:"updatedAt"`
    DeletedAt   *time.Time           `bson:"deleted_at,omitempty" json:"deletedAt,omitempty"`
}

type Attachment struct {
    Type string `bson:"type" json:"type"` // image, file, video
    URL  string `bson:"url" json:"url"`
    Name string `bson:"name" json:"name"`
    Size int64  `bson:"size" json:"size"`
}

type ReadReceipt struct {
    UserID primitive.ObjectID `bson:"user_id" json:"userId"`
    ReadAt time.Time          `bson:"read_at" json:"readAt"`
}

// Room represents a chat room (group chat)
type Room struct {
    ID          primitive.ObjectID   `bson:"_id,omitempty" json:"id"`
    Name        string               `bson:"name" json:"name"`
    Description string               `bson:"description" json:"description"`
    Type        string               `bson:"type" json:"type"` // public, private
    Avatar      string               `bson:"avatar" json:"avatar"`
    OwnerID     primitive.ObjectID   `bson:"owner_id" json:"ownerId"`
    Members     []RoomMember         `bson:"members" json:"members"`
    Settings    RoomSettings         `bson:"settings" json:"settings"`
    CreatedAt   time.Time            `bson:"created_at" json:"createdAt"`
    UpdatedAt   time.Time            `bson:"updated_at" json:"updatedAt"`
}

type RoomMember struct {
    UserID    primitive.ObjectID `bson:"user_id" json:"userId"`
    Role      string             `bson:"role" json:"role"` // admin, moderator, member
    JoinedAt  time.Time          `bson:"joined_at" json:"joinedAt"`
    Muted     bool               `bson:"muted" json:"muted"`
    LastRead  time.Time          `bson:"last_read" json:"lastRead"`
}

type RoomSettings struct {
    MaxMembers       int  `bson:"max_members" json:"maxMembers"`
    AllowInvites     bool `bson:"allow_invites" json:"allowInvites"`
    OnlyAdminsPost   bool `bson:"only_admins_post" json:"onlyAdminsPost"`
    DisableNotif     bool `bson:"disable_notif" json:"disableNotif"`
}

// Conversation tracks direct message threads
type Conversation struct {
    ID            primitive.ObjectID   `bson:"_id,omitempty" json:"id"`
    Participants  []primitive.ObjectID `bson:"participants" json:"participants"`
    LastMessage   *Message             `bson:"last_message,omitempty" json:"lastMessage,omitempty"`
    UnreadCount   map[string]int       `bson:"unread_count" json:"unreadCount"`
    CreatedAt     time.Time            `bson:"created_at" json:"createdAt"`
    UpdatedAt     time.Time            `bson:"updated_at" json:"updatedAt"`
}
```

### 2. MongoDB Indexes

```go
package repository

import (
    "context"
    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

func CreateIndexes(ctx context.Context, db *mongo.Database) error {
    // User indexes
    userIndexes := []mongo.IndexModel{
        {
            Keys:    bson.D{{Key: "email", Value: 1}},
            Options: options.Index().SetUnique(true),
        },
        {
            Keys:    bson.D{{Key: "username", Value: 1}},
            Options: options.Index().SetUnique(true),
        },
    }
    _, err := db.Collection("users").Indexes().CreateMany(ctx, userIndexes)
    if err != nil {
        return err
    }

    // Message indexes
    messageIndexes := []mongo.IndexModel{
        {
            Keys: bson.D{
                {Key: "sender_id", Value: 1},
                {Key: "created_at", Value: -1},
            },
        },
        {
            Keys: bson.D{
                {Key: "recipient_id", Value: 1},
                {Key: "created_at", Value: -1},
            },
        },
        {
            Keys: bson.D{
                {Key: "room_id", Value: 1},
                {Key: "created_at", Value: -1},
            },
        },
        {
            Keys: bson.D{
                {Key: "type", Value: 1},
                {Key: "created_at", Value: -1},
            },
        },
        {
            // For searching messages
            Keys: bson.D{
                {Key: "content", Value: "text"},
            },
        },
    }
    _, err = db.Collection("messages").Indexes().CreateMany(ctx, messageIndexes)
    if err != nil {
        return err
    }

    // Room indexes
    roomIndexes := []mongo.IndexModel{
        {
            Keys: bson.D{{Key: "members.user_id", Value: 1}},
        },
        {
            Keys: bson.D{{Key: "type", Value: 1}},
        },
    }
    _, err = db.Collection("rooms").Indexes().CreateMany(ctx, roomIndexes)
    if err != nil {
        return err
    }

    // Conversation indexes
    conversationIndexes := []mongo.IndexModel{
        {
            Keys: bson.D{{Key: "participants", Value: 1}},
        },
        {
            Keys: bson.D{{Key: "updated_at", Value: -1}},
        },
    }
    _, err = db.Collection("conversations").Indexes().CreateMany(ctx, conversationIndexes)
    
    return err
}
```

## Message Repository

```go
package repository

import (
    "context"
    "time"

    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/bson/primitive"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

type MessageRepository interface {
    Create(ctx context.Context, message *domain.Message) error
    FindByID(ctx context.Context, id primitive.ObjectID) (*domain.Message, error)
    FindDirectMessages(ctx context.Context, userID1, userID2 primitive.ObjectID, limit, offset int) ([]*domain.Message, error)
    FindRoomMessages(ctx context.Context, roomID primitive.ObjectID, limit, offset int) ([]*domain.Message, error)
    MarkAsRead(ctx context.Context, messageID, userID primitive.ObjectID) error
    MarkMultipleAsRead(ctx context.Context, messageIDs []primitive.ObjectID, userID primitive.ObjectID) error
    DeleteMessage(ctx context.Context, messageID primitive.ObjectID) error
    UpdateMessage(ctx context.Context, messageID primitive.ObjectID, content string) error
    SearchMessages(ctx context.Context, userID primitive.ObjectID, query string, limit int) ([]*domain.Message, error)
}

type messageRepository struct {
    collection *mongo.Collection
}

func NewMessageRepository(db *mongo.Database) MessageRepository {
    return &messageRepository{
        collection: db.Collection("messages"),
    }
}

func (r *messageRepository) Create(ctx context.Context, message *domain.Message) error {
    message.CreatedAt = time.Now()
    message.UpdatedAt = time.Now()
    
    result, err := r.collection.InsertOne(ctx, message)
    if err != nil {
        return err
    }
    
    message.ID = result.InsertedID.(primitive.ObjectID)
    return nil
}

func (r *messageRepository) FindByID(ctx context.Context, id primitive.ObjectID) (*domain.Message, error) {
    var message domain.Message
    err := r.collection.FindOne(ctx, bson.M{"_id": id}).Decode(&message)
    if err != nil {
        return nil, err
    }
    return &message, nil
}

func (r *messageRepository) FindDirectMessages(ctx context.Context, userID1, userID2 primitive.ObjectID, limit, offset int) ([]*domain.Message, error) {
    filter := bson.M{
        "type": "direct",
        "$or": []bson.M{
            {
                "sender_id":    userID1,
                "recipient_id": userID2,
            },
            {
                "sender_id":    userID2,
                "recipient_id": userID1,
            },
        },
        "deleted_at": nil,
    }

    opts := options.Find().
        SetSort(bson.D{{Key: "created_at", Value: -1}}).
        SetLimit(int64(limit)).
        SetSkip(int64(offset))

    cursor, err := r.collection.Find(ctx, filter, opts)
    if err != nil {
        return nil, err
    }
    defer cursor.Close(ctx)

    var messages []*domain.Message
    if err := cursor.All(ctx, &messages); err != nil {
        return nil, err
    }

    return messages, nil
}

func (r *messageRepository) FindRoomMessages(ctx context.Context, roomID primitive.ObjectID, limit, offset int) ([]*domain.Message, error) {
    filter := bson.M{
        "type":       "group",
        "room_id":    roomID,
        "deleted_at": nil,
    }

    opts := options.Find().
        SetSort(bson.D{{Key: "created_at", Value: -1}}).
        SetLimit(int64(limit)).
        SetSkip(int64(offset))

    cursor, err := r.collection.Find(ctx, filter, opts)
    if err != nil {
        return nil, err
    }
    defer cursor.Close(ctx)

    var messages []*domain.Message
    if err := cursor.All(ctx, &messages); err != nil {
        return nil, err
    }

    return messages, nil
}

func (r *messageRepository) MarkAsRead(ctx context.Context, messageID, userID primitive.ObjectID) error {
    filter := bson.M{"_id": messageID}
    update := bson.M{
        "$addToSet": bson.M{
            "read_by": bson.M{
                "user_id": userID,
                "read_at": time.Now(),
            },
        },
    }

    _, err := r.collection.UpdateOne(ctx, filter, update)
    return err
}

func (r *messageRepository) MarkMultipleAsRead(ctx context.Context, messageIDs []primitive.ObjectID, userID primitive.ObjectID) error {
    filter := bson.M{"_id": bson.M{"$in": messageIDs}}
    update := bson.M{
        "$addToSet": bson.M{
            "read_by": bson.M{
                "user_id": userID,
                "read_at": time.Now(),
            },
        },
    }

    _, err := r.collection.UpdateMany(ctx, filter, update)
    return err
}

func (r *messageRepository) DeleteMessage(ctx context.Context, messageID primitive.ObjectID) error {
    filter := bson.M{"_id": messageID}
    update := bson.M{
        "$set": bson.M{
            "deleted_at": time.Now(),
        },
    }

    _, err := r.collection.UpdateOne(ctx, filter, update)
    return err
}

func (r *messageRepository) UpdateMessage(ctx context.Context, messageID primitive.ObjectID, content string) error {
    filter := bson.M{"_id": messageID}
    update := bson.M{
        "$set": bson.M{
            "content":    content,
            "updated_at": time.Now(),
        },
    }

    _, err := r.collection.UpdateOne(ctx, filter, update)
    return err
}

func (r *messageRepository) SearchMessages(ctx context.Context, userID primitive.ObjectID, query string, limit int) ([]*domain.Message, error) {
    filter := bson.M{
        "$text": bson.M{"$search": query},
        "$or": []bson.M{
            {"sender_id": userID},
            {"recipient_id": userID},
            {"room_id": bson.M{"$exists": true}},
        },
    }

    opts := options.Find().
        SetLimit(int64(limit)).
        SetSort(bson.D{{Key: "created_at", Value: -1}})

    cursor, err := r.collection.Find(ctx, filter, opts)
    if err != nil {
        return nil, err
    }
    defer cursor.Close(ctx)

    var messages []*domain.Message
    if err := cursor.All(ctx, &messages); err != nil {
        return nil, err
    }

    return messages, nil
}
```

## Room Repository

```go
package repository

import (
    "context"
    "time"

    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/bson/primitive"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

type RoomRepository interface {
    Create(ctx context.Context, room *domain.Room) error
    FindByID(ctx context.Context, id primitive.ObjectID) (*domain.Room, error)
    FindUserRooms(ctx context.Context, userID primitive.ObjectID) ([]*domain.Room, error)
    AddMember(ctx context.Context, roomID, userID primitive.ObjectID, role string) error
    RemoveMember(ctx context.Context, roomID, userID primitive.ObjectID) error
    UpdateMemberRole(ctx context.Context, roomID, userID primitive.ObjectID, role string) error
    UpdateSettings(ctx context.Context, roomID primitive.ObjectID, settings *domain.RoomSettings) error
    IsMember(ctx context.Context, roomID, userID primitive.ObjectID) (bool, error)
}

type roomRepository struct {
    collection *mongo.Collection
}

func NewRoomRepository(db *mongo.Database) RoomRepository {
    return &roomRepository{
        collection: db.Collection("rooms"),
    }
}

func (r *roomRepository) Create(ctx context.Context, room *domain.Room) error {
    room.CreatedAt = time.Now()
    room.UpdatedAt = time.Now()
    
    result, err := r.collection.InsertOne(ctx, room)
    if err != nil {
        return err
    }
    
    room.ID = result.InsertedID.(primitive.ObjectID)
    return nil
}

func (r *roomRepository) FindByID(ctx context.Context, id primitive.ObjectID) (*domain.Room, error) {
    var room domain.Room
    err := r.collection.FindOne(ctx, bson.M{"_id": id}).Decode(&room)
    if err != nil {
        return nil, err
    }
    return &room, nil
}

func (r *roomRepository) FindUserRooms(ctx context.Context, userID primitive.ObjectID) ([]*domain.Room, error) {
    filter := bson.M{
        "members.user_id": userID,
    }

    opts := options.Find().SetSort(bson.D{{Key: "updated_at", Value: -1}})

    cursor, err := r.collection.Find(ctx, filter, opts)
    if err != nil {
        return nil, err
    }
    defer cursor.Close(ctx)

    var rooms []*domain.Room
    if err := cursor.All(ctx, &rooms); err != nil {
        return nil, err
    }

    return rooms, nil
}

func (r *roomRepository) AddMember(ctx context.Context, roomID, userID primitive.ObjectID, role string) error {
    filter := bson.M{"_id": roomID}
    update := bson.M{
        "$addToSet": bson.M{
            "members": domain.RoomMember{
                UserID:   userID,
                Role:     role,
                JoinedAt: time.Now(),
                Muted:    false,
                LastRead: time.Now(),
            },
        },
        "$set": bson.M{
            "updated_at": time.Now(),
        },
    }

    _, err := r.collection.UpdateOne(ctx, filter, update)
    return err
}

func (r *roomRepository) RemoveMember(ctx context.Context, roomID, userID primitive.ObjectID) error {
    filter := bson.M{"_id": roomID}
    update := bson.M{
        "$pull": bson.M{
            "members": bson.M{"user_id": userID},
        },
        "$set": bson.M{
            "updated_at": time.Now(),
        },
    }

    _, err := r.collection.UpdateOne(ctx, filter, update)
    return err
}

func (r *roomRepository) UpdateMemberRole(ctx context.Context, roomID, userID primitive.ObjectID, role string) error {
    filter := bson.M{
        "_id":              roomID,
        "members.user_id": userID,
    }
    update := bson.M{
        "$set": bson.M{
            "members.$.role": role,
            "updated_at":     time.Now(),
        },
    }

    _, err := r.collection.UpdateOne(ctx, filter, update)
    return err
}

func (r *roomRepository) UpdateSettings(ctx context.Context, roomID primitive.ObjectID, settings *domain.RoomSettings) error {
    filter := bson.M{"_id": roomID}
    update := bson.M{
        "$set": bson.M{
            "settings":   settings,
            "updated_at": time.Now(),
        },
    }

    _, err := r.collection.UpdateOne(ctx, filter, update)
    return err
}

func (r *roomRepository) IsMember(ctx context.Context, roomID, userID primitive.ObjectID) (bool, error) {
    filter := bson.M{
        "_id":              roomID,
        "members.user_id": userID,
    }

    count, err := r.collection.CountDocuments(ctx, filter)
    if err != nil {
        return false, err
    }

    return count > 0, nil
}
```

## WebSocket Handler

```go
package handler

import (
    "encoding/json"
    "log"
    "net/http"

    "github.com/gorilla/websocket"
    "github.com/gin-gonic/gin"
)

var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 1024,
    CheckOrigin: func(r *http.Request) bool {
        // Configure CORS properly for production
        return true
    },
}

type WebSocketHandler struct {
    hub *websocket.Hub
}

func NewWebSocketHandler(hub *websocket.Hub) *WebSocketHandler {
    return &WebSocketHandler{hub: hub}
}

// ServeWs handles websocket requests from clients
func (h *WebSocketHandler) ServeWs(c *gin.Context) {
    // Get user from auth middleware
    userID, exists := c.Get("userID")
    if !exists {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
        return
    }

    conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
    if err != nil {
        log.Printf("Failed to upgrade connection: %v", err)
        return
    }

    client := websocket.NewClient(conn, h.hub, userID.(string))
    h.hub.Register <- client

    // Start pumps in separate goroutines
    go client.WritePump()
    go client.ReadPump()
}

// JoinRoom handles room join requests
func (h *WebSocketHandler) JoinRoom(c *gin.Context) {
    clientID := c.Param("clientID")
    roomID := c.Param("roomID")

    h.hub.AddClientToRoom(clientID, roomID)
    
    c.JSON(http.StatusOK, gin.H{
        "message": "joined room successfully",
    })
}

// LeaveRoom handles room leave requests
func (h *WebSocketHandler) LeaveRoom(c *gin.Context) {
    clientID := c.Param("clientID")
    roomID := c.Param("roomID")

    h.hub.RemoveClientFromRoom(clientID, roomID)
    
    c.JSON(http.StatusOK, gin.H{
        "message": "left room successfully",
    })
}

// SendMessage handles HTTP message sending
func (h *WebSocketHandler) SendMessage(c *gin.Context) {
    var req struct {
        Type        string   `json:"type" binding:"required"`
        RecipientID string   `json:"recipientId,omitempty"`
        RoomID      string   `json:"roomId,omitempty"`
        Content     string   `json:"content" binding:"required"`
        ContentType string   `json:"contentType"`
    }

    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    userID := c.GetString("userID")

    msgData := websocket.MessageData{
        Type:        req.Type,
        SenderID:    userID,
        RecipientID: req.RecipientID,
        RoomID:      req.RoomID,
        Content:     req.Content,
        ContentType: req.ContentType,
    }

    data, _ := json.Marshal(msgData)
    
    h.hub.Broadcast <- &websocket.Message{
        Content: data,
    }

    c.JSON(http.StatusOK, gin.H{
        "message": "sent successfully",
    })
}
```

## Security Best Practices

### 1. Authentication Middleware

```go
package middleware

import (
    "net/http"
    "strings"

    "github.com/gin-gonic/gin"
    "github.com/golang-jwt/jwt/v5"
)

func AuthMiddleware(secretKey string) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "missing authorization header"})
            c.Abort()
            return
        }

        parts := strings.Split(authHeader, " ")
        if len(parts) != 2 || parts[0] != "Bearer" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization header"})
            c.Abort()
            return
        }

        token, err := jwt.Parse(parts[1], func(token *jwt.Token) (interface{}, error) {
            return []byte(secretKey), nil
        })

        if err != nil || !token.Valid {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
            c.Abort()
            return
        }

        claims, ok := token.Claims.(jwt.MapClaims)
        if !ok {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token claims"})
            c.Abort()
            return
        }

        c.Set("userID", claims["user_id"])
        c.Next()
    }
}
```

### 2. Rate Limiting

```go
package middleware

import (
    "net/http"
    "sync"
    "time"

    "github.com/gin-gonic/gin"
    "golang.org/x/time/rate"
)

type RateLimiter struct {
    limiters map[string]*rate.Limiter
    mu       sync.RWMutex
    rate     rate.Limit
    burst    int
}

func NewRateLimiter(r rate.Limit, b int) *RateLimiter {
    return &RateLimiter{
        limiters: make(map[string]*rate.Limiter),
        rate:     r,
        burst:    b,
    }
}

func (rl *RateLimiter) getLimiter(key string) *rate.Limiter {
    rl.mu.RLock()
    limiter, exists := rl.limiters[key]
    rl.mu.RUnlock()

    if !exists {
        rl.mu.Lock()
        limiter = rate.NewLimiter(rl.rate, rl.burst)
        rl.limiters[key] = limiter
        rl.mu.Unlock()
    }

    return limiter
}

func (rl *RateLimiter) Middleware() gin.HandlerFunc {
    // Cleanup old limiters periodically
    go func() {
        ticker := time.NewTicker(time.Minute)
        for range ticker.C {
            rl.mu.Lock()
            for key, limiter := range rl.limiters {
                if limiter.Tokens() == float64(rl.burst) {
                    delete(rl.limiters, key)
                }
            }
            rl.mu.Unlock()
        }
    }()

    return func(c *gin.Context) {
        key := c.ClientIP()
        limiter := rl.getLimiter(key)

        if !limiter.Allow() {
            c.JSON(http.StatusTooManyRequests, gin.H{
                "error": "rate limit exceeded",
            })
            c.Abort()
            return
        }

        c.Next()
    }
}
```

### 3. Message Validation

```go
package validator

import (
    "errors"
    "strings"
)

const (
    MaxMessageLength = 5000
    MaxRoomNameLength = 100
)

func ValidateMessage(content string) error {
    content = strings.TrimSpace(content)
    
    if content == "" {
        return errors.New("message cannot be empty")
    }
    
    if len(content) > MaxMessageLength {
        return errors.New("message exceeds maximum length")
    }
    
    return nil
}

func ValidateRoomName(name string) error {
    name = strings.TrimSpace(name)
    
    if name == "" {
        return errors.New("room name cannot be empty")
    }
    
    if len(name) > MaxRoomNameLength {
        return errors.New("room name exceeds maximum length")
    }
    
    return nil
}

func SanitizeMessage(content string) string {
    // Implement HTML sanitization if needed
    return strings.TrimSpace(content)
}
```

## Performance Optimization

### 1. Message Pagination

```go
// Cursor-based pagination for better performance
type MessagePagination struct {
    Limit  int
    Cursor string // Last message ID
}

func (r *messageRepository) FindMessagesByCursor(ctx context.Context, roomID primitive.ObjectID, pagination MessagePagination) ([]*domain.Message, error) {
    filter := bson.M{
        "room_id": roomID,
        "deleted_at": nil,
    }

    if pagination.Cursor != "" {
        cursorID, err := primitive.ObjectIDFromHex(pagination.Cursor)
        if err == nil {
            filter["_id"] = bson.M{"$lt": cursorID}
        }
    }

    opts := options.Find().
        SetSort(bson.D{{Key: "_id", Value: -1}}).
        SetLimit(int64(pagination.Limit))

    cursor, err := r.collection.Find(ctx, filter, opts)
    if err != nil {
        return nil, err
    }
    defer cursor.Close(ctx)

    var messages []*domain.Message
    if err := cursor.All(ctx, &messages); err != nil {
        return nil, err
    }

    return messages, nil
}
```

### 2. Connection Pooling

```go
package database

import (
    "context"
    "time"

    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

func NewMongoClient(uri string) (*mongo.Client, error) {
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    clientOptions := options.Client().
        ApplyURI(uri).
        SetMaxPoolSize(100).
        SetMinPoolSize(10).
        SetMaxConnIdleTime(30 * time.Second).
        SetServerSelectionTimeout(5 * time.Second).
        SetRetryWrites(true).
        SetRetryReads(true)

    client, err := mongo.Connect(ctx, clientOptions)
    if err != nil {
        return nil, err
    }

    // Ping to verify connection
    if err := client.Ping(ctx, nil); err != nil {
        return nil, err
    }

    return client, nil
}
```

### 3. Caching Strategy

```go
package cache

import (
    "context"
    "encoding/json"
    "time"

    "github.com/redis/go-redis/v9"
)

type Cache struct {
    client *redis.Client
}

func NewCache(addr string) *Cache {
    rdb := redis.NewClient(&redis.Options{
        Addr:         addr,
        PoolSize:     50,
        MinIdleConns: 10,
    })

    return &Cache{client: rdb}
}

func (c *Cache) SetUserStatus(ctx context.Context, userID string, status string) error {
    key := "user:status:" + userID
    return c.client.Set(ctx, key, status, 24*time.Hour).Err()
}

func (c *Cache) GetUserStatus(ctx context.Context, userID string) (string, error) {
    key := "user:status:" + userID
    return c.client.Get(ctx, key).Result()
}

func (c *Cache) CacheRoomMembers(ctx context.Context, roomID string, members []string) error {
    key := "room:members:" + roomID
    data, _ := json.Marshal(members)
    return c.client.Set(ctx, key, data, 10*time.Minute).Err()
}

func (c *Cache) GetRoomMembers(ctx context.Context, roomID string) ([]string, error) {
    key := "room:members:" + roomID
    data, err := c.client.Get(ctx, key).Result()
    if err != nil {
        return nil, err
    }

    var members []string
    json.Unmarshal([]byte(data), &members)
    return members, nil
}
```

## Main Application Setup

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

    "github.com/gin-gonic/gin"
)

func main() {
    // Load configuration
    cfg := config.Load()

    // Initialize MongoDB
    mongoClient, err := database.NewMongoClient(cfg.MongoURI)
    if err != nil {
        log.Fatal("Failed to connect to MongoDB:", err)
    }
    defer mongoClient.Disconnect(context.Background())

    db := mongoClient.Database(cfg.DatabaseName)

    // Create indexes
    if err := repository.CreateIndexes(context.Background(), db); err != nil {
        log.Fatal("Failed to create indexes:", err)
    }

    // Initialize repositories
    messageRepo := repository.NewMessageRepository(db)
    roomRepo := repository.NewRoomRepository(db)
    userRepo := repository.NewUserRepository(db)

    // Initialize services
    messageService := service.NewMessageService(messageRepo)
    chatService := service.NewChatService(messageRepo, roomRepo)

    // Initialize WebSocket hub
    hub := websocket.NewHub(messageService)
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    go hub.Run(ctx)

    // Initialize handlers
    wsHandler := handler.NewWebSocketHandler(hub)
    httpHandler := handler.NewHTTPHandler(chatService, userRepo)

    // Setup router
    router := gin.Default()

    // Middleware
    router.Use(middleware.CORS())
    rateLimiter := middleware.NewRateLimiter(10, 20) // 10 req/sec, burst 20
    router.Use(rateLimiter.Middleware())

    // Public routes
    public := router.Group("/api")
    {
        public.POST("/login", httpHandler.Login)
        public.POST("/register", httpHandler.Register)
    }

    // Protected routes
    protected := router.Group("/api")
    protected.Use(middleware.AuthMiddleware(cfg.JWTSecret))
    {
        // WebSocket
        protected.GET("/ws", wsHandler.ServeWs)
        
        // Messages
        protected.POST("/messages", wsHandler.SendMessage)
        protected.GET("/messages/direct/:userID", httpHandler.GetDirectMessages)
        protected.GET("/messages/room/:roomID", httpHandler.GetRoomMessages)
        
        // Rooms
        protected.POST("/rooms", httpHandler.CreateRoom)
        protected.GET("/rooms", httpHandler.GetUserRooms)
        protected.POST("/rooms/:roomID/join", httpHandler.JoinRoom)
        protected.POST("/rooms/:roomID/leave", httpHandler.LeaveRoom)
        protected.GET("/rooms/:roomID", httpHandler.GetRoom)
    }

    // Start server
    srv := &http.Server{
        Addr:    ":" + cfg.Port,
        Handler: router,
    }

    go func() {
        log.Printf("Server starting on port %s", cfg.Port)
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatal("Failed to start server:", err)
        }
    }()

    // Graceful shutdown
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("Shutting down server...")
    cancel() // Stop hub

    shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer shutdownCancel()

    if err := srv.Shutdown(shutdownCtx); err != nil {
        log.Fatal("Server forced to shutdown:", err)
    }

    log.Println("Server exited")
}
```

## Best Practices Summary

### 1. **Concurrency Management**
- Use buffered channels for message queuing
- Implement proper mutex locks for shared resources
- Limit goroutines with worker pools
- Use context for cancellation and timeouts

### 2. **Scalability**
- Implement horizontal scaling with Redis pub/sub
- Use MongoDB sharding for large datasets
- Load balance WebSocket connections
- Cache frequently accessed data

### 3. **Monitoring & Logging**
- Use structured logging (zap, logrus)
- Monitor connection counts and message rates
- Track database query performance
- Implement health check endpoints

### 4. **Error Handling**
- Always check and handle errors
- Use custom error types
- Implement retry mechanisms
- Log errors with context

### 5. **Testing**
- Unit test individual components
- Integration test WebSocket flows
- Load test with tools like k6
- Mock external dependencies

This guide provides a production-ready foundation for building scalable chat applications with Go, WebSockets, and MongoDB.
