# Elasticsearch Best Practices for Golang + PostgreSQL

## Table of Contents
1. [Overview](#overview)
2. [Architecture Patterns](#architecture-patterns)
3. [Integration Strategies](#integration-strategies)
4. [Implementation Guide](#implementation-guide)
5. [Synchronization Patterns](#synchronization-patterns)
6. [Performance Optimization](#performance-optimization)
7. [Error Handling](#error-handling)
8. [Testing Strategies](#testing-strategies)
9. [Production Considerations](#production-considerations)

## Overview

### When to Use Elasticsearch with PostgreSQL

**Use Elasticsearch when you need:**
- Full-text search with relevance scoring
- Complex text analysis (stemming, synonyms, n-grams)
- Fast aggregations on large datasets
- Fuzzy matching and typo tolerance
- Geospatial queries
- Real-time analytics

**Keep PostgreSQL for:**
- ACID transactions
- Complex joins and relationships
- Source of truth for your data
- Data integrity and constraints

### Key Principle
**PostgreSQL is your source of truth, Elasticsearch is your search/analytics layer.**

---

## Architecture Patterns

### Pattern 1: Event-Driven Synchronization (Recommended)

```
PostgreSQL (Write) → Event Queue → Elasticsearch Indexer
                ↓
         PostgreSQL (Read for details)
                ↑
         Elasticsearch (Search)
```

**Pros:**
- Decoupled systems
- Reliable with retry mechanisms
- Scalable
- Eventually consistent

**Cons:**
- Slight delay in search results
- More complex infrastructure

### Pattern 2: Application-Level Dual Write

```
Application → PostgreSQL (Primary)
           → Elasticsearch (Secondary)
```

**Pros:**
- Simpler architecture
- Near real-time updates

**Cons:**
- Risk of inconsistency
- Coupled systems
- No transaction guarantees

### Pattern 3: Change Data Capture (CDC)

```
PostgreSQL → Debezium/Logical Replication → Kafka → Elasticsearch
```

**Pros:**
- Zero application code changes
- Reliable and proven
- Captures all changes

**Cons:**
- Complex infrastructure
- Requires PostgreSQL logical replication

---

## Integration Strategies

### Strategy 1: Selective Indexing

Only index what you need to search.

```go
// PostgreSQL Model (Complete)
type User struct {
    ID              int64     `db:"id"`
    Email           string    `db:"email"`
    PasswordHash    string    `db:"password_hash"`
    FirstName       string    `db:"first_name"`
    LastName        string    `db:"last_name"`
    Bio             string    `db:"bio"`
    City            string    `db:"city"`
    Country         string    `db:"country"`
    ProfileImageURL string    `db:"profile_image_url"`
    IsActive        bool      `db:"is_active"`
    CreatedAt       time.Time `db:"created_at"`
    UpdatedAt       time.Time `db:"updated_at"`
}

// Elasticsearch Model (Searchable Fields Only)
type UserSearchDocument struct {
    ID        int64     `json:"id"`
    Email     string    `json:"email"`
    FirstName string    `json:"first_name"`
    LastName  string    `json:"last_name"`
    FullName  string    `json:"full_name"` // Computed field
    Bio       string    `json:"bio"`
    City      string    `json:"city"`
    Country   string    `json:"country"`
    IsActive  bool      `json:"is_active"`
    CreatedAt time.Time `json:"created_at"`
}
```

### Strategy 2: Read from PostgreSQL After Search

```go
// 1. Search in Elasticsearch (fast)
userIDs := searchElasticsearch(query)

// 2. Fetch full details from PostgreSQL (authoritative)
users := fetchUsersFromPostgres(userIDs)
```

---

## Implementation Guide

### 1. Setup Elasticsearch Client

```go
package elasticsearch

import (
    "crypto/tls"
    "github.com/elastic/go-elasticsearch/v8"
    "go.uber.org/zap"
    "time"
)

type Config struct {
    Addresses []string
    Username  string
    Password  string
    CloudID   string
    APIKey    string
}

func NewClient(cfg Config, logger *zap.Logger) (*elasticsearch.Client, error) {
    esCfg := elasticsearch.Config{
        Addresses: cfg.Addresses,
        Username:  cfg.Username,
        Password:  cfg.Password,
        CloudID:   cfg.CloudID,
        APIKey:    cfg.APIKey,
        
        // Connection pooling
        Transport: &http.Transport{
            MaxIdleConnsPerHost:   10,
            ResponseHeaderTimeout: 5 * time.Second,
            DialContext:           (&net.Dialer{Timeout: 5 * time.Second}).DialContext,
            TLSClientConfig: &tls.Config{
                MinVersion: tls.VersionTLS12,
            },
        },
        
        // Retry configuration
        RetryOnStatus: []int{502, 503, 504, 429},
        MaxRetries:    3,
        RetryBackoff:  func(i int) time.Duration {
            return time.Duration(i) * 100 * time.Millisecond
        },
    }
    
    client, err := elasticsearch.NewClient(esCfg)
    if err != nil {
        return nil, err
    }
    
    // Verify connection
    res, err := client.Info()
    if err != nil {
        return nil, err
    }
    defer res.Body.Close()
    
    if res.IsError() {
        return nil, fmt.Errorf("elasticsearch connection error: %s", res.String())
    }
    
    logger.Info("Connected to Elasticsearch", zap.Any("info", res))
    return client, nil
}
```

### 2. Index Management

```go
package elasticsearch

const userIndexMapping = `
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "name_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "asciifolding", "name_edge_ngram"]
        },
        "email_analyzer": {
          "type": "custom",
          "tokenizer": "keyword",
          "filter": ["lowercase"]
        }
      },
      "filter": {
        "name_edge_ngram": {
          "type": "edge_ngram",
          "min_gram": 2,
          "max_gram": 20
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "id": { "type": "long" },
      "email": {
        "type": "text",
        "analyzer": "email_analyzer",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      },
      "first_name": {
        "type": "text",
        "analyzer": "name_analyzer",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      },
      "last_name": {
        "type": "text",
        "analyzer": "name_analyzer",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      },
      "full_name": {
        "type": "text",
        "analyzer": "name_analyzer"
      },
      "bio": {
        "type": "text",
        "analyzer": "standard"
      },
      "city": {
        "type": "text",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      },
      "country": {
        "type": "keyword"
      },
      "is_active": { "type": "boolean" },
      "created_at": { "type": "date" }
    }
  }
}
`

func CreateUserIndex(client *elasticsearch.Client, indexName string) error {
    res, err := client.Indices.Create(
        indexName,
        client.Indices.Create.WithBody(strings.NewReader(userIndexMapping)),
    )
    if err != nil {
        return err
    }
    defer res.Body.Close()
    
    if res.IsError() {
        return fmt.Errorf("error creating index: %s", res.String())
    }
    
    return nil
}

func DeleteIndex(client *elasticsearch.Client, indexName string) error {
    res, err := client.Indices.Delete([]string{indexName})
    if err != nil {
        return err
    }
    defer res.Body.Close()
    
    return nil
}
```

### 3. Document Indexing

```go
package elasticsearch

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "github.com/elastic/go-elasticsearch/v8"
    "github.com/elastic/go-elasticsearch/v8/esapi"
    "go.uber.org/zap"
)

type UserIndexer struct {
    client    *elasticsearch.Client
    indexName string
    logger    *zap.Logger
}

func NewUserIndexer(client *elasticsearch.Client, indexName string, logger *zap.Logger) *UserIndexer {
    return &UserIndexer{
        client:    client,
        indexName: indexName,
        logger:    logger,
    }
}

// IndexUser indexes a single user document
func (ui *UserIndexer) IndexUser(ctx context.Context, user UserSearchDocument) error {
    // Convert struct to JSON
    data, err := json.Marshal(user)
    if err != nil {
        return fmt.Errorf("failed to marshal user: %w", err)
    }
    
    // Index document
    req := esapi.IndexRequest{
        Index:      ui.indexName,
        DocumentID: fmt.Sprintf("%d", user.ID),
        Body:       bytes.NewReader(data),
        Refresh:    "false", // Don't force refresh for performance
    }
    
    res, err := req.Do(ctx, ui.client)
    if err != nil {
        return fmt.Errorf("failed to index user: %w", err)
    }
    defer res.Body.Close()
    
    if res.IsError() {
        return fmt.Errorf("elasticsearch error: %s", res.String())
    }
    
    ui.logger.Debug("User indexed successfully", zap.Int64("user_id", user.ID))
    return nil
}

// BulkIndexUsers indexes multiple users efficiently
func (ui *UserIndexer) BulkIndexUsers(ctx context.Context, users []UserSearchDocument) error {
    if len(users) == 0 {
        return nil
    }
    
    var buf bytes.Buffer
    
    for _, user := range users {
        // Action metadata
        meta := map[string]interface{}{
            "index": map[string]interface{}{
                "_index": ui.indexName,
                "_id":    fmt.Sprintf("%d", user.ID),
            },
        }
        
        if err := json.NewEncoder(&buf).Encode(meta); err != nil {
            return fmt.Errorf("failed to encode meta: %w", err)
        }
        
        // Document data
        if err := json.NewEncoder(&buf).Encode(user); err != nil {
            return fmt.Errorf("failed to encode user: %w", err)
        }
    }
    
    res, err := ui.client.Bulk(
        bytes.NewReader(buf.Bytes()),
        ui.client.Bulk.WithContext(ctx),
        ui.client.Bulk.WithIndex(ui.indexName),
    )
    if err != nil {
        return fmt.Errorf("bulk indexing failed: %w", err)
    }
    defer res.Body.Close()
    
    if res.IsError() {
        return fmt.Errorf("elasticsearch bulk error: %s", res.String())
    }
    
    // Parse response for errors
    var bulkRes map[string]interface{}
    if err := json.NewDecoder(res.Body).Decode(&bulkRes); err != nil {
        return fmt.Errorf("failed to parse bulk response: %w", err)
    }
    
    if bulkRes["errors"].(bool) {
        ui.logger.Warn("Some documents failed to index", zap.Any("response", bulkRes))
    }
    
    ui.logger.Info("Bulk indexing completed", zap.Int("count", len(users)))
    return nil
}

// DeleteUser removes a user document
func (ui *UserIndexer) DeleteUser(ctx context.Context, userID int64) error {
    req := esapi.DeleteRequest{
        Index:      ui.indexName,
        DocumentID: fmt.Sprintf("%d", userID),
    }
    
    res, err := req.Do(ctx, ui.client)
    if err != nil {
        return fmt.Errorf("failed to delete user: %w", err)
    }
    defer res.Body.Close()
    
    if res.IsError() && res.StatusCode != 404 {
        return fmt.Errorf("elasticsearch delete error: %s", res.String())
    }
    
    return nil
}
```

### 4. Search Implementation

```go
package elasticsearch

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
)

type SearchRequest struct {
    Query    string
    Filters  map[string]interface{}
    From     int
    Size     int
    SortBy   string
    SortDesc bool
}

type SearchResult struct {
    Total int64
    Users []UserSearchDocument
    Took  int
}

func (ui *UserIndexer) SearchUsers(ctx context.Context, req SearchRequest) (*SearchResult, error) {
    // Build query
    query := buildSearchQuery(req)
    
    var buf bytes.Buffer
    if err := json.NewEncoder(&buf).Encode(query); err != nil {
        return nil, fmt.Errorf("failed to encode query: %w", err)
    }
    
    // Execute search
    res, err := ui.client.Search(
        ui.client.Search.WithContext(ctx),
        ui.client.Search.WithIndex(ui.indexName),
        ui.client.Search.WithBody(&buf),
        ui.client.Search.WithTrackTotalHits(true),
    )
    if err != nil {
        return nil, fmt.Errorf("search request failed: %w", err)
    }
    defer res.Body.Close()
    
    if res.IsError() {
        return nil, fmt.Errorf("elasticsearch search error: %s", res.String())
    }
    
    // Parse response
    var searchRes map[string]interface{}
    if err := json.NewDecoder(res.Body).Decode(&searchRes); err != nil {
        return nil, fmt.Errorf("failed to parse search response: %w", err)
    }
    
    return parseSearchResponse(searchRes)
}

func buildSearchQuery(req SearchRequest) map[string]interface{} {
    query := map[string]interface{}{
        "from": req.From,
        "size": req.Size,
    }
    
    // Build bool query
    boolQuery := map[string]interface{}{
        "must": []interface{}{},
        "filter": []interface{}{},
    }
    
    // Text search
    if req.Query != "" {
        boolQuery["must"] = append(boolQuery["must"].([]interface{}), map[string]interface{}{
            "multi_match": map[string]interface{}{
                "query":  req.Query,
                "fields": []string{"full_name^3", "email^2", "bio"},
                "type":   "best_fields",
                "fuzziness": "AUTO",
            },
        })
    } else {
        boolQuery["must"] = append(boolQuery["must"].([]interface{}), map[string]interface{}{
            "match_all": map[string]interface{}{},
        })
    }
    
    // Filters
    if country, ok := req.Filters["country"].(string); ok && country != "" {
        boolQuery["filter"] = append(boolQuery["filter"].([]interface{}), map[string]interface{}{
            "term": map[string]interface{}{"country": country},
        })
    }
    
    if isActive, ok := req.Filters["is_active"].(bool); ok {
        boolQuery["filter"] = append(boolQuery["filter"].([]interface{}), map[string]interface{}{
            "term": map[string]interface{}{"is_active": isActive},
        })
    }
    
    query["query"] = map[string]interface{}{"bool": boolQuery}
    
    // Sorting
    if req.SortBy != "" {
        order := "asc"
        if req.SortDesc {
            order = "desc"
        }
        query["sort"] = []interface{}{
            map[string]interface{}{
                req.SortBy: map[string]interface{}{"order": order},
            },
        }
    }
    
    return query
}

func parseSearchResponse(res map[string]interface{}) (*SearchResult, error) {
    hits := res["hits"].(map[string]interface{})
    total := hits["total"].(map[string]interface{})
    took := int(res["took"].(float64))
    
    result := &SearchResult{
        Total: int64(total["value"].(float64)),
        Took:  took,
        Users: []UserSearchDocument{},
    }
    
    for _, hit := range hits["hits"].([]interface{}) {
        h := hit.(map[string]interface{})
        source := h["_source"].(map[string]interface{})
        
        var user UserSearchDocument
        data, _ := json.Marshal(source)
        json.Unmarshal(data, &user)
        
        result.Users = append(result.Users, user)
    }
    
    return result, nil
}
```

---

## Synchronization Patterns

### Pattern 1: Application-Level Sync

```go
package service

type UserService struct {
    userRepo      *repository.UserRepository
    esIndexer     *elasticsearch.UserIndexer
    logger        *zap.Logger
}

func (s *UserService) CreateUser(ctx context.Context, user *User) error {
    // 1. Write to PostgreSQL (source of truth)
    if err := s.userRepo.Create(ctx, user); err != nil {
        return fmt.Errorf("failed to create user in postgres: %w", err)
    }
    
    // 2. Index in Elasticsearch (best effort)
    searchDoc := toSearchDocument(user)
    if err := s.esIndexer.IndexUser(ctx, searchDoc); err != nil {
        // Log error but don't fail the operation
        s.logger.Error("Failed to index user in Elasticsearch",
            zap.Error(err),
            zap.Int64("user_id", user.ID),
        )
        // Consider: Send to dead letter queue for retry
    }
    
    return nil
}

func (s *UserService) UpdateUser(ctx context.Context, user *User) error {
    // 1. Update PostgreSQL
    if err := s.userRepo.Update(ctx, user); err != nil {
        return fmt.Errorf("failed to update user: %w", err)
    }
    
    // 2. Update Elasticsearch
    searchDoc := toSearchDocument(user)
    if err := s.esIndexer.IndexUser(ctx, searchDoc); err != nil {
        s.logger.Error("Failed to update user in Elasticsearch",
            zap.Error(err),
            zap.Int64("user_id", user.ID),
        )
    }
    
    return nil
}

func (s *UserService) DeleteUser(ctx context.Context, userID int64) error {
    // 1. Delete from PostgreSQL
    if err := s.userRepo.Delete(ctx, userID); err != nil {
        return fmt.Errorf("failed to delete user: %w", err)
    }
    
    // 2. Delete from Elasticsearch
    if err := s.esIndexer.DeleteUser(ctx, userID); err != nil {
        s.logger.Error("Failed to delete user from Elasticsearch",
            zap.Error(err),
            zap.Int64("user_id", userID),
        )
    }
    
    return nil
}
```

### Pattern 2: Event-Driven Sync (Recommended)

```go
package events

type UserEvent struct {
    Type      string    `json:"type"` // created, updated, deleted
    UserID    int64     `json:"user_id"`
    User      *User     `json:"user,omitempty"`
    Timestamp time.Time `json:"timestamp"`
}

type EventPublisher interface {
    Publish(ctx context.Context, event UserEvent) error
}

// In your service
func (s *UserService) CreateUser(ctx context.Context, user *User) error {
    // 1. Write to PostgreSQL
    if err := s.userRepo.Create(ctx, user); err != nil {
        return err
    }
    
    // 2. Publish event
    event := UserEvent{
        Type:      "created",
        UserID:    user.ID,
        User:      user,
        Timestamp: time.Now(),
    }
    
    if err := s.eventPublisher.Publish(ctx, event); err != nil {
        s.logger.Error("Failed to publish user event", zap.Error(err))
        // Event will be retried or handled by dead letter queue
    }
    
    return nil
}

// Separate indexer service
type IndexerWorker struct {
    eventSubscriber EventSubscriber
    esIndexer       *elasticsearch.UserIndexer
    logger          *zap.Logger
}

func (w *IndexerWorker) ProcessEvents(ctx context.Context) error {
    events, err := w.eventSubscriber.Subscribe(ctx, "user-events")
    if err != nil {
        return err
    }
    
    for event := range events {
        if err := w.handleEvent(ctx, event); err != nil {
            w.logger.Error("Failed to process event",
                zap.Error(err),
                zap.Any("event", event),
            )
            // Retry logic here
        }
    }
    
    return nil
}

func (w *IndexerWorker) handleEvent(ctx context.Context, event UserEvent) error {
    switch event.Type {
    case "created", "updated":
        searchDoc := toSearchDocument(event.User)
        return w.esIndexer.IndexUser(ctx, searchDoc)
    case "deleted":
        return w.esIndexer.DeleteUser(ctx, event.UserID)
    default:
        return fmt.Errorf("unknown event type: %s", event.Type)
    }
}
```

### Pattern 3: Periodic Full Reindex

```go
package jobs

type ReindexJob struct {
    userRepo  *repository.UserRepository
    esIndexer *elasticsearch.UserIndexer
    esClient  *elasticsearch.Client
    logger    *zap.Logger
}

func (j *ReindexJob) Run(ctx context.Context) error {
    newIndex := fmt.Sprintf("users_%d", time.Now().Unix())
    oldIndex := "users"
    aliasName := "users"
    
    // 1. Create new index
    if err := elasticsearch.CreateUserIndex(j.esClient, newIndex); err != nil {
        return fmt.Errorf("failed to create new index: %w", err)
    }
    
    // 2. Index all users from PostgreSQL
    offset := 0
    batchSize := 1000
    
    for {
        users, err := j.userRepo.FindAll(ctx, offset, batchSize)
        if err != nil {
            return fmt.Errorf("failed to fetch users: %w", err)
        }
        
        if len(users) == 0 {
            break
        }
        
        // Convert to search documents
        searchDocs := make([]elasticsearch.UserSearchDocument, len(users))
        for i, user := range users {
            searchDocs[i] = toSearchDocument(&user)
        }
        
        // Bulk index
        if err := j.esIndexer.BulkIndexUsers(ctx, searchDocs); err != nil {
            return fmt.Errorf("bulk indexing failed: %w", err)
        }
        
        j.logger.Info("Indexed batch", zap.Int("offset", offset), zap.Int("count", len(users)))
        offset += batchSize
    }
    
    // 3. Switch alias atomically
    if err := j.switchAlias(ctx, aliasName, oldIndex, newIndex); err != nil {
        return fmt.Errorf("failed to switch alias: %w", err)
    }
    
    // 4. Delete old index
    if err := elasticsearch.DeleteIndex(j.esClient, oldIndex); err != nil {
        j.logger.Warn("Failed to delete old index", zap.Error(err))
    }
    
    j.logger.Info("Reindex completed successfully")
    return nil
}

func (j *ReindexJob) switchAlias(ctx context.Context, alias, oldIndex, newIndex string) error {
    // Atomic alias switch
    body := map[string]interface{}{
        "actions": []interface{}{
            map[string]interface{}{
                "remove": map[string]interface{}{
                    "index": oldIndex,
                    "alias": alias,
                },
            },
            map[string]interface{}{
                "add": map[string]interface{}{
                    "index": newIndex,
                    "alias": alias,
                },
            },
        },
    }
    
    var buf bytes.Buffer
    json.NewEncoder(&buf).Encode(body)
    
    res, err := j.esClient.Indices.UpdateAliases(&buf)
    if err != nil {
        return err
    }
    defer res.Body.Close()
    
    if res.IsError() {
        return fmt.Errorf("alias update failed: %s", res.String())
    }
    
    return nil
}
```

---

## Performance Optimization

### 1. Bulk Operations

```go
// BAD: Indexing one by one
for _, user := range users {
    indexer.IndexUser(ctx, user) // N network calls
}

// GOOD: Bulk indexing
indexer.BulkIndexUsers(ctx, users) // 1 network call
```

### 2. Connection Pooling

```go
// Configure client with proper pooling
esCfg := elasticsearch.Config{
    Transport: &http.Transport{
        MaxIdleConnsPerHost:   10,
        MaxIdleConns:          100,
        IdleConnTimeout:       90 * time.Second,
    },
}
```

### 3. Async Indexing

```go
type AsyncIndexer struct {
    indexer *UserIndexer
    queue   chan UserSearchDocument
    workers int
}

func NewAsyncIndexer(indexer *UserIndexer, workers int) *AsyncIndexer {
    ai := &AsyncIndexer{
        indexer: indexer,
        queue:   make(chan UserSearchDocument, 1000),
        workers: workers,
    }
    
    // Start worker pool
    for i := 0; i < workers; i++ {
        go ai.worker()
    }
    
    return ai
}

func (ai *AsyncIndexer) Index(user UserSearchDocument) {
    ai.queue <- user
}

func (ai *AsyncIndexer) worker() {
    batch := make([]UserSearchDocument, 0, 100)
    ticker := time.NewTicker(1 * time.Second)
    
    for {
        select {
        case user := <-ai.queue:
            batch = append(batch, user)
            if len(batch) >= 100 {
                ai.indexer.BulkIndexUsers(context.Background(), batch)
                batch = batch[:0]
            }
        case <-ticker.C:
            if len(batch) > 0 {
                ai.indexer.BulkIndexUsers(context.Background(), batch)
                batch = batch[:0]
            }
        }
    }
}
```

### 4. Query Optimization

```go
// Use filters instead of queries when you don't need scoring
// Filters are cached and faster
query := map[string]interface{}{
    "query": map[string]interface{}{
        "bool": map[string]interface{}{
            "must": map[string]interface{}{
                "match": map[string]interface{}{
                    "full_name": searchTerm,
                },
            },
            "filter": []interface{}{ // Filters are cached!
                map[string]interface{}{
                    "term": map[string]interface{}{"is_active": true},
                },
                map[string]interface{}{
                    "term": map[string]interface{}{"country": "US"},
                },
            },
        },
    },
}
```

---

## Error Handling

### 1. Graceful Degradation

```go
func (s *UserService) SearchUsers(ctx context.Context, query string) ([]User, error) {
    // Try Elasticsearch first
    esResults, err := s.esIndexer.SearchUsers(ctx, SearchRequest{Query: query})
    if err != nil {
        s.logger.Warn("Elasticsearch search failed, falling back to PostgreSQL",
            zap.Error(err),
        )
        // Fallback to PostgreSQL
        return s.userRepo.SearchByName(ctx, query)
    }
    
    // Get full details from PostgreSQL
    userIDs := make([]int64, len(esResults.Users))
    for i, u := range esResults.Users {
        userIDs[i] = u.ID
    }
    
    return s.userRepo.FindByIDs(ctx, userIDs)
}
```

### 2. Retry Logic

```go
func (ui *UserIndexer) IndexUserWithRetry(ctx context.Context, user UserSearchDocument, maxRetries int) error {
    var err error
    for i := 0; i < maxRetries; i++ {
        err = ui.IndexUser(ctx, user)
        if err == nil {
            return nil
        }
        
        // Exponential backoff
        backoff := time.Duration(math.Pow(2, float64(i))) * 100 * time.Millisecond
        time.Sleep(backoff)
    }
    
    return fmt.Errorf("failed after %d retries: %w", maxRetries, err)
}
```

### 3. Circuit Breaker

```go
import "github.com/sony/gobreaker"

type ResilientIndexer struct {
    indexer *UserIndexer
    cb      *gobreaker.CircuitBreaker
}

func NewResilientIndexer(indexer *UserIndexer) *ResilientIndexer {
    settings := gobreaker.Settings{
        Name:        "elasticsearch",
        MaxRequests: 3,
        Interval:    60 * time.Second,
        Timeout:     30 * time.Second,
        ReadyToTrip: func(counts gobreaker.Counts) bool {
            failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
            return counts.Requests >= 3 && failureRatio >= 0.6
        },
    }
    
    return &ResilientIndexer{
        indexer: indexer,
        cb:      gobreaker.NewCircuitBreaker(settings),
    }
}

func (ri *ResilientIndexer) IndexUser(ctx context.Context, user UserSearchDocument) error {
    _, err := ri.cb.Execute(func() (interface{}, error) {
        return nil, ri.indexer.IndexUser(ctx, user)
    })
    return err
}
```

---

## Testing Strategies

### 1. Integration Tests with Testcontainers

```go
import (
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/wait"
)

func setupElasticsearchContainer(t *testing.T) (*elasticsearch.Client, func()) {
    ctx := context.Background()
    
    req := testcontainers.ContainerRequest{
        Image:        "docker.elastic.co/elasticsearch/elasticsearch:8.10.0",
        ExposedPorts: []string{"9200/tcp"},
        Env: map[string]string{
            "discovery.type":         "single-node",
            "xpack.security.enabled": "false",
        },
        WaitingFor: wait.ForHTTP("/").WithPort("9200/tcp"),
    }
    
    container, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
        ContainerRequest: req,
        Started:          true,
    })
    require.NoError(t, err)
    
    host, _ := container.Host(ctx)
    port, _ := container.MappedPort(ctx, "9200")
    
    client, err := elasticsearch.NewClient(elasticsearch.Config{
        Addresses: []string{fmt.Sprintf("http://%s:%s", host, port.Port())},
    })
    require.NoError(t, err)
    
    cleanup := func() {
        container.Terminate(ctx)
    }
    
    return client, cleanup
}

func TestUserIndexer(t *testing.T) {
    client, cleanup := setupElasticsearchContainer(t)
    defer cleanup()
    
    indexer := NewUserIndexer(client, "test_users", zap.NewNop())
    
    // Create index
    err := CreateUserIndex(client, "test_users")
    require.NoError(t, err)
    
    // Test indexing
    user := UserSearchDocument{
        ID:        1,
        Email:     "test@example.com",
        FirstName: "John",
        LastName:  "Doe",
    }
    
    err = indexer.IndexUser(context.Background(), user)
    require.NoError(t, err)
    
    // Wait for indexing
    time.Sleep(1 * time.Second)
    
    // Test search
    results, err := indexer.SearchUsers(context.Background(), SearchRequest{
        Query: "John",
    })
    require.NoError(t, err)
    assert.Equal(t, int64(1), results.Total)
}
```

### 2. Mock Elasticsearch for Unit Tests

```go
type MockIndexer struct {
    mock.Mock
}

func (m *MockIndexer) IndexUser(ctx context.Context, user UserSearchDocument) error {
    args := m.Called(ctx, user)
    return args.Error(0)
}

func TestUserService_CreateUser(t *testing.T) {
    mockRepo := new(MockUserRepository)
    mockIndexer := new(MockIndexer)
    
    service := &UserService{
        userRepo:  mockRepo,
        esIndexer: mockIndexer,
        logger:    zap.NewNop(),
    }
    
    user := &User{FirstName: "John", LastName: "Doe"}
    
    mockRepo.On("Create", mock.Anything, user).Return(nil)
    mockIndexer.On("IndexUser", mock.Anything, mock.Anything).Return(nil)
    
    err := service.CreateUser(context.Background(), user)
    assert.NoError(t, err)
    
    mockRepo.AssertExpectations(t)
    mockIndexer.AssertExpectations(t)
}
```

---

## Production Considerations

### 1. Monitoring

```go
import "github.com/prometheus/client_golang/prometheus"

var (
    esIndexDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "elasticsearch_index_duration_seconds",
            Help: "Time taken to index documents",
        },
        []string{"operation"},
    )
    
    esIndexErrors = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "elasticsearch_index_errors_total",
            Help: "Total number of indexing errors",
        },
        []string{"operation"},
    )
)

func init() {
    prometheus.MustRegister(esIndexDuration)
    prometheus.MustRegister(esIndexErrors)
}

func (ui *UserIndexer) IndexUser(ctx context.Context, user UserSearchDocument) error {
    start := time.Now()
    defer func() {
        esIndexDuration.WithLabelValues("index_user").Observe(time.Since(start).Seconds())
    }()
    
    err := ui.indexUser(ctx, user)
    if err != nil {
        esIndexErrors.WithLabelValues("index_user").Inc()
    }
    
    return err
}
```

### 2. Health Checks

```go
func (ui *UserIndexer) HealthCheck(ctx context.Context) error {
    res, err := ui.client.Cluster.Health(
        ui.client.Cluster.Health.WithContext(ctx),
    )
    if err != nil {
        return fmt.Errorf("cluster health check failed: %w", err)
    }
    defer res.Body.Close()
    
    if res.IsError() {
        return fmt.Errorf("cluster unhealthy: %s", res.String())
    }
    
    var health map[string]interface{}
    if err := json.NewDecoder(res.Body).Decode(&health); err != nil {
        return err
    }
    
    status := health["status"].(string)
    if status == "red" {
        return fmt.Errorf("cluster status is red")
    }
    
    return nil
}
```

### 3. Configuration Management

```go
type ElasticsearchConfig struct {
    Addresses           []string      `yaml:"addresses"`
    Username            string        `yaml:"username"`
    Password            string        `yaml:"password"`
    MaxRetries          int           `yaml:"max_retries"`
    IndexName           string        `yaml:"index_name"`
    BulkSize            int           `yaml:"bulk_size"`
    FlushInterval       time.Duration `yaml:"flush_interval"`
    NumShards           int           `yaml:"num_shards"`
    NumReplicas         int           `yaml:"num_replicas"`
    EnableSniffing      bool          `yaml:"enable_sniffing"`
    HealthCheckInterval time.Duration `yaml:"health_check_interval"`
}

// config.yaml
/*
elasticsearch:
  addresses:
    - http://localhost:9200
  username: elastic
  password: changeme
  max_retries: 3
  index_name: users
  bulk_size: 1000
  flush_interval: 1s
  num_shards: 3
  num_replicas: 1
  enable_sniffing: false
  health_check_interval: 30s
*/
```

### 4. Index Lifecycle Management

```go
// Setup ILM policy
const ilmPolicy = `
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "50GB",
            "max_age": "7d"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": {
            "number_of_shards": 1
          },
          "forcemerge": {
            "max_num_segments": 1
          }
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
`
```

---

## Summary Checklist

### Architecture
- [ ] PostgreSQL is the source of truth
- [ ] Elasticsearch is for search/analytics only
- [ ] Use event-driven sync for production
- [ ] Implement fallback to PostgreSQL

### Performance
- [ ] Use bulk operations (batch size: 1000-5000)
- [ ] Configure connection pooling
- [ ] Implement async indexing for high throughput
- [ ] Use filters for non-scored queries
- [ ] Enable query caching

### Reliability
- [ ] Implement retry logic with exponential backoff
- [ ] Use circuit breakers
- [ ] Handle Elasticsearch downtime gracefully
- [ ] Implement dead letter queue for failed events
- [ ] Set up periodic full reindex

### Monitoring
- [ ] Track indexing latency
- [ ] Monitor error rates
- [ ] Set up health checks
- [ ] Alert on cluster health issues
- [ ] Monitor search performance

### Testing
- [ ] Integration tests with Testcontainers
- [ ] Unit tests with mocks
- [ ] Load testing for bulk operations
- [ ] Test failover scenarios

### Production
- [ ] Use index aliases for zero-downtime reindex
- [ ] Configure proper shard/replica counts
- [ ] Set up ILM policies
- [ ] Enable security (TLS, authentication)
- [ ] Regular backups with snapshots

---

## Additional Resources

- [Official Go Elasticsearch Client](https://github.com/elastic/go-elasticsearch)
- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [PostgreSQL Full-Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- [Change Data Capture with Debezium](https://debezium.io/)
- [Testcontainers Go](https://golang.testcontainers.org/)

---

**Last Updated:** October 31, 2025
