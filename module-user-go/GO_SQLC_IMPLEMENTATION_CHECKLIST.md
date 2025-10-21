# Go + sqlc Implementation Checklist

Complete step-by-step checklist for implementing user management with Repository, Service, and Controller patterns using sqlc.

---

## Phase 1: Environment Setup

### Prerequisites
- [ ] Go 1.22+ installed (`go version`)
- [ ] PostgreSQL installed and running
- [ ] sqlc installed (`brew install sqlc` or download from sqlc.dev)
- [ ] Git repository initialized
- [ ] Code editor/IDE with Go support

### Verify Installations
```bash
✓ go version
✓ psql --version
✓ sqlc version
✓ git --version
```

---

## Phase 2: Project Structure

### Create Directory Layout
- [ ] Create `cmd/` directory
- [ ] Create `internal/` directory with subdirectories:
  - [ ] `internal/domain/`
  - [ ] `internal/repository/queries/`
  - [ ] `internal/service/`
  - [ ] `internal/handler/`
- [ ] Create `migrations/` directory
- [ ] Create root configuration files

### Files to Create
- [ ] `cmd/main.go` (entry point)
- [ ] `go.mod` (Go module file)
- [ ] `sqlc.yaml` (sqlc configuration)
- [ ] `migrations/schema.sql` (database schema)
- [ ] `internal/domain/user.go` (domain models)
- [ ] `internal/domain/errors.go` (error definitions)
- [ ] `internal/repository/queries/users.sql` (SQL queries)
- [ ] `internal/repository/user_repository.go` (repository interface)
- [ ] `internal/repository/user_postgres.go` (repository impl)
- [ ] `internal/service/user_service.go` (service layer)
- [ ] `internal/handler/user_handler.go` (HTTP handlers)
- [ ] `.gitignore` (exclude binaries, generated files)

---

## Phase 3: Configuration & Dependencies

### Initialize Go Module
- [ ] Run `go mod init github.com/yourusername/myapp`
- [ ] Verify `go.mod` file created

### Add Dependencies
- [ ] `go get github.com/lib/pq` (PostgreSQL driver)
- [ ] `go get github.com/google/uuid` (UUID generation)
- [ ] `go get golang.org/x/crypto/bcrypt` (password hashing)
- [ ] Run `go mod tidy` to clean up

### Configure sqlc
- [ ] Create `sqlc.yaml` with:
  - [ ] Engine: `postgres`
  - [ ] Queries path: `./internal/repository/queries`
  - [ ] Schema path: `./migrations/schema.sql`
  - [ ] Output path: `./internal/repository/queries`
  - [ ] Go package: `queries`
  - [ ] Options: `emit_json_tags: true`

---

## Phase 4: Database Schema

### Design Schema
- [ ] Define `users` table with:
  - [ ] `id` (PRIMARY KEY, VARCHAR(36))
  - [ ] `name` (VARCHAR(100), NOT NULL)
  - [ ] `email` (VARCHAR(255), NOT NULL, UNIQUE)
  - [ ] `password` (VARCHAR(255), NOT NULL)
  - [ ] `created_at` (TIMESTAMP, DEFAULT NOW())
  - [ ] `updated_at` (TIMESTAMP, DEFAULT NOW())

### Add Indexes
- [ ] Create index on `email` column
- [ ] Create index on `created_at` column

### Save Schema
- [ ] Save complete schema to `migrations/schema.sql`
- [ ] Test schema syntax manually if needed

---

## Phase 5: Define SQL Queries

### Plan Query Operations
- [ ] CreateUser (:exec)
- [ ] GetUserByID (:one)
- [ ] GetUserByEmail (:one)
- [ ] UpdateUser (:exec)
- [ ] DeleteUser (:exec)
- [ ] ListUsers (:many)
- [ ] CountUsers (:one)
- [ ] UserExists (:one)

### Write Queries
- [ ] Add each query to `internal/repository/queries/users.sql`
- [ ] Use proper naming: `-- name: QueryName :modifier`
- [ ] Use parameterized queries ($1, $2, etc.)
- [ ] Select columns explicitly (no SELECT *)
- [ ] Use appropriate modifiers (:one, :many, :exec)
- [ ] Add helpful comments to each query

### Verify Queries
- [ ] Check query syntax
- [ ] Verify parameter counts
- [ ] Test queries manually in psql (optional)
- [ ] Confirm column names are correct

---

## Phase 6: Code Generation

### Generate sqlc Code
- [ ] Run `sqlc generate`
- [ ] Check for errors in output
- [ ] Verify generated files created:
  - [ ] `db.go`
  - [ ] `models.go`
  - [ ] `querier.go`
  - [ ] `users.sql.go`

### Review Generated Code
- [ ] Check `models.go` - struct fields match schema
- [ ] Check `querier.go` - interface has all methods
- [ ] Check `users.sql.go` - implementation looks correct
- [ ] Verify JSON tags are present (if configured)

### Commit Generated Code
- [ ] Add generated files to git
- [ ] Commit with message "Generated sqlc code"

---

## Phase 7: Domain Layer

### Create Domain Models
- [ ] Create `internal/domain/user.go`
- [ ] Define `User` struct with:
  - [ ] ID, Name, Email, Password, CreatedAt, UpdatedAt
  - [ ] JSON tags for API responses
  - [ ] Validation tags (if using validator)

### Create DTOs
- [ ] Define `CreateUserRequest` struct
- [ ] Define `UpdateUserRequest` struct
- [ ] Define `UserResponse` struct
- [ ] Add validation tags to each DTO

### Define Errors
- [ ] Create `internal/domain/errors.go`
- [ ] Define domain-specific errors:
  - [ ] `ErrUserNotFound`
  - [ ] `ErrEmailAlreadyUsed`
  - [ ] `ErrInvalidEmail`
  - [ ] `ErrWeakPassword`
  - [ ] `ErrUnauthorized`
  - [ ] `ErrInternalServer`

---

## Phase 8: Repository Layer

### Create Repository Interface
- [ ] Create `internal/repository/user_repository.go`
- [ ] Define `UserRepository` interface with methods:
  - [ ] `Create(ctx context.Context, user *domain.User) error`
  - [ ] `GetByID(ctx context.Context, id string) (*domain.User, error)`
  - [ ] `GetByEmail(ctx context.Context, email string) (*domain.User, error)`
  - [ ] `Update(ctx context.Context, user *domain.User) error`
  - [ ] `Delete(ctx context.Context, id string) error`
  - [ ] `List(ctx context.Context, offset, limit int32) ([]*domain.User, int64, error)`
  - [ ] `Exists(ctx context.Context, email string) (bool, error)`

### Implement Repository
- [ ] Create `internal/repository/user_postgres.go`
- [ ] Define `PostgresUserRepository` struct with:
  - [ ] `queries *queries.Queries` field
- [ ] Implement constructor: `NewPostgresUserRepository(q *queries.Queries)`
- [ ] Implement each repository method:
  - [ ] Call appropriate sqlc query
  - [ ] Handle `sql.ErrNoRows` errors
  - [ ] Map domain errors (e.g., duplicate email)
  - [ ] Map sqlc types to domain types
  - [ ] Return domain errors, not database errors

### Test Repository Implementation
- [ ] Verify method signatures match interface
- [ ] Check error handling is correct
- [ ] Ensure domain models properly mapped

---

## Phase 9: Service Layer

### Create Service Interface
- [ ] Create `internal/service/user_service.go`
- [ ] Define `UserService` interface with methods:
  - [ ] `CreateUser(ctx, req) (*domain.User, error)`
  - [ ] `GetUser(ctx, id) (*domain.User, error)`
  - [ ] `GetUserByEmail(ctx, email) (*domain.User, error)`
  - [ ] `UpdateUser(ctx, id, req) (*domain.User, error)`
  - [ ] `DeleteUser(ctx, id) error`
  - [ ] `ListUsers(ctx, offset, limit) ([]*domain.User, int64, error)`
  - [ ] `ValidatePassword(hash, plain) error`

### Implement Service
- [ ] Define `userService` struct with `repo repository.UserRepository`
- [ ] Implement constructor: `NewUserService(repo repository.UserRepository)`
- [ ] Implement `CreateUser`:
  - [ ] Validate input
  - [ ] Check email uniqueness via repository
  - [ ] Hash password with bcrypt
  - [ ] Call repository Create
  - [ ] Remove password before returning
- [ ] Implement `GetUser`:
  - [ ] Validate ID not empty
  - [ ] Call repository GetByID
  - [ ] Remove password before returning
- [ ] Implement `GetUserByEmail`:
  - [ ] Validate email not empty
  - [ ] Call repository GetByEmail
  - [ ] Remove password before returning
- [ ] Implement `UpdateUser`:
  - [ ] Get current user
  - [ ] Update fields if provided
  - [ ] Check new email uniqueness if changing
  - [ ] Call repository Update
  - [ ] Remove password before returning
- [ ] Implement `DeleteUser`:
  - [ ] Call repository Delete
- [ ] Implement `ListUsers`:
  - [ ] Validate pagination params
  - [ ] Call repository List
  - [ ] Remove passwords from all users
- [ ] Implement `ValidatePassword`:
  - [ ] Use bcrypt.CompareHashAndPassword
- [ ] Add private helper methods:
  - [ ] `validateUserInput()`
  - [ ] `hashPassword()`
  - [ ] `isValidEmail()`

### Test Service Implementation
- [ ] Verify all methods implemented
- [ ] Check business logic correctness
- [ ] Ensure passwords are never exposed

---

## Phase 10: Handler Layer

### Create HTTP Handlers
- [ ] Create `internal/handler/user_handler.go`
- [ ] Define `UserHandler` struct with `service service.UserService`
- [ ] Implement constructor: `NewUserHandler(service service.UserService)`

### Implement Create Handler
- [ ] Implement `CreateUser(w http.ResponseWriter, r *http.Request)`
- [ ] Parse JSON request body into `CreateUserRequest`
- [ ] Handle JSON decode errors (HTTP 400)
- [ ] Call service layer
- [ ] Handle errors appropriately
- [ ] Return JSON response (HTTP 201 on success)

### Implement Get Handler
- [ ] Implement `GetUser(w http.ResponseWriter, r *http.Request)`
- [ ] Extract user ID from path
- [ ] Validate ID not empty
- [ ] Call service layer
- [ ] Handle not found error (HTTP 404)
- [ ] Return JSON response (HTTP 200)

### Implement List Handler
- [ ] Implement `ListUsers(w http.ResponseWriter, r *http.Request)`
- [ ] Parse pagination params from query string
- [ ] Validate and set defaults for offset/limit
- [ ] Call service layer
- [ ] Return paginated response (HTTP 200)

### Implement Update Handler
- [ ] Implement `UpdateUser(w http.ResponseWriter, r *http.Request)`
- [ ] Extract user ID from path
- [ ] Parse JSON request body into `UpdateUserRequest`
- [ ] Call service layer
- [ ] Handle errors appropriately
- [ ] Return JSON response (HTTP 200)

### Implement Delete Handler
- [ ] Implement `DeleteUser(w http.ResponseWriter, r *http.Request)`
- [ ] Extract user ID from path
- [ ] Call service layer
- [ ] Return no content response (HTTP 204)

### Add Helper Functions
- [ ] `respondJSON(w, code, payload)` - Write JSON response
- [ ] `respondError(w, code, message)` - Write error response
- [ ] `toUserResponse(user)` - Map domain to response DTO
- [ ] `toUserResponses(users)` - Map slice to responses
- [ ] `handleServiceError(w, err)` - Map errors to HTTP codes

### Verify Handler Implementation
- [ ] All CRUD methods implemented
- [ ] Error handling for each endpoint
- [ ] HTTP status codes correct
- [ ] JSON serialization working

---

## Phase 11: Dependency Injection & Main

### Setup Main Function
- [ ] Create `cmd/main.go`
- [ ] Import required packages:
  - [ ] `database/sql`
  - [ ] `github.com/lib/pq`
  - [ ] Internal packages (repository, service, handler)

### Initialize Database
- [ ] Open database connection with `sql.Open()`
- [ ] Use environment variable for connection string
- [ ] Defer `db.Close()`
- [ ] Set connection pool parameters:
  - [ ] `SetMaxOpenConns(25)`
  - [ ] `SetMaxIdleConns(5)`
  - [ ] `SetConnMaxLifetime(5 * time.Minute)`

### Create sqlc Queries
- [ ] Initialize `queries.New(db)`

### Instantiate Layers
- [ ] Create `repository.NewPostgresUserRepository(sqlcQueries)`
- [ ] Create `service.NewUserService(repository)`
- [ ] Create `handler.NewUserHandler(service)`

### Setup HTTP Routes
- [ ] Create `http.NewServeMux()`
- [ ] Register routes:
  - [ ] `POST /users` → `handler.CreateUser`
  - [ ] `GET /users` → `handler.ListUsers`
  - [ ] `GET /users/{id}` → `handler.GetUser`
  - [ ] `PUT /users/{id}` → `handler.UpdateUser`
  - [ ] `DELETE /users/{id}` → `handler.DeleteUser`

### Start Server
- [ ] Create `http.Server` with:
  - [ ] Address: `:8080`
  - [ ] ReadTimeout: 10s
  - [ ] WriteTimeout: 10s
- [ ] Call `server.ListenAndServe()`
- [ ] Handle errors with appropriate logging

---

## Phase 12: Database Setup

### Create Database
- [ ] Connect to PostgreSQL: `psql postgres`
- [ ] Create database: `CREATE DATABASE myapp;`
- [ ] Exit psql: `\q`

### Apply Schema
- [ ] Run: `psql myapp < migrations/schema.sql`
- [ ] Verify tables created: `psql myapp -c "\dt"`
- [ ] Verify indexes created: `psql myapp -c "\di"`

### Set Environment Variable
- [ ] Export `DATABASE_URL`:
  ```
  export DATABASE_URL="postgres://user:password@localhost:5432/myapp?sslmode=disable"
  ```
- [ ] Or create `.env` file with connection string

---

## Phase 13: Build & Run

### Build Application
- [ ] Run: `go build -o myapp cmd/main.go`
- [ ] Verify binary created

### Run Application
- [ ] Ensure database is running
- [ ] Set `DATABASE_URL` environment variable
- [ ] Run: `./myapp` or `go run cmd/main.go`
- [ ] Verify server starts on port 8080
- [ ] Check for any errors in logs

---

## Phase 14: Testing Endpoints

### Test Create User
- [ ] POST request to `http://localhost:8080/users`
- [ ] Body: `{"name":"John Doe","email":"john@example.com","password":"securepass123"}`
- [ ] Verify response: 201 status, user data returned
- [ ] Test invalid inputs (missing fields, weak password)
- [ ] Test duplicate email error

### Test Get User
- [ ] GET request to `http://localhost:8080/users/{id}`
- [ ] Verify response: 200 status, user data
- [ ] Test non-existent user: 404 error

### Test List Users
- [ ] GET request to `http://localhost:8080/users`
- [ ] Verify response: paginated user list
- [ ] Test pagination: `?limit=5&offset=0`

### Test Update User
- [ ] PUT request to `http://localhost:8080/users/{id}`
- [ ] Body: `{"name":"Jane Doe","email":"jane@example.com"}`
- [ ] Verify response: 200 status, updated data
- [ ] Test partial updates
- [ ] Test duplicate email error

### Test Delete User
- [ ] DELETE request to `http://localhost:8080/users/{id}`
- [ ] Verify response: 204 status (no content)
- [ ] Verify user deleted: GET returns 404

---

## Phase 15: Code Quality

### Add Input Validation
- [ ] Optional: Add validator package
- [ ] Add validation tags to DTOs
- [ ] Validate in handler or service
- [ ] Return appropriate error messages

### Add Logging
- [ ] Optional: Add logging package (zap or logrus)
- [ ] Log important operations
- [ ] Log errors with context
- [ ] Log request/response details

### Add Tests
- [ ] Write unit tests for service layer
- [ ] Mock repository in tests
- [ ] Test success and error cases
- [ ] Write handler tests with mocks
- [ ] Test integration with database

### Code Review
- [ ] Check code follows Go conventions
- [ ] Verify error handling throughout
- [ ] Check context usage
- [ ] Verify no hardcoded values
- [ ] Review performance considerations

---

## Phase 16: Production Preparation

### Security
- [ ] Never log passwords
- [ ] Use bcrypt for password hashing
- [ ] Validate all input
- [ ] Use prepared queries (sqlc ensures this)
- [ ] Add rate limiting middleware
- [ ] Add authentication middleware
- [ ] Use HTTPS in production

### Configuration
- [ ] Use environment variables for secrets
- [ ] Configure database connection pooling
- [ ] Set appropriate timeouts
- [ ] Configure logging levels
- [ ] Setup graceful shutdown

### Monitoring & Logging
- [ ] Setup structured logging
- [ ] Add error tracking
- [ ] Monitor database performance
- [ ] Setup alerts for errors
- [ ] Track API metrics

### Deployment
- [ ] Create Dockerfile (optional)
- [ ] Setup CI/CD pipeline (GitHub Actions, etc.)
- [ ] Create database migration strategy
- [ ] Document API endpoints
- [ ] Setup monitoring/logging tools

---

## Phase 17: Documentation

### Code Documentation
- [ ] Add comments to exported functions
- [ ] Document interface contracts
- [ ] Add README.md with:
  - [ ] Project description
  - [ ] Setup instructions
  - [ ] API documentation
  - [ ] Development guidelines

### API Documentation
- [ ] Document all endpoints
- [ ] Include example requests/responses
- [ ] Explain error codes
- [ ] Document query parameters
- [ ] Create OpenAPI/Swagger spec (optional)

---

## Final Verification Checklist

- [ ] All dependencies added and go.mod clean
- [ ] sqlc code generated and committed
- [ ] Database created and schema applied
- [ ] Application builds without errors
- [ ] Application runs without errors
- [ ] All HTTP endpoints respond correctly
- [ ] Error handling working as expected
- [ ] Passwords hashed and never exposed
- [ ] Unit tests passing
- [ ] No hardcoded secrets or credentials
- [ ] Code follows Go best practices
- [ ] Documentation complete
- [ ] Ready for production deployment

---

## Troubleshooting

### sqlc generate fails
- [ ] Check schema.sql syntax
- [ ] Verify columns are named
- [ ] Check query parameter counts
- [ ] Ensure :one, :many, or :exec modifier present

### Database connection fails
- [ ] Verify PostgreSQL running
- [ ] Check DATABASE_URL is set correctly
- [ ] Check username/password correct
- [ ] Verify database exists

### Handler tests fail
- [ ] Verify mock implementations
- [ ] Check JSON marshaling
- [ ] Verify error responses

### Port already in use
- [ ] Change port in main.go
- [ ] Or kill existing process on port 8080

### Foreign key constraint errors
- [ ] Check referential integrity in schema
- [ ] Verify insert order (parent before child)

---

**Status: [ ] Complete - Ready for Production**

Last Updated: October 21, 2025
