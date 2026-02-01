# Dependency Injection Architecture

## 🏗️ Architecture Overview

This document explains the Dependency Injection (DI) architecture implemented using InversifyJS.

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Application Entry                     │
│                    (src/server.ts)                       │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│                  DI Container                            │
│                (src/di/container.ts)                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │ Services │  │Controllers│ │Repositories│             │
│  └──────────┘  └──────────┘  └──────────┘             │
└───────────────────┬─────────────────────────────────────┘
                    │
       ┌────────────┼────────────┐
       │            │            │
       ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ Router   │ │Controller│ │ Service  │
│          │ │          │ │          │
│  gets →  │ │  injects │ │  uses    │
│Controller│ │  Service │ │Repository│
└──────────┘ └──────────┘ └──────────┘
```

---

## 🔧 Core Components

### 1. DI Symbols ([src/di/types.ts](src/di/types.ts))

Unique identifiers for each injectable dependency:

```typescript
export const TYPES = {
  // Core
  Config: Symbol.for('Config'),
  Database: Symbol.for('Database'),
  
  // Services
  AccessService: Symbol.for('AccessService'),
  KeyTokenService: Symbol.for('KeyTokenService'),
  ShopService: Symbol.for('ShopService'),
  
  // Controllers
  AccessController: Symbol.for('AccessController'),
  
  // Repositories
  ProductRepository: Symbol.for('ProductRepository'),
};
```

**Why Symbols?**
- Guaranteed unique identifiers
- Prevent naming collisions
- Type-safe dependency resolution

---

### 2. DI Container ([src/di/container.ts](src/di/container.ts))

Central registry for all dependencies:

```typescript
import { Container } from 'inversify';
import { TYPES } from './types';

const container = new Container();

// Bind implementations to symbols
container.bind<Config>(TYPES.Config)
  .toConstantValue(new Config());

container.bind<AccessService>(TYPES.AccessService)
  .to(AccessService)
  .inSingletonScope();

export { container };
```

**Binding Scopes:**
- `.inSingletonScope()`: One instance shared across app
- `.inTransientScope()`: New instance each time (default)
- `.inRequestScope()`: One instance per request

---

### 3. Injectable Classes

Classes marked with `@injectable()` can be managed by the container:

```typescript
import { injectable, inject } from 'inversify';
import { TYPES } from '../di/types';

@injectable()
export class AccessService {
  constructor(
    @inject(TYPES.KeyTokenService) 
    private keyTokenService: KeyTokenService,
    
    @inject(TYPES.ShopService) 
    private shopService: ShopService
  ) {}
  
  async login(credentials) {
    // Use injected services
    const shop = await this.shopService.findByEmail(credentials.email);
    const token = await this.keyTokenService.createToken(/*...*/);
    return { shop, token };
  }
}
```

---

## 🔄 Dependency Flow

### Example: Login Request Flow

```
1. HTTP Request
   └─→ Router (routers/access/index.ts)
        └─→ Gets AccessController from container
             └─→ AccessController.login()
                  └─→ Uses injected AccessService
                       ├─→ Uses injected ShopService
                       │    └─→ Queries ShopModel
                       │
                       └─→ Uses injected KeyTokenService
                            └─→ Queries KeyTokenModel
```

**Code Flow:**

```typescript
// 1. Router retrieves controller from container
const accessController = container.get<AccessController>(TYPES.AccessController);

// 2. Controller method called
router.post('/login', asyncHandler(accessController.login.bind(accessController)));

// 3. Controller uses injected service
@injectable()
export class AccessController {
  constructor(
    @inject(TYPES.AccessService) private accessService: AccessService
  ) {}
  
  login = async (req, res) => {
    const result = await this.accessService.login(req.body);
    return new SuccessResponse({ metadata: result }).send(res);
  }
}

// 4. Service uses injected dependencies
@injectable()
export class AccessService {
  constructor(
    @inject(TYPES.KeyTokenService) private keyTokenService: KeyTokenService,
    @inject(TYPES.ShopService) private shopService: ShopService
  ) {}
  
  async login({ email, password }) {
    const shop = await this.shopService.findByEmail({ email });
    const token = await this.keyTokenService.createKeyToken({...});
    return { shop, token };
  }
}
```

---

## 🎯 Benefits of This Architecture

### 1. **Loose Coupling**
Services don't directly instantiate their dependencies:
```typescript
// ❌ Tight coupling (old way)
class AccessService {
  login() {
    const shopService = new ShopService(); // Direct instantiation
  }
}

// ✅ Loose coupling (new way)
@injectable()
class AccessService {
  constructor(
    @inject(TYPES.ShopService) private shopService: ShopService
  ) {} // Dependency injected
}
```

### 2. **Testability**
Easy to mock dependencies in tests:
```typescript
// Test setup
const mockShopService = {
  findByEmail: jest.fn().mockResolvedValue({ id: '123' })
};

container.rebind<ShopService>(TYPES.ShopService)
  .toConstantValue(mockShopService);

const accessService = container.get<AccessService>(TYPES.AccessService);
// accessService now uses mock
```

### 3. **Flexibility**
Swap implementations without changing dependent code:
```typescript
// Switch from MongoDB to PostgreSQL
container.rebind<IShopRepository>(TYPES.ShopRepository)
  .to(PostgresShopRepository); // Changed implementation
// All services using IShopRepository automatically use new implementation
```

### 4. **Single Responsibility**
Each class focuses on its core logic, not dependency management:
```typescript
@injectable()
export class AccessService {
  // No complex initialization logic
  // Just business logic
  async login() { /* ... */ }
  async signUp() { /* ... */ }
}
```

---

## 🏗️ Layer Architecture

### Layered Structure

```
┌─────────────────────────────────────┐
│          Routers Layer              │  ← HTTP endpoints
│  (Express routes, middleware)       │
└──────────────┬──────────────────────┘
               │ gets controller
               ▼
┌─────────────────────────────────────┐
│       Controllers Layer             │  ← Request/Response handling
│  (Handle HTTP, validate input)      │
└──────────────┬──────────────────────┘
               │ injects service
               ▼
┌─────────────────────────────────────┐
│        Services Layer               │  ← Business logic
│  (Core business operations)         │
└──────────────┬──────────────────────┘
               │ injects repository
               ▼
┌─────────────────────────────────────┐
│     Repositories Layer              │  ← Data access
│  (Database queries, ORM)            │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│         Models Layer                │  ← Data models
│  (Mongoose schemas, interfaces)     │
└─────────────────────────────────────┘
```

### Dependency Rules
- **Higher layers depend on lower layers**
- **Lower layers never depend on higher layers**
- **Each layer only depends on the layer directly below**

---

## 📝 Adding New Dependencies

### Step-by-Step Guide

#### 1. Create Service Interface & Implementation
```typescript
// src/services/notification.service.ts
export interface INotificationService {
  sendEmail(to: string, subject: string): Promise<void>;
}

@injectable()
export class NotificationService implements INotificationService {
  async sendEmail(to: string, subject: string): Promise<void> {
    // Implementation
  }
}
```

#### 2. Add Symbol to types.ts
```typescript
// src/di/types.ts
export const TYPES = {
  // ... existing symbols
  NotificationService: Symbol.for('NotificationService'),
};
```

#### 3. Register in Container
```typescript
// src/di/container.ts
import { NotificationService } from '../services/notification.service';

container.bind<NotificationService>(TYPES.NotificationService)
  .to(NotificationService)
  .inSingletonScope();
```

#### 4. Inject Where Needed
```typescript
// src/services/access.service.ts
@injectable()
export class AccessService {
  constructor(
    @inject(TYPES.KeyTokenService) private keyTokenService: KeyTokenService,
    @inject(TYPES.ShopService) private shopService: ShopService,
    @inject(TYPES.NotificationService) private notificationService: NotificationService
  ) {}
  
  async signUp({ email }) {
    // ... create user
    await this.notificationService.sendEmail(email, 'Welcome!');
  }
}
```

---

## 🧪 Testing with DI

### Unit Test Example

```typescript
import 'reflect-metadata';
import { Container } from 'inversify';
import { AccessService } from './access.service';
import { IShopService } from './shop.service';
import { TYPES } from '../di/types';

describe('AccessService', () => {
  let container: Container;
  let accessService: AccessService;
  let mockShopService: IShopService;
  
  beforeEach(() => {
    // Create new container for each test
    container = new Container();
    
    // Create mock
    mockShopService = {
      findByEmail: jest.fn().mockResolvedValue({
        id: '123',
        email: 'test@test.com',
        password: 'hashedpassword'
      })
    };
    
    // Bind mock
    container.bind<IShopService>(TYPES.ShopService)
      .toConstantValue(mockShopService);
    
    // Bind service under test
    container.bind<AccessService>(TYPES.AccessService)
      .to(AccessService);
    
    // Get instance
    accessService = container.get<AccessService>(TYPES.AccessService);
  });
  
  it('should find shop by email during login', async () => {
    await accessService.login({ email: 'test@test.com', password: '123' });
    
    expect(mockShopService.findByEmail).toHaveBeenCalledWith({
      email: 'test@test.com'
    });
  });
});
```

---

## 🔍 Advanced Patterns

### 1. Factory Pattern
```typescript
// For creating instances dynamically
container.bind<interfaces.Factory<IProduct>>(TYPES.ProductFactory)
  .toFactory<IProduct>((context) => {
    return (type: string) => {
      if (type === 'Electronic') {
        return context.container.get<Electronic>(TYPES.Electronic);
      }
      // ... other types
    };
  });
```

### 2. Conditional Binding
```typescript
// Different implementations based on environment
if (process.env.NODE_ENV === 'production') {
  container.bind<ILogger>(TYPES.Logger).to(ProductionLogger);
} else {
  container.bind<ILogger>(TYPES.Logger).to(DevLogger);
}
```

### 3. Multi-Injection
```typescript
// Inject all implementations of an interface
container.bind<IPlugin>(TYPES.Plugin).to(AnalyticsPlugin);
container.bind<IPlugin>(TYPES.Plugin).to(LoggingPlugin);

@injectable()
class PluginManager {
  constructor(
    @multiInject(TYPES.Plugin) private plugins: IPlugin[]
  ) {}
}
```

---

## 📚 References

- [InversifyJS Documentation](https://inversify.io/)
- [Dependency Injection Principles](https://en.wikipedia.org/wiki/Dependency_injection)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)

---

## ✅ Best Practices

1. **Always use interfaces** for dependencies when possible
2. **Keep constructors simple** - no business logic
3. **Prefer constructor injection** over property injection
4. **Use singleton scope** for stateless services
5. **Bind to interfaces**, not concrete implementations
6. **Keep the container in one place** (di/container.ts)
7. **Document dependencies** in service comments
8. **Test with mocked dependencies**
