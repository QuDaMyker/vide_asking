# Step-by-Step Guide: Implementing Elasticsearch with Golang + PostgreSQL

## 🎯 What We'll Build

A user search system where:
- **PostgreSQL** stores user data (source of truth)
- **Elasticsearch** provides fast full-text search
- Data stays synchronized between both systems

---

## 📋 Prerequisites

```bash
# Check your Go version (need 1.19+)
go version

# Install Docker (for running Elasticsearch & PostgreSQL locally)
docker --version

# Install Docker Compose
docker-compose --version
```

---

## Step 1: Project Setup

### 1.1 Create Project Structure

```bash
# Create project directory
mkdir user-search-service
cd user-search-service

# Initialize Go module
go mod init github.com/yourusername/user-search-service

# Create directory structure
mkdir -p cmd/api
mkdir -p internal/{database,elasticsearch,repository,service,handler,models}
mkdir -p config
mkdir -p migrations
mkdir -p scripts
```

Your structure should look like:
```
user-search-service/
├── cmd/
│   └── api/
│       └── main.go
├── internal/
│   ├── database/
│   │   └── postgres.go
│   ├── elasticsearch/
│   │   ├── client.go
│   │   ├── indexer.go
│   │   └── search.go
│   ├── repository/
│   │   └── user_repository.go
│   ├── service/
│   │   └── user_service.go
│   ├── handler/
│   │   └── user_handler.go
│   └── models/
│       └── user.go
├── config/
│   └── config.yaml
├── migrations/
│   └── 001_create_users_table.sql
├── docker-compose.yml
├── Makefile
└── go.mod
```

### 1.2 Install Dependencies

```bash
# Database
go get github.com/lib/pq
go get github.com/jmoiron/sqlx

# Elasticsearch
go get github.com/elastic/go-elasticsearch/v8

# Web framework
go get github.com/gin-gonic/gin

# Configuration
go get github.com/spf13/viper

# Logging
go get go.uber.org/zap

# Database migrations
go get github.com/golang-migrate/migrate/v4
go get github.com/golang-migrate/migrate/v4/database/postgres
go get github.com/golang-migrate/migrate/v4/source/file
```

---

## Step 2: Setup Docker Environment

### 2.1 Create `docker-compose.yml`

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: user_search_postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: userdb
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.10.0
    container_name: user_search_elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
      - "9300:9300"
    volumes:
      - es_data:/usr/share/elasticsearch/data
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  postgres_data:
  es_data:
```

### 2.2 Start Services

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Test PostgreSQL connection
docker exec -it user_search_postgres psql -U postgres -d userdb

# Test Elasticsearch connection
curl http://localhost:9200
```

---

## Step 3: Database Setup

### 3.1 Create Migration File

Create `migrations/001_create_users_table.sql`:

```sql
-- migrations/001_create_users_table.sql
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    bio TEXT,
    city VARCHAR(100),
    country VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_name ON users(first_name, last_name);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data
INSERT INTO users (email, first_name, last_name, bio, city, country) VALUES
('john.doe@example.com', 'John', 'Doe', 'Software engineer passionate about distributed systems', 'San Francisco', 'USA'),
('jane.smith@example.com', 'Jane', 'Smith', 'Full-stack developer and tech blogger', 'New York', 'USA'),
('bob.wilson@example.com', 'Bob', 'Wilson', 'DevOps engineer specializing in Kubernetes', 'London', 'UK'),
('alice.brown@example.com', 'Alice', 'Brown', 'Data scientist working with ML and AI', 'Toronto', 'Canada'),
('charlie.davis@example.com', 'Charlie', 'Davis', 'Mobile app developer for iOS and Android', 'Sydney', 'Australia');
```

### 3.2 Run Migration

Create `scripts/migrate.sh`:

```bash
#!/bin/bash

# scripts/migrate.sh
docker exec -i user_search_postgres psql -U postgres -d userdb < migrations/001_create_users_table.sql

echo "Migration completed!"
```

```bash
# Make executable and run
chmod +x scripts/migrate.sh
./scripts/migrate.sh
```

---

## Step 4: Configuration

### 4.1 Create `config/config.yaml`

```yaml
server:
  port: 8080
  host: localhost

database:
  host: localhost
  port: 5432
  user: postgres
  password: postgres
  dbname: userdb
  sslmode: disable
  max_open_conns: 25
  max_idle_conns: 5
  conn_max_lifetime: 5m

elasticsearch:
  addresses:
    - http://localhost:9200
  username: ""
  password: ""
  index_name: users
  max_retries: 3
  bulk_size: 1000
  num_shards: 1
  num_replicas: 0

logging:
  level: debug
  encoding: console
```

### 4.2 Create Config Loader

Create `internal/config/config.go`:

```go
package config

import (
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	Server        ServerConfig        `mapstructure:"server"`
	Database      DatabaseConfig      `mapstructure:"database"`
	Elasticsearch ElasticsearchConfig `mapstructure:"elasticsearch"`
	Logging       LoggingConfig       `mapstructure:"logging"`
}

type ServerConfig struct {
	Port string `mapstructure:"port"`
	Host string `mapstructure:"host"`
}

type DatabaseConfig struct {
	Host            string        `mapstructure:"host"`
	Port            int           `mapstructure:"port"`
	User            string        `mapstructure:"user"`
	Password        string        `mapstructure:"password"`
	DBName          string        `mapstructure:"dbname"`
	SSLMode         string        `mapstructure:"sslmode"`
	MaxOpenConns    int           `mapstructure:"max_open_conns"`
	MaxIdleConns    int           `mapstructure:"max_idle_conns"`
	ConnMaxLifetime time.Duration `mapstructure:"conn_max_lifetime"`
}

type ElasticsearchConfig struct {
	Addresses   []string `mapstructure:"addresses"`
	Username    string   `mapstructure:"username"`
	Password    string   `mapstructure:"password"`
	IndexName   string   `mapstructure:"index_name"`
	MaxRetries  int      `mapstructure:"max_retries"`
	BulkSize    int      `mapstructure:"bulk_size"`
	NumShards   int      `mapstructure:"num_shards"`
	NumReplicas int      `mapstructure:"num_replicas"`
}

type LoggingConfig struct {
	Level    string `mapstructure:"level"`
	Encoding string `mapstructure:"encoding"`
}

func Load(configPath string) (*Config, error) {
	viper.SetConfigFile(configPath)
	viper.AutomaticEnv()

	if err := viper.ReadInConfig(); err != nil {
		return nil, err
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, err
	}

	return &config, nil
}
```

---

## Step 5: Define Models

### 5.1 Create `internal/models/user.go`

```go
package models

import "time"

// User represents the database model
type User struct {
	ID        int64     `db:"id" json:"id"`
	Email     string    `db:"email" json:"email"`
	FirstName string    `db:"first_name" json:"first_name"`
	LastName  string    `db:"last_name" json:"last_name"`
	Bio       string    `db:"bio" json:"bio"`
	City      string    `db:"city" json:"city"`
	Country   string    `db:"country" json:"country"`
	IsActive  bool      `db:"is_active" json:"is_active"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

// UserSearchDocument represents the Elasticsearch document
type UserSearchDocument struct {
	ID        int64     `json:"id"`
	Email     string    `json:"email"`
	FirstName string    `json:"first_name"`
	LastName  string    `json:"last_name"`
	FullName  string    `json:"full_name"`
	Bio       string    `json:"bio"`
	City      string    `json:"city"`
	Country   string    `json:"country"`
	IsActive  bool      `json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
}

// ToSearchDocument converts User to UserSearchDocument
func (u *User) ToSearchDocument() UserSearchDocument {
	return UserSearchDocument{
		ID:        u.ID,
		Email:     u.Email,
		FirstName: u.FirstName,
		LastName:  u.LastName,
		FullName:  u.FirstName + " " + u.LastName,
		Bio:       u.Bio,
		City:      u.City,
		Country:   u.Country,
		IsActive:  u.IsActive,
		CreatedAt: u.CreatedAt,
	}
}

// CreateUserRequest for API
type CreateUserRequest struct {
	Email     string `json:"email" binding:"required,email"`
	FirstName string `json:"first_name" binding:"required"`
	LastName  string `json:"last_name" binding:"required"`
	Bio       string `json:"bio"`
	City      string `json:"city"`
	Country   string `json:"country"`
}

// SearchRequest for search API
type SearchRequest struct {
	Query    string                 `json:"query"`
	Filters  map[string]interface{} `json:"filters"`
	Page     int                    `json:"page"`
	PageSize int                    `json:"page_size"`
}

// SearchResponse for search results
type SearchResponse struct {
	Total    int64  `json:"total"`
	Page     int    `json:"page"`
	PageSize int    `json:"page_size"`
	Users    []User `json:"users"`
	Took     int    `json:"took_ms"`
}
```

---

## Step 6: PostgreSQL Database Layer

### 6.1 Create `internal/database/postgres.go`

```go
package database

import (
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	"go.uber.org/zap"
)

type Config struct {
	Host            string
	Port            int
	User            string
	Password        string
	DBName          string
	SSLMode         string
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
}

func NewPostgresDB(cfg Config, logger *zap.Logger) (*sqlx.DB, error) {
	dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.DBName, cfg.SSLMode)

	db, err := sqlx.Connect("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	// Configure connection pool
	db.SetMaxOpenConns(cfg.MaxOpenConns)
	db.SetMaxIdleConns(cfg.MaxIdleConns)
	db.SetConnMaxLifetime(cfg.ConnMaxLifetime)

	// Test connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	logger.Info("Connected to PostgreSQL",
		zap.String("host", cfg.Host),
		zap.Int("port", cfg.Port),
		zap.String("database", cfg.DBName),
	)

	return db, nil
}
```

### 6.2 Create `internal/repository/user_repository.go`

```go
package repository

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/jmoiron/sqlx"
	"github.com/yourusername/user-search-service/internal/models"
)

type UserRepository struct {
	db *sqlx.DB
}

func NewUserRepository(db *sqlx.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (email, first_name, last_name, bio, city, country, is_active)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at, updated_at
	`

	err := r.db.QueryRowContext(ctx, query,
		user.Email, user.FirstName, user.LastName, user.Bio, user.City, user.Country, user.IsActive,
	).Scan(&user.ID, &user.CreatedAt, &user.UpdatedAt)

	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}

	return nil
}

func (r *UserRepository) GetByID(ctx context.Context, id int64) (*models.User, error) {
	var user models.User
	query := `SELECT * FROM users WHERE id = $1`

	err := r.db.GetContext(ctx, &user, query, id)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

func (r *UserRepository) GetByIDs(ctx context.Context, ids []int64) ([]models.User, error) {
	if len(ids) == 0 {
		return []models.User{}, nil
	}

	query := `SELECT * FROM users WHERE id = ANY($1) ORDER BY id`
	var users []models.User

	err := r.db.SelectContext(ctx, &users, query, ids)
	if err != nil {
		return nil, fmt.Errorf("failed to get users by IDs: %w", err)
	}

	return users, nil
}

func (r *UserRepository) Update(ctx context.Context, user *models.User) error {
	query := `
		UPDATE users 
		SET email = $1, first_name = $2, last_name = $3, bio = $4, 
		    city = $5, country = $6, is_active = $7
		WHERE id = $8
		RETURNING updated_at
	`

	err := r.db.QueryRowContext(ctx, query,
		user.Email, user.FirstName, user.LastName, user.Bio,
		user.City, user.Country, user.IsActive, user.ID,
	).Scan(&user.UpdatedAt)

	if err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}

	return nil
}

func (r *UserRepository) Delete(ctx context.Context, id int64) error {
	query := `DELETE FROM users WHERE id = $1`

	result, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rows == 0 {
		return fmt.Errorf("user not found")
	}

	return nil
}

func (r *UserRepository) FindAll(ctx context.Context, offset, limit int) ([]models.User, error) {
	query := `SELECT * FROM users ORDER BY id LIMIT $1 OFFSET $2`
	var users []models.User

	err := r.db.SelectContext(ctx, &users, query, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to find all users: %w", err)
	}

	return users, nil
}

func (r *UserRepository) SearchByName(ctx context.Context, name string) ([]models.User, error) {
	query := `
		SELECT * FROM users 
		WHERE first_name ILIKE $1 OR last_name ILIKE $1 
		ORDER BY id 
		LIMIT 50
	`
	var users []models.User
	searchTerm := "%" + name + "%"

	err := r.db.SelectContext(ctx, &users, query, searchTerm)
	if err != nil {
		return nil, fmt.Errorf("failed to search users: %w", err)
	}

	return users, nil
}
```

---

## Step 7: Elasticsearch Layer

### 7.1 Create `internal/elasticsearch/client.go`

```go
package elasticsearch

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"time"

	"github.com/elastic/go-elasticsearch/v8"
	"go.uber.org/zap"
)

type Config struct {
	Addresses   []string
	Username    string
	Password    string
	MaxRetries  int
	NumShards   int
	NumReplicas int
}

func NewClient(cfg Config, logger *zap.Logger) (*elasticsearch.Client, error) {
	esCfg := elasticsearch.Config{
		Addresses: cfg.Addresses,
		Username:  cfg.Username,
		Password:  cfg.Password,

		Transport: &http.Transport{
			MaxIdleConnsPerHost:   10,
			ResponseHeaderTimeout: 5 * time.Second,
			DialContext:           (&net.Dialer{Timeout: 5 * time.Second}).DialContext,
			TLSClientConfig: &tls.Config{
				MinVersion: tls.VersionTLS12,
			},
		},

		RetryOnStatus: []int{502, 503, 504, 429},
		MaxRetries:    cfg.MaxRetries,
		RetryBackoff: func(i int) time.Duration {
			return time.Duration(i) * 100 * time.Millisecond
		},
	}

	client, err := elasticsearch.NewClient(esCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create elasticsearch client: %w", err)
	}

	// Verify connection
	res, err := client.Info()
	if err != nil {
		return nil, fmt.Errorf("failed to get elasticsearch info: %w", err)
	}
	defer res.Body.Close()

	if res.IsError() {
		return nil, fmt.Errorf("elasticsearch connection error: %s", res.String())
	}

	logger.Info("Connected to Elasticsearch",
		zap.Strings("addresses", cfg.Addresses),
	)

	return client, nil
}
```

### 7.2 Create `internal/elasticsearch/indexer.go`

```go
package elasticsearch

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/elastic/go-elasticsearch/v8"
	"github.com/elastic/go-elasticsearch/v8/esapi"
	"github.com/yourusername/user-search-service/internal/models"
	"go.uber.org/zap"
)

type Indexer struct {
	client    *elasticsearch.Client
	indexName string
	logger    *zap.Logger
}

func NewIndexer(client *elasticsearch.Client, indexName string, logger *zap.Logger) *Indexer {
	return &Indexer{
		client:    client,
		indexName: indexName,
		logger:    logger,
	}
}

const userIndexMapping = `
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "analysis": {
      "analyzer": {
        "name_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "asciifolding", "name_edge_ngram"]
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

func (i *Indexer) CreateIndex(ctx context.Context) error {
	// Check if index exists
	res, err := i.client.Indices.Exists([]string{i.indexName})
	if err != nil {
		return fmt.Errorf("failed to check index existence: %w", err)
	}
	defer res.Body.Close()

	if res.StatusCode == 200 {
		i.logger.Info("Index already exists", zap.String("index", i.indexName))
		return nil
	}

	// Create index
	res, err = i.client.Indices.Create(
		i.indexName,
		i.client.Indices.Create.WithBody(strings.NewReader(userIndexMapping)),
		i.client.Indices.Create.WithContext(ctx),
	)
	if err != nil {
		return fmt.Errorf("failed to create index: %w", err)
	}
	defer res.Body.Close()

	if res.IsError() {
		return fmt.Errorf("error creating index: %s", res.String())
	}

	i.logger.Info("Index created successfully", zap.String("index", i.indexName))
	return nil
}

func (i *Indexer) IndexUser(ctx context.Context, doc models.UserSearchDocument) error {
	data, err := json.Marshal(doc)
	if err != nil {
		return fmt.Errorf("failed to marshal document: %w", err)
	}

	req := esapi.IndexRequest{
		Index:      i.indexName,
		DocumentID: fmt.Sprintf("%d", doc.ID),
		Body:       bytes.NewReader(data),
		Refresh:    "false",
	}

	res, err := req.Do(ctx, i.client)
	if err != nil {
		return fmt.Errorf("failed to index document: %w", err)
	}
	defer res.Body.Close()

	if res.IsError() {
		return fmt.Errorf("error indexing document: %s", res.String())
	}

	i.logger.Debug("User indexed", zap.Int64("user_id", doc.ID))
	return nil
}

func (i *Indexer) BulkIndexUsers(ctx context.Context, docs []models.UserSearchDocument) error {
	if len(docs) == 0 {
		return nil
	}

	var buf bytes.Buffer

	for _, doc := range docs {
		meta := map[string]interface{}{
			"index": map[string]interface{}{
				"_index": i.indexName,
				"_id":    fmt.Sprintf("%d", doc.ID),
			},
		}

		if err := json.NewEncoder(&buf).Encode(meta); err != nil {
			return fmt.Errorf("failed to encode meta: %w", err)
		}

		if err := json.NewEncoder(&buf).Encode(doc); err != nil {
			return fmt.Errorf("failed to encode document: %w", err)
		}
	}

	res, err := i.client.Bulk(
		bytes.NewReader(buf.Bytes()),
		i.client.Bulk.WithContext(ctx),
		i.client.Bulk.WithIndex(i.indexName),
	)
	if err != nil {
		return fmt.Errorf("bulk indexing failed: %w", err)
	}
	defer res.Body.Close()

	if res.IsError() {
		return fmt.Errorf("error in bulk response: %s", res.String())
	}

	var bulkRes map[string]interface{}
	if err := json.NewDecoder(res.Body).Decode(&bulkRes); err != nil {
		return fmt.Errorf("failed to parse bulk response: %w", err)
	}

	if bulkRes["errors"].(bool) {
		i.logger.Warn("Some documents failed to index", zap.Any("response", bulkRes))
	}

	i.logger.Info("Bulk indexing completed", zap.Int("count", len(docs)))
	return nil
}

func (i *Indexer) DeleteUser(ctx context.Context, userID int64) error {
	req := esapi.DeleteRequest{
		Index:      i.indexName,
		DocumentID: fmt.Sprintf("%d", userID),
	}

	res, err := req.Do(ctx, i.client)
	if err != nil {
		return fmt.Errorf("failed to delete document: %w", err)
	}
	defer res.Body.Close()

	if res.IsError() && res.StatusCode != 404 {
		return fmt.Errorf("error deleting document: %s", res.String())
	}

	i.logger.Debug("User deleted from index", zap.Int64("user_id", userID))
	return nil
}
```

### 7.3 Create `internal/elasticsearch/search.go`

```go
package elasticsearch

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"

	"github.com/yourusername/user-search-service/internal/models"
)

type SearchResult struct {
	Total int64
	Users []models.UserSearchDocument
	Took  int
}

func (i *Indexer) Search(ctx context.Context, req models.SearchRequest) (*SearchResult, error) {
	query := buildSearchQuery(req)

	var buf bytes.Buffer
	if err := json.NewEncoder(&buf).Encode(query); err != nil {
		return nil, fmt.Errorf("failed to encode query: %w", err)
	}

	res, err := i.client.Search(
		i.client.Search.WithContext(ctx),
		i.client.Search.WithIndex(i.indexName),
		i.client.Search.WithBody(&buf),
		i.client.Search.WithTrackTotalHits(true),
	)
	if err != nil {
		return nil, fmt.Errorf("search request failed: %w", err)
	}
	defer res.Body.Close()

	if res.IsError() {
		return nil, fmt.Errorf("search error: %s", res.String())
	}

	var searchRes map[string]interface{}
	if err := json.NewDecoder(res.Body).Decode(&searchRes); err != nil {
		return nil, fmt.Errorf("failed to parse search response: %w", err)
	}

	return parseSearchResponse(searchRes)
}

func buildSearchQuery(req models.SearchRequest) map[string]interface{} {
	if req.PageSize == 0 {
		req.PageSize = 10
	}
	if req.Page < 1 {
		req.Page = 1
	}

	from := (req.Page - 1) * req.PageSize

	query := map[string]interface{}{
		"from": from,
		"size": req.PageSize,
	}

	boolQuery := map[string]interface{}{
		"must":   []interface{}{},
		"filter": []interface{}{},
	}

	// Text search
	if req.Query != "" {
		boolQuery["must"] = append(boolQuery["must"].([]interface{}), map[string]interface{}{
			"multi_match": map[string]interface{}{
				"query":     req.Query,
				"fields":    []string{"full_name^3", "email^2", "bio"},
				"type":      "best_fields",
				"fuzziness": "AUTO",
			},
		})
	} else {
		boolQuery["must"] = append(boolQuery["must"].([]interface{}), map[string]interface{}{
			"match_all": map[string]interface{}{},
		})
	}

	// Filters
	if req.Filters != nil {
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
	}

	query["query"] = map[string]interface{}{"bool": boolQuery}

	return query
}

func parseSearchResponse(res map[string]interface{}) (*SearchResult, error) {
	hits := res["hits"].(map[string]interface{})
	total := hits["total"].(map[string]interface{})
	took := int(res["took"].(float64))

	result := &SearchResult{
		Total: int64(total["value"].(float64)),
		Took:  took,
		Users: []models.UserSearchDocument{},
	}

	for _, hit := range hits["hits"].([]interface{}) {
		h := hit.(map[string]interface{})
		source := h["_source"].(map[string]interface{})

		var user models.UserSearchDocument
		data, _ := json.Marshal(source)
		json.Unmarshal(data, &user)

		result.Users = append(result.Users, user)
	}

	return result, nil
}
```

---

## Step 8: Business Logic Layer

### 8.1 Create `internal/service/user_service.go`

```go
package service

import (
	"context"
	"fmt"

	"github.com/yourusername/user-search-service/internal/elasticsearch"
	"github.com/yourusername/user-search-service/internal/models"
	"github.com/yourusername/user-search-service/internal/repository"
	"go.uber.org/zap"
)

type UserService struct {
	repo      *repository.UserRepository
	indexer   *elasticsearch.Indexer
	logger    *zap.Logger
}

func NewUserService(
	repo *repository.UserRepository,
	indexer *elasticsearch.Indexer,
	logger *zap.Logger,
) *UserService {
	return &UserService{
		repo:    repo,
		indexer: indexer,
		logger:  logger,
	}
}

func (s *UserService) CreateUser(ctx context.Context, req models.CreateUserRequest) (*models.User, error) {
	user := &models.User{
		Email:     req.Email,
		FirstName: req.FirstName,
		LastName:  req.LastName,
		Bio:       req.Bio,
		City:      req.City,
		Country:   req.Country,
		IsActive:  true,
	}

	// 1. Save to PostgreSQL (source of truth)
	if err := s.repo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	// 2. Index in Elasticsearch (best effort)
	searchDoc := user.ToSearchDocument()
	if err := s.indexer.IndexUser(ctx, searchDoc); err != nil {
		s.logger.Error("Failed to index user in Elasticsearch",
			zap.Error(err),
			zap.Int64("user_id", user.ID),
		)
		// Don't fail the operation - Elasticsearch is secondary
	}

	return user, nil
}

func (s *UserService) GetUser(ctx context.Context, id int64) (*models.User, error) {
	return s.repo.GetByID(ctx, id)
}

func (s *UserService) UpdateUser(ctx context.Context, id int64, req models.CreateUserRequest) (*models.User, error) {
	// Get existing user
	user, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	// Update fields
	user.Email = req.Email
	user.FirstName = req.FirstName
	user.LastName = req.LastName
	user.Bio = req.Bio
	user.City = req.City
	user.Country = req.Country

	// 1. Update PostgreSQL
	if err := s.repo.Update(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to update user: %w", err)
	}

	// 2. Update Elasticsearch
	searchDoc := user.ToSearchDocument()
	if err := s.indexer.IndexUser(ctx, searchDoc); err != nil {
		s.logger.Error("Failed to update user in Elasticsearch",
			zap.Error(err),
			zap.Int64("user_id", user.ID),
		)
	}

	return user, nil
}

func (s *UserService) DeleteUser(ctx context.Context, id int64) error {
	// 1. Delete from PostgreSQL
	if err := s.repo.Delete(ctx, id); err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	// 2. Delete from Elasticsearch
	if err := s.indexer.DeleteUser(ctx, id); err != nil {
		s.logger.Error("Failed to delete user from Elasticsearch",
			zap.Error(err),
			zap.Int64("user_id", id),
		)
	}

	return nil
}

func (s *UserService) SearchUsers(ctx context.Context, req models.SearchRequest) (*models.SearchResponse, error) {
	// Try Elasticsearch first
	esResult, err := s.indexer.Search(ctx, req)
	if err != nil {
		s.logger.Warn("Elasticsearch search failed, falling back to PostgreSQL",
			zap.Error(err),
		)
		// Fallback to PostgreSQL
		return s.searchWithPostgres(ctx, req)
	}

	// Get full user details from PostgreSQL
	if len(esResult.Users) == 0 {
		return &models.SearchResponse{
			Total:    0,
			Page:     req.Page,
			PageSize: req.PageSize,
			Users:    []models.User{},
			Took:     esResult.Took,
		}, nil
	}

	userIDs := make([]int64, len(esResult.Users))
	for i, u := range esResult.Users {
		userIDs[i] = u.ID
	}

	users, err := s.repo.GetByIDs(ctx, userIDs)
	if err != nil {
		return nil, fmt.Errorf("failed to get users from postgres: %w", err)
	}

	return &models.SearchResponse{
		Total:    esResult.Total,
		Page:     req.Page,
		PageSize: req.PageSize,
		Users:    users,
		Took:     esResult.Took,
	}, nil
}

func (s *UserService) searchWithPostgres(ctx context.Context, req models.SearchRequest) (*models.SearchResponse, error) {
	users, err := s.repo.SearchByName(ctx, req.Query)
	if err != nil {
		return nil, err
	}

	return &models.SearchResponse{
		Total:    int64(len(users)),
		Page:     1,
		PageSize: len(users),
		Users:    users,
		Took:     0,
	}, nil
}

// ReindexAll reindexes all users from PostgreSQL to Elasticsearch
func (s *UserService) ReindexAll(ctx context.Context) error {
	offset := 0
	batchSize := 1000

	totalIndexed := 0

	for {
		users, err := s.repo.FindAll(ctx, offset, batchSize)
		if err != nil {
			return fmt.Errorf("failed to fetch users: %w", err)
		}

		if len(users) == 0 {
			break
		}

		// Convert to search documents
		searchDocs := make([]models.UserSearchDocument, len(users))
		for i, user := range users {
			searchDocs[i] = user.ToSearchDocument()
		}

		// Bulk index
		if err := s.indexer.BulkIndexUsers(ctx, searchDocs); err != nil {
			return fmt.Errorf("bulk indexing failed: %w", err)
		}

		totalIndexed += len(users)
		s.logger.Info("Indexed batch",
			zap.Int("offset", offset),
			zap.Int("count", len(users)),
			zap.Int("total", totalIndexed),
		)

		offset += batchSize
	}

	s.logger.Info("Reindex completed", zap.Int("total_indexed", totalIndexed))
	return nil
}
```

---

## Step 9: API Handler Layer

### 9.1 Create `internal/handler/user_handler.go`

```go
package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/yourusername/user-search-service/internal/models"
	"github.com/yourusername/user-search-service/internal/service"
	"go.uber.org/zap"
)

type UserHandler struct {
	service *service.UserService
	logger  *zap.Logger
}

func NewUserHandler(service *service.UserService, logger *zap.Logger) *UserHandler {
	return &UserHandler{
		service: service,
		logger:  logger,
	}
}

func (h *UserHandler) CreateUser(c *gin.Context) {
	var req models.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user, err := h.service.CreateUser(c.Request.Context(), req)
	if err != nil {
		h.logger.Error("Failed to create user", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	c.JSON(http.StatusCreated, user)
}

func (h *UserHandler) GetUser(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	user, err := h.service.GetUser(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, user)
}

func (h *UserHandler) UpdateUser(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var req models.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user, err := h.service.UpdateUser(c.Request.Context(), id, req)
	if err != nil {
		h.logger.Error("Failed to update user", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user"})
		return
	}

	c.JSON(http.StatusOK, user)
}

func (h *UserHandler) DeleteUser(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	if err := h.service.DeleteUser(c.Request.Context(), id); err != nil {
		h.logger.Error("Failed to delete user", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "User deleted successfully"})
}

func (h *UserHandler) SearchUsers(c *gin.Context) {
	var req models.SearchRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.PageSize == 0 {
		req.PageSize = 10
	}
	if req.Page < 1 {
		req.Page = 1
	}

	result, err := h.service.SearchUsers(c.Request.Context(), req)
	if err != nil {
		h.logger.Error("Failed to search users", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search users"})
		return
	}

	c.JSON(http.StatusOK, result)
}

func (h *UserHandler) Reindex(c *gin.Context) {
	if err := h.service.ReindexAll(c.Request.Context()); err != nil {
		h.logger.Error("Failed to reindex", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reindex"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Reindex completed successfully"})
}
```

---

## Step 10: Main Application

### 10.1 Create `cmd/api/main.go`

```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/yourusername/user-search-service/internal/config"
	"github.com/yourusername/user-search-service/internal/database"
	"github.com/yourusername/user-search-service/internal/elasticsearch"
	"github.com/yourusername/user-search-service/internal/handler"
	"github.com/yourusername/user-search-service/internal/repository"
	"github.com/yourusername/user-search-service/internal/service"
	"go.uber.org/zap"
)

func main() {
	// Load configuration
	cfg, err := config.Load("config/config.yaml")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Initialize logger
	logger, err := initLogger(cfg.Logging)
	if err != nil {
		log.Fatalf("Failed to initialize logger: %v", err)
	}
	defer logger.Sync()

	logger.Info("Starting user search service")

	// Initialize PostgreSQL
	dbCfg := database.Config{
		Host:            cfg.Database.Host,
		Port:            cfg.Database.Port,
		User:            cfg.Database.User,
		Password:        cfg.Database.Password,
		DBName:          cfg.Database.DBName,
		SSLMode:         cfg.Database.SSLMode,
		MaxOpenConns:    cfg.Database.MaxOpenConns,
		MaxIdleConns:    cfg.Database.MaxIdleConns,
		ConnMaxLifetime: cfg.Database.ConnMaxLifetime,
	}

	db, err := database.NewPostgresDB(dbCfg, logger)
	if err != nil {
		logger.Fatal("Failed to connect to PostgreSQL", zap.Error(err))
	}
	defer db.Close()

	// Initialize Elasticsearch
	esCfg := elasticsearch.Config{
		Addresses:   cfg.Elasticsearch.Addresses,
		Username:    cfg.Elasticsearch.Username,
		Password:    cfg.Elasticsearch.Password,
		MaxRetries:  cfg.Elasticsearch.MaxRetries,
		NumShards:   cfg.Elasticsearch.NumShards,
		NumReplicas: cfg.Elasticsearch.NumReplicas,
	}

	esClient, err := elasticsearch.NewClient(esCfg, logger)
	if err != nil {
		logger.Fatal("Failed to connect to Elasticsearch", zap.Error(err))
	}

	// Initialize Elasticsearch indexer
	indexer := elasticsearch.NewIndexer(esClient, cfg.Elasticsearch.IndexName, logger)

	// Create index if it doesn't exist
	if err := indexer.CreateIndex(context.Background()); err != nil {
		logger.Fatal("Failed to create index", zap.Error(err))
	}

	// Initialize layers
	userRepo := repository.NewUserRepository(db)
	userService := service.NewUserService(userRepo, indexer, logger)
	userHandler := handler.NewUserHandler(userService, logger)

	// Setup HTTP server
	router := setupRouter(userHandler)

	// Start server with graceful shutdown
	addr := fmt.Sprintf("%s:%s", cfg.Server.Host, cfg.Server.Port)
	startServer(router, addr, logger)
}

func setupRouter(userHandler *handler.UserHandler) *gin.Engine {
	router := gin.Default()

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// API routes
	v1 := router.Group("/api/v1")
	{
		users := v1.Group("/users")
		{
			users.POST("", userHandler.CreateUser)
			users.GET("/:id", userHandler.GetUser)
			users.PUT("/:id", userHandler.UpdateUser)
			users.DELETE("/:id", userHandler.DeleteUser)
			users.POST("/search", userHandler.SearchUsers)
		}

		// Admin routes
		admin := v1.Group("/admin")
		{
			admin.POST("/reindex", userHandler.Reindex)
		}
	}

	return router
}

func startServer(router *gin.Engine, addr string, logger *zap.Logger) {
	srv := &http.Server{
		Addr:    addr,
		Handler: router,
	}

	// Start server in goroutine
	go func() {
		logger.Info("Server starting", zap.String("address", addr))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Failed to start server", zap.Error(err))
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatal("Server forced to shutdown", zap.Error(err))
	}

	logger.Info("Server stopped")
}

func initLogger(cfg config.LoggingConfig) (*zap.Logger, error) {
	var zapCfg zap.Config

	if cfg.Encoding == "json" {
		zapCfg = zap.NewProductionConfig()
	} else {
		zapCfg = zap.NewDevelopmentConfig()
	}

	level, err := zap.ParseAtomicLevel(cfg.Level)
	if err != nil {
		return nil, err
	}
	zapCfg.Level = level

	return zapCfg.Build()
}
```

---

## Step 11: Testing

### 11.1 Create `Makefile`

```makefile
.PHONY: help docker-up docker-down migrate run reindex test

help:
	@echo "Available commands:"
	@echo "  make docker-up    - Start Docker containers"
	@echo "  make docker-down  - Stop Docker containers"
	@echo "  make migrate      - Run database migrations"
	@echo "  make run          - Run the application"
	@echo "  make reindex      - Reindex all users"
	@echo "  make test         - Run all tests"

docker-up:
	docker-compose up -d
	@echo "Waiting for services to be ready..."
	@sleep 5

docker-down:
	docker-compose down

migrate:
	@echo "Running migrations..."
	./scripts/migrate.sh

run:
	go run cmd/api/main.go

reindex:
	curl -X POST http://localhost:8080/api/v1/admin/reindex

test:
	go test -v ./...

clean:
	docker-compose down -v
	rm -rf vendor/
```

### 11.2 Test the API

Create `scripts/test_api.sh`:

```bash
#!/bin/bash

BASE_URL="http://localhost:8080/api/v1"

echo "=== Testing User Search Service ==="

# 1. Health check
echo -e "\n1. Health Check"
curl -X GET http://localhost:8080/health

# 2. Create a user
echo -e "\n\n2. Create User"
curl -X POST $BASE_URL/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "first_name": "Test",
    "last_name": "User",
    "bio": "This is a test user for Elasticsearch",
    "city": "San Francisco",
    "country": "USA"
  }'

# 3. Get user by ID
echo -e "\n\n3. Get User (ID: 1)"
curl -X GET $BASE_URL/users/1

# 4. Search users
echo -e "\n\n4. Search Users (query: 'John')"
curl -X POST $BASE_URL/users/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "John",
    "page": 1,
    "page_size": 10
  }'

# 5. Search with filters
echo -e "\n\n5. Search with Filters (country: USA)"
curl -X POST $BASE_URL/users/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "",
    "filters": {
      "country": "USA"
    },
    "page": 1,
    "page_size": 10
  }'

# 6. Update user
echo -e "\n\n6. Update User (ID: 1)"
curl -X PUT $BASE_URL/users/1 \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john.updated@example.com",
    "first_name": "John",
    "last_name": "Updated",
    "bio": "Updated bio",
    "city": "New York",
    "country": "USA"
  }'

# 7. Reindex all users
echo -e "\n\n7. Reindex All Users"
curl -X POST $BASE_URL/admin/reindex

# 8. Delete user
echo -e "\n\n8. Delete User (ID: 6)"
curl -X DELETE $BASE_URL/users/6

echo -e "\n\nTests completed!"
```

```bash
chmod +x scripts/test_api.sh
```

---

## Step 12: Run the Application

### 12.1 Start Everything

```bash
# 1. Start Docker services
make docker-up

# 2. Run migrations
make migrate

# 3. Run the application
make run
```

### 12.2 Test the Endpoints

In another terminal:

```bash
# Run test script
./scripts/test_api.sh

# Or test manually:

# Create a user
curl -X POST http://localhost:8080/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "new@example.com",
    "first_name": "New",
    "last_name": "User",
    "bio": "Software engineer",
    "city": "Seattle",
    "country": "USA"
  }'

# Search users
curl -X POST http://localhost:8080/api/v1/users/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "software",
    "page": 1,
    "page_size": 10
  }'

# Trigger reindex
curl -X POST http://localhost:8080/api/v1/admin/reindex
```

---

## Step 13: Verify Data

### 13.1 Check PostgreSQL

```bash
docker exec -it user_search_postgres psql -U postgres -d userdb

# In psql:
SELECT id, first_name, last_name, email FROM users;
```

### 13.2 Check Elasticsearch

```bash
# Check index status
curl http://localhost:9200/users/_count

# Search directly in Elasticsearch
curl -X POST http://localhost:9200/users/_search \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "match": {
        "full_name": "John"
      }
    }
  }'
```

---

## 🎉 Success Checklist

- [ ] Docker containers running (PostgreSQL & Elasticsearch)
- [ ] Database migrated with users table
- [ ] Elasticsearch index created with proper mappings
- [ ] Application starts without errors
- [ ] Health check endpoint responds
- [ ] Can create users (saves to both PostgreSQL & Elasticsearch)
- [ ] Can search users (uses Elasticsearch)
- [ ] Can update users (updates both systems)
- [ ] Can delete users (removes from both systems)
- [ ] Reindex works (syncs PostgreSQL → Elasticsearch)

---

## 📝 Key Takeaways

### Data Flow
1. **Write operations**: App → PostgreSQL → Elasticsearch
2. **Search operations**: App → Elasticsearch → Get IDs → PostgreSQL (full details)
3. **Read by ID**: App → PostgreSQL directly

### Best Practices Applied
✅ PostgreSQL as source of truth  
✅ Elasticsearch for search only  
✅ Graceful degradation (fallback to PostgreSQL)  
✅ Non-blocking Elasticsearch errors  
✅ Bulk operations for reindexing  
✅ Proper connection pooling  
✅ Structured logging  
✅ Health checks  

---

## 🔧 Troubleshooting

### Elasticsearch not starting
```bash
# Check logs
docker logs user_search_elasticsearch

# Common fix: Increase Docker memory to 4GB+
```

### Cannot connect to PostgreSQL
```bash
# Check if running
docker ps

# Verify credentials in config.yaml match docker-compose.yml
```

### Search returns empty results
```bash
# Trigger manual reindex
curl -X POST http://localhost:8080/api/v1/admin/reindex

# Check Elasticsearch index
curl http://localhost:9200/users/_count
```

---

## 🚀 Next Steps

1. **Add authentication/authorization**
2. **Implement event-driven sync** (using message queues)
3. **Add monitoring** (Prometheus metrics)
4. **Implement caching** (Redis)
5. **Add rate limiting**
6. **Deploy to production** (Kubernetes)

---

**Congratulations! You've built a production-ready user search service with Golang, PostgreSQL, and Elasticsearch!** 🎊
