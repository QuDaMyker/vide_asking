# Node.js CRUD API

Modern Node.js CRUD API built with TypeScript, featuring dependency injection, JWT authentication, PostgreSQL database, and comprehensive middleware.

## Features

- ✅ **Node.js 22+** - Latest Node.js features
- ✅ **TypeScript** - Type-safe development
- ✅ **Dependency Injection** - Using TSyringe
- ✅ **PostgreSQL** - Database with Drizzle ORM
- ✅ **JWT Authentication** - Secure token-based auth
- ✅ **Logging** - Winston logger with multiple transports
- ✅ **Middleware** - Error handling, validation, rate limiting
- ✅ **Environment Config** - Separate dev/production configs
- ✅ **Docker** - Multi-stage builds and docker-compose
- ✅ **Database Migration** - Drizzle Kit migration system
- ✅ **Security** - Helmet, CORS, rate limiting
- ✅ **Validation** - Zod schema validation

## Project Structure

```
nodejs-template/
├── src/
│   ├── config/              # Configuration files
│   │   └── index.ts
│   ├── controllers/         # Request handlers
│   │   ├── auth.controller.ts
│   │   └── user.controller.ts
│   ├── db/                  # Database setup
│   │   ├── schema.ts
│   │   └── migrate.ts
│   ├── di/                  # Dependency injection
│   │   └── container.ts
│   ├── middlewares/         # Express middlewares
│   │   ├── auth.middleware.ts
│   │   ├── error.middleware.ts
│   │   ├── logger.middleware.ts
│   │   └── validation.middleware.ts
│   ├── repositories/        # Data access layer
│   │   └── user.repository.ts
│   ├── routes/              # API routes
│   │   ├── auth.routes.ts
│   │   ├── user.routes.ts
│   │   └── index.ts
│   ├── services/            # Business logic
│   │   ├── auth.service.ts
│   │   ├── database.service.ts
│   │   └── user.service.ts
│   ├── utils/               # Utilities
│   │   └── logger.ts
│   ├── validators/          # Zod schemas
│   │   └── user.validator.ts
│   ├── app.ts               # Express app setup
│   └── index.ts             # Entry point
├── drizzle/                 # Database migrations
├── logs/                    # Application logs
├── .env.development         # Development environment
├── .env.production          # Production environment
├── docker-compose.yml       # Production compose
├── docker-compose.dev.yml   # Development compose
├── Dockerfile               # Multi-stage build
├── drizzle.config.ts        # Drizzle configuration
├── tsconfig.json            # TypeScript config
└── package.json             # Dependencies
```

## Prerequisites

- Node.js 22+ 
- PostgreSQL 16+
- Docker & Docker Compose (optional)

## Installation

### 1. Clone and Install Dependencies

```bash
cd nodejs-template
npm install
```

### 2. Environment Setup

Copy the appropriate environment file:

```bash
# For development
cp .env.development .env

# For production
cp .env.production .env
```

Update the environment variables as needed.

### 3. Database Setup

#### Option A: Using Docker (Recommended)

```bash
# Start PostgreSQL container
docker-compose -f docker-compose.dev.yml up -d
```

#### Option B: Local PostgreSQL

Ensure PostgreSQL is running and create the database:

```sql
CREATE DATABASE nodejs_crud_dev;
```

### 4. Run Migrations

```bash
# Generate migration files
npm run migration:generate

# Run migrations
npm run migration:migrate
```

## Running the Application

### Development Mode

```bash
npm run dev
```

The API will be available at `http://localhost:3000/api/v1`

### Production Mode

```bash
# Build the project
npm run build

# Start the server
npm start
```

### Using Docker Compose

#### Development

```bash
docker-compose -f docker-compose.dev.yml up
```

#### Production

```bash
docker-compose up --build
```

## API Endpoints

### Authentication

- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login user
- `POST /api/v1/auth/refresh` - Refresh access token

### Users (Protected Routes)

- `GET /api/v1/users` - Get all users
- `GET /api/v1/users/:id` - Get user by ID
- `PUT /api/v1/users/:id` - Update user
- `DELETE /api/v1/users/:id` - Delete user

### Health Check

- `GET /api/v1/health` - API health status

## API Examples

### Register User

```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123",
    "firstName": "John",
    "lastName": "Doe"
  }'
```

### Login

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

### Get All Users (Protected)

```bash
curl -X GET http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Update User (Protected)

```bash
curl -X PUT http://localhost:3000/api/v1/users/1 \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Jane",
    "lastName": "Smith"
  }'
```

## Database Migrations

```bash
# Generate migration from schema changes
npm run migration:generate

# Apply migrations
npm run migration:migrate

# Drop all tables
npm run migration:drop

# Open Drizzle Studio (database GUI)
npm run migration:studio
```

## Scripts

- `npm run dev` - Start development server with hot reload
- `npm run build` - Build for production
- `npm start` - Start production server
- `npm run lint` - Run ESLint
- `npm run lint:fix` - Fix ESLint errors
- `npm run format` - Format code with Prettier
- `npm run migration:generate` - Generate migrations
- `npm run migration:migrate` - Run migrations
- `npm run migration:studio` - Open Drizzle Studio

## Environment Variables

### Development (.env.development)

```env
NODE_ENV=development
PORT=3000
API_PREFIX=/api/v1

DB_HOST=localhost
DB_PORT=5432
DB_NAME=nodejs_crud_dev
DB_USER=postgres
DB_PASSWORD=postgres

JWT_SECRET=your-super-secret-jwt-key-change-in-production
JWT_EXPIRES_IN=7d
JWT_REFRESH_SECRET=your-refresh-secret-key-change-in-production
JWT_REFRESH_EXPIRES_IN=30d

LOG_LEVEL=debug
CORS_ORIGIN=http://localhost:3000

RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
```

### Production (.env.production)

Update all secrets and credentials for production use.

## Architecture

### Dependency Injection

Uses TSyringe for IoC container, enabling:
- Loose coupling between components
- Easy testing with mock dependencies
- Better code organization

### Middleware Stack

1. **Helmet** - Security headers
2. **CORS** - Cross-origin resource sharing
3. **Rate Limiting** - DDoS protection
4. **Body Parser** - JSON/URL encoded
5. **Request Logger** - HTTP request logging
6. **Authentication** - JWT verification
7. **Validation** - Zod schema validation
8. **Error Handler** - Centralized error handling

### Database Layer

- **Drizzle ORM** - Type-safe SQL queries
- **Repository Pattern** - Data access abstraction
- **Migration System** - Version-controlled schema changes

## Security Features

- JWT token authentication
- Password hashing with bcrypt
- Rate limiting
- CORS configuration
- Helmet security headers
- Input validation with Zod
- SQL injection protection (ORM)
- Environment-based configuration

## Logging

Winston logger with multiple transports:
- Console output (colorized)
- Error log file (`logs/error.log`)
- Combined log file (`logs/all.log`)

Log levels: error, warn, info, http, debug

## Docker

### Multi-stage Build

Optimized Docker image with:
- Node.js 22 Alpine base
- Dependency caching
- Non-root user
- Production-only dependencies

### Docker Compose Services

- **postgres** - PostgreSQL 16 database
- **app** - Node.js application

## Testing

The project is set up with Jest for testing. Add your tests in `__tests__` directories.

```bash
npm test
```

## Production Deployment

1. Update `.env.production` with production values
2. Build and deploy using Docker:

```bash
docker-compose up -d --build
```

3. Run migrations:

```bash
docker-compose exec app npm run migration:migrate
```

## Best Practices

- ✅ TypeScript for type safety
- ✅ Dependency injection for testability
- ✅ Repository pattern for data access
- ✅ Service layer for business logic
- ✅ Middleware for cross-cutting concerns
- ✅ Environment-based configuration
- ✅ Centralized error handling
- ✅ Request validation
- ✅ Structured logging
- ✅ Database migrations

## License

MIT

## Contributing

Feel free to submit issues and pull requests.
