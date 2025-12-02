# Java Spring Boot Interview Questions (Junior & Middle)

## 1. Dependency Injection Basics (Junior)

**Question:** What is dependency injection in Spring Boot?

**Answer:** Dependency injection lets Spring create and manage bean lifecycles, wiring dependencies declared as constructor or field parameters. This inversion of control decouples components, improves testability, and removes manual instantiation boilerplate.

**Example:**

```java
@RestController
public class GreetingController {
    private final GreetingService service;

    public GreetingController(GreetingService service) {
        this.service = service;
    }

    @GetMapping("/hello")
    public String hello() {
        return service.greet();
    }
}
```

Spring injects a `GreetingService` bean into the controller without manual `new` calls.

## 2. Creating REST Endpoints Quickly (Junior)

**Question:** How do you expose REST endpoints quickly in Spring Boot?

**Answer:** Annotate a class with `@RestController`, map request paths using `@GetMapping`, `@PostMapping`, or similar annotations, and return domain objects or DTOs. Spring MVC handles JSON serialization and request parsing automatically.

**Example:**

```java
@PostMapping("/users")
public ResponseEntity<UserDto> createUser(@RequestBody CreateUserRequest request) {
    UserDto user = userService.create(request);
    return ResponseEntity.status(HttpStatus.CREATED).body(user);
}
```

The method declares routing, validation input, and the response contract with minimal code.

## 3. Asynchronous Processing (Middle)

**Question:** How would you handle async processing of long-running tasks?

**Answer:** Enable asynchronous execution with `@EnableAsync`, annotate methods with `@Async` to run in a task executor, and return `CompletableFuture` or `ListenableFuture` for result tracking. For durable workloads, pair async methods with message brokers or scheduling.

**Example:**

```java
@Service
public class ReportService {
    @Async
    public CompletableFuture<Report> generateReport(Long id) {
        Report report = heavyComputation(id);
        return CompletableFuture.completedFuture(report);
    }
}
```

The `generateReport` method runs on a separate thread pool, allowing HTTP handlers to respond immediately and poll for completion.

## 4. Resilient Inter-Service Communication (Middle)

**Question:** Explain resilient communication between microservices.

**Answer:** Combine client-side timeouts, retries with jitter, circuit breakers, bulkheads, and fallbacks to handle downstream instability. Observability (metrics, logs, tracing) and idempotent operations ensure recovery from transient failures.

**Example:**

```java
@Bean
public Customizer<Resilience4JCircuitBreakerFactory> circuitBreakerCustomizer() {
    return factory -> factory.configureDefault(id -> new Resilience4JConfigBuilder(id)
        .timeLimiterConfig(TimeLimiterConfig.custom().timeoutDuration(Duration.ofSeconds(2)).build())
        .circuitBreakerConfig(CircuitBreakerConfig.ofDefaults())
        .build());
}
```

The circuit breaker enforces timeouts and failure thresholds for outbound calls, protecting the service under load.
