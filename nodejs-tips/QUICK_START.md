# Quick Start Guide - TypeScript & DI Conversion

## 🚀 Quick Setup

### 1. Install Dependencies
```bash
npm install
```

### 2. Run Development Server
```bash
npm run dev
```

### 3. Build for Production
```bash
npm run build
npm start
```

---

## 📦 Key Changes At a Glance

### Dependencies Added
- **inversify**: Dependency Injection framework
- **reflect-metadata**: Required for decorators
- **ts-node-dev**: TypeScript development server
- **@types/***: Type definitions for all libraries

### File Structure Changes
```
✅ All .js files → .ts files
✅ New: src/di/ (DI container & symbols)
✅ server.js → src/server.ts
✅ Added: tsconfig.json
```

---

## 🎯 Core Concepts

### 1. Dependency Injection Pattern

**Before (JavaScript):**
```javascript
// Direct require, tight coupling
const KeyTokenService = require('./keyToken.service');
class AccessService {
  static login() {
    KeyTokenService.createToken();
  }
}
```

**After (TypeScript + DI):**
```typescript
// Injected dependency, loose coupling
@injectable()
export class AccessService {
  constructor(
    @inject(TYPES.KeyTokenService) private keyTokenService: KeyTokenService
  ) {}
  
  async login() {
    this.keyTokenService.createToken();
  }
}
```

### 2. Service Registration

All services are registered in [src/di/container.ts](src/di/container.ts):

```typescript
container.bind<AccessService>(TYPES.AccessService).to(AccessService).inSingletonScope();
```

### 3. Service Usage

Controllers get services from the container:

```typescript
const controller = container.get<AccessController>(TYPES.AccessController);
```

---

## 📋 Conversion Checklist

### Models
- [x] shop.model.ts
- [x] keytoken.model.ts
- [x] product.model.ts
- [x] apiKey.model.ts

### Services
- [x] access.service.ts
- [x] keyToken.service.ts
- [x] shop.service.ts
- [x] apiKey.service.ts
- [x] product.service.ts

### Controllers
- [x] access.controller.ts
- [x] product.controller.ts

### Core
- [x] config.mongodb.ts
- [x] error.response.ts
- [x] success.response.ts

### Utilities
- [x] authUtils.ts
- [x] checkAuth.ts
- [x] asyncHandler.ts
- [x] utils/index.ts

### Infrastructure
- [x] init.mongodb.ts
- [x] app.ts
- [x] server.ts

### Routers
- [x] routers/index.ts
- [x] routers/access/index.ts
- [x] routers/product/index.ts

---

## 🔑 Key Files Reference

| File | Purpose |
|------|---------|
| [src/di/types.ts](src/di/types.ts) | DI symbol definitions |
| [src/di/container.ts](src/di/container.ts) | DI container configuration |
| [src/server.ts](src/server.ts) | Application entry point |
| [src/app.ts](src/app.ts) | Express app configuration |
| [tsconfig.json](tsconfig.json) | TypeScript configuration |

---

## 💡 Common Patterns

### Creating a New Service

1. **Define Interface & Implementation**
```typescript
export interface IMyService {
  doSomething(): Promise<void>;
}

@injectable()
export class MyService implements IMyService {
  async doSomething(): Promise<void> {
    // Implementation
  }
}
```

2. **Add Symbol**
```typescript
// src/di/types.ts
export const TYPES = {
  MyService: Symbol.for('MyService'),
  // ...
};
```

3. **Register in Container**
```typescript
// src/di/container.ts
container.bind<MyService>(TYPES.MyService).to(MyService).inSingletonScope();
```

4. **Inject & Use**
```typescript
@injectable()
export class MyController {
  constructor(
    @inject(TYPES.MyService) private myService: MyService
  ) {}
}
```

---

## 🐛 Troubleshooting

### Issue: Decorator errors
**Fix:** Add to tsconfig.json:
```json
{
  "experimentalDecorators": true,
  "emitDecoratorMetadata": true
}
```

### Issue: "Cannot find module"
**Fix:** Check imports don't include `.ts` extension
```typescript
// ✅ Correct
import { MyService } from './my.service';

// ❌ Wrong
import { MyService } from './my.service.ts';
```

### Issue: DI container errors
**Fix:** Import reflect-metadata first in server.ts:
```typescript
import 'reflect-metadata'; // Must be first!
import app from './src/app';
```

---

## 📖 Full Documentation

See [TYPESCRIPT_DI_CONVERSION_GUIDE.md](TYPESCRIPT_DI_CONVERSION_GUIDE.md) for comprehensive documentation.

---

## 🎓 Learning Resources

- [InversifyJS Guide](https://inversify.io/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Mongoose TypeScript](https://mongoosejs.com/docs/typescript.html)
