# Quick Start Guide

Get your Express + TypeScript backend running in 5 minutes.

## Prerequisites

- Node.js v18+
- PostgreSQL v13+
- npm

## Installation Steps

### 1. Install Dependencies
```bash
npm install
```

### 2. Create Database
```bash
createdb nodejs_template_dev
```

### 3. Configure Environment
```bash
# .env file is already created
# Edit it with your PostgreSQL password
nano .env
```

Update this line:
```env
DB_PASSWORD=your_actual_password_here
```

### 4. Start Server
```bash
npm run dev
```

### 5. Test API
```bash
# Health check
curl http://localhost:3000/health

# Register user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test1234",
    "firstName": "John",
    "lastName": "Doe"
  }'
```

## Alternative: Docker Setup

```bash
# Start everything with Docker
docker-compose up

# Test
curl http://localhost:3000/health
```

## Available Scripts

```bash
npm run dev      # Development with hot reload
npm run build    # Compile TypeScript
npm start        # Production server
npm test         # Run tests
```

## API Endpoints

- `GET /health` - Health check
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login
- `GET /api/auth/profile` - Get profile (protected)
- `POST /api/auth/refresh-token` - Refresh access token

## Need More Help?

See [GETTING_STARTED.md](./GETTING_STARTED.md) for detailed instructions.

## Troubleshooting

**Database connection failed?**
```bash
# Check PostgreSQL is running
pg_isready

# Test connection
psql -U postgres -d nodejs_template_dev
```

**Port already in use?**
```bash
# Kill process on port 3000
lsof -ti:3000 | xargs kill -9

# Or change port in .env
PORT=3001
```

---

✅ **You're all set!** Start building your API! 🚀
