# Getting Started Guide

This guide will walk you through setting up and running the Express + TypeScript backend project from scratch.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Database Setup](#database-setup)
4. [Configuration](#configuration)
5. [Running the Application](#running-the-application)
6. [Testing the API](#testing-the-api)
7. [Running Tests](#running-tests)
8. [Docker Setup (Optional)](#docker-setup-optional)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before you begin, ensure you have the following installed on your system:

- **Node.js** (v18 or higher) - [Download here](https://nodejs.org/)
- **npm** (comes with Node.js) or **yarn**
- **PostgreSQL** (v13 or higher) - [Download here](https://www.postgresql.org/download/)
- **Git** (optional, for version control)

### Verify Installation

```bash
# Check Node.js version
node --version
# Should output: v18.x.x or higher

# Check npm version
npm --version
# Should output: 8.x.x or higher

# Check PostgreSQL version
psql --version
# Should output: psql (PostgreSQL) 13.x or higher
```

---

## Installation

### Step 1: Clone or Navigate to the Project

If you cloned the repository:
```bash
git clone <your-repo-url>
cd nodejs-template
```

If you're already in the project directory:
```bash
cd nodejs-template
```

### Step 2: Install Dependencies

```bash
npm install
```

This will install all required packages including:
- Express.js
- TypeScript
- Sequelize
- JWT libraries
- Testing frameworks
- And all other dependencies

**Expected output:** You should see packages being installed, and "added XXX packages" at the end.

---

## Database Setup

### Step 3: Start PostgreSQL Service

**On macOS (using Homebrew):**
```bash
brew services start postgresql@15
```

**On Linux:**
```bash
sudo systemctl start postgresql
```

**On Windows:**
PostgreSQL should start automatically, or start it from Services.

### Step 4: Create the Database

**Option 1: Using createdb command**
```bash
createdb nodejs_template_dev
```

**Option 2: Using psql**
```bash
# Connect to PostgreSQL
psql -U postgres

# Inside psql, create database
CREATE DATABASE nodejs_template_dev;

# Exit psql
\q
```

### Step 5: Verify Database Creation

```bash
psql -U postgres -l
```

You should see `nodejs_template_dev` in the list of databases.

---

## Configuration

### Step 6: Set Up Environment Variables

The project already has a `.env` file created from `.env.example`. Now you need to update it with your configuration.

**Edit the `.env` file:**

```bash
# Open .env in your editor
nano .env
# or
code .env
# or
vim .env
```

**Update the following values:**

```env
# Application
NODE_ENV=development
PORT=3000

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=nodejs_template_dev
DB_USER=postgres
DB_PASSWORD=your_actual_password_here

# JWT Configuration
# IMPORTANT: Change these secrets in production!
JWT_SECRET=my_super_secret_jwt_key_12345
JWT_EXPIRES_IN=24h
JWT_REFRESH_SECRET=my_super_secret_refresh_key_67890
JWT_REFRESH_EXPIRES_IN=7d

# CORS Configuration
CORS_ORIGIN=*
# For production, set specific origin like: http://localhost:3001,https://yourdomain.com

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
```

**Important Notes:**
- Replace `your_actual_password_here` with your PostgreSQL password
- In production, use strong, random secrets for JWT keys
- Never commit the `.env` file to version control

### Step 7: Verify Configuration

Ensure your PostgreSQL credentials are correct:

```bash
psql -U postgres -d nodejs_template_dev -c "SELECT version();"
```

If this command succeeds, your database configuration is correct.

---

## Running the Application

### Step 8: Build the Project

Compile TypeScript to JavaScript:

```bash
npm run build
```

**Expected output:** Files will be compiled to the `dist/` directory.

### Step 9: Start Development Server

For development with hot-reload:

```bash
npm run dev
```

**Expected output:**
```
✅ Database connection established successfully.
✅ Database synchronized.
🚀 Server is running on port 3000
📝 Environment: development
```

If you see these messages, congratulations! Your server is running successfully.

### Step 10: Verify Server is Running

Open another terminal and test the health endpoint:

```bash
curl http://localhost:3000/health
```

**Expected response:**
```json
{
  "status": "ok",
  "timestamp": "2026-02-03T09:53:39.000Z",
  "uptime": 5.123
}
```

---

## Testing the API

### Step 11: Test User Registration

```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john.doe@example.com",
    "password": "SecurePass123",
    "firstName": "John",
    "lastName": "Doe"
  }'
```

**Expected response:**
```json
{
  "status": "success",
  "data": {
    "user": {
      "id": 1,
      "email": "john.doe@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "isActive": true,
      "createdAt": "2026-02-03T09:53:39.000Z",
      "updatedAt": "2026-02-03T09:53:39.000Z"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Copy the `accessToken` from the response** - you'll need it for the next step.

### Step 12: Test User Login

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john.doe@example.com",
    "password": "SecurePass123"
  }'
```

### Step 13: Test Protected Endpoint

Replace `YOUR_ACCESS_TOKEN` with the token from Step 11:

```bash
curl -X GET http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Expected response:**
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "email": "john.doe@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "isActive": true,
    "createdAt": "2026-02-03T09:53:39.000Z",
    "updatedAt": "2026-02-03T09:53:39.000Z"
  }
}
```

### Using Postman or Insomnia (Alternative)

If you prefer a GUI tool:

1. **Import endpoints:**
   - Health: `GET http://localhost:3000/health`
   - Register: `POST http://localhost:3000/api/auth/register`
   - Login: `POST http://localhost:3000/api/auth/login`
   - Profile: `GET http://localhost:3000/api/auth/profile`

2. **Set up authorization:**
   - For protected endpoints, add header: `Authorization: Bearer YOUR_TOKEN`

---

## Running Tests

### Step 14: Create Test Database

```bash
createdb nodejs_template_test
```

Or update `.env` to specify test database:
```env
DB_NAME_TEST=nodejs_template_test
```

### Step 15: Run Test Suite

```bash
npm test
```

**Expected output:**
```
PASS  tests/auth.test.ts
  Auth Endpoints
    POST /api/auth/register
      ✓ should register a new user (150ms)
      ✓ should not register user with existing email (45ms)
      ✓ should validate password strength (35ms)
    POST /api/auth/login
      ✓ should login with valid credentials (80ms)
      ✓ should not login with invalid password (40ms)
      ✓ should not login with non-existent email (35ms)
    GET /api/auth/profile
      ✓ should get user profile with valid token (60ms)
      ✓ should not get profile without token (25ms)
      ✓ should not get profile with invalid token (30ms)

Test Suites: 1 passed, 1 total
Tests:       9 passed, 9 total
```

### Step 16: Check Test Coverage

```bash
npm test -- --coverage
```

This will show you code coverage statistics.

---

## Docker Setup (Optional)

If you prefer to run everything in Docker:

### Step 17: Build and Run with Docker Compose

```bash
# Start all services (app + PostgreSQL)
docker-compose up --build
```

This will:
- Build the Docker image
- Start PostgreSQL container
- Start the application container
- Expose the API on port 3000

### Step 18: Verify Docker Setup

```bash
# Check running containers
docker-compose ps

# Test the API
curl http://localhost:3000/health
```

### Stop Docker Services

```bash
docker-compose down
```

### Remove volumes (fresh start)

```bash
docker-compose down -v
```

---

## Troubleshooting

### Problem: Database Connection Failed

**Error:** `Unable to connect to the database`

**Solutions:**
1. Verify PostgreSQL is running:
   ```bash
   pg_isready
   ```

2. Check credentials in `.env` file

3. Test connection manually:
   ```bash
   psql -U postgres -d nodejs_template_dev
   ```

4. Check PostgreSQL is listening on correct port:
   ```bash
   psql -U postgres -c "SHOW port;"
   ```

### Problem: Port 3000 Already in Use

**Error:** `EADDRINUSE: address already in use :::3000`

**Solutions:**
1. Find and kill the process:
   ```bash
   # macOS/Linux
   lsof -ti:3000 | xargs kill -9
   
   # Windows
   netstat -ano | findstr :3000
   taskkill /PID <PID> /F
   ```

2. Or change the port in `.env`:
   ```env
   PORT=3001
   ```

### Problem: Module Not Found Errors

**Error:** `Cannot find module 'express'`

**Solution:**
```bash
# Delete node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

### Problem: TypeScript Compilation Errors

**Error:** Various TypeScript errors

**Solutions:**
1. Clean build:
   ```bash
   rm -rf dist
   npm run build
   ```

2. Check TypeScript version:
   ```bash
   npx tsc --version
   ```

3. Reinstall dependencies:
   ```bash
   npm install --save-dev typescript
   ```

### Problem: JWT Secret Warning

**Warning:** Using default JWT secrets

**Solution:**
Update `.env` with strong, random secrets:
```bash
# Generate random secrets (macOS/Linux)
openssl rand -base64 32
```

Use the output as your JWT_SECRET and JWT_REFRESH_SECRET.

### Problem: Tests Failing

**Error:** Tests are failing

**Solutions:**
1. Ensure test database exists:
   ```bash
   createdb nodejs_template_test
   ```

2. Clear Jest cache:
   ```bash
   npx jest --clearCache
   ```

3. Run tests in verbose mode:
   ```bash
   npm test -- --verbose
   ```

---

## Next Steps

Now that your backend is running, you can:

1. **Add More Models** - Create additional Sequelize models in `src/models/`
2. **Add More Routes** - Create new controllers and routes for your API
3. **Set Up Migrations** - Use Sequelize CLI for database migrations
4. **Add Swagger Documentation** - Install and configure Swagger for API docs
5. **Deploy to Production** - Deploy to Heroku, AWS, or your preferred platform

---

## Useful Commands Reference

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server with hot reload |
| `npm run build` | Compile TypeScript to JavaScript |
| `npm start` | Start production server |
| `npm test` | Run test suite |
| `npm run test:watch` | Run tests in watch mode |
| `npm run lint` | Check code for linting errors |
| `npm run lint:fix` | Fix linting errors automatically |
| `docker-compose up` | Start with Docker |
| `docker-compose down` | Stop Docker containers |

---

## Getting Help

If you encounter any issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review the main [README.md](./README.md)
3. Check the logs for error messages
4. Open an issue on GitHub (if applicable)

---

**Congratulations! You've successfully set up your Express + TypeScript backend! 🎉**
