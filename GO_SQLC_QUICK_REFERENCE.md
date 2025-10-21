# Go + sqlc Quick Reference Guide

A quick reference for common patterns when building user management with sqlc.

## sqlc Query Modifiers

| Modifier | Purpose | Returns |
|----------|---------|---------|
| `:one` | Fetch single row | Error if no/multiple rows |
| `:many` | Fetch multiple rows | Array of results |
| `:exec` | Execute without return | Error only |
| `:execrows` | Execute with row count | RowsAffected value |

## Common Query Patterns

### Create (INSERT)

```sql
-- name: CreateUser :exec
INSERT INTO users (id, name, email, password, created_at, updated_at)
VALUES ($1, $2, $3, $4, NOW(), NOW());
```

**Usage:**
```go
err := repo.queries.CreateUser(ctx, queries.CreateUserParams{
    ID:       uuid.New().String(),
    Name:     "John",
    Email:    "john@example.com",
    Password: hashedPassword,
})
```

### Read (SELECT :one)

```sql
-- name: GetUserByID :one
SELECT id, name, email, password, created_at, updated_at 
FROM users WHERE id = $1;
```

**Usage:**
```go
user, err := repo.queries.GetUserByID(ctx, id)
if err == sql.ErrNoRows {
    // Not found
    return nil, domain.ErrUserNotFound
}
```

### Read (SELECT :many)

```sql
-- name: ListUsers :many
SELECT id, name, email, password, created_at, updated_at 
FROM users
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;
```

**Usage:**
```go
users, err := repo.queries.ListUsers(ctx, queries.ListUsersParams{
    Limit:  limit,
    Offset: offset,
})
// users is []*User
```

### Update (UPDATE)

```sql
-- name: UpdateUser :exec
UPDATE users 
SET name = $1, email = $2, password = $3, updated_at = NOW()
WHERE id = $4;
```

**Usage:**
```go
err := repo.queries.UpdateUser(ctx, queries.UpdateUserParams{
    Name:     "Jane",
    Email:    "jane@example.com",
    Password: newHashedPassword,
    ID:       userId,
})
```

### Delete (DELETE)

```sql
-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;
```

**Usage:**
```go
err := repo.queries.DeleteUser(ctx, id)
```

### Check Existence

```sql
-- name: UserExists :one
SELECT EXISTS(SELECT 1 FROM users WHERE email = $1);
```

**Usage:**
```go
exists, err := repo.queries.UserExists(ctx, email)
if exists {
    return domain.ErrEmailAlreadyUsed
}
```

### Count

```sql
-- name: CountUsers :one
SELECT COUNT(*) FROM users;
```

**Usage:**
```go
total, err := repo.queries.CountUsers(ctx)
```

## sqlc Parameter Types

Parameter names and types are inferred from SQL:

```sql
-- name: SearchUsers :many
-- SQL uses $1, $2, etc. for parameters
WHERE name LIKE $1 AND created_at > $2 AND status = $3
```

```go
// Generated Params struct automatically names parameters
type SearchUsersParams struct {
    Name      string    // $1
    CreatedAt time.Time // $2
    Status    string    // $3
}
```

## Error Handling

```go
// Check for "not found"
if err == sql.ErrNoRows {
    return domain.ErrUserNotFound
}

// Check for unique constraint violation (PostgreSQL)
if err != nil {
    var pgErr *pq.Error
    if errors.As(err, &pgErr) {
        if pgErr.Code == "23505" { // Unique violation
            return domain.ErrEmailAlreadyUsed
        }
    }
}
```

## Repository Pattern with sqlc

```go
type UserRepository interface {
    Create(ctx context.Context, user *domain.User) error
    GetByID(ctx context.Context, id string) (*domain.User, error)
    List(ctx context.Context, offset, limit int32) ([]*domain.User, int64, error)
}

type PostgresUserRepository struct {
    queries *queries.Queries
}

// Implementation
func (r *PostgresUserRepository) Create(ctx context.Context, user *domain.User) error {
    return r.queries.CreateUser(ctx, queries.CreateUserParams{
        ID:       user.ID,
        Name:     user.Name,
        Email:    user.Email,
        Password: user.Password,
    })
}
```

## Dependency Injection Setup

```go
// Initialize database
db, err := sql.Open("postgres", dsn)
defer db.Close()

// Create sqlc queries
q := queries.New(db)

// Inject into repository
repo := repository.NewPostgresUserRepository(q)

// Inject into service
svc := service.NewUserService(repo)

// Inject into handler
handler := handler.NewUserHandler(svc)
```

## Transaction Support

```go
// Using database/sql transactions
tx, err := db.BeginTx(ctx, nil)
if err != nil {
    return err
}
defer tx.Rollback()

// Create queries for transaction
qtx := queries.WithTx(tx)

// Execute queries
err = qtx.CreateUser(ctx, params)
if err != nil {
    return err
}

if err = tx.Commit(); err != nil {
    return err
}
```

## sqlc Configuration Options

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
        
        # Emit JSON tags on generated types
        emit_json_tags: true
        
        # Emit pointer types for nullable columns
        emit_pointer_types: true
        
        # Emit database/sql types
        emit_db_tags: true
        
        # Custom SQL package (pgx or database/sql)
        sql_package: "pgx/v5"
```

## Context Usage

Always pass context to queries:

```go
// Good - using context with timeout
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

user, err := repo.queries.GetUserByID(ctx, id)

// Good - using request context
user, err := repo.queries.GetUserByID(r.Context(), id)

// Bad - using background context for long operations
user, err := repo.queries.GetUserByID(context.Background(), id)
```

## Testing with sqlc

### Mock approach:

```go
type mockQueries struct {
    *queries.Queries
    getUserByIDFunc func(ctx context.Context, id string) (*queries.User, error)
}

func (m *mockQueries) GetUserByID(ctx context.Context, id string) (*queries.User, error) {
    return m.getUserByIDFunc(ctx, id)
}

// Test
mock := &mockQueries{
    getUserByIDFunc: func(ctx context.Context, id string) (*queries.User, error) {
        return &queries.User{ID: id, Name: "Test"}, nil
    },
}
```

### Test database approach:

```go
// Use testcontainers or local test DB
db, err := sql.Open("postgres", testDBURL)
q := queries.New(db)

// Run tests against real database
err := q.CreateUser(ctx, params)
```

## Common Workflow

1. **Define schema** in `migrations/schema.sql`
2. **Write SQL queries** in `internal/repository/queries/*.sql`
3. **Generate code**: `sqlc generate`
4. **Implement repository** using generated code
5. **Create service** layer with business logic
6. **Build handler** layer for HTTP endpoints
7. **Test** with mocks or test database

## Regenerating Code

After modifying SQL queries:

```bash
sqlc generate
```

The generated code is deterministic - running it multiple times produces identical output. This is safe to commit to version control.

## Common Issues & Solutions

### Issue: "query doesn't have the right suffix"

**Problem:** Query name doesn't have `:one`, `:many`, or `:exec`

**Solution:**
```sql
-- ❌ Wrong
-- name: GetUser
SELECT * FROM users WHERE id = $1;

-- ✅ Correct
-- name: GetUser :one
SELECT * FROM users WHERE id = $1;
```

### Issue: "column must have a name"

**Problem:** Using `SELECT *` or unnamed columns

**Solution:**
```sql
-- ❌ Wrong
-- name: ListUsers :many
SELECT * FROM users;

-- ✅ Correct
-- name: ListUsers :many
SELECT id, name, email, password, created_at, updated_at FROM users;
```

### Issue: "Parameter not found in query"

**Problem:** SQL parameter count doesn't match

**Solution:**
```sql
-- ❌ Wrong - 2 parameters but 3 used
-- name: UpdateUser :exec
UPDATE users SET name = $1, email = $2, password = $3 WHERE id = $4;

-- ✅ Correct - Update sqlc.yaml schema and regenerate
```

### Issue: NULL values not handled

**Problem:** Generated type doesn't handle nullable columns

**Solution:** Enable pointer types in sqlc.yaml:
```yaml
emit_pointer_types: true
```

## Best Practices

✅ **Always use context** for query operations
✅ **Name queries explicitly** - don't use SELECT *
✅ **Use transaction wrapper** for multi-query operations
✅ **Map sqlc types to domain models** in repository layer
✅ **Never expose sqlc types** outside repository layer
✅ **Handle sql.ErrNoRows** for :one queries
✅ **Create indexes** on frequently queried columns
✅ **Keep SQL queries** separate from Go code
✅ **Commit generated code** to version control
✅ **Regenerate after schema changes** before deployment
