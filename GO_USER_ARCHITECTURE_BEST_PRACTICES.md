# Go User Management Architecture Best Practices

A comprehensive guide for implementing Repository, Service, and Controller layers for user management in Go.

## Table of Contents
1. [Project Structure](#project-structure)
2. [Models/Domain Entities](#modelsdomain-entities)
3. [Repository Layer](#repository-layer)
4. [Service Layer](#service-layer)
5. [Controller/Handler Layer](#controllerhandler-layer)
6. [Dependency Injection](#dependency-injection)
7. [Error Handling](#error-handling)
8. [Complete Example](#complete-example)

---

## Project Structure

```
project/
├── cmd/
│   └── main.go
├── internal/
│   ├── domain/
│   │   ├── user.go           # Domain models
│   │   └── errors.go         # Custom errors
│   ├── repository/
│   │   ├── user_repository.go  # Interface
│   │   └── user_postgres.go    # Implementation
│   ├── service/
│   │   └── user_service.go
│   ├── handler/
│   │   └── user_handler.go
│   └── config/
│       └── config.go
├── go.mod
└── go.sum
```

---

## Models/Domain Entities

### Best Practices:
- Keep domain models in a separate package
- Use struct tags for validation and database mapping
- Define interfaces for repository contracts
- Create custom error types

**File: `internal/domain/user.go`**

```go
package domain

import (
	"errors"
	"time"
)

// User represents a user in the system
type User struct {
	ID        string    `db:"id" json:"id"`
	Name      string    `db:"name" json:"name" validate:"required,min=2,max=100"`
	Email     string    `db:"email" json:"email" validate:"required,email"`
	Password  string    `db:"password" json:"-"` // Never expose password in JSON
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

// CreateUserRequest is the DTO for creating a user
type CreateUserRequest struct {
	Name     string `json:"name" validate:"required,min=2,max=100"`
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required,min=8"`
}

// UpdateUserRequest is the DTO for updating a user
type UpdateUserRequest struct {
	Name  string `json:"name" validate:"omitempty,min=2,max=100"`
	Email string `json:"email" validate:"omitempty,email"`
}

// UserResponse is the DTO for responding with user data
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

---

## Repository Layer

### Best Practices:
- Define interfaces first (dependency inversion principle)
- Repository handles only data persistence logic
- No business logic in the repository
- Support pagination and filtering
- Use context for cancellation and timeout
- **Use sqlc for type-safe SQL queries** (eliminates boilerplate and prevents SQL errors)

### Setting up sqlc

First, install sqlc:
```bash
brew install sqlc  # macOS
# or visit https://docs.sqlc.dev/en/latest/overview/install.html
```

Create `sqlc.yaml` in your project root:

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
```

Create SQL queries in `internal/repository/queries/users.sql`:

```sql
-- name: CreateUser :exec
INSERT INTO users (id, name, email, password, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6);

-- name: GetUserByID :one
SELECT id, name, email, password, created_at, updated_at FROM users
WHERE id = $1;

-- name: GetUserByEmail :one
SELECT id, name, email, password, created_at, updated_at FROM users
WHERE email = $1;

-- name: UpdateUser :exec
UPDATE users
SET name = $1, email = $2, password = $3, updated_at = $4
WHERE id = $5;

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

Generate Go code:
```bash
sqlc generate
```

**File: `internal/repository/user_repository.go`**

```go
package repository

import (
	"context"
	"github.com/yourusername/yourapp/internal/domain"
)

// UserRepository defines the contract for user data access
type UserRepository interface {
	// Create inserts a new user
	Create(ctx context.Context, user *domain.User) error

	// GetByID retrieves a user by ID
	GetByID(ctx context.Context, id string) (*domain.User, error)

	// GetByEmail retrieves a user by email
	GetByEmail(ctx context.Context, email string) (*domain.User, error)

	// Update updates an existing user
	Update(ctx context.Context, user *domain.User) error

	// Delete removes a user
	Delete(ctx context.Context, id string) error

	// List retrieves users with pagination
	List(ctx context.Context, offset, limit int) ([]*domain.User, int64, error)

	// Exists checks if a user exists by email
	Exists(ctx context.Context, email string) (bool, error)
}
```

**File: `internal/repository/user_postgres.go`**

```go
package repository

import (
	"context"
	"github.com/yourusername/yourapp/internal/domain"
	"github.com/yourusername/yourapp/internal/repository/queries"
)

// UserRepository defines the contract for user data access
type UserRepository interface {
	// Create inserts a new user
	Create(ctx context.Context, user *domain.User) error

	// GetByID retrieves a user by ID
	GetByID(ctx context.Context, id string) (*domain.User, error)

	// GetByEmail retrieves a user by email
	GetByEmail(ctx context.Context, email string) (*domain.User, error)

	// Update updates an existing user
	Update(ctx context.Context, user *domain.User) error

	// Delete removes a user
	Delete(ctx context.Context, id string) error

	// List retrieves users with pagination
	List(ctx context.Context, offset, limit int32) ([]*domain.User, int64, error)

	// Exists checks if a user exists by email
	Exists(ctx context.Context, email string) (bool, error)
}

type PostgresUserRepository struct {
	queries *queries.Queries
}

// NewPostgresUserRepository creates a new postgres user repository
func NewPostgresUserRepository(q *queries.Queries) UserRepository {
	return &PostgresUserRepository{queries: q}
}

// Create inserts a new user into the database
func (r *PostgresUserRepository) Create(ctx context.Context, user *domain.User) error {
	return r.queries.CreateUser(ctx, queries.CreateUserParams{
		ID:       user.ID,
		Name:     user.Name,
		Email:    user.Email,
		Password: user.Password,
	})
}

// GetByID retrieves a user by ID
func (r *PostgresUserRepository) GetByID(ctx context.Context, id string) (*domain.User, error) {
	row, err := r.queries.GetUserByID(ctx, id)
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

// GetByEmail retrieves a user by email
func (r *PostgresUserRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	row, err := r.queries.GetUserByEmail(ctx, email)
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

// Update updates an existing user
func (r *PostgresUserRepository) Update(ctx context.Context, user *domain.User) error {
	return r.queries.UpdateUser(ctx, queries.UpdateUserParams{
		ID:       user.ID,
		Name:     user.Name,
		Email:    user.Email,
		Password: user.Password,
	})
}

// Delete removes a user
func (r *PostgresUserRepository) Delete(ctx context.Context, id string) error {
	return r.queries.DeleteUser(ctx, id)
}

// List retrieves users with pagination
func (r *PostgresUserRepository) List(ctx context.Context, offset, limit int32) ([]*domain.User, int64, error) {
	// Get total count
	total, err := r.queries.CountUsers(ctx)
	if err != nil {
		return nil, 0, err
	}

	// Get paginated results
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

// Exists checks if a user exists by email
func (r *PostgresUserRepository) Exists(ctx context.Context, email string) (bool, error) {
	return r.queries.UserExists(ctx, email)
}

```

---

## Service Layer

### Best Practices:
- Contains all business logic
- Validates input data
- Orchestrates repository calls
- Implements authentication/authorization
- Uses interfaces for dependencies (loose coupling)
- Returns domain errors, not database errors

**File: `internal/service/user_service.go`**

```go
package service

import (
	"context"
	"fmt"
	"github.com/google/uuid"
	"github.com/yourusername/yourapp/internal/domain"
	"github.com/yourusername/yourapp/internal/repository"
	"golang.org/x/crypto/bcrypt"
	"regexp"
)

// UserService defines business logic for users
type UserService interface {
	CreateUser(ctx context.Context, req *domain.CreateUserRequest) (*domain.User, error)
	GetUser(ctx context.Context, id string) (*domain.User, error)
	GetUserByEmail(ctx context.Context, email string) (*domain.User, error)
	UpdateUser(ctx context.Context, id string, req *domain.UpdateUserRequest) (*domain.User, error)
	DeleteUser(ctx context.Context, id string) error
	ListUsers(ctx context.Context, offset, limit int) ([]*domain.User, int64, error)
	ValidatePassword(hashedPassword, plainPassword string) error
}

type userService struct {
	repo repository.UserRepository
}

// NewUserService creates a new user service
func NewUserService(repo repository.UserRepository) UserService {
	return &userService{repo: repo}
}

// CreateUser creates a new user with validation and hashing
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

	// Don't expose password
	user.Password = ""
	return user, nil
}

// GetUser retrieves a user by ID
func (s *userService) GetUser(ctx context.Context, id string) (*domain.User, error) {
	if id == "" {
		return nil, domain.ErrUserNotFound
	}

	user, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	// Don't expose password
	user.Password = ""
	return user, nil
}

// GetUserByEmail retrieves a user by email
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

// UpdateUser updates an existing user
func (s *userService) UpdateUser(ctx context.Context, id string, req *domain.UpdateUserRequest) (*domain.User, error) {
	// Get current user
	user, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	// Update fields if provided
	if req.Name != "" {
		user.Name = req.Name
	}
	if req.Email != "" {
		// Check if new email already exists (if changing email)
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

// DeleteUser deletes a user
func (s *userService) DeleteUser(ctx context.Context, id string) error {
	return s.repo.Delete(ctx, id)
}

// ListUsers lists all users with pagination
func (s *userService) ListUsers(ctx context.Context, offset, limit int) ([]*domain.User, int64, error) {
	// Validate pagination params
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

	// Remove passwords from response
	for _, user := range users {
		user.Password = ""
	}

	return users, total, nil
}

// ValidatePassword validates a password against its hash
func (s *userService) ValidatePassword(hashedPassword, plainPassword string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(plainPassword))
}

// Private helper methods

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

---

## Controller/Handler Layer

### Best Practices:
- Handles HTTP requests and responses
- Validates query/path parameters
- Maps DTOs to domain models
- Delegates business logic to service
- Handles proper HTTP status codes
- Returns consistent error responses

**File: `internal/handler/user_handler.go`**

```go
package handler

import (
	"encoding/json"
	"fmt"
	"github.com/yourusername/yourapp/internal/domain"
	"github.com/yourusername/yourapp/internal/service"
	"net/http"
	"strconv"
)

// UserHandler handles user-related HTTP requests
type UserHandler struct {
	service service.UserService
}

// NewUserHandler creates a new user handler
func NewUserHandler(service service.UserService) *UserHandler {
	return &UserHandler{service: service}
}

// CreateUser handles POST /users
func (h *UserHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

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

// GetUser handles GET /users/:id
func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	id := r.PathValue("id") // Go 1.22+
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

// UpdateUser handles PUT /users/:id
func (h *UserHandler) UpdateUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

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

// DeleteUser handles DELETE /users/:id
func (h *UserHandler) DeleteUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

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

// ListUsers handles GET /users?offset=0&limit=10
func (h *UserHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	offset := 0
	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil {
			offset = o
		}
	}

	limit := 10
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil {
			limit = l
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

// Helper functions

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

---

## Dependency Injection

### Best Practices:
- Inject dependencies through constructors
- Use wire or manual DI
- Avoid global variables
- Create a setup function for initialization

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
	"github.com/yourusername/yourapp/internal/handler"
	"github.com/yourusername/yourapp/internal/repository"
	"github.com/yourusername/yourapp/internal/repository/queries"
	"github.com/yourusername/yourapp/internal/service"
)

func main() {
	// Initialize database
	db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	// Initialize sqlc queries
	sqlcQueries := queries.New(db)

	// Initialize layers
	userRepo := repository.NewPostgresUserRepository(sqlcQueries)
	userService := service.NewUserService(userRepo)
	userHandler := handler.NewUserHandler(userService)

	// Setup routes
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

	log.Printf("Server listening on %s", server.Addr)
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}
```

---

## Error Handling

### Best Practices:
- Define domain errors
- Return specific errors from service layer
- Map errors to HTTP status codes in handler
- Don't expose internal database errors
- Use error wrapping for context

**Error Mapping Guide:**
| Domain Error | HTTP Status | Meaning |
|---|---|---|
| `ErrUserNotFound` | 404 | Resource doesn't exist |
| `ErrEmailAlreadyUsed` | 409 | Conflict/duplicate |
| `ErrInvalidEmail` | 400 | Bad request |
| `ErrWeakPassword` | 400 | Bad request |
| `ErrUnauthorized` | 401 | Authentication failed |
| Other errors | 500 | Internal server error |

---

## Testing

### Unit Test Example

**File: `internal/service/user_service_test.go`**

```go
package service

import (
	"context"
	"errors"
	"testing"
	"github.com/yourusername/yourapp/internal/domain"
	"github.com/yourusername/yourapp/internal/repository"
)

type mockUserRepository struct {
	repository.UserRepository
	createFunc func(ctx context.Context, user *domain.User) error
	getByIDFunc func(ctx context.Context, id string) (*domain.User, error)
	existsFunc func(ctx context.Context, email string) (bool, error)
}

func (m *mockUserRepository) Create(ctx context.Context, user *domain.User) error {
	return m.createFunc(ctx, user)
}

func (m *mockUserRepository) GetByID(ctx context.Context, id string) (*domain.User, error) {
	return m.getByIDFunc(ctx, id)
}

func (m *mockUserRepository) Exists(ctx context.Context, email string) (bool, error) {
	return m.existsFunc(ctx, email)
}

func TestCreateUserSuccess(t *testing.T) {
	mock := &mockUserRepository{
		createFunc: func(ctx context.Context, user *domain.User) error {
			return nil
		},
		existsFunc: func(ctx context.Context, email string) (bool, error) {
			return false, nil
		},
	}

	service := NewUserService(mock)
	req := &domain.CreateUserRequest{
		Name:     "John Doe",
		Email:    "john@example.com",
		Password: "securepassword123",
	}

	user, err := service.CreateUser(context.Background(), req)
	if err != nil {
		t.Errorf("Expected no error, got %v", err)
	}

	if user == nil {
		t.Error("Expected user, got nil")
	}

	if user.Name != "John Doe" {
		t.Errorf("Expected name 'John Doe', got '%s'", user.Name)
	}
}

func TestCreateUserEmailExists(t *testing.T) {
	mock := &mockUserRepository{
		existsFunc: func(ctx context.Context, email string) (bool, error) {
			return true, nil
		},
	}

	service := NewUserService(mock)
	req := &domain.CreateUserRequest{
		Name:     "John Doe",
		Email:    "john@example.com",
		Password: "securepassword123",
	}

	_, err := service.CreateUser(context.Background(), req)
	if err != domain.ErrEmailAlreadyUsed {
		t.Errorf("Expected ErrEmailAlreadyUsed, got %v", err)
	}
}
```

---

## Key Takeaways

✅ **Do's:**
- Separate concerns into distinct layers
- Use interfaces for loose coupling
- Define domain errors explicitly
- Use context for timeouts and cancellation
- Hash passwords before storage
- Never expose sensitive data in responses
- Write unit tests for service layer
- Use dependency injection

❌ **Don'ts:**
- Mix business logic with HTTP handling
- Return database errors to clients
- Expose passwords in responses
- Use global variables
- Skip input validation
- Hardcode database credentials
- Make repository methods know about business rules

---

## Recommended Packages

```go
// Database
github.com/lib/pq              // PostgreSQL driver
github.com/sqlc-dev/sqlc       // SQL code generation

// Validation
github.com/go-playground/validator  // Input validation

// Hashing
golang.org/x/crypto/bcrypt     // Password hashing

// Dependency Injection
github.com/google/wire          // Wire DI framework

// HTTP Framework (Optional)
github.com/labstack/echo        // Echo web framework
github.com/gin-gonic/gin        // Gin web framework

// Logging
github.com/sirupsen/logrus      // Structured logging
go.uber.org/zap                 // High-performance logging

// Testing
github.com/stretchr/testify     // Testing toolkit
```

---

## SQLC Best Practices Guide

### What is sqlc?

**sqlc** is a tool that generates type-safe Go code from SQL queries. It eliminates boilerplate code, prevents SQL injection, and catches query errors at code generation time rather than runtime.

### Installation

```bash
brew install sqlc  # macOS
# or visit https://docs.sqlc.dev/en/latest/overview/install.html
```

### Project Structure with sqlc

```
project/
├── migrations/
│   └── schema.sql              # Database schema
├── internal/
│   └── repository/
│       ├── queries/
│       │   ├── models.go       # Generated by sqlc
│       │   ├── querier.go      # Generated by sqlc
│       │   ├── users.sql.go    # Generated by sqlc
│       │   └── users.sql       # Your SQL queries
│       ├── user_repository.go  # Repository interface
│       └── user_postgres.go    # Repository implementation
├── sqlc.yaml                   # sqlc configuration
└── go.mod
```

### Setup Configuration

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
```

### Database Schema

**File: `migrations/schema.sql`**

```sql
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
```

### SQL Queries File

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

### Generate Go Code

```bash
sqlc generate
```

This generates:
- `queries/models.go` - Domain models
- `queries/querier.go` - Interface for all queries
- `queries/users.sql.go` - Implemented query functions

### Generated Code Example

**Generated `queries/models.go`** (snippet):

```go
type User struct {
	ID        string    `db:"id" json:"id"`
	Name      string    `db:"name" json:"name"`
	Email     string    `db:"email" json:"email"`
	Password  string    `db:"password" json:"password"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}
```

**Generated `queries/users.sql.go`** (snippet):

```go
const createUser = `-- name: CreateUser :exec
INSERT INTO users (id, name, email, password, created_at, updated_at)
VALUES ($1, $2, $3, $4, NOW(), NOW())
`

type CreateUserParams struct {
	ID       string
	Name     string
	Email    string
	Password string
}

func (q *Queries) CreateUser(ctx context.Context, arg CreateUserParams) error {
	return q.db.ExecContext(ctx, createUser, arg.ID, arg.Name, arg.Email, arg.Password).Err()
}
```

### Benefits of sqlc

✅ **Type Safety** - SQL errors caught at code generation time, not runtime
✅ **No Boilerplate** - No manual Scan() calls or row mapping
✅ **SQL First** - Write real SQL queries, not string concatenation
✅ **Version Control** - Generated code is deterministic
✅ **IDE Support** - SQL queries syntax validated in editors
✅ **Less Code** - ~70% less database code than manual SQL

### Example: Repository with sqlc

**Simplified `internal/repository/user_postgres.go`**

```go
package repository

import (
	"context"
	"database/sql"
	"github.com/yourusername/yourapp/internal/domain"
	"github.com/yourusername/yourapp/internal/repository/queries"
)

type PostgresUserRepository struct {
	queries *queries.Queries
}

func NewPostgresUserRepository(q *queries.Queries) UserRepository {
	return &PostgresUserRepository{queries: q}
}

// Create inserts a new user
func (r *PostgresUserRepository) Create(ctx context.Context, user *domain.User) error {
	return r.queries.CreateUser(ctx, queries.CreateUserParams{
		ID:       user.ID,
		Name:     user.Name,
		Email:    user.Email,
		Password: user.Password,
	})
}

// GetByID retrieves a user by ID
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

// GetByEmail retrieves a user by email
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

// Update updates an existing user
func (r *PostgresUserRepository) Update(ctx context.Context, user *domain.User) error {
	return r.queries.UpdateUser(ctx, queries.UpdateUserParams{
		ID:       user.ID,
		Name:     user.Name,
		Email:    user.Email,
		Password: user.Password,
	})
}

// Delete removes a user
func (r *PostgresUserRepository) Delete(ctx context.Context, id string) error {
	return r.queries.DeleteUser(ctx, id)
}

// List retrieves users with pagination
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

// Exists checks if a user exists by email
func (r *PostgresUserRepository) Exists(ctx context.Context, email string) (bool, error) {
	return r.queries.UserExists(ctx, email)
}
```

### Testing with sqlc

For testing, you can mock the `Queries` interface or use a test database:

```go
package repository

import (
	"context"
	"database/sql"
	"testing"
	"github.com/yourusername/yourapp/internal/domain"
	"github.com/yourusername/yourapp/internal/repository/queries"
)

type mockQueries struct {
	*queries.Queries
	getUserByIDFunc func(ctx context.Context, id string) (*queries.User, error)
}

func (m *mockQueries) GetUserByID(ctx context.Context, id string) (*queries.User, error) {
	return m.getUserByIDFunc(ctx, id)
}

func TestGetUser(t *testing.T) {
	mock := &mockQueries{
		getUserByIDFunc: func(ctx context.Context, id string) (*queries.User, error) {
			return &queries.User{
				ID:    "123",
				Name:  "John Doe",
				Email: "john@example.com",
			}, nil
		},
	}

	repo := &PostgresUserRepository{queries: mock}
	user, err := repo.GetByID(context.Background(), "123")

	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}

	if user.Name != "John Doe" {
		t.Errorf("Expected name 'John Doe', got '%s'", user.Name)
	}
}
```

### Workflow Summary

1. **Write SQL queries** in `.sql` files
2. **Run `sqlc generate`** to create Go code
3. **Use generated code** in repository implementations
4. **Commit generated code** to version control
5. **Update SQL** → regenerate → test → commit

### sqlc.yaml Advanced Options

```yaml
version: "2"
sql:
  - engine: "postgres"
    queries: "./internal/repository/queries"
    schema: "./migrations"
    gen:
      go:
        package: "queries"
        out: "./internal/repository/queries"
        emit_json_tags: true
        emit_pointer_types: true
        emit_prepared_queries: false
        emit_methods: false
        emit_db_tags: true
        sql_package: "pgx/v5"  # or "database/sql" for stdlib
```

---

## Project Layout Summary

```
project/
├── cmd/
│   └── main.go                    # Application entry point
├── internal/
│   ├── domain/
│   │   ├── user.go               # Domain models & DTOs
│   │   └── errors.go             # Domain-specific errors
│   ├── repository/
│   │   ├── user_repository.go    # Interface
│   │   └── user_postgres.go      # Implementation
│   ├── service/
│   │   ├── user_service.go       # Business logic
│   │   └── user_service_test.go  # Unit tests
│   └── handler/
│       └── user_handler.go       # HTTP handlers
├── migrations/                    # Database migrations
├── go.mod
├── go.sum
└── README.md
```

This architecture provides:
- **Testability**: Easy to mock dependencies
- **Maintainability**: Clear separation of concerns
- **Scalability**: Layers can be extended independently
- **Flexibility**: Easy to swap implementations (e.g., switch databases)
