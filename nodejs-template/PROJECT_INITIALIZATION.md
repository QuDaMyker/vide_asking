# Project Initialization Guide

This guide will walk you through the process of creating a new Node.js + TypeScript + Express + PostgreSQL project from scratch, similar to this template.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Project Setup](#step-1-project-setup)
3. [Step 2: TypeScript Configuration](#step-2-typescript-configuration)
4. [Step 3: Install Dependencies](#step-3-install-dependencies)
5. [Step 4: Project Structure](#step-4-project-structure)
6. [Step 5: Environment Configuration](#step-5-environment-configuration)
7. [Step 6: Database Setup](#step-6-database-setup)
8. [Step 7: Core Files](#step-7-core-files)
9. [Step 8: Development Tools](#step-8-development-tools)
10. [Step 9: Docker Setup (Optional)](#step-9-docker-setup-optional)
11. [Step 10: Testing Setup](#step-10-testing-setup)
12. [Step 11: Documentation](#step-11-documentation)

---

## Prerequisites

Before starting, ensure you have the following installed:

- **Node.js** (v18 or higher) - [Download](https://nodejs.org/)
- **npm** or **yarn** - Comes with Node.js
- **PostgreSQL** (v13 or higher) - [Download](https://www.postgresql.org/download/)
- **Git** - [Download](https://git-scm.com/)
- **Code Editor** (VS Code recommended) - [Download](https://code.visualstudio.com/)

---

## Step 1: Project Setup

### 1.1 Create Project Directory

```bash
mkdir my-nodejs-api
cd my-nodejs-api
```

### 1.2 Initialize Node.js Project

```bash
npm init -y
```

This creates a basic `package.json` file.

### 1.3 Initialize Git Repository

```bash
git init
```

### 1.4 Create `.gitignore`

```bash
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables
.env
.env.local
.env.*.local

# Build output
dist/
build/
*.tsbuildinfo

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Testing
coverage/
.nyc_output/

# Logs
logs/
*.log
EOF
```

---

## Step 2: TypeScript Configuration

### 2.1 Install TypeScript

```bash
npm install --save-dev typescript ts-node @types/node
```

### 2.2 Create `tsconfig.json`

```bash
npx tsc --init
```

Or create manually:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "moduleResolution": "node",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

---

## Step 3: Install Dependencies

### 3.1 Production Dependencies

```bash
npm install express cors dotenv helmet morgan compression
npm install bcryptjs jsonwebtoken express-validator express-rate-limit
npm install pg pg-hstore sequelize
```

### 3.2 Development Dependencies

```bash
npm install --save-dev @types/express @types/cors @types/morgan
npm install --save-dev @types/bcryptjs @types/jsonwebtoken @types/compression
npm install --save-dev @types/validator
npm install --save-dev nodemon
npm install --save-dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
npm install --save-dev prettier eslint-config-prettier eslint-plugin-prettier
npm install --save-dev jest @types/jest ts-jest supertest @types/supertest
npm install --save-dev sequelize-cli
```

### 3.3 Update `package.json` Scripts

Add these scripts to your `package.json`:

```json
{
  "scripts": {
    "dev": "nodemon",
    "build": "tsc",
    "start": "node dist/server.js",
    "test": "jest --coverage",
    "test:watch": "jest --watch",
    "lint": "eslint . --ext .ts",
    "lint:fix": "eslint . --ext .ts --fix"
  }
}
```

---

## Step 4: Project Structure

### 4.1 Create Directory Structure

```bash
mkdir -p src/{config,controllers,middleware,models,routes,services,utils,validators,types}
mkdir -p tests
mkdir -p migrations
```

Your structure should look like:

```
my-nodejs-api/
├── src/
│   ├── config/          # Configuration files
│   ├── controllers/     # Route controllers (business logic handlers)
│   ├── middleware/      # Custom middleware (auth, error handling, etc.)
│   ├── models/          # Database models (Sequelize)
│   ├── routes/          # API route definitions
│   ├── services/        # Business logic layer
│   ├── utils/           # Helper functions and utilities
│   ├── validators/      # Request validation schemas
│   ├── types/           # TypeScript type definitions
│   ├── app.ts           # Express app configuration
│   └── server.ts        # Server entry point
├── tests/               # Test files
├── migrations/          # Database migrations
└── dist/                # Compiled output (generated)
```

---

## Step 5: Environment Configuration

### 5.1 Create `.env.example`

```bash
cat > .env.example << 'EOF'
# Environment Configuration
NODE_ENV=development
PORT=3000

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=my_app_dev
DB_USER=postgres
DB_PASSWORD=your_password_here

# JWT Configuration
JWT_SECRET=your_super_secret_jwt_key_change_this_in_production
JWT_EXPIRES_IN=24h
JWT_REFRESH_SECRET=your_super_secret_refresh_key_change_this_in_production
JWT_REFRESH_EXPIRES_IN=7d

# CORS Configuration
CORS_ORIGIN=*

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
EOF
```

### 5.2 Create `.env`

```bash
cp .env.example .env
```

Update `.env` with your actual configuration values.

---

## Step 6: Database Setup

### 6.1 Create `.sequelizerc`

```javascript
const path = require('path');

module.exports = {
  'config': path.resolve('src', 'config', 'config.js'),
  'models-path': path.resolve('src', 'models'),
  'seeders-path': path.resolve('seeders'),
  'migrations-path': path.resolve('migrations')
};
```

### 6.2 Create Database Configuration

Create `src/config/database.ts`:

```typescript
import { Sequelize } from 'sequelize';
import dotenv from 'dotenv';

dotenv.config();

const sequelize = new Sequelize({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'my_app_dev',
  username: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || '',
  dialect: 'postgres',
  logging: process.env.NODE_ENV === 'development' ? console.log : false,
  pool: {
    max: 5,
    min: 0,
    acquire: 30000,
    idle: 10000
  }
});

export default sequelize;
```

Create `src/config/config.js` (for Sequelize CLI):

```javascript
require('dotenv').config();

module.exports = {
  development: {
    username: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'my_app_dev',
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    dialect: 'postgres'
  },
  test: {
    username: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME_TEST || 'my_app_test',
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    dialect: 'postgres'
  },
  production: {
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 5432,
    dialect: 'postgres'
  }
};
```

### 6.3 Create PostgreSQL Database

```bash
# Using createdb command
createdb my_app_dev

# Or using psql
psql -U postgres
CREATE DATABASE my_app_dev;
\q
```

---

## Step 7: Core Files

### 7.1 Create `src/app.ts`

```typescript
import express, { Application } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import dotenv from 'dotenv';
import routes from './routes';
import { errorHandler } from './middleware/errorHandler';
import { notFoundHandler } from './middleware/notFoundHandler';

dotenv.config();

const app: Application = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));

// Body parsing middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Compression middleware
app.use(compression());

// Logging middleware
if (process.env.NODE_ENV === 'development') {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined'));
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api', routes);

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

export default app;
```

### 7.2 Create `src/server.ts`

```typescript
import app from './app';
import sequelize from './config/database';

const PORT = process.env.PORT || 3000;

async function startServer() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connection established successfully.');

    app.listen(PORT, () => {
      console.log(`🚀 Server is running on port ${PORT}`);
      console.log(`📝 Environment: ${process.env.NODE_ENV || 'development'}`);
    });
  } catch (error) {
    console.error('❌ Unable to connect to the database:', error);
    process.exit(1);
  }
}

startServer();
```

### 7.3 Create Middleware Files

**`src/middleware/errorHandler.ts`:**

```typescript
import { Request, Response, NextFunction } from 'express';

export const errorHandler = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  res.status(statusCode).json({
    success: false,
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
};
```

**`src/middleware/notFoundHandler.ts`:**

```typescript
import { Request, Response } from 'express';

export const notFoundHandler = (req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    error: 'Route not found'
  });
};
```

### 7.4 Create Routes

**`src/routes/index.ts`:**

```typescript
import { Router } from 'express';

const router = Router();

// Add your routes here
// Example: router.use('/auth', authRoutes);

export default router;
```

---

## Step 8: Development Tools

### 8.1 Create `nodemon.json`

```json
{
  "watch": ["src"],
  "ext": "ts",
  "exec": "ts-node src/server.ts",
  "ignore": ["src/**/*.test.ts", "node_modules"]
}
```

### 8.2 Create `.eslintrc.js`

```javascript
module.exports = {
  parser: '@typescript-eslint/parser',
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:prettier/recommended'
  ],
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: 'module'
  },
  rules: {
    '@typescript-eslint/no-explicit-any': 'warn',
    '@typescript-eslint/explicit-module-boundary-types': 'off',
    'no-console': 'off'
  }
};
```

### 8.3 Create `.prettierrc`

```json
{
  "semi": true,
  "trailingComma": "none",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2,
  "arrowParens": "avoid"
}
```

---

## Step 9: Docker Setup (Optional)

### 9.1 Create `Dockerfile`

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci --only=production

COPY . .

RUN npm run build

EXPOSE 3000

CMD ["node", "dist/server.js"]
```

### 9.2 Create `.dockerignore`

```
node_modules
npm-debug.log
dist
.env
.git
.gitignore
README.md
```

### 9.3 Create `docker-compose.yml`

```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "${PORT:-3000}:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=${DB_NAME:-my_app}
      - DB_USER=${DB_USER:-postgres}
      - DB_PASSWORD=${DB_PASSWORD:-postgres}
      - JWT_SECRET=${JWT_SECRET}
      - JWT_EXPIRES_IN=${JWT_EXPIRES_IN:-24h}
      - JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
      - JWT_REFRESH_EXPIRES_IN=${JWT_REFRESH_EXPIRES_IN:-7d}
      - CORS_ORIGIN=${CORS_ORIGIN:-*}
    depends_on:
      - postgres
    restart: unless-stopped
    networks:
      - app-network

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=${DB_NAME:-my_app}
      - POSTGRES_USER=${DB_USER:-postgres}
      - POSTGRES_PASSWORD=${DB_PASSWORD:-postgres}
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - app-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres-data:

networks:
  app-network:
    driver: bridge
```

---

## Step 10: Testing Setup

### 10.1 Create `jest.config.js`

```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/server.ts'
  ],
  coverageDirectory: 'coverage',
  verbose: true
};
```

### 10.2 Create `tests/setup.ts`

```typescript
import sequelize from '../src/config/database';

beforeAll(async () => {
  await sequelize.sync({ force: true });
});

afterAll(async () => {
  await sequelize.close();
});
```

---

## Step 11: Documentation

### 11.1 Create `README.md`

Include:
- Project overview
- Features list
- Prerequisites
- Installation instructions
- Usage examples
- API endpoints
- Project structure
- Available scripts
- Environment variables
- Contributing guidelines

### 11.2 Create Additional Documentation

Consider creating:
- `API_DOCUMENTATION.md` - Detailed API reference
- `GETTING_STARTED.md` - Step-by-step setup guide
- `QUICK_START.md` - 5-minute quick start guide
- `CONTRIBUTING.md` - Contribution guidelines
- `CHANGELOG.md` - Version history

---

## Verification Steps

After completing all steps, verify your setup:

### 1. Install Dependencies

```bash
npm install
```

### 2. Build TypeScript

```bash
npm run build
```

### 3. Run Linter

```bash
npm run lint
```

### 4. Start Development Server

```bash
npm run dev
```

### 5. Test Health Endpoint

```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "OK",
  "timestamp": "2026-02-03T10:00:00.000Z"
}
```

### 6. Run Tests

```bash
npm test
```

---

## Next Steps

After initialization, you can:

1. **Create Models**: Define your database models in `src/models/`
2. **Add Controllers**: Implement business logic in `src/controllers/`
3. **Create Services**: Add service layer in `src/services/`
4. **Define Routes**: Set up API routes in `src/routes/`
5. **Add Validators**: Create input validation in `src/validators/`
6. **Implement Middleware**: Add custom middleware as needed
7. **Write Tests**: Create comprehensive test suite
8. **Create Migrations**: Use Sequelize CLI to manage database schema
9. **Add Documentation**: Document your API endpoints

---

## Common Commands

```bash
# Development
npm run dev              # Start dev server with hot reload
npm run build            # Build for production
npm start                # Start production server

# Code Quality
npm run lint             # Check for linting errors
npm run lint:fix         # Fix linting errors automatically

# Testing
npm test                 # Run tests
npm run test:watch       # Run tests in watch mode

# Database
npx sequelize-cli db:migrate              # Run migrations
npx sequelize-cli db:migrate:undo         # Undo last migration
npx sequelize-cli migration:generate --name <name>  # Create migration

# Docker
docker-compose up        # Start all services
docker-compose down      # Stop all services
docker-compose logs -f   # View logs
```

---

## Troubleshooting

### Database Connection Issues

```bash
# Check PostgreSQL is running
pg_isready

# Test connection
psql -U postgres -d my_app_dev
```

### Port Already in Use

```bash
# Find process using port 3000
lsof -i :3000

# Kill the process (replace PID)
kill -9 <PID>
```

### Module Not Found Errors

```bash
# Clear node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

---

## Best Practices

1. **Environment Variables**: Never commit `.env` files
2. **Security**: Use strong JWT secrets in production
3. **Database**: Always use migrations for schema changes
4. **Testing**: Write tests before deploying to production
5. **Code Quality**: Run linter and formatter before committing
6. **Git**: Use meaningful commit messages
7. **Documentation**: Keep documentation up to date
8. **Error Handling**: Always handle errors gracefully
9. **Logging**: Use appropriate log levels
10. **Validation**: Validate all user inputs

---

## Resources

- [Express.js Documentation](https://expressjs.com/)
- [TypeScript Documentation](https://www.typescriptlang.org/docs/)
- [Sequelize Documentation](https://sequelize.org/docs/v6/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Docker Documentation](https://docs.docker.com/)

---

## Support

For issues or questions:
1. Check existing documentation
2. Search for similar issues
3. Create a new issue with detailed information
4. Include error messages and logs

---

**Congratulations!** 🎉 You now have a fully configured Node.js + TypeScript + Express + PostgreSQL project ready for development.
