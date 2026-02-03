# Express + TypeScript Backend API

A production-ready RESTful API backend built with Express.js, TypeScript, PostgreSQL, Sequelize ORM, and JWT authentication.

---

## 📚 Documentation

- **[Quick Start Guide](QUICK_START.md)** - Get running in 5 minutes
- **[Getting Started Guide](GETTING_STARTED.md)** - Detailed setup instructions
- **[API Documentation](API_DOCUMENTATION.md)** - Complete API reference

---

## Features

- ✅ **TypeScript** - Full TypeScript support with strict type checking
- ✅ **Express.js** - Fast, minimalist web framework
- ✅ **PostgreSQL** - Robust relational database
- ✅ **Sequelize ORM** - Promise-based Node.js ORM with TypeScript support
- ✅ **JWT Authentication** - Secure token-based authentication with refresh tokens
- ✅ **Input Validation** - Request validation using express-validator
- ✅ **Security** - Helmet, CORS, rate limiting, and bcrypt password hashing
- ✅ **Error Handling** - Centralized error handling middleware
- ✅ **Logging** - Request logging with Morgan
- ✅ **Testing** - Jest and Supertest for unit and integration tests
- ✅ **Code Quality** - ESLint and Prettier for code consistency
- ✅ **Hot Reload** - Nodemon for development

## Prerequisites

- Node.js (v18 or higher)
- PostgreSQL (v13 or higher)
- npm or yarn

## Getting Started

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd nodejs-template
```

### 2. Install dependencies

```bash
npm install
```

### 3. Set up environment variables

Copy the `.env.example` file to `.env` and update the values:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
NODE_ENV=development
PORT=3000

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=nodejs_template_dev
DB_USER=postgres
DB_PASSWORD=your_password

# JWT
JWT_SECRET=your_super_secret_jwt_key
JWT_EXPIRES_IN=24h
JWT_REFRESH_SECRET=your_super_secret_refresh_key
JWT_REFRESH_EXPIRES_IN=7d

# CORS
CORS_ORIGIN=*
```

### 4. Create the database

```bash
# Create PostgreSQL database
createdb nodejs_template_dev

# Or using psql
psql -U postgres
CREATE DATABASE nodejs_template_dev;
```

### 5. Run the application

**Development mode with hot reload:**

```bash
npm run dev
```

**Build for production:**

```bash
npm run build
npm start
```

## API Endpoints

### Health Check

```
GET /health
```

### Authentication

#### Register a new user

```
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass123",
  "firstName": "John",
  "lastName": "Doe"
}
```

#### Login

```
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass123"
}
```

#### Refresh Token

```
POST /api/auth/refresh-token
Content-Type: application/json

{
  "refreshToken": "your_refresh_token"
}
```

#### Get Profile (Protected)

```
GET /api/auth/profile
Authorization: Bearer <access_token>
```

## Project Structure

```
nodejs-template/
├── src/
│   ├── config/          # Configuration files
│   │   ├── database.ts  # Sequelize configuration
│   │   └── config.js    # Database config for migrations
│   ├── controllers/     # Route controllers
│   │   └── authController.ts
│   ├── middleware/      # Custom middleware
│   │   ├── authenticate.ts
│   │   ├── errorHandler.ts
│   │   ├── notFoundHandler.ts
│   │   ├── rateLimiter.ts
│   │   └── validateRequest.ts
│   ├── models/          # Sequelize models
│   │   ├── User.ts
│   │   └── index.ts
│   ├── routes/          # API routes
│   │   ├── authRoutes.ts
│   │   └── index.ts
│   ├── services/        # Business logic
│   │   └── authService.ts
│   ├── utils/           # Utility functions
│   │   └── jwt.ts
│   ├── validators/      # Request validators
│   │   └── authValidator.ts
│   ├── types/           # TypeScript type definitions
│   ├── app.ts           # Express app setup
│   └── server.ts        # Server entry point
├── tests/               # Test files
│   ├── setup.ts
│   └── auth.test.ts
├── migrations/          # Database migrations
├── dist/                # Compiled JavaScript
├── .env.example         # Environment variables template
├── .gitignore
├── .eslintrc.js         # ESLint configuration
├── .prettierrc          # Prettier configuration
├── .sequelizerc         # Sequelize CLI configuration
├── tsconfig.json        # TypeScript configuration
├── jest.config.js       # Jest configuration
├── nodemon.json         # Nodemon configuration
├── package.json
└── README.md
```

## Scripts

- `npm run dev` - Start development server with hot reload
- `npm run build` - Compile TypeScript to JavaScript
- `npm start` - Start production server
- `npm test` - Run tests
- `npm run test:watch` - Run tests in watch mode
- `npm run lint` - Lint code with ESLint
- `npm run lint:fix` - Fix linting errors automatically

## Testing

Run the test suite:

```bash
npm test
```

Run tests with coverage:

```bash
npm test -- --coverage
```

## Database Migrations

### Create a migration

```bash
npx sequelize-cli migration:generate --name migration-name
```

### Run migrations

```bash
npx sequelize-cli db:migrate
```

### Undo last migration

```bash
npx sequelize-cli db:migrate:undo
```

## Security Features

- **Helmet** - Sets various HTTP headers for security
- **CORS** - Configurable Cross-Origin Resource Sharing
- **Rate Limiting** - Prevents brute force attacks
- **Password Hashing** - Bcrypt with 10 salt rounds
- **JWT** - Secure token-based authentication
- **Input Validation** - Validates and sanitizes all inputs
- **SQL Injection Protection** - Sequelize parameterized queries

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment (development/production) | development |
| `PORT` | Server port | 3000 |
| `DB_HOST` | Database host | localhost |
| `DB_PORT` | Database port | 5432 |
| `DB_NAME` | Database name | nodejs_template_dev |
| `DB_USER` | Database user | postgres |
| `DB_PASSWORD` | Database password | - |
| `JWT_SECRET` | JWT secret key | - |
| `JWT_EXPIRES_IN` | JWT expiration time | 24h |
| `JWT_REFRESH_SECRET` | Refresh token secret | - |
| `JWT_REFRESH_EXPIRES_IN` | Refresh token expiration | 7d |
| `CORS_ORIGIN` | Allowed CORS origins | * |

## Error Handling

The API uses a centralized error handling system:

- Operational errors return appropriate status codes and messages
- Validation errors return 400 with detailed messages
- Authentication errors return 401
- Not found errors return 404
- Server errors return 500 (details hidden in production)

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -am 'Add my feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Submit a pull request

## License

This project is licensed under the ISC License.

## Support

For issues and questions, please open an issue on GitHub.
