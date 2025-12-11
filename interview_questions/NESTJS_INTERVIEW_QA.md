# NestJS Interview Questions (Junior & Middle)

## 1. Module Fundamentals (Junior)

**Question:** What is a module in NestJS and why is it required?

**Answer:** A module organizes related controllers, providers, and exported components. Every Nest application has at least `AppModule`, and additional feature modules isolate domain logic, control provider scope, and structure dependency injection cleanly.

**Example:**

```typescript
@Module({
  imports: [UsersModule],
  controllers: [AuthController],
  providers: [AuthService],
})
export class AuthModule {}
```

The `AuthModule` encapsulates authentication logic while importing `UsersModule` for user data access.

## 2. Service Injection (Junior)

**Question:** How do you inject a service into a controller?

**Answer:** Mark the service with `@Injectable()`, register it in the module's `providers`, and accept it as a constructor parameter in the controller. Nest's container resolves and injects the dependency automatically.

**Example:**

```typescript
@Injectable()
export class NotificationsService {
  sendEmail(user: User, message: string) {
    // send email logic
  }
}

@Controller('alerts')
export class AlertsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Post()
  trigger(@Body() dto: AlertDto) {
    this.notifications.sendEmail(dto.user, dto.message);
  }
}
```

The controller depends on `NotificationsService` without manual instantiation.

## 3. Scheduling Background Jobs (Middle)

**Question:** How do you schedule background jobs?

**Answer:** Add `@nestjs/schedule`, import `ScheduleModule.forRoot()`, and annotate provider methods with `@Cron`, `@Interval`, or `@Timeout`. For heavier workloads, offload to queues like Bull with worker processes to scale horizontally.

**Example:**

```typescript
@Module({
  imports: [ScheduleModule.forRoot()],
  providers: [CleanupService],
})
export class MaintenanceModule {}

@Injectable()
export class CleanupService {
  @Cron('0 */1 * * *')
  removeExpiredSessions() {
    // purge sessions
  }
}
```

The cron job runs hourly, keeping the application responsive while background cleanup executes.

## 4. JWT Route Protection (Middle)

**Question:** How do you protect API routes with JWT?

**Answer:** Implement a Passport JWT strategy, provide it via an authentication module, and guard routes with `@UseGuards(AuthGuard('jwt'))`. The strategy validates tokens, attaches user context, and rejects unauthorized requests.

**Example:**

```typescript
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET,
    });
  }

  async validate(payload: JwtPayload) {
    return { userId: payload.sub, email: payload.email };
  }
}

@Controller('orders')
@UseGuards(AuthGuard('jwt'))
export class OrdersController {
  @Get()
  findAll(@Request() req) {
    return this.ordersService.listForUser(req.user.userId);
  }
}
```

The guard ensures only requests with valid bearer tokens reach the controller.

## 5. Middleware Usage (Junior)

**Question:** How do you add middleware in NestJS?

**Answer:** Implement a class with an `use` method, register it in a module's `configure` function via `MiddlewareConsumer`, and optionally scope it to specific routes. Middleware run before guards and controllers.

**Example:**

```typescript
export class LoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    console.log(`[${req.method}] ${req.url}`);
    next();
  }
}

export class AppModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggerMiddleware).forRoutes('*');
  }
}
```

Every inbound request logs method and path before reaching guards or controllers.

## 6. Validation Pipes (Junior)

**Question:** How do pipes support request validation?

**Answer:** Attach `ValidationPipe` globally or per-route to transform and validate DTOs using class-validator decorators. Invalid payloads trigger 400 responses with descriptive errors.

**Example:**

```typescript
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
  await app.listen(3000);
}
```

Routes now automatically validate DTOs and strip unexpected fields.

## 7. Interceptors for Cross-Cutting Concerns (Middle)

**Question:** What role do interceptors play?

**Answer:** Interceptors wrap request/response flows, enabling logging, caching, or response shaping. They can measure execution time, mutate results, or short-circuit responses before reaching the controller.

**Example:**

```typescript
@Injectable()
export class TimingInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler) {
    const started = Date.now();
    return next.handle().pipe(tap(() => console.log('took', Date.now() - started)));
  }
}

@UseInterceptors(TimingInterceptor)
@Get('reports')
listReports() {
  return this.reportsService.list();
}
```

The interceptor logs how long the handler took, aiding performance analysis under load.

## 8. Custom Providers and Tokens (Middle)

**Question:** How do you provide configuration objects or third-party clients?

**Answer:** Define custom providers with unique tokens (symbols or strings) via the module's `providers` array, then inject them using `@Inject`. This pattern supplies clients like Redis or environment-specific configuration data.

**Example:**

```typescript
export const REDIS_CLIENT = Symbol('REDIS_CLIENT');

@Module({
  providers: [
    {
      provide: REDIS_CLIENT,
      useFactory: async () => createClient({ url: process.env.REDIS_URL }),
    },
  ],
  exports: [REDIS_CLIENT],
})
export class RedisModule {}

@Injectable()
export class CacheService {
  constructor(@Inject(REDIS_CLIENT) private readonly redis: RedisClientType) {}
}
```

Services depend on the token rather than constructing clients directly, easing testing.

## 9. Event-Driven Microservices (Middle)

**Question:** How does NestJS support event-driven communication?

**Answer:** Nest offers microservice transport layers (Redis, NATS, Kafka). You decorate handlers with `@EventPattern` or `@MessagePattern` to consume messages asynchronously, enabling resilient, decoupled services.

**Example:**

```typescript
@Module({
  imports: [ClientsModule.register([{ name: 'BILLING', transport: Transport.REDIS }])],
})
export class BillingModule {}

@Controller()
export class BillingListener {
  @EventPattern('invoice.paid')
  handleInvoicePaid(@Payload() event: InvoicePaidEvent) {
    // update ledger
  }
}
```

The listener processes invoices asynchronously, smoothing spikes in payment events.

## 10. Testing with TestingModule (Middle)

**Question:** How do you unit test NestJS providers?

**Answer:** Use `Test.createTestingModule` to instantiate modules in isolation, override dependencies with mocks, and retrieve providers for testing. This avoids spinning up HTTP servers while exercising business logic.

**Example:**

```typescript
describe('AuthService', () => {
  let service: AuthService;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      providers: [AuthService, { provide: UsersService, useValue: mockUsersService }],
    }).compile();
    service = module.get(AuthService);
  });

  it('validates credentials', async () => {
    await expect(service.validateUser('a@b.com', 'secret')).resolves.toBeDefined();
  });
});
```

The unit test runs business logic rapidly without network or database dependencies.
