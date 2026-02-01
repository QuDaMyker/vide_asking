# Getting Started

Welcome to the TypeScript + DI version of the Node.js e-commerce backend!

## 🚀 Quick Start (5 minutes)

### 1. Install Dependencies
```bash
npm install
```

### 2. Set Up Environment
Create a `.env` file in the project root:

```env
NODE_ENV=dev

# Development Database
DEV_DB_HOST=localhost
DEV_DB_PORT=27017
DEV_DB_NAME=dbDev
DEV_APP_PORT=3052
```

### 3. Start MongoDB
```bash
# Option 1: Using Docker
docker run -d -p 27017:27017 --name mongodb mongo:latest

# Option 2: Local MongoDB
mongod
```

### 4. Run Development Server
```bash
npm run dev
```

Server will start on http://localhost:3052

---

## 🧪 Test the API

### Create an API Key (One-time setup)
First, you need to create an API key in the database:

```javascript
// Run this in MongoDB shell or MongoDB Compass
use dbDev

db.apikeys.insertOne({
  key: "your-api-key-here",
  status: true,
  permissions: ["0000"],
  createdAt: new Date(),
  updatedAt: new Date()
})
```

### Test Authentication

#### 1. Sign Up
```bash
curl -X POST http://localhost:3052/v1/api/auth/signup \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key-here" \
  -d '{
    "name": "Test Shop",
    "email": "test@shop.com",
    "password": "password123"
  }'
```

Expected Response:
```json
{
  "message": "Registered OK!",
  "status": 201,
  "metadata": {
    "shop": {
      "_id": "...",
      "name": "Test Shop",
      "email": "test@shop.com",
      "createdAt": "..."
    },
    "tokens": {
      "accessToken": "...",
      "refreshToken": "..."
    }
  },
  "options": {
    "limit": 10
  }
}
```

#### 2. Login
```bash
curl -X POST http://localhost:3052/v1/api/auth/login \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key-here" \
  -d '{
    "email": "test@shop.com",
    "password": "password123"
  }'
```

#### 3. Create a Product
```bash
curl -X POST http://localhost:3052/v1/api/product \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key-here" \
  -H "x-client-id: <user-id-from-login>" \
  -H "authorization: <access-token-from-login>" \
  -d '{
    "product_name": "iPhone 15",
    "product_type": "Electronic",
    "product_price": 999,
    "product_quantity": 100,
    "product_thumb": "https://example.com/iphone.jpg",
    "product_description": "Latest iPhone model",
    "product_attributes": {
      "manufacturer": "Apple",
      "modelName": "iPhone 15",
      "color": "Black"
    }
  }'
```

---

## 📚 Understanding the Code

### DI Container Location
All dependency bindings are in: `src/di/container.ts`

### Service Example
```typescript
// src/services/access.service.ts
@injectable()
export class AccessService {
  constructor(
    @inject(TYPES.KeyTokenService) private keyTokenService: KeyTokenService
  ) {}
  
  async login({ email, password }) {
    // Business logic
  }
}
```

### Controller Example
```typescript
// src/controllers/access.controller.ts
@injectable()
export class AccessController {
  constructor(
    @inject(TYPES.AccessService) private accessService: AccessService
  ) {}
  
  login = async (req: Request, res: Response) => {
    const result = await this.accessService.login(req.body);
    return new SuccessResponse({ metadata: result }).send(res);
  }
}
```

### Router Usage
```typescript
// src/routers/access/index.ts
const controller = container.get<AccessController>(TYPES.AccessController);
router.post('/login', asyncHandler(controller.login.bind(controller)));
```

---

## 🛠️ Development Workflow

### 1. Add a New Service

Create the service:
```typescript
// src/services/email.service.ts
@injectable()
export class EmailService {
  async sendEmail(to: string, subject: string): Promise<void> {
    // Implementation
  }
}
```

Add symbol:
```typescript
// src/di/types.ts
export const TYPES = {
  EmailService: Symbol.for('EmailService'),
  // ... other symbols
};
```

Register in container:
```typescript
// src/di/container.ts
container.bind<EmailService>(TYPES.EmailService)
  .to(EmailService)
  .inSingletonScope();
```

Use it:
```typescript
@injectable()
export class AccessService {
  constructor(
    @inject(TYPES.EmailService) private emailService: EmailService
  ) {}
}
```

### 2. Compile TypeScript
```bash
npm run build
```

Output goes to `dist/` folder

### 3. Run Production Build
```bash
npm start
```

---

## 📖 Documentation

- **[README.md](README.md)** - Full project documentation
- **[QUICK_START.md](QUICK_START.md)** - Common patterns
- **[DI_ARCHITECTURE.md](DI_ARCHITECTURE.md)** - Architecture deep dive
- **[TYPESCRIPT_DI_CONVERSION_GUIDE.md](TYPESCRIPT_DI_CONVERSION_GUIDE.md)** - Conversion details

---

## 🐛 Common Issues

### Issue: "Cannot find module"
**Solution:** Check that imports don't include `.ts` extension
```typescript
// ✅ Correct
import { MyService } from './my.service';

// ❌ Wrong
import { MyService } from './my.service.ts';
```

### Issue: Decorator errors
**Solution:** Ensure `reflect-metadata` is imported first in `src/server.ts`
```typescript
import 'reflect-metadata'; // Must be first!
```

### Issue: DI binding errors
**Solution:** Check that service is:
1. Decorated with `@injectable()`
2. Registered in `src/di/container.ts`
3. Symbol defined in `src/di/types.ts`

---

## 💡 Tips

1. **Use interfaces** for all service contracts
2. **Keep constructors simple** - no business logic
3. **Bind to singleton scope** for stateless services
4. **Test with mocked dependencies** using DI container
5. **Use TypeScript strict mode** to catch errors early

---

## 🎯 Next Steps

1. ✅ Review the [README.md](README.md)
2. ✅ Explore [DI_ARCHITECTURE.md](DI_ARCHITECTURE.md)
3. ✅ Try the API endpoints
4. ✅ Add your own features
5. ✅ Write tests

---

## 🤝 Need Help?

- Check the documentation files
- Review example code in services/controllers
- Open an issue if you find bugs

---

**Happy Coding! 🚀**
