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
