# Go Clean Architecture with sqlc - Visual Guide

## Request Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         HTTP CLIENT                                  │
│                  (curl, Postman, Browser, etc)                       │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                     HTTP Request
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      HANDLER LAYER                                   │
│              (HTTP Request/Response Handling)                        │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ 1. Parse HTTP request                                     │    │
│  │ 2. Validate path/query parameters                         │    │
│  │ 3. Decode JSON body into Request DTO                      │    │
│  │ 4. Call Service layer                                     │    │
│  │ 5. Map response to Response DTO                           │    │
│  │ 6. Encode to JSON and send back                           │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Methods: CreateUser, GetUser, UpdateUser, DeleteUser, ListUsers   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                       Service Call
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     SERVICE LAYER                                    │
│              (Business Logic & Validation)                          │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ 1. Validate input (name length, email format, etc)        │    │
│  │ 2. Apply business rules                                    │    │
│  │ 3. Check for duplicates (email uniqueness)                │    │
│  │ 4. Hash passwords with bcrypt                             │    │
│  │ 5. Call Repository layer                                  │    │
│  │ 6. Map domain models to DTOs                              │    │
│  │ 7. Never expose sensitive data                            │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Methods: CreateUser, GetUser, UpdateUser, DeleteUser, ListUsers   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                    Repository Call
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   REPOSITORY LAYER                                   │
│              (Data Persistence & Mapping)                           │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ 1. Call sqlc-generated query functions                    │    │
│  │ 2. Map sqlc result types to domain models                 │    │
│  │ 3. Handle sql.ErrNoRows errors                            │    │
│  │ 4. Convert database constraints to domain errors          │    │
│  │ 5. Return domain models to service layer                  │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │           Uses sqlc-Generated Code                        │    │
│  │  (Queries interface with type-safe methods)               │    │
│  │  - CreateUser()                                            │    │
│  │  - GetUserByID()                                           │    │
│  │  - UpdateUser()                                            │    │
│  │  - DeleteUser()                                            │    │
│  │  - ListUsers()                                             │    │
│  └────────────────────────────────────────────────────────────┘    │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                      SQL Queries
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    SQLC LAYER                                        │
│              (Type-Safe SQL Code Generation)                        │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ Generated from: internal/repository/queries/users.sql     │    │
│  │                                                             │    │
│  │ Generates:                                                 │    │
│  │  - models.go (User struct with JSON tags)                 │    │
│  │  - querier.go (Queries interface)                         │    │
│  │  - users.sql.go (Implementation for each query)           │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Features:                                                           │
│  ✓ Type-safe parameters (no string concatenation)                  │
│  ✓ SQL injection prevention (parameterized queries)                │
│  ✓ Compile-time error checking                                     │
│  ✓ Auto-generated error handling                                   │
│  ✓ Support for :one, :many, :exec modifiers                       │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                   database/sql Package
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   DATABASE DRIVER                                    │
│                  (github.com/lib/pq)                                │
│                                                                      │
│              Executes prepared statements on                        │
│              PostgreSQL database via TCP connection                 │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    POSTGRESQL                                        │
│              (Relational Database)                                  │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ CREATE TABLE users (                                       │    │
│  │   id VARCHAR(36) PRIMARY KEY,                             │    │
│  │   name VARCHAR(100) NOT NULL,                             │    │
│  │   email VARCHAR(255) NOT NULL UNIQUE,                     │    │
│  │   password VARCHAR(255) NOT NULL,                         │    │
│  │   created_at TIMESTAMP DEFAULT NOW(),                     │    │
│  │   updated_at TIMESTAMP DEFAULT NOW()                      │    │
│  │ );                                                         │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
myapp/
│
├── cmd/
│   └── main.go                    ← Application entry point
│       Responsibilities:
│       - Initialize database connection
│       - Create sqlc queries instance
│       - Setup dependency injection
│       - Configure HTTP routes
│       - Start server
│
├── internal/
│   │
│   ├── domain/
│   │   ├── user.go               ← Domain models, DTOs, validation tags
│   │   │   struct User           (domain representation)
│   │   │   struct CreateUserRequest
│   │   │   struct UpdateUserRequest
│   │   │   struct UserResponse
│   │   │
│   │   └── errors.go             ← Domain-specific error definitions
│   │       var ErrUserNotFound
│   │       var ErrEmailAlreadyUsed
│   │       var ErrInvalidEmail
│   │       var ErrWeakPassword
│   │
│   ├── repository/
│   │   ├── queries/
│   │   │   ├── users.sql         ← Your SQL query definitions
│   │   │   │   -- name: CreateUser :exec
│   │   │   │   -- name: GetUserByID :one
│   │   │   │   -- name: ListUsers :many
│   │   │   │   etc.
│   │   │   │
│   │   │   ├── models.go         ← GENERATED by sqlc
│   │   │   │   type User struct
│   │   │   │   (database representation)
│   │   │   │
│   │   │   ├── querier.go        ← GENERATED by sqlc
│   │   │   │   type Queries interface
│   │   │   │   All query method signatures
│   │   │   │
│   │   │   └── users.sql.go      ← GENERATED by sqlc
│   │   │       func (q *Queries) CreateUser(...)
│   │   │       func (q *Queries) GetUserByID(...)
│   │   │       etc.
│   │   │
│   │   ├── user_repository.go    ← Repository interface & adapter
│   │   │   type UserRepository interface
│   │   │       Create(...)
│   │   │       GetByID(...)
│   │   │       Update(...)
│   │   │       Delete(...)
│   │   │       List(...)
│   │   │
│   │   └── user_postgres.go      ← Repository implementation
│   │       type PostgresUserRepository struct
│   │       func (r *PostgresUserRepository) Create(...)
│   │           Maps domain.User to queries.CreateUserParams
│   │           Calls r.queries.CreateUser()
│   │           Returns domain errors
│   │
│   ├── service/
│   │   ├── user_service.go       ← Business logic implementation
│   │   │   type UserService interface
│   │   │   type userService struct
│   │   │       repo repository.UserRepository
│   │   │   func (s *userService) CreateUser(...)
│   │   │       Validate input
│   │   │       Check for duplicates (via repo)
│   │   │       Hash password
│   │   │       Call repo.Create()
│   │   │       Remove passwords from response
│   │   │
│   │   └── user_service_test.go  ← Unit tests with mocks
│   │       type mockUserRepository struct
│   │       func TestCreateUserSuccess(...)
│   │       func TestCreateUserEmailExists(...)
│   │
│   └── handler/
│       └── user_handler.go       ← HTTP handlers
│           type UserHandler struct
│               service service.UserService
│           func (h *UserHandler) CreateUser(w, r)
│               Parse JSON request
│               Call h.service.CreateUser()
│               Return JSON response
│
├── migrations/
│   └── schema.sql                ← Database schema
│       CREATE TABLE users (...)
│       CREATE INDEX idx_users_email
│
├── sqlc.yaml                     ← sqlc configuration
│       version: "2"
│       engine: "postgres"
│       schema: "./migrations/schema.sql"
│       queries: "./internal/repository/queries"
│       out: "./internal/repository/queries"
│
├── go.mod                        ← Go module definition
├── go.sum                        ← Go dependencies checksum
└── README.md                     ← Project documentation
```

---

## Data Flow Examples

### Create User Flow

```
POST /users
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "securepass123"
}
                    ↓
        ┌───────────────────────┐
        │   Handler.CreateUser  │
        │ - Parse JSON          │
        │ - Validate params     │
        └───────────┬───────────┘
                    ↓
        ┌───────────────────────┐
        │ Service.CreateUser    │
        │ - Validate input      │
        │ - Check email exists  │
        │ - Hash password       │
        └───────────┬───────────┘
                    ↓
        ┌───────────────────────┐
        │ Repository.Create     │
        │ - Map domain → sqlc   │
        │ - Call generated code │
        └───────────┬───────────┘
                    ↓
        ┌───────────────────────┐
        │ sqlc.CreateUser       │
        │ - Execute SQL         │
        │ - Handle errors       │
        └───────────┬───────────┘
                    ↓
        ┌───────────────────────┐
        │ PostgreSQL            │
        │ INSERT INTO users     │
        └───────────┬───────────┘
                    ↓
            ✓ User Created
            JSON Response (201)
```

### Get User Flow

```
GET /users/123
                    ↓
        ┌───────────────────────┐
        │   Handler.GetUser     │
        │ - Extract user ID     │
        └───────────┬───────────┘
                    ↓
        ┌───────────────────────┐
        │ Service.GetUser       │
        │ - Validate ID         │
        │ - Remove password     │
        └───────────┬───────────┘
                    ↓
        ┌───────────────────────┐
        │ Repository.GetByID    │
        │ - Call generated code │
        │ - Handle ErrNoRows    │
        └───────────┬───────────┘
                    ↓
        ┌───────────────────────┐
        │ sqlc.GetUserByID      │
        │ - Execute query       │
        │ - Return user data    │
        └───────────┬───────────┘
                    ↓
        ┌───────────────────────┐
        │ PostgreSQL            │
        │ SELECT * FROM users   │
        │ WHERE id = $1         │
        └───────────┬───────────┘
                    ↓
            ✓ User Found
            JSON Response (200)
```

---

## Dependency Injection Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    cmd/main.go                              │
│                                                             │
│  1. sql.Open("postgres", dsn)                              │
│     ↓                                                       │
│     Returns: *sql.DB                                       │
│                                                             │
│  2. queries.New(db)                                        │
│     ↓                                                       │
│     Returns: *queries.Queries                              │
│                                                             │
│  3. repository.NewPostgresUserRepository(sqlcQueries)      │
│     ↓                                                       │
│     Returns: UserRepository interface                      │
│                                                             │
│  4. service.NewUserService(userRepository)                 │
│     ↓                                                       │
│     Returns: UserService interface                         │
│                                                             │
│  5. handler.NewUserHandler(userService)                    │
│     ↓                                                       │
│     Returns: *UserHandler                                  │
│                                                             │
│  6. Register routes:                                       │
│     mux.HandleFunc("POST /users", handler.CreateUser)      │
│     mux.HandleFunc("GET /users/{id}", handler.GetUser)     │
│     etc.                                                    │
│                                                             │
│  7. server.ListenAndServe()                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Error Handling Flow

```
Handler receives error from service
                    ↓
        ┌───────────────────────────┐
        │ Switch on error type      │
        └───────────┬───────────────┘
                    ↓
        ┌───────────────────────────────────────┐
        │ if err == domain.ErrUserNotFound      │
        │   → HTTP 404 Not Found                │
        │                                       │
        │ if err == domain.ErrEmailAlreadyUsed  │
        │   → HTTP 409 Conflict                 │
        │                                       │
        │ if err == domain.ErrInvalidEmail      │
        │   → HTTP 400 Bad Request              │
        │                                       │
        │ default:                              │
        │   → HTTP 500 Internal Server Error    │
        └───────────┬───────────────────────────┘
                    ↓
        Return JSON error response
```

---

## Workflow Summary

```
1. DESIGN PHASE
   ├─ Define database schema (schema.sql)
   ├─ Define domain models (domain/)
   └─ Define interfaces (repository, service)

2. SQL PHASE
   ├─ Write SQL queries (queries/users.sql)
   ├─ Add query names and modifiers (:one, :many)
   └─ Test queries manually

3. CODE GENERATION PHASE
   ├─ Run: sqlc generate
   ├─ Review generated code
   └─ Commit to version control

4. IMPLEMENTATION PHASE
   ├─ Implement repository using sqlc-generated code
   ├─ Implement service with business logic
   ├─ Implement handlers for HTTP endpoints
   └─ Wire up dependency injection

5. TESTING PHASE
   ├─ Unit test service (with mocks)
   ├─ Integration test repository
   ├─ Handler test with test endpoints
   └─ Manual API testing

6. DEPLOYMENT PHASE
   ├─ Build binary
   ├─ Setup database
   ├─ Apply migrations
   ├─ Configure environment
   └─ Start server
```

---

## Key Architectural Principles

### 1. SOLID Principles
```
✓ Single Responsibility
  Each layer has ONE reason to change
  
✓ Open/Closed
  Handler depends on Service interface
  Service depends on Repository interface
  
✓ Liskov Substitution
  Any UserRepository implementation can be swapped
  
✓ Interface Segregation
  Interfaces are small and focused
  
✓ Dependency Inversion
  Depend on abstractions (interfaces)
  Not on concrete implementations
```

### 2. Clean Architecture
```
                    ┌─────────────────┐
                    │  Outer: Web UI  │
                    │  (HTTP)         │
                    └────────┬────────┘
                             ↓
                    ┌─────────────────┐
                    │ Interface Layer │
                    │ (Controllers)   │
                    └────────┬────────┘
                             ↓
                    ┌─────────────────┐
                    │ Application     │
                    │ Layer (Service) │
                    └────────┬────────┘
                             ↓
                    ┌─────────────────┐
                    │ Infrastructure  │
                    │ (Repository)    │
                    └────────┬────────┘
                             ↓
                    ┌─────────────────┐
                    │ Enterprise      │
                    │ (Domain Models) │
                    └─────────────────┘
```

### 3. Dependency Flow
```
HTTP Request Flow:
Handler → Service → Repository → Database

Dependency Resolution:
Database ← Repository ← Service ← Handler
(Constructor Injection)
```

---

## Testing Strategy Diagram

```
┌──────────────────────────────────────────────────────────┐
│                    UNIT TESTS                            │
│              (Service Layer)                             │
│                                                          │
│  ┌──────────────────────────────────────────┐           │
│  │ Mock UserRepository                     │           │
│  │ ↓                                        │           │
│  │ Test CreateUser()                       │           │
│  │ Test GetUser()                          │           │
│  │ Test UpdateUser()                       │           │
│  │ Test DeleteUser()                       │           │
│  │ Test ListUsers()                        │           │
│  │ Test ValidatePassword()                 │           │
│  └──────────────────────────────────────────┘           │
│                                                          │
│  Fast ✓  Isolated ✓  No DB ✓  Deterministic ✓          │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│               INTEGRATION TESTS                          │
│             (Repository Layer)                          │
│                                                          │
│  ┌──────────────────────────────────────────┐           │
│  │ Test Database (PostgreSQL Docker)       │           │
│  │ ↓                                        │           │
│  │ Test Create()                           │           │
│  │ Test GetByID()                          │           │
│  │ Test GetByEmail()                       │           │
│  │ Test Update()                           │           │
│  │ Test Delete()                           │           │
│  │ Test List()                             │           │
│  │ Test Exists()                           │           │
│  └──────────────────────────────────────────┘           │
│                                                          │
│  Slower ✓  Real DB ✓  Schema validation ✓              │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                  HANDLER TESTS                           │
│            (HTTP Endpoint Testing)                       │
│                                                          │
│  ┌──────────────────────────────────────────┐           │
│  │ Mock UserService                        │           │
│  │ ↓                                        │           │
│  │ Test POST /users                        │           │
│  │ Test GET /users/{id}                    │           │
│  │ Test PUT /users/{id}                    │           │
│  │ Test DELETE /users/{id}                 │           │
│  │ Test GET /users?limit=10&offset=0       │           │
│  │ Test error responses                    │           │
│  └──────────────────────────────────────────┘           │
│                                                          │
│  Fast ✓  No DB ✓  HTTP validation ✓                     │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                   E2E TESTS                              │
│          (Full Stack Testing)                            │
│                                                          │
│  ┌──────────────────────────────────────────┐           │
│  │ Real Server + Real Database              │           │
│  │ ↓                                        │           │
│  │ HTTP Client                              │           │
│  │ Make actual requests                     │           │
│  │ Verify responses                         │           │
│  │ Check database state                     │           │
│  └──────────────────────────────────────────┘           │
│                                                          │
│  Slowest ✓  Most realistic ✓  Full validation ✓         │
└──────────────────────────────────────────────────────────┘
```

---

## Performance Considerations

```
┌─────────────────────────────────────────────────────────┐
│          CONNECTION POOLING                            │
│                                                         │
│  db.SetMaxOpenConns(25)    ← Max concurrent conns      │
│  db.SetMaxIdleConns(5)     ← Keep warm in pool         │
│  db.SetConnMaxLifetime(5 * time.Minute)  ← Reset conn │
│                                                         │
│  Prevents:                                              │
│  - Connection exhaustion                               │
│  - Resource leaks                                      │
│  - Database overwhelm                                  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│          DATABASE INDEXING                             │
│                                                         │
│  CREATE INDEX idx_users_email ON users(email);         │
│  CREATE INDEX idx_users_created_at ON users(created_at);
│                                                         │
│  Speeds up:                                             │
│  - GetUserByEmail() queries                            │
│  - ListUsers() ordering                                │
│  - Duplicate email checks                              │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│          PAGINATION                                     │
│                                                         │
│  GET /users?limit=10&offset=0                           │
│  Prevents:                                              │
│  - Loading entire table into memory                    │
│  - Slow HTTP responses                                 │
│  - High database load                                  │
│  - Poor user experience                                │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│          CONTEXT TIMEOUTS                              │
│                                                         │
│  ctx, cancel := context.WithTimeout(                    │
│      context.Background(),                              │
│      5 * time.Second,                                   │
│  )                                                      │
│  defer cancel()                                         │
│                                                         │
│  Prevents:                                              │
│  - Hanging requests                                    │
│  - Resource exhaustion                                 │
│  - Cascade failures                                    │
└─────────────────────────────────────────────────────────┘
```

This visual guide should help you understand the complete architecture and data flow when building user management systems in Go with sqlc!
