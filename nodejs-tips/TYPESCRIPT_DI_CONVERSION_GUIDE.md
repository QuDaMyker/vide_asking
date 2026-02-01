# TypeScript & Dependency Injection Conversion Guide

## 📋 Table of Contents
- [Overview](#overview)
- [Migration Summary](#migration-summary)
- [Architecture Changes](#architecture-changes)
- [Key Improvements](#key-improvements)
- [Installation & Setup](#installation--setup)
- [Dependency Injection Pattern](#dependency-injection-pattern)
- [File-by-File Conversion](#file-by-file-conversion)
- [Running the Application](#running-the-application)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This document outlines the complete conversion of the Node.js e-commerce backend from JavaScript to TypeScript with Dependency Injection (DI) using InversifyJS.

### Migration Goals
✅ Convert all JavaScript files to TypeScript  
✅ Implement Dependency Injection pattern  
✅ Add strong type safety  
✅ Improve code maintainability and testability  
✅ Enhance IDE support and autocompletion  

---

## 📊 Migration Summary

### Files Converted
- **Total Files**: 30+ files converted
- **Configuration**: 1 new tsconfig.json
- **DI Setup**: 2 new files (container.ts, types.ts)
- **Models**: 4 models converted to TypeScript interfaces
- **Services**: 5 services with DI decorators
- **Controllers**: 2 controllers with DI
- **Routers**: 3 router files
- **Core Files**: Config, error handling, success responses

### Technology Stack Changes

| Category | Before | After |
|----------|--------|-------|
| **Language** | JavaScript (ES6+) | TypeScript 5.9+ |
| **Module System** | CommonJS | CommonJS with TS |
| **DI Framework** | None | InversifyJS 6.0+ |
| **Type Safety** | None | Full TypeScript |
| **Dev Tools** | node --watch | ts-node-dev |

---

## 🏗️ Architecture Changes

### Before (JavaScript)
```
src/
├── services/
│   └── access.service.js (static methods, no DI)
├── controllers/
│   └── access.controller.js (singleton export)
└── routers/
    └── access/index.js (direct require)
```

### After (TypeScript + DI)
```
src/
├── di/
│   ├── types.ts (DI symbols)
│   └── container.ts (DI bindings)
├── services/
│   └── access.service.ts (@injectable, constructor injection)
├── controllers/
│   └── access.controller.ts (@injectable, injected services)
└── routers/
    └── access/index.ts (container.get<T>)
```

---

## ✨ Key Improvements

### 1. **Type Safety**
```typescript
// Before (JavaScript)
const login = async ({ email, password, refreshToken }) => {
  // No type checking
}

// After (TypeScript)
async login({
  email,
  password,
  refreshToken,
}: {
  email: string;
  password: string;
  refreshToken?: string;
}): Promise<{ shop: any; tokens: any }> {
  // Full type safety
}
```

### 2. **Dependency Injection**
```typescript
// Before (JavaScript)
const KeyTokenService = require('./keyToken.service');
class AccessService {
  static login() {
    await KeyTokenService.createKeyToken(/*...*/);
  }
}

// After (TypeScript + DI)
@injectable()
export class AccessService {
  constructor(
    @inject(TYPES.KeyTokenService) private keyTokenService: KeyTokenService
  ) {}
  
  async login() {
    await this.keyTokenService.createKeyToken(/*...*/);
  }
}
```

### 3. **Interface Definitions**
```typescript
export interface IShop extends Document {
  name: string;
  email: string;
  password: string;
  status: 'active' | 'inactive';
  verify: boolean;
  roles: string[];
}
```

### 4. **Better Error Handling**
```typescript
export class ErrorResponse extends Error {
  public status: number;
  
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}
```

---

## 🚀 Installation & Setup

### 1. Install Dependencies
```bash
cd nodejs-tips
npm install
```

### 2. New Dependencies Added
```json
{
  "dependencies": {
    "inversify": "^6.0.1",
    "reflect-metadata": "^0.1.13"
  },
  "devDependencies": {
    "@types/bcrypt": "^5.0.0",
    "@types/compression": "^1.7.2",
    "@types/express": "^4.17.17",
    "@types/jsonwebtoken": "^9.0.2",
    "@types/lodash": "^4.14.195",
    "@types/morgan": "^1.9.4",
    "@types/node": "^20.3.1",
    "ts-node-dev": "^2.0.0"
  }
}
```

### 3. TypeScript Configuration
See [tsconfig.json](../tsconfig.json) with:
- Target: ES2020
- Module: CommonJS
- Decorators enabled
- Strict mode enabled
- Source maps enabled

---

## 🔧 Dependency Injection Pattern

### DI Container Setup

#### 1. Define Symbols ([src/di/types.ts](../src/di/types.ts))
```typescript
export const TYPES = {
  AccessService: Symbol.for('AccessService'),
  KeyTokenService: Symbol.for('KeyTokenService'),
  ShopService: Symbol.for('ShopService'),
  // ... more symbols
};
```

#### 2. Configure Container ([src/di/container.ts](../src/di/container.ts))
```typescript
const container = new Container();

container.bind<AccessService>(TYPES.AccessService)
  .to(AccessService)
  .inSingletonScope();

container.bind<KeyTokenService>(TYPES.KeyTokenService)
  .to(KeyTokenService)
  .inSingletonScope();
```

#### 3. Inject Dependencies
```typescript
@injectable()
export class AccessController {
  constructor(
    @inject(TYPES.AccessService) private accessService: AccessService
  ) {}
  
  login = async (req: Request, res: Response) => {
    const result = await this.accessService.login(req.body);
    // ...
  };
}
```

#### 4. Retrieve from Container
```typescript
const accessController = container.get<AccessController>(TYPES.AccessController);
router.post('/login', asyncHandler(accessController.login.bind(accessController)));
```

---

## 📁 File-by-File Conversion

### Configuration Files

#### [src/config/config.mongodb.ts](../src/config/config.mongodb.ts)
**Changes:**
- Converted to class-based configuration
- Added `@injectable()` decorator
- Added interface `IConfig`
- Strong typing for all config properties

**Before:**
```javascript
const dev = { app: { port: process.env.DEV_APP_PORT || 3052 } };
module.exports = config[env];
```

**After:**
```typescript
@injectable()
export class Config implements IConfig {
  public app: { port: number };
  public db: { host: string; port: number; name: string };
  constructor() { /* ... */ }
}
```

---

### Core Files

#### [src/core/error.response.ts](../src/core/error.response.ts)
**Changes:**
- Proper TypeScript class inheritance
- Added proper error stack traces
- Type-safe error constructors

#### [src/core/success.response.ts](../src/core/success.response.ts)
**Changes:**
- Typed Response from Express
- Interface-based options
- Generic metadata support

---

### Models

#### [src/models/shop.model.ts](../src/models/shop.model.ts)
**Changes:**
- Added `IShop` interface extending Mongoose `Document`
- Typed Schema definition
- Exported typed Model

**Pattern:**
```typescript
export interface IShop extends Document {
  name: string;
  email: string;
  // ...
}

const shopSchema = new Schema<IShop>({ /* ... */ });
export const shopModel: Model<IShop> = mongoose.model<IShop>('Shop', shopSchema);
```

**Applied to:**
- `shop.model.ts`
- `keytoken.model.ts`
- `product.model.ts`
- `apiKey.model.ts`

---

### Services

#### [src/services/access.service.ts](../src/services/access.service.ts)
**Changes:**
- Static methods → Instance methods
- Constructor injection for dependencies
- `@injectable()` decorator
- Type-safe method signatures

**Before:**
```javascript
class AccessService {
  static login = async ({ email, password }) => {
    const foundShop = await findByEmail({ email });
    // ...
  }
}
module.exports = AccessService;
```

**After:**
```typescript
@injectable()
export class AccessService {
  constructor(
    @inject(TYPES.KeyTokenService) private keyTokenService: KeyTokenService,
    @inject(TYPES.ShopService) private shopService: ShopService
  ) {}
  
  async login({ email, password }: { email: string; password: string }) {
    const foundShop = await this.shopService.findByEmail({ email });
    // ...
  }
}
```

**Other Services Converted:**
- `keyToken.service.ts`
- `shop.service.ts`
- `apiKey.service.ts`
- `product.service.ts`

---

### Controllers

#### [src/controllers/access.controller.ts](../src/controllers/access.controller.ts)
**Changes:**
- Injected service dependencies
- Typed request/response handlers
- `@injectable()` decorator

**Pattern:**
```typescript
@injectable()
export class AccessController {
  constructor(
    @inject(TYPES.AccessService) private accessService: AccessService
  ) {}
  
  login = async (req: Request, res: Response, next: NextFunction) => {
    // Implementation
  };
}
```

---

### Routers

#### [src/routers/access/index.ts](../src/routers/access/index.ts)
**Changes:**
- Retrieve controller from DI container
- Bind controller methods to instance
- TypeScript Router typing

**Pattern:**
```typescript
const router: Router = express.Router();
const controller = container.get<AccessController>(TYPES.AccessController);

router.post('/signup', asyncHandler(controller.signUp.bind(controller)));
```

---

### Utilities & Helpers

#### [src/auth/authUtils.ts](../src/auth/authUtils.ts)
**Changes:**
- Typed JWT payload
- Extended Request interface (`AuthRequest`)
- Type-safe middleware

#### [src/helpers/asyncHandler.ts](../src/helpers/asyncHandler.ts)
**Changes:**
- Generic type support
- Express types

#### [src/utils/index.ts](../src/utils/index.ts)
**Changes:**
- Typed utility functions
- Generic object typing

---

### Database

#### [src/dbs/init.mongodb.ts](../src/dbs/init.mongodb.ts)
**Changes:**
- Singleton pattern with typed getInstance
- Config injection
- Typed mongoose connection

---

### Entry Points

#### [src/server.ts](../src/server.ts)
**Changes:**
- Import reflect-metadata (required for InversifyJS)
- Get config from DI container
- Clean process handling

#### [src/app.ts](../src/app.ts)
**Changes:**
- Typed Express application
- Typed middleware
- Typed error handlers
- DI container initialization

---

## 🏃 Running the Application

### Development Mode
```bash
npm run dev
```
Uses `ts-node-dev` for hot-reload during development.

### Build Production
```bash
npm run build
```
Compiles TypeScript to JavaScript in `dist/` folder.

### Run Production
```bash
npm start
```
Runs compiled JavaScript from `dist/`.

---

## 🧪 Testing

### Unit Testing Pattern (Example)
```typescript
import 'reflect-metadata';
import { Container } from 'inversify';
import { AccessService } from './access.service';
import { KeyTokenService } from './keyToken.service';
import { TYPES } from '../di/types';

describe('AccessService', () => {
  let container: Container;
  let accessService: AccessService;
  
  beforeEach(() => {
    container = new Container();
    container.bind<KeyTokenService>(TYPES.KeyTokenService).to(KeyTokenService);
    container.bind<AccessService>(TYPES.AccessService).to(AccessService);
    accessService = container.get<AccessService>(TYPES.AccessService);
  });
  
  it('should login successfully', async () => {
    // Test implementation
  });
});
```

---

## 🐛 Troubleshooting

### Common Issues

#### 1. **"Cannot find module" errors**
**Solution:** Ensure all imports use `.ts` extensions removed and proper paths.

#### 2. **Decorator errors**
**Solution:** Check `tsconfig.json` has:
```json
{
  "experimentalDecorators": true,
  "emitDecoratorMetadata": true
}
```

#### 3. **DI Container errors**
**Solution:** Import `reflect-metadata` at the top of your entry file:
```typescript
import 'reflect-metadata';
```

#### 4. **Type errors with Mongoose**
**Solution:** Ensure interfaces extend `Document`:
```typescript
export interface IShop extends Document { /* ... */ }
```

#### 5. **"Cannot read property of undefined" in controllers**
**Solution:** Bind methods when passing to router:
```typescript
router.post('/login', asyncHandler(controller.login.bind(controller)));
```

---

## 📚 Additional Resources

### InversifyJS Documentation
- [Official Docs](https://inversify.io/)
- [GitHub Repository](https://github.com/inversify/InversifyJS)

### TypeScript Documentation
- [Official Handbook](https://www.typescriptlang.org/docs/)
- [TypeScript with Express](https://www.typescriptlang.org/docs/handbook/declaration-files/templates/module-class-d-ts.html)

### Mongoose with TypeScript
- [Mongoose TypeScript Guide](https://mongoosejs.com/docs/typescript.html)

---

## 📝 Summary

The conversion successfully:
- ✅ Migrated 30+ files from JavaScript to TypeScript
- ✅ Implemented Dependency Injection with InversifyJS
- ✅ Added comprehensive type safety
- ✅ Improved code maintainability and testability
- ✅ Enhanced IDE support with autocompletion
- ✅ Maintained backward compatibility with existing APIs

All services, controllers, models, and utilities now follow modern TypeScript and DI best practices, making the codebase more robust, testable, and maintainable.
