# Node.js E-Commerce Backend - TypeScript & DI

A modern, scalable e-commerce backend built with TypeScript, Express, MongoDB, and Dependency Injection.

## 🚀 Features

- ✅ **TypeScript** - Full type safety and modern JavaScript features
- ✅ **Dependency Injection** - InversifyJS for loose coupling and testability
- ✅ **MongoDB** - Mongoose ODM with typed schemas
- ✅ **JWT Authentication** - Secure token-based auth with refresh tokens
- ✅ **Product Management** - Multi-type products (Electronics, Clothing, Furniture)
- ✅ **User Management** - Shop registration, login, and profile
- ✅ **API Key Middleware** - Permission-based access control
- ✅ **Error Handling** - Centralized error management
- ✅ **Development Mode** - Hot-reload with ts-node-dev

---

## 📋 Prerequisites

- Node.js >= 16.x
- MongoDB >= 4.x
- npm or yarn

---

## 🛠️ Installation

### 1. Clone the repository
```bash
git clone <repository-url>
cd nodejs-tips
```

### 2. Install dependencies
```bash
npm install
```

### 3. Configure environment
Create a `.env` file:
```env
NODE_ENV=dev

# Development Database
DEV_DB_HOST=localhost
DEV_DB_PORT=27017
DEV_DB_NAME=dbDev
DEV_APP_PORT=3052

# Production Database
PRO_DB_HOST=localhost
PRO_DB_PORT=27018
PRO_DB_NAME=dbPro
PRO_APP_PORT=3000
```

### 4. Start MongoDB
```bash
# Using Docker
docker run -d -p 27017:27017 --name mongodb mongo:latest

# Or use local MongoDB installation
mongod
```

---

## 🏃 Running the Application

### Development Mode (Hot Reload)
```bash
npm run dev
```

### Build for Production
```bash
npm run build
```

### Run Production Build
```bash
npm start
```

---

## 📁 Project Structure

```
nodejs-tips/
├── src/
│   ├── di/                      # Dependency Injection
│   │   ├── container.ts         # DI container configuration
│   │   └── types.ts             # DI symbols/types
│   │
│   ├── models/                  # Mongoose models
│   │   ├── shop.model.ts
│   │   ├── keytoken.model.ts
│   │   ├── product.model.ts
│   │   ├── apiKey.model.ts
│   │   └── repositories/
│   │       └── product.repo.ts
│   │
│   ├── services/                # Business logic
│   │   ├── access.service.ts
│   │   ├── keyToken.service.ts
│   │   ├── shop.service.ts
│   │   ├── apiKey.service.ts
│   │   └── product.service.ts
│   │
│   ├── controllers/             # Request handlers
│   │   ├── access.controller.ts
│   │   └── product.controller.ts
│   │
│   ├── routers/                 # Express routes
│   │   ├── index.ts
│   │   ├── access/
│   │   └── product/
│   │
│   ├── auth/                    # Authentication
│   │   ├── authUtils.ts
│   │   └── checkAuth.ts
│   │
│   ├── core/                    # Core utilities
│   │   ├── error.response.ts
│   │   └── success.response.ts
│   │
│   ├── config/                  # Configuration
│   │   └── config.mongodb.ts
│   │
│   ├── dbs/                     # Database connection
│   │   └── init.mongodb.ts
│   │
│   ├── helpers/                 # Helper functions
│   │   └── asyncHandler.ts
│   │
│   ├── utils/                   # Utility functions
│   │   └── index.ts
│   │
│   ├── app.ts                   # Express app setup
│   └── server.ts                # Application entry point
│
├── dist/                        # Compiled JavaScript (production)
├── node_modules/
├── .env                         # Environment variables
├── .gitignore
├── package.json
├── tsconfig.json                # TypeScript configuration
│
└── Documentation/
    ├── TYPESCRIPT_DI_CONVERSION_GUIDE.md
    ├── QUICK_START.md
    └── DI_ARCHITECTURE.md
```

---

## 🔑 API Endpoints

### Authentication

#### Register Shop
```http
POST /v1/api/auth/signup
Content-Type: application/json
x-api-key: <your-api-key>

{
  "name": "My Shop",
  "email": "shop@example.com",
  "password": "securepassword"
}
```

#### Login
```http
POST /v1/api/auth/login
Content-Type: application/json
x-api-key: <your-api-key>

{
  "email": "shop@example.com",
  "password": "securepassword"
}
```

#### Logout
```http
POST /v1/api/auth/logout
Content-Type: application/json
x-api-key: <your-api-key>
x-client-id: <user-id>
authorization: <access-token>
```

#### Refresh Token
```http
POST /v1/api/auth/handlerRefreshToken
Content-Type: application/json
x-api-key: <your-api-key>
x-client-id: <user-id>
refreshtoken: <refresh-token>
```

### Products

#### Create Product
```http
POST /v1/api/product
Content-Type: application/json
x-api-key: <your-api-key>
x-client-id: <user-id>
authorization: <access-token>

{
  "product_name": "iPhone 15",
  "product_type": "Electronic",
  "product_price": 999,
  "product_quantity": 100,
  "product_thumb": "https://example.com/thumb.jpg",
  "product_description": "Latest iPhone",
  "product_attributes": {
    "manufacturer": "Apple",
    "model": "iPhone 15",
    "color": "Black"
  }
}
```

#### Get All Drafts
```http
GET /v1/api/product/drafts/all
x-api-key: <your-api-key>
x-client-id: <user-id>
authorization: <access-token>
```

#### Get All Published
```http
GET /v1/api/product/publishs/all
x-api-key: <your-api-key>
x-client-id: <user-id>
authorization: <access-token>
```

#### Publish Product
```http
POST /v1/api/product/publish/:productId
x-api-key: <your-api-key>
x-client-id: <user-id>
authorization: <access-token>
```

#### Unpublish Product
```http
POST /v1/api/product/unpublish/:productId
x-api-key: <your-api-key>
x-client-id: <user-id>
authorization: <access-token>
```

---

## 🏗️ Architecture

### Dependency Injection Pattern

This project uses **InversifyJS** for dependency injection:

```typescript
// 1. Define service with @injectable decorator
@injectable()
export class AccessService {
  constructor(
    @inject(TYPES.KeyTokenService) private keyTokenService: KeyTokenService
  ) {}
}

// 2. Register in DI container
container.bind<AccessService>(TYPES.AccessService)
  .to(AccessService)
  .inSingletonScope();

// 3. Retrieve and use
const accessService = container.get<AccessService>(TYPES.AccessService);
```

### Layers

1. **Router Layer** - HTTP endpoints and middleware
2. **Controller Layer** - Request/response handling
3. **Service Layer** - Business logic
4. **Repository Layer** - Data access
5. **Model Layer** - Data structures

See [DI_ARCHITECTURE.md](DI_ARCHITECTURE.md) for detailed architecture documentation.

---

## 🧪 Testing

### Unit Tests (Example Pattern)
```typescript
import 'reflect-metadata';
import { Container } from 'inversify';
import { AccessService } from './services/access.service';
import { TYPES } from './di/types';

describe('AccessService', () => {
  let container: Container;
  let accessService: AccessService;
  
  beforeEach(() => {
    container = new Container();
    // Setup mock dependencies
    container.bind<AccessService>(TYPES.AccessService).to(AccessService);
    accessService = container.get<AccessService>(TYPES.AccessService);
  });
  
  it('should login successfully', async () => {
    // Test implementation
  });
});
```

---

## 📚 Documentation

- **[TYPESCRIPT_DI_CONVERSION_GUIDE.md](TYPESCRIPT_DI_CONVERSION_GUIDE.md)** - Complete conversion guide from JavaScript to TypeScript with DI
- **[QUICK_START.md](QUICK_START.md)** - Quick setup and common patterns
- **[DI_ARCHITECTURE.md](DI_ARCHITECTURE.md)** - Dependency Injection architecture details

---

## 🔧 Technology Stack

### Core
- **Node.js** - Runtime environment
- **TypeScript** - Type-safe JavaScript
- **Express** - Web framework
- **MongoDB** - Database
- **Mongoose** - MongoDB ODM

### Dependency Injection
- **InversifyJS** - DI container
- **reflect-metadata** - Decorator support

### Security
- **helmet** - Security headers
- **bcrypt** - Password hashing
- **jsonwebtoken** - JWT tokens

### Development
- **ts-node-dev** - TypeScript development server
- **morgan** - HTTP request logger
- **compression** - Response compression
- **dotenv** - Environment variables

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the ISC License.

---

## 👥 Authors

- Your Name - Initial work

---

## 🙏 Acknowledgments

- InversifyJS for the excellent DI framework
- Express.js team for the robust web framework
- MongoDB team for the powerful database
- TypeScript team for making JavaScript better

---

## 📞 Support

For questions and support, please open an issue in the GitHub repository.

---

## 🗺️ Roadmap

- [ ] Add unit tests
- [ ] Add integration tests
- [ ] Implement caching (Redis)
- [ ] Add API documentation (Swagger)
- [ ] Add GraphQL support
- [ ] Implement rate limiting
- [ ] Add Docker Compose setup
- [ ] Add CI/CD pipeline
- [ ] Implement logging service
- [ ] Add monitoring and analytics

---

**Happy Coding! 🚀**
