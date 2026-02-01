GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build flags
LDFLAGS := -ldflags "-w -s -X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"

# Binary name
BINARY_NAME := cloud-manager

.PHONY: all build run clean test lint fmt deps migrate-up migrate-down docker-build docker-up docker-down help

# Default target
all: build

# Build the application
build:
	@echo "Building $(BINARY_NAME)..."
	@go build $(LDFLAGS) -o bin/$(BINARY_NAME) ./cmd/server

# Build for multiple platforms
build-all:
	@echo "Building for multiple platforms..."
	@GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o bin/$(BINARY_NAME)-linux-amd64 ./cmd/server
	@GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o bin/$(BINARY_NAME)-linux-arm64 ./cmd/server
	@GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o bin/$(BINARY_NAME)-darwin-amd64 ./cmd/server
	@GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o bin/$(BINARY_NAME)-darwin-arm64 ./cmd/server
	@GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o bin/$(BINARY_NAME)-windows-amd64.exe ./cmd/server

# Run the application
run: build
	@echo "Running $(BINARY_NAME)..."
	@./bin/$(BINARY_NAME)

# Run with hot reload (requires air)
dev:
	@echo "Starting development server with hot reload..."
	@air -c .air.toml

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@rm -rf bin/
	@rm -rf tmp/
	@go clean

# Run tests
test:
	@echo "Running tests..."
	@go test -v -race -coverprofile=coverage.out ./...

# Run tests with coverage report
test-coverage: test
	@go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Run linter
lint:
	@echo "Running linter..."
	@golangci-lint run ./...

# Format code
fmt:
	@echo "Formatting code..."
	@go fmt ./...
	@goimports -w .

# Download dependencies
deps:
	@echo "Downloading dependencies..."
	@go mod download
	@go mod tidy

# Generate swagger docs
swagger:
	@echo "Generating Swagger documentation..."
	@swag init -g cmd/server/main.go -o docs

# Run database migrations up
migrate-up:
	@echo "Running migrations..."
	@go run ./cmd/migrate up

# Run database migrations down
migrate-down:
	@echo "Rolling back migrations..."
	@go run ./cmd/migrate down

# Reset database
migrate-reset:
	@echo "Resetting database..."
	@go run ./cmd/migrate reset

# Docker build
docker-build:
	@echo "Building Docker image..."
	@docker build -t $(BINARY_NAME):$(VERSION) -t $(BINARY_NAME):latest .

# Docker compose up
docker-up:
	@echo "Starting Docker containers..."
	@docker-compose up -d

# Docker compose down
docker-down:
	@echo "Stopping Docker containers..."
	@docker-compose down

# Docker compose up for development
docker-dev:
	@echo "Starting development Docker containers..."
	@docker-compose -f docker-compose.dev.yml up -d

# Docker compose down for development
docker-dev-down:
	@echo "Stopping development Docker containers..."
	@docker-compose -f docker-compose.dev.yml down

# View Docker logs
docker-logs:
	@docker-compose logs -f app

# Install development tools
install-tools:
	@echo "Installing development tools..."
	@go install github.com/air-verse/air@latest
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@go install github.com/swaggo/swag/cmd/swag@latest
	@go install golang.org/x/tools/cmd/goimports@latest
	@go install github.com/go-delve/delve/cmd/dlv@latest

# Help
help:
	@echo "Cloud Manager Backend - Available targets:"
	@echo ""
	@echo "  build          - Build the application"
	@echo "  build-all      - Build for multiple platforms"
	@echo "  run            - Build and run the application"
	@echo "  dev            - Run with hot reload (requires air)"
	@echo "  clean          - Clean build artifacts"
	@echo "  test           - Run tests"
	@echo "  test-coverage  - Run tests with coverage report"
	@echo "  lint           - Run linter"
	@echo "  fmt            - Format code"
	@echo "  deps           - Download dependencies"
	@echo "  swagger        - Generate Swagger documentation"
	@echo "  migrate-up     - Run database migrations"
	@echo "  migrate-down   - Rollback database migrations"
	@echo "  migrate-reset  - Reset database"
	@echo "  docker-build   - Build Docker image"
	@echo "  docker-up      - Start Docker containers"
	@echo "  docker-down    - Stop Docker containers"
	@echo "  docker-dev     - Start development Docker containers"
	@echo "  docker-dev-down- Stop development Docker containers"
	@echo "  docker-logs    - View Docker logs"
	@echo "  install-tools  - Install development tools"
	@echo "  help           - Show this help message"
