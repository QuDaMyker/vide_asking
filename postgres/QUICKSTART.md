# Photos & Reactions API - Quick Start

## 🚀 Setup Instructions

### 1. Install Dependencies

```bash
# Install Go dependencies
go mod download

# Install SQLC
brew install sqlc  # macOS
# OR
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
```

### 2. Setup Database

```bash
# Create database
createdb your_database_name

# Run migrations
psql -U postgres -d your_database_name -f schema.sql
```

### 3. Generate SQLC Code

```bash
sqlc generate
```

This will create the `generated/` directory with type-safe database code.

### 4. Configure Environment

Create a `.env` file:

```env
DATABASE_URL=postgres://user:password@localhost:5432/your_database_name?sslmode=disable
PORT=8080
```

### 5. Run the Application

```bash
go run main.go
```

## 📡 API Endpoints

### Get Photo with Reactions

```bash
GET /api/v1/photos/{id}

curl http://localhost:8080/api/v1/photos/123e4567-e89b-12d3-a456-426614174000
```

**Response:**
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "sender_id": "987fcdeb-51a2-43d7-8f6e-123456789abc",
  "photo_url": "https://example.com/photo.jpg",
  "reactions": [
    {
      "id": "111e4567-e89b-12d3-a456-426614174111",
      "user_id": "222fcdeb-51a2-43d7-8f6e-123456789222",
      "emoji": "👍",
      "created_at": "2025-11-15T10:30:00Z"
    }
  ]
}
```

### Get User's Photos

```bash
GET /api/v1/users/{user_id}/photos?limit=20&offset=0

curl "http://localhost:8080/api/v1/users/987fcdeb-51a2-43d7-8f6e-123456789abc/photos?limit=10&offset=0"
```

### Add Reaction

```bash
POST /api/v1/photos/{id}/reactions

curl -X POST http://localhost:8080/api/v1/photos/{photo_id}/reactions \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "222fcdeb-51a2-43d7-8f6e-123456789222",
    "emoji": "❤️"
  }'
```

### Remove Reaction

```bash
DELETE /api/v1/photos/{id}/reactions?user_id={user_id}

curl -X DELETE "http://localhost:8080/api/v1/photos/{photo_id}/reactions?user_id={user_id}"
```

## 🧪 Testing

```bash
# Run tests
go test ./...

# Run with coverage
go test -cover ./...

# Run with race detection
go test -race ./...
```

## 📊 Database Queries

The project includes two main approaches:

1. **Two-Query Approach** - Easier to understand, good for simple cases
2. **Single-Query Approach** - Better performance, recommended for production

Both are implemented in `photo_service.go`. Choose based on your needs.

## 🔧 Troubleshooting

### SQLC Generation Fails

```bash
# Make sure sqlc.yaml is correct
cat sqlc.yaml

# Check SQL syntax
psql -U postgres -d your_database -f query.sql
```

### Database Connection Issues

```bash
# Test connection
psql -U postgres -d your_database -c "SELECT 1"

# Check DATABASE_URL format
echo $DATABASE_URL
```

### Import Path Issues

Update import paths in all Go files:
```go
// Replace this
"github.com/yourusername/yourproject/db"

// With your actual module path
"your-module-name/db"
```

## 📚 Next Steps

1. Read the full [README.md](README.md) for best practices
2. Implement authentication and authorization
3. Add caching layer with Redis
4. Setup monitoring with Prometheus
5. Add API documentation with Swagger

## 🤝 Contributing

See [README.md](README.md) for detailed architecture and best practices.
