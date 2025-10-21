# Go User Management with sqlc - Complete Setup Guide

This guide provides step-by-step instructions to set up a Go project with sqlc for type-safe database access.

## Prerequisites

```bash
# Install Go (1.22+)
brew install go

# Install PostgreSQL
brew install postgresql

# Install sqlc
brew install sqlc

# Verify installations
go version
psql --version
sqlc version
```

## Step 1: Create Project Structure

```bash
mkdir -p myapp/{cmd,internal/{domain,repository/queries,service,handler},migrations}
cd myapp

# Initialize Go module
go mod init github.com/yourusername/myapp

# Create necessary files
touch cmd/main.go
touch sqlc.yaml
touch migrations/schema.sql
touch internal/repository/queries/users.sql
touch internal/domain/user.go
touch internal/domain/errors.go
touch internal/repository/user_repository.go
touch internal/service/user_service.go
touch internal/handler/user_handler.go
```

## Step 2: Configure sqlc

**File: `sqlc.yaml`**

```yaml
version: "2"
sql:
  - engine: "postgres"
    queries: "./internal/repository/queries"
    schema: "./migrations/schema.sql"
    gen:
      go:
        package: "queries"
        out: "./internal/repository/queries"
        emit_json_tags: true
        emit_pointer_types: true
        emit_db_tags: true
```

## Step 3: Create Database Schema

**File: `migrations/schema.sql`**

```sql
-- Users table
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at DESC);
```

## Step 4: Define SQL Queries

**File: `internal/repository/queries/users.sql`**

```sql
-- name: CreateUser :exec
INSERT INTO users (id, name, email, password, created_at, updated_at)
VALUES ($1, $2, $3, $4, NOW(), NOW());

-- name: GetUserByID :one
SELECT id, name, email, password, created_at, updated_at FROM users
WHERE id = $1;

-- name: GetUserByEmail :one
SELECT id, name, email, password, created_at, updated_at FROM users
WHERE email = $1;

-- name: UpdateUser :exec
UPDATE users
SET name = $1, email = $2, password = $3, updated_at = NOW()
WHERE id = $4;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;

-- name: ListUsers :many
SELECT id, name, email, password, created_at, updated_at FROM users
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;

-- name: CountUsers :one
SELECT COUNT(*) FROM users;

-- name: UserExists :one
SELECT EXISTS(SELECT 1 FROM users WHERE email = $1);
```

## Step 5: Generate Go Code

```bash
sqlc generate
```

This generates:
- `internal/repository/queries/db.go`
- `internal/repository/queries/models.go`
- `internal/repository/queries/querier.go`
- `internal/repository/queries/users.sql.go`

## Step 6: Create Domain Models

**File: `internal/domain/user.go`**

```go
package domain

import "time"

type User struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	Password  string    `json:"-"` // Never expose in JSON
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CreateUserRequest struct {
	Name     string `json:"name" validate:"required,min=2,max=100"`
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required,min=8"`
}

type UpdateUserRequest struct {
	Name  string `json:"name" validate:"omitempty,min=2,max=100"`
	Email string `json:"email" validate:"omitempty,email"`
}

type UserResponse struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
```

**File: `internal/domain/errors.go`**

```go
package domain

import "errors"

var (
	ErrUserNotFound     = errors.New("user not found")
	ErrEmailAlreadyUsed = errors.New("email already in use")
	ErrInvalidEmail     = errors.New("invalid email format")
	ErrWeakPassword     = errors.New("password must be at least 8 characters")
	ErrUnauthorized     = errors.New("unauthorized")
	ErrInternalServer   = errors.New("internal server error")
)
```

## Step 7: Create Repository Layer

**File: `internal/repository/user_repository.go`**

```go
package repository

import (
	"context"
	"database/sql"
	"github.com/yourusername/myapp/internal/domain"
	"github.com/yourusername/myapp/internal/repository/queries"
)

type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	GetByID(ctx context.Context, id string) (*domain.User, error)
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	Update(ctx context.Context, user *domain.User) error
	Delete(ctx context.Context, id string) error
	List(ctx context.Context, offset, limit int32) ([]*domain.User, int64, error)
	Exists(ctx context.Context, email string) (bool, error)
}

type PostgresUserRepository struct {
	queries *queries.Queries
}

func NewPostgresUserRepository(q *queries.Queries) UserRepository {
	return &PostgresUserRepository{queries: q}
}

func (r *PostgresUserRepository) Create(ctx context.Context, user *domain.User) error {
	return r.queries.CreateUser(ctx, queries.CreateUserParams{
		ID:       user.ID,
		Name:     user.Name,
		Email:    user.Email,
		Password: user.Password,
	})
}

func (r *PostgresUserRepository) GetByID(ctx context.Context, id string) (*domain.User, error) {
	row, err := r.queries.GetUserByID(ctx, id)
	if err == sql.ErrNoRows {
		return nil, domain.ErrUserNotFound
	}
	if err != nil {
		return nil, err
	}

	return &domain.User{
		ID:        row.ID,
		Name:      row.Name,
		Email:     row.Email,
		Password:  row.Password,
		CreatedAt: row.CreatedAt,
		UpdatedAt: row.UpdatedAt,
	}, nil
}

func (r *PostgresUserRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	row, err := r.queries.GetUserByEmail(ctx, email)
	if err == sql.ErrNoRows {
		return nil, domain.ErrUserNotFound
	}
	if err != nil {
		return nil, err
	}

	return &domain.User{
		ID:        row.ID,
		Name:      row.Name,
		Email:     row.Email,
		Password:  row.Password,
		CreatedAt: row.CreatedAt,
		UpdatedAt: row.UpdatedAt,
	}, nil
}

func (r *PostgresUserRepository) Update(ctx context.Context, user *domain.User) error {
	return r.queries.UpdateUser(ctx, queries.UpdateUserParams{
		ID:       user.ID,
		Name:     user.Name,
		Email:    user.Email,
		Password: user.Password,
	})
}

func (r *PostgresUserRepository) Delete(ctx context.Context, id string) error {
	return r.queries.DeleteUser(ctx, id)
}

func (r *PostgresUserRepository) List(ctx context.Context, offset, limit int32) ([]*domain.User, int64, error) {
	total, err := r.queries.CountUsers(ctx)
	if err != nil {
		return nil, 0, err
	}

	rows, err := r.queries.ListUsers(ctx, queries.ListUsersParams{
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		return nil, 0, err
	}

	users := make([]*domain.User, len(rows))
	for i, row := range rows {
		users[i] = &domain.User{
			ID:        row.ID,
			Name:      row.Name,
			Email:     row.Email,
			Password:  row.Password,
			CreatedAt: row.CreatedAt,
			UpdatedAt: row.UpdatedAt,
		}
	}

	return users, total, nil
}

func (r *PostgresUserRepository) Exists(ctx context.Context, email string) (bool, error) {
	return r.queries.UserExists(ctx, email)
}
```

## Step 8: Create Service Layer

**File: `internal/service/user_service.go`**

```go
package service

import (
	"context"
	"fmt"
	"github.com/google/uuid"
	"github.com/yourusername/myapp/internal/domain"
	"github.com/yourusername/myapp/internal/repository"
	"golang.org/x/crypto/bcrypt"
	"regexp"
)

type UserService interface {
	CreateUser(ctx context.Context, req *domain.CreateUserRequest) (*domain.User, error)
	GetUser(ctx context.Context, id string) (*domain.User, error)
	GetUserByEmail(ctx context.Context, email string) (*domain.User, error)
	UpdateUser(ctx context.Context, id string, req *domain.UpdateUserRequest) (*domain.User, error)
	DeleteUser(ctx context.Context, id string) error
	ListUsers(ctx context.Context, offset, limit int32) ([]*domain.User, int64, error)
	ValidatePassword(hashedPassword, plainPassword string) error
}

type userService struct {
	repo repository.UserRepository
}

func NewUserService(repo repository.UserRepository) UserService {
	return &userService{repo: repo}
}

func (s *userService) CreateUser(ctx context.Context, req *domain.CreateUserRequest) (*domain.User, error) {
	// Validate input
	if err := s.validateUserInput(req); err != nil {
		return nil, err
	}

	// Check if email already exists
	exists, err := s.repo.Exists(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("failed to check email: %w", err)
	}
	if exists {
		return nil, domain.ErrEmailAlreadyUsed
	}

	// Hash password
	hashedPassword, err := s.hashPassword(req.Password)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// Create user
	user := &domain.User{
		ID:       uuid.New().String(),
		Name:     req.Name,
		Email:    req.Email,
		Password: hashedPassword,
	}

	if err := s.repo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	user.Password = ""
	return user, nil
}

func (s *userService) GetUser(ctx context.Context, id string) (*domain.User, error) {
	if id == "" {
		return nil, domain.ErrUserNotFound
	}

	user, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	user.Password = ""
	return user, nil
}

func (s *userService) GetUserByEmail(ctx context.Context, email string) (*domain.User, error) {
	if email == "" {
		return nil, domain.ErrInvalidEmail
	}

	user, err := s.repo.GetByEmail(ctx, email)
	if err != nil {
		return nil, err
	}

	user.Password = ""
	return user, nil
}

func (s *userService) UpdateUser(ctx context.Context, id string, req *domain.UpdateUserRequest) (*domain.User, error) {
	user, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if req.Name != "" {
		user.Name = req.Name
	}
	if req.Email != "" {
		if req.Email != user.Email {
			exists, err := s.repo.Exists(ctx, req.Email)
			if err != nil {
				return nil, fmt.Errorf("failed to check email: %w", err)
			}
			if exists {
				return nil, domain.ErrEmailAlreadyUsed
			}
		}
		user.Email = req.Email
	}

	if err := s.repo.Update(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to update user: %w", err)
	}

	user.Password = ""
	return user, nil
}

func (s *userService) DeleteUser(ctx context.Context, id string) error {
	return s.repo.Delete(ctx, id)
}

func (s *userService) ListUsers(ctx context.Context, offset, limit int32) ([]*domain.User, int64, error) {
	if offset < 0 {
		offset = 0
	}
	if limit <= 0 || limit > 100 {
		limit = 10
	}

	users, total, err := s.repo.List(ctx, offset, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to list users: %w", err)
	}

	for _, user := range users {
		user.Password = ""
	}

	return users, total, nil
}

func (s *userService) ValidatePassword(hashedPassword, plainPassword string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(plainPassword))
}

func (s *userService) validateUserInput(req *domain.CreateUserRequest) error {
	if req.Name == "" || len(req.Name) < 2 {
		return fmt.Errorf("invalid name: minimum 2 characters required")
	}

	if !isValidEmail(req.Email) {
		return domain.ErrInvalidEmail
	}

	if len(req.Password) < 8 {
		return domain.ErrWeakPassword
	}

	return nil
}

func (s *userService) hashPassword(password string) (string, error) {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(hashedPassword), nil
}

func isValidEmail(email string) bool {
	re := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	return re.MatchString(email)
}
```

## Step 9: Create Handler Layer

**File: `internal/handler/user_handler.go`**

```go
package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"github.com/yourusername/myapp/internal/domain"
	"github.com/yourusername/myapp/internal/service"
)

type UserHandler struct {
	service service.UserService
}

func NewUserHandler(service service.UserService) *UserHandler {
	return &UserHandler{service: service}
}

func (h *UserHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
	var req domain.CreateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	user, err := h.service.CreateUser(r.Context(), &req)
	if err != nil {
		handleServiceError(w, err)
		return
	}

	respondJSON(w, http.StatusCreated, toUserResponse(user))
}

func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		respondError(w, http.StatusBadRequest, "Missing user ID")
		return
	}

	user, err := h.service.GetUser(r.Context(), id)
	if err != nil {
		handleServiceError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, toUserResponse(user))
}

func (h *UserHandler) UpdateUser(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		respondError(w, http.StatusBadRequest, "Missing user ID")
		return
	}

	var req domain.UpdateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	user, err := h.service.UpdateUser(r.Context(), id, &req)
	if err != nil {
		handleServiceError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, toUserResponse(user))
}

func (h *UserHandler) DeleteUser(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		respondError(w, http.StatusBadRequest, "Missing user ID")
		return
	}

	if err := h.service.DeleteUser(r.Context(), id); err != nil {
		handleServiceError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *UserHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	offset := int32(0)
	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if o, err := strconv.ParseInt(offsetStr, 10, 32); err == nil {
			offset = int32(o)
		}
	}

	limit := int32(10)
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if l, err := strconv.ParseInt(limitStr, 10, 32); err == nil {
			limit = int32(l)
		}
	}

	users, total, err := h.service.ListUsers(r.Context(), offset, limit)
	if err != nil {
		handleServiceError(w, err)
		return
	}

	response := map[string]interface{}{
		"data":  toUserResponses(users),
		"total": total,
	}

	respondJSON(w, http.StatusOK, response)
}

func toUserResponse(user *domain.User) *domain.UserResponse {
	return &domain.UserResponse{
		ID:        user.ID,
		Name:      user.Name,
		Email:     user.Email,
		CreatedAt: user.CreatedAt,
		UpdatedAt: user.UpdatedAt,
	}
}

func toUserResponses(users []*domain.User) []*domain.UserResponse {
	responses := make([]*domain.UserResponse, len(users))
	for i, user := range users {
		responses[i] = toUserResponse(user)
	}
	return responses
}

func respondJSON(w http.ResponseWriter, code int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(payload)
}

func respondError(w http.ResponseWriter, code int, message string) {
	response := map[string]string{"error": message}
	respondJSON(w, code, response)
}

func handleServiceError(w http.ResponseWriter, err error) {
	switch err {
	case domain.ErrUserNotFound:
		respondError(w, http.StatusNotFound, "User not found")
	case domain.ErrEmailAlreadyUsed:
		respondError(w, http.StatusConflict, "Email already in use")
	case domain.ErrInvalidEmail:
		respondError(w, http.StatusBadRequest, "Invalid email format")
	case domain.ErrWeakPassword:
		respondError(w, http.StatusBadRequest, "Password too weak")
	default:
		respondError(w, http.StatusInternalServerError, "Internal server error")
	}
}
```

## Step 10: Create Main Application

**File: `cmd/main.go`**

```go
package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/lib/pq"
	"github.com/yourusername/myapp/internal/handler"
	"github.com/yourusername/myapp/internal/repository"
	"github.com/yourusername/myapp/internal/repository/queries"
	"github.com/yourusername/myapp/internal/service"
)

func main() {
	// Database connection
	db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Connection pooling
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	// Initialize sqlc queries
	q := queries.New(db)

	// Dependency injection
	userRepo := repository.NewPostgresUserRepository(q)
	userService := service.NewUserService(userRepo)
	userHandler := handler.NewUserHandler(userService)

	// Setup HTTP routes
	mux := http.NewServeMux()
	mux.HandleFunc("POST /users", userHandler.CreateUser)
	mux.HandleFunc("GET /users", userHandler.ListUsers)
	mux.HandleFunc("GET /users/{id}", userHandler.GetUser)
	mux.HandleFunc("PUT /users/{id}", userHandler.UpdateUser)
	mux.HandleFunc("DELETE /users/{id}", userHandler.DeleteUser)

	// Start server
	server := &http.Server{
		Addr:         ":8080",
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	log.Printf("Server starting on %s", server.Addr)
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}
```

## Step 11: Add Dependencies

```bash
go get github.com/lib/pq
go get github.com/google/uuid
go get golang.org/x/crypto/bcrypt
go get github.com/go-playground/validator/v10
go mod tidy
```

## Step 12: Setup Database and Run

```bash
# Create PostgreSQL database
createdb myapp

# Set DATABASE_URL environment variable
export DATABASE_URL="postgres://user:password@localhost:5432/myapp?sslmode=disable"

# Apply schema
psql myapp < migrations/schema.sql

# Run application
go run cmd/main.go
```

## Step 13: Test the API

```bash
# Create user
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "securepassword123"
  }'

# Get all users
curl http://localhost:8080/users

# Get specific user
curl http://localhost:8080/users/{user_id}

# Update user
curl -X PUT http://localhost:8080/users/{user_id} \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jane Doe",
    "email": "jane@example.com"
  }'

# Delete user
curl -X DELETE http://localhost:8080/users/{user_id}
```

## Key Advantages of This Architecture

✅ **Type Safety** - sqlc catches SQL errors at compile time
✅ **Clean Separation** - Domain, Repository, Service, Handler layers
✅ **Testability** - Easy to mock interfaces
✅ **No Boilerplate** - No manual Scan() or row mapping
✅ **Security** - Built-in parameterized queries prevent SQL injection
✅ **Performance** - Minimal overhead with database/sql
✅ **Maintainability** - Clear code organization and flow

## Next Steps

1. Add input validation with `github.com/go-playground/validator`
2. Implement logging with `go.uber.org/zap` or `github.com/sirupsen/logrus`
3. Add authentication/authorization middleware
4. Write comprehensive unit tests
5. Add database migrations with `golang-migrate/migrate`
6. Implement graceful shutdown handling
7. Add error handling middleware
8. Setup CI/CD pipeline
