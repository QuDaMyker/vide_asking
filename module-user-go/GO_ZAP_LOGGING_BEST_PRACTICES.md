# Go Logging Best Practices with Zap

## Table of Contents
- [Introduction](#introduction)
- [Why Zap?](#why-zap)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Logger Configuration](#logger-configuration)
- [Production Setup](#production-setup)
- [Integration with Clean Architecture](#integration-with-clean-architecture)
- [Structured Logging](#structured-logging)
- [Context-Based Logging](#context-based-logging)
- [Performance Tips](#performance-tips)
- [Common Patterns](#common-patterns)
- [Testing with Zap](#testing-with-zap)

---

## Introduction

**Zap** is Uber's blazing-fast, structured, leveled logging library for Go. It's designed for high-performance production environments and provides:

- ⚡ **Blazing fast** - Zero allocation logging
- 🔒 **Type-safe** - Structured logging with strong typing
- 📊 **Structured** - JSON output for log aggregation
- 🎯 **Leveled** - Debug, Info, Warn, Error, Fatal, Panic
- 🔧 **Configurable** - Flexible configuration options

---

## Why Zap?

### Performance Comparison

```
BenchmarkZap           20000000    64 ns/op    0 allocs/op
BenchmarkLogrus         3000000   481 ns/op    6 allocs/op
BenchmarkStdLog         5000000   286 ns/op    2 allocs/op
```

**Zap is 7-10x faster than alternatives with zero allocations!**

### Feature Comparison

| Feature | Zap | Logrus | Standard Log |
|---------|-----|--------|--------------|
| Structured Logging | ✅ | ✅ | ❌ |
| JSON Output | ✅ | ✅ | ❌ |
| Zero Allocation | ✅ | ❌ | ❌ |
| Type-Safe Fields | ✅ | ❌ | ❌ |
| Context Support | ✅ | ✅ | ❌ |
| Log Levels | ✅ | ✅ | ❌ |
| Performance | 🚀 | 🐢 | 🐢 |

---

## Installation

```bash
go get -u go.uber.org/zap
```

---

## Quick Start

### 1. Basic Usage (Development)

```go
package main

import (
    "go.uber.org/zap"
)

func main() {
    // Create a development logger (human-readable)
    logger, _ := zap.NewDevelopment()
    defer logger.Sync() // Flush any buffered logs

    logger.Info("This is an info message")
    logger.Warn("This is a warning")
    logger.Error("This is an error")
}
```

**Output:**
```
2025-10-29T10:30:45.123+0700	INFO	main.go:11	This is an info message
2025-10-29T10:30:45.124+0700	WARN	main.go:12	This is a warning
2025-10-29T10:30:45.125+0700	ERROR	main.go:13	This is an error
```

### 2. Structured Logging

```go
package main

import (
    "go.uber.org/zap"
)

func main() {
    logger, _ := zap.NewProduction()
    defer logger.Sync()

    logger.Info("User logged in",
        zap.String("username", "john_doe"),
        zap.Int("user_id", 12345),
        zap.String("ip", "192.168.1.1"),
    )
}
```

**Output (JSON):**
```json
{
  "level": "info",
  "ts": 1698567845.123,
  "caller": "main.go:11",
  "msg": "User logged in",
  "username": "john_doe",
  "user_id": 12345,
  "ip": "192.168.1.1"
}
```

---

## Logger Configuration

### Development vs Production

```go
package logger

import (
    "os"
    "go.uber.org/zap"
    "go.uber.org/zap/zapcore"
)

// NewLogger creates a logger based on environment
func NewLogger(env string) (*zap.Logger, error) {
    switch env {
    case "production":
        return NewProductionLogger()
    case "development":
        return NewDevelopmentLogger()
    default:
        return NewDevelopmentLogger()
    }
}

// NewProductionLogger creates a production-ready logger
func NewProductionLogger() (*zap.Logger, error) {
    config := zap.NewProductionConfig()
    
    // JSON encoding for log aggregation
    config.Encoding = "json"
    
    // Set log level
    config.Level = zap.NewAtomicLevelAt(zapcore.InfoLevel)
    
    // Output to stdout (for Docker/Kubernetes)
    config.OutputPaths = []string{"stdout"}
    config.ErrorOutputPaths = []string{"stderr"}
    
    return config.Build()
}

// NewDevelopmentLogger creates a developer-friendly logger
func NewDevelopmentLogger() (*zap.Logger, error) {
    config := zap.NewDevelopmentConfig()
    
    // Console encoding (human-readable)
    config.Encoding = "console"
    
    // Enable debug level
    config.Level = zap.NewAtomicLevelAt(zapcore.DebugLevel)
    
    // Colorized output
    config.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
    
    return config.Build()
}
```

### Custom Configuration

```go
package logger

import (
    "go.uber.org/zap"
    "go.uber.org/zap/zapcore"
)

func NewCustomLogger() (*zap.Logger, error) {
    // Custom encoder config
    encoderConfig := zapcore.EncoderConfig{
        TimeKey:        "timestamp",
        LevelKey:       "level",
        NameKey:        "logger",
        CallerKey:      "caller",
        FunctionKey:    zapcore.OmitKey,
        MessageKey:     "message",
        StacktraceKey:  "stacktrace",
        LineEnding:     zapcore.DefaultLineEnding,
        EncodeLevel:    zapcore.LowercaseLevelEncoder,
        EncodeTime:     zapcore.ISO8601TimeEncoder,
        EncodeDuration: zapcore.SecondsDurationEncoder,
        EncodeCaller:   zapcore.ShortCallerEncoder,
    }

    // Create JSON encoder
    encoder := zapcore.NewJSONEncoder(encoderConfig)

    // Create core
    core := zapcore.NewCore(
        encoder,
        zapcore.AddSync(os.Stdout),
        zapcore.InfoLevel,
    )

    // Create logger with options
    logger := zap.New(core,
        zap.AddCaller(),           // Add caller information
        zap.AddCallerSkip(1),      // Skip wrapper functions
        zap.AddStacktrace(zapcore.ErrorLevel), // Add stacktrace on errors
    )

    return logger, nil
}
```

---

## Production Setup

### Complete Production Logger

**File: `pkg/logger/logger.go`**

```go
package logger

import (
    "os"
    "time"

    "go.uber.org/zap"
    "go.uber.org/zap/zapcore"
)

var (
    // Global logger instance
    Log *zap.Logger
)

// Config holds logger configuration
type Config struct {
    Environment string
    Level       string
    OutputPaths []string
}

// Initialize sets up the global logger
func Initialize(cfg Config) error {
    var err error
    
    switch cfg.Environment {
    case "production":
        Log, err = newProductionLogger(cfg)
    case "staging":
        Log, err = newStagingLogger(cfg)
    default:
        Log, err = newDevelopmentLogger(cfg)
    }
    
    if err != nil {
        return err
    }
    
    // Replace global zap logger
    zap.ReplaceGlobals(Log)
    
    return nil
}

func newProductionLogger(cfg Config) (*zap.Logger, error) {
    encoderConfig := zapcore.EncoderConfig{
        TimeKey:        "ts",
        LevelKey:       "level",
        NameKey:        "logger",
        CallerKey:      "caller",
        FunctionKey:    zapcore.OmitKey,
        MessageKey:     "msg",
        StacktraceKey:  "stacktrace",
        LineEnding:     zapcore.DefaultLineEnding,
        EncodeLevel:    zapcore.LowercaseLevelEncoder,
        EncodeTime:     zapcore.EpochTimeEncoder,
        EncodeDuration: zapcore.SecondsDurationEncoder,
        EncodeCaller:   zapcore.ShortCallerEncoder,
    }

    // Parse log level
    level := zapcore.InfoLevel
    if cfg.Level != "" {
        if err := level.UnmarshalText([]byte(cfg.Level)); err != nil {
            level = zapcore.InfoLevel
        }
    }

    config := zap.Config{
        Level:             zap.NewAtomicLevelAt(level),
        Development:       false,
        DisableCaller:     false,
        DisableStacktrace: false,
        Sampling: &zap.SamplingConfig{
            Initial:    100,
            Thereafter: 100,
        },
        Encoding:         "json",
        EncoderConfig:    encoderConfig,
        OutputPaths:      cfg.OutputPaths,
        ErrorOutputPaths: []string{"stderr"},
    }

    return config.Build(
        zap.AddCaller(),
        zap.AddCallerSkip(1),
        zap.AddStacktrace(zapcore.ErrorLevel),
    )
}

func newDevelopmentLogger(cfg Config) (*zap.Logger, error) {
    encoderConfig := zapcore.EncoderConfig{
        TimeKey:        "T",
        LevelKey:       "L",
        NameKey:        "N",
        CallerKey:      "C",
        FunctionKey:    zapcore.OmitKey,
        MessageKey:     "M",
        StacktraceKey:  "S",
        LineEnding:     zapcore.DefaultLineEnding,
        EncodeLevel:    zapcore.CapitalColorLevelEncoder,
        EncodeTime:     zapcore.ISO8601TimeEncoder,
        EncodeDuration: zapcore.StringDurationEncoder,
        EncodeCaller:   zapcore.ShortCallerEncoder,
    }

    config := zap.Config{
        Level:            zap.NewAtomicLevelAt(zapcore.DebugLevel),
        Development:      true,
        Encoding:         "console",
        EncoderConfig:    encoderConfig,
        OutputPaths:      []string{"stdout"},
        ErrorOutputPaths: []string{"stderr"},
    }

    return config.Build(zap.AddCaller(), zap.AddStacktrace(zapcore.ErrorLevel))
}

// Sync flushes any buffered log entries
func Sync() error {
    if Log != nil {
        return Log.Sync()
    }
    return nil
}
```

### Main Application Setup

**File: `cmd/main.go`**

```go
package main

import (
    "log"
    "os"

    "yourapp/pkg/logger"
    "go.uber.org/zap"
)

func main() {
    // Initialize logger
    loggerConfig := logger.Config{
        Environment: getEnv("ENVIRONMENT", "development"),
        Level:       getEnv("LOG_LEVEL", "info"),
        OutputPaths: []string{"stdout"},
    }

    if err := logger.Initialize(loggerConfig); err != nil {
        log.Fatalf("Failed to initialize logger: %v", err)
    }
    defer logger.Sync()

    // Use the logger
    logger.Log.Info("Application starting",
        zap.String("environment", loggerConfig.Environment),
        zap.String("version", "1.0.0"),
    )

    // Your application code here
    if err := run(); err != nil {
        logger.Log.Fatal("Application failed", zap.Error(err))
    }

    logger.Log.Info("Application shutdown successfully")
}

func run() error {
    // Application logic
    return nil
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}
```

---

## Integration with Clean Architecture

### 1. Handler Layer

**File: `internal/handler/user_handler.go`**

```go
package handler

import (
    "encoding/json"
    "net/http"

    "yourapp/internal/service"
    "go.uber.org/zap"
)

type UserHandler struct {
    service service.UserService
    logger  *zap.Logger
}

func NewUserHandler(service service.UserService, logger *zap.Logger) *UserHandler {
    return &UserHandler{
        service: service,
        logger:  logger,
    }
}

func (h *UserHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    
    // Log incoming request
    h.logger.Info("Creating user",
        zap.String("method", r.Method),
        zap.String("path", r.URL.Path),
        zap.String("remote_addr", r.RemoteAddr),
    )

    var req CreateUserRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        h.logger.Error("Failed to decode request",
            zap.Error(err),
            zap.String("remote_addr", r.RemoteAddr),
        )
        http.Error(w, "Invalid request", http.StatusBadRequest)
        return
    }

    // Call service
    user, err := h.service.CreateUser(ctx, req.Name, req.Email, req.Password)
    if err != nil {
        h.logger.Error("Failed to create user",
            zap.Error(err),
            zap.String("email", req.Email),
        )
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    // Success
    h.logger.Info("User created successfully",
        zap.String("user_id", user.ID),
        zap.String("email", user.Email),
    )

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(user)
}
```

### 2. Service Layer

**File: `internal/service/user_service.go`**

```go
package service

import (
    "context"
    "errors"
    "fmt"

    "yourapp/internal/domain"
    "yourapp/internal/repository"
    "go.uber.org/zap"
    "golang.org/x/crypto/bcrypt"
)

type UserService interface {
    CreateUser(ctx context.Context, name, email, password string) (*domain.User, error)
    GetUser(ctx context.Context, id string) (*domain.User, error)
}

type userService struct {
    repo   repository.UserRepository
    logger *zap.Logger
}

func NewUserService(repo repository.UserRepository, logger *zap.Logger) UserService {
    return &userService{
        repo:   repo,
        logger: logger,
    }
}

func (s *userService) CreateUser(ctx context.Context, name, email, password string) (*domain.User, error) {
    // Log business operation
    s.logger.Debug("Starting user creation",
        zap.String("email", email),
    )

    // Validate
    if email == "" {
        s.logger.Warn("User creation failed: empty email")
        return nil, errors.New("email is required")
    }

    // Check if user exists
    existing, err := s.repo.GetByEmail(ctx, email)
    if err == nil && existing != nil {
        s.logger.Warn("User creation failed: email already exists",
            zap.String("email", email),
        )
        return nil, fmt.Errorf("user with email %s already exists", email)
    }

    // Hash password
    hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
    if err != nil {
        s.logger.Error("Failed to hash password", zap.Error(err))
        return nil, err
    }

    // Create user
    user := &domain.User{
        Name:     name,
        Email:    email,
        Password: string(hashedPassword),
    }

    if err := s.repo.Create(ctx, user); err != nil {
        s.logger.Error("Failed to create user in database",
            zap.Error(err),
            zap.String("email", email),
        )
        return nil, err
    }

    s.logger.Info("User created successfully",
        zap.String("user_id", user.ID),
        zap.String("email", user.Email),
    )

    return user, nil
}

func (s *userService) GetUser(ctx context.Context, id string) (*domain.User, error) {
    s.logger.Debug("Fetching user", zap.String("user_id", id))

    user, err := s.repo.GetByID(ctx, id)
    if err != nil {
        s.logger.Error("Failed to fetch user",
            zap.Error(err),
            zap.String("user_id", id),
        )
        return nil, err
    }

    return user, nil
}
```

### 3. Repository Layer

**File: `internal/repository/user_repository.go`**

```go
package repository

import (
    "context"
    "database/sql"

    "yourapp/internal/domain"
    "yourapp/internal/repository/queries"
    "go.uber.org/zap"
)

type UserRepository interface {
    Create(ctx context.Context, user *domain.User) error
    GetByID(ctx context.Context, id string) (*domain.User, error)
    GetByEmail(ctx context.Context, email string) (*domain.User, error)
}

type postgresUserRepository struct {
    queries *queries.Queries
    logger  *zap.Logger
}

func NewPostgresUserRepository(q *queries.Queries, logger *zap.Logger) UserRepository {
    return &postgresUserRepository{
        queries: q,
        logger:  logger,
    }
}

func (r *postgresUserRepository) Create(ctx context.Context, user *domain.User) error {
    r.logger.Debug("Executing database query: CreateUser",
        zap.String("email", user.Email),
    )

    params := queries.CreateUserParams{
        Name:     user.Name,
        Email:    user.Email,
        Password: user.Password,
    }

    dbUser, err := r.queries.CreateUser(ctx, params)
    if err != nil {
        r.logger.Error("Database query failed: CreateUser",
            zap.Error(err),
            zap.String("email", user.Email),
        )
        return err
    }

    user.ID = dbUser.ID
    user.CreatedAt = dbUser.CreatedAt
    user.UpdatedAt = dbUser.UpdatedAt

    r.logger.Debug("Database query succeeded: CreateUser",
        zap.String("user_id", user.ID),
    )

    return nil
}

func (r *postgresUserRepository) GetByID(ctx context.Context, id string) (*domain.User, error) {
    r.logger.Debug("Executing database query: GetUser", zap.String("user_id", id))

    dbUser, err := r.queries.GetUser(ctx, id)
    if err != nil {
        if err == sql.ErrNoRows {
            r.logger.Debug("User not found", zap.String("user_id", id))
        } else {
            r.logger.Error("Database query failed: GetUser",
                zap.Error(err),
                zap.String("user_id", id),
            )
        }
        return nil, err
    }

    return &domain.User{
        ID:        dbUser.ID,
        Name:      dbUser.Name,
        Email:     dbUser.Email,
        Password:  dbUser.Password,
        CreatedAt: dbUser.CreatedAt,
        UpdatedAt: dbUser.UpdatedAt,
    }, nil
}
```

---

## Structured Logging

### Field Types

```go
package main

import (
    "time"
    "go.uber.org/zap"
)

func demonstrateFieldTypes(logger *zap.Logger) {
    // String field
    logger.Info("Message", zap.String("key", "value"))

    // Integer fields
    logger.Info("Message",
        zap.Int("age", 30),
        zap.Int64("count", 1000000),
        zap.Uint32("port", 8080),
    )

    // Float fields
    logger.Info("Message",
        zap.Float64("price", 19.99),
        zap.Float32("rating", 4.5),
    )

    // Boolean field
    logger.Info("Message", zap.Bool("active", true))

    // Time field
    logger.Info("Message",
        zap.Time("timestamp", time.Now()),
        zap.Duration("elapsed", time.Second*5),
    )

    // Error field
    err := someFunction()
    logger.Error("Operation failed", zap.Error(err))

    // Array fields
    logger.Info("Message",
        zap.Strings("tags", []string{"go", "logging", "zap"}),
        zap.Ints("scores", []int{95, 87, 92}),
    )

    // Namespace (grouped fields)
    logger.Info("Message",
        zap.Namespace("user"),
        zap.String("id", "12345"),
        zap.String("name", "John"),
    )

    // Object field (custom struct)
    user := User{ID: "123", Name: "John"}
    logger.Info("Message", zap.Object("user", user))

    // Multiple fields
    logger.Info("User login",
        zap.String("user_id", "12345"),
        zap.String("username", "john_doe"),
        zap.String("ip", "192.168.1.1"),
        zap.Time("login_time", time.Now()),
        zap.Bool("successful", true),
    )
}
```

### Custom Object Marshaling

```go
package domain

import "go.uber.org/zap/zapcore"

type User struct {
    ID       string
    Name     string
    Email    string
    Password string // Don't log passwords!
}

// MarshalLogObject implements zapcore.ObjectMarshaler
func (u User) MarshalLogObject(enc zapcore.ObjectEncoder) error {
    enc.AddString("id", u.ID)
    enc.AddString("name", u.Name)
    enc.AddString("email", u.Email)
    // Never log password!
    return nil
}

// Usage:
// logger.Info("User details", zap.Object("user", user))
```

---

## Context-Based Logging

### Logging with Request Context

```go
package middleware

import (
    "context"
    "net/http"

    "github.com/google/uuid"
    "go.uber.org/zap"
)

type contextKey string

const (
    requestIDKey contextKey = "request_id"
    loggerKey    contextKey = "logger"
)

// RequestIDMiddleware adds a unique request ID to the context
func RequestIDMiddleware(logger *zap.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // Generate request ID
            requestID := uuid.New().String()

            // Create logger with request ID
            reqLogger := logger.With(
                zap.String("request_id", requestID),
                zap.String("method", r.Method),
                zap.String("path", r.URL.Path),
                zap.String("remote_addr", r.RemoteAddr),
            )

            // Add to context
            ctx := context.WithValue(r.Context(), requestIDKey, requestID)
            ctx = context.WithValue(ctx, loggerKey, reqLogger)

            // Add request ID to response header
            w.Header().Set("X-Request-ID", requestID)

            reqLogger.Info("Request received")
            next.ServeHTTP(w, r.WithContext(ctx))
            reqLogger.Info("Request completed")
        })
    }
}

// GetLogger retrieves the logger from context
func GetLogger(ctx context.Context) *zap.Logger {
    if logger, ok := ctx.Value(loggerKey).(*zap.Logger); ok {
        return logger
    }
    return zap.L() // Fallback to global logger
}

// GetRequestID retrieves the request ID from context
func GetRequestID(ctx context.Context) string {
    if requestID, ok := ctx.Value(requestIDKey).(string); ok {
        return requestID
    }
    return ""
}
```

### Using Context Logger in Handlers

```go
package handler

import (
    "net/http"
    "yourapp/pkg/middleware"
    "go.uber.org/zap"
)

func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    logger := middleware.GetLogger(ctx)

    userID := r.PathValue("id")

    // All logs will include request_id, method, path, etc.
    logger.Info("Fetching user", zap.String("user_id", userID))

    user, err := h.service.GetUser(ctx, userID)
    if err != nil {
        logger.Error("Failed to fetch user",
            zap.Error(err),
            zap.String("user_id", userID),
        )
        http.Error(w, "User not found", http.StatusNotFound)
        return
    }

    logger.Info("User fetched successfully", zap.String("user_id", userID))
    // ... send response
}
```

---

## Performance Tips

### 1. Use SugaredLogger for Development

```go
package main

import "go.uber.org/zap"

func main() {
    logger, _ := zap.NewProduction()
    defer logger.Sync()

    // Sugared logger (slower but more convenient)
    sugar := logger.Sugar()

    // Printf-style
    sugar.Infof("User %s logged in at %v", "john", time.Now())
    sugar.Debugw("Debug message",
        "user_id", 12345,
        "action", "login",
    )

    // Regular logger (faster, zero-allocation)
    logger.Info("User logged in",
        zap.String("username", "john"),
        zap.Time("timestamp", time.Now()),
    )
}
```

### 2. Pre-allocate Fields for Repeated Logging

```go
package service

import "go.uber.org/zap"

type UserService struct {
    baseLogger *zap.Logger
}

func NewUserService(logger *zap.Logger) *UserService {
    return &UserService{
        baseLogger: logger.With(
            zap.String("service", "user_service"),
            zap.String("version", "1.0.0"),
        ),
    }
}

func (s *UserService) CreateUser(ctx context.Context, name, email string) error {
    // baseLogger already has service and version fields
    s.baseLogger.Info("Creating user", zap.String("email", email))
    // ...
}
```

### 3. Use Sampling in High-Traffic Production

```go
package logger

import "go.uber.org/zap"

func NewHighTrafficLogger() (*zap.Logger, error) {
    config := zap.NewProductionConfig()
    
    // Sample logs: log first 100, then 1 out of every 100
    config.Sampling = &zap.SamplingConfig{
        Initial:    100,
        Thereafter: 100,
    }
    
    return config.Build()
}
```

### 4. Conditional Debug Logging

```go
package main

import "go.uber.org/zap"

func processRequest(logger *zap.Logger) {
    // Check if debug is enabled before expensive operations
    if logger.Core().Enabled(zap.DebugLevel) {
        // Only compute expensive debug info if debug is enabled
        debugInfo := computeExpensiveDebugInfo()
        logger.Debug("Debug info", zap.String("data", debugInfo))
    }
}
```

---

## Common Patterns

### 1. Logging HTTP Middleware

```go
package middleware

import (
    "net/http"
    "time"
    "go.uber.org/zap"
)

type responseWriter struct {
    http.ResponseWriter
    statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.statusCode = code
    rw.ResponseWriter.WriteHeader(code)
}

func LoggingMiddleware(logger *zap.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()

            wrapped := &responseWriter{
                ResponseWriter: w,
                statusCode:     http.StatusOK,
            }

            next.ServeHTTP(wrapped, r)

            duration := time.Since(start)

            logger.Info("HTTP request",
                zap.String("method", r.Method),
                zap.String("path", r.URL.Path),
                zap.Int("status", wrapped.statusCode),
                zap.Duration("duration", duration),
                zap.String("remote_addr", r.RemoteAddr),
                zap.String("user_agent", r.UserAgent()),
            )
        })
    }
}
```

### 2. Error Logging with Stack Traces

```go
package service

import (
    "errors"
    "go.uber.org/zap"
)

func (s *UserService) DeleteUser(ctx context.Context, id string) error {
    if err := s.repo.Delete(ctx, id); err != nil {
        // Log error with stack trace
        s.logger.Error("Failed to delete user",
            zap.Error(err),
            zap.String("user_id", id),
            zap.Stack("stacktrace"), // Add full stack trace
        )
        return errors.New("failed to delete user")
    }
    return nil
}
```

### 3. Panic Recovery with Logging

```go
package middleware

import (
    "net/http"
    "go.uber.org/zap"
)

func RecoveryMiddleware(logger *zap.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            defer func() {
                if err := recover(); err != nil {
                    logger.Error("Panic recovered",
                        zap.Any("error", err),
                        zap.String("path", r.URL.Path),
                        zap.String("method", r.Method),
                        zap.Stack("stacktrace"),
                    )
                    http.Error(w, "Internal Server Error", http.StatusInternalServerError)
                }
            }()
            next.ServeHTTP(w, r)
        })
    }
}
```

### 4. Database Query Logging

```go
package repository

import (
    "context"
    "time"
    "go.uber.org/zap"
)

func (r *postgresUserRepository) GetByID(ctx context.Context, id string) (*domain.User, error) {
    start := time.Now()

    r.logger.Debug("Executing query",
        zap.String("query", "SELECT * FROM users WHERE id = $1"),
        zap.String("user_id", id),
    )

    user, err := r.queries.GetUser(ctx, id)
    
    duration := time.Since(start)

    if err != nil {
        r.logger.Error("Query failed",
            zap.Error(err),
            zap.String("user_id", id),
            zap.Duration("duration", duration),
        )
        return nil, err
    }

    r.logger.Debug("Query succeeded",
        zap.String("user_id", id),
        zap.Duration("duration", duration),
    )

    return user, nil
}
```

---

## Testing with Zap

### 1. Test Logger

```go
package handler_test

import (
    "testing"
    "go.uber.org/zap"
    "go.uber.org/zap/zaptest"
)

func TestUserHandler_CreateUser(t *testing.T) {
    // Create test logger that writes to testing.T
    logger := zaptest.NewLogger(t)
    
    // Or create a no-op logger for silent tests
    // logger := zap.NewNop()
    
    handler := NewUserHandler(mockService, logger)
    
    // Test your handler...
}
```

### 2. Capturing Logs in Tests

```go
package service_test

import (
    "testing"
    "go.uber.org/zap"
    "go.uber.org/zap/zapcore"
    "go.uber.org/zap/zaptest/observer"
)

func TestUserService_CreateUser_Logging(t *testing.T) {
    // Create observed logger
    core, recorded := observer.New(zapcore.InfoLevel)
    logger := zap.New(core)

    service := NewUserService(mockRepo, logger)

    // Execute operation
    _, err := service.CreateUser(context.Background(), "John", "john@example.com", "pass123")
    if err != nil {
        t.Fatal(err)
    }

    // Assert logs
    logs := recorded.All()
    if len(logs) != 1 {
        t.Errorf("Expected 1 log entry, got %d", len(logs))
    }

    if logs[0].Message != "User created successfully" {
        t.Errorf("Expected log message 'User created successfully', got '%s'", logs[0].Message)
    }

    // Check log fields
    fields := logs[0].ContextMap()
    if fields["email"] != "john@example.com" {
        t.Errorf("Expected email field to be 'john@example.com', got '%v'", fields["email"])
    }
}
```

---

## Complete Example

### Full Application with Zap Integration

**File: `cmd/main.go`**

```go
package main

import (
    "context"
    "database/sql"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    _ "github.com/lib/pq"
    "yourapp/internal/handler"
    "yourapp/internal/repository"
    "yourapp/internal/repository/queries"
    "yourapp/internal/service"
    "yourapp/pkg/logger"
    "yourapp/pkg/middleware"
    "go.uber.org/zap"
)

func main() {
    // Initialize logger
    logConfig := logger.Config{
        Environment: getEnv("ENVIRONMENT", "development"),
        Level:       getEnv("LOG_LEVEL", "info"),
        OutputPaths: []string{"stdout"},
    }

    if err := logger.Initialize(logConfig); err != nil {
        log.Fatalf("Failed to initialize logger: %v", err)
    }
    defer logger.Sync()

    logger.Log.Info("Application starting",
        zap.String("environment", logConfig.Environment),
        zap.String("version", "1.0.0"),
    )

    // Initialize database
    db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        logger.Log.Fatal("Failed to connect to database", zap.Error(err))
    }
    defer db.Close()

    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(5 * time.Minute)

    logger.Log.Info("Database connection established")

    // Initialize dependencies
    q := queries.New(db)
    userRepo := repository.NewPostgresUserRepository(q, logger.Log)
    userService := service.NewUserService(userRepo, logger.Log)
    userHandler := handler.NewUserHandler(userService, logger.Log)

    // Setup routes
    mux := http.NewServeMux()
    mux.HandleFunc("POST /users", userHandler.CreateUser)
    mux.HandleFunc("GET /users/{id}", userHandler.GetUser)
    mux.HandleFunc("PUT /users/{id}", userHandler.UpdateUser)
    mux.HandleFunc("DELETE /users/{id}", userHandler.DeleteUser)

    // Apply middleware
    handler := middleware.RecoveryMiddleware(logger.Log)(
        middleware.RequestIDMiddleware(logger.Log)(
            middleware.LoggingMiddleware(logger.Log)(mux),
        ),
    )

    // Start server
    srv := &http.Server{
        Addr:         ":8080",
        Handler:      handler,
        ReadTimeout:  10 * time.Second,
        WriteTimeout: 10 * time.Second,
        IdleTimeout:  120 * time.Second,
    }

    // Graceful shutdown
    go func() {
        logger.Log.Info("Server starting", zap.String("addr", srv.Addr))
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            logger.Log.Fatal("Server failed", zap.Error(err))
        }
    }()

    // Wait for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    logger.Log.Info("Server shutting down...")

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        logger.Log.Fatal("Server forced to shutdown", zap.Error(err))
    }

    logger.Log.Info("Server stopped gracefully")
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}
```

---

## Environment Configuration

### Development

```bash
export ENVIRONMENT=development
export LOG_LEVEL=debug
```

### Production

```bash
export ENVIRONMENT=production
export LOG_LEVEL=info
```

### Docker Compose

```yaml
version: '3.8'
services:
  app:
    build: .
    environment:
      - ENVIRONMENT=production
      - LOG_LEVEL=info
      - DATABASE_URL=postgres://user:pass@db:5432/mydb
    ports:
      - "8080:8080"
```

---

## Summary

### ✅ Best Practices Checklist

- [x] Use `zap.NewProduction()` in production
- [x] Use `zap.NewDevelopment()` in development
- [x] Always call `defer logger.Sync()` in main
- [x] Use structured logging with typed fields
- [x] Inject logger through constructors (DI)
- [x] Use context-based logging for request tracing
- [x] Never log sensitive data (passwords, tokens)
- [x] Use appropriate log levels (Debug, Info, Warn, Error)
- [x] Add request IDs for traceability
- [x] Log errors with `zap.Error(err)`
- [x] Add stack traces for critical errors
- [x] Use sampling for high-traffic production
- [x] Create logger wrappers per service/layer
- [x] Use zaptest.NewLogger() in tests

### 🚀 Performance

- **Zero allocations** for structured logging
- **7-10x faster** than alternatives
- **Sampling** reduces overhead in production
- **Pre-allocated fields** for repeated logging

### 📊 Production Ready

- **JSON output** for log aggregation (ELK, Splunk, CloudWatch)
- **Structured fields** for easy parsing
- **Request tracing** with context
- **Error tracking** with stack traces
- **Graceful shutdown** with Sync()

---

## Additional Resources

- **Official Docs**: https://pkg.go.dev/go.uber.org/zap
- **GitHub**: https://github.com/uber-go/zap
- **Performance**: https://github.com/uber-go/zap#performance
- **Best Practices**: https://github.com/uber-go/guide/blob/master/style.md#logging

---

**You're now ready to implement production-grade logging in your Go applications! 🚀**
