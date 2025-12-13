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

## 5. Configuration Profiles (Junior)

**Question:** How do Spring profiles help manage configuration?

**Answer:** Profiles like `dev` or `prod` let you activate different bean sets and property files per environment. Spring loads `application-{profile}.yaml` when the profile is active, keeping secrets and infrastructure endpoints isolated.

**Example:**

```yaml
spring:
  profiles: dev
datasource:
  url: jdbc:postgresql://localhost/devdb
```

Running with `--spring.profiles.active=dev` picks up the development datasource settings.

## 6. Bean Validation (Junior)

**Question:** How do you validate request payloads?

**Answer:** Annotate DTO fields with Jakarta Bean Validation constraints (`@NotBlank`, `@Email`), add `@Valid` to controller method parameters, and Spring automatically returns 400 responses when validation fails.

**Example:**

```java
public record CreateUserRequest(@NotBlank String name, @Email String email) {}

@PostMapping("/users")
public ResponseEntity<UserDto> create(@Valid @RequestBody CreateUserRequest req) {
    return ResponseEntity.ok(service.create(req));
}
```

The framework rejects invalid input before hitting business logic.

## 7. Transaction Management (Middle)

**Question:** How do you ensure transactional integrity in Spring Boot?

**Answer:** Annotate service methods with `@Transactional` so Spring creates proxies that start, commit, or roll back transactions automatically. You can configure isolation or propagation to control concurrency behavior.

**Example:**

```java
@Service
public class PaymentService {
    @Transactional(isolation = Isolation.REPEATABLE_READ)
    public void transfer(long from, long to, BigDecimal amount) {
        accountRepo.debit(from, amount);
        accountRepo.credit(to, amount);
    }
}
```

Both debit and credit operations succeed or fail together even under concurrent access.

## 8. Centralized Exception Handling (Middle)

**Question:** How do you expose consistent error responses?

**Answer:** Use `@ControllerAdvice` with `@ExceptionHandler` methods to map exceptions to HTTP responses. This centralizes logging, status codes, and error payloads outside controllers.

**Example:**

```java
@ControllerAdvice
public class ApiErrorHandler {
    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<ApiError> handleNotFound(NotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body(new ApiError("NOT_FOUND", ex.getMessage()));
    }
}
```

All `NotFoundException` occurrences now return a standardized 404 body.

## 9. Caching Responses (Middle)

**Question:** How do you cache expensive method results?

**Answer:** Enable caching with `@EnableCaching`, annotate methods with `@Cacheable`, and configure a cache manager (e.g., Redis, Caffeine). Spring stores results keyed by method arguments and returns cached values on subsequent calls.

**Example:**

```java
@Cacheable(value = "pricing", key = "#productId")
public PriceDto getPrice(String productId) {
    return pricingClient.fetch(productId);
}
```

Repeated price lookups hit the cache instead of the remote service, reducing latency.

## 10. Testing Controllers (Middle)

**Question:** How do you test REST controllers effectively?

**Answer:** Use `@WebMvcTest` with `MockMvc` to slice-test controllers without starting the full server. Mock dependencies and perform HTTP-like requests to assert status codes and payloads.

**Example:**

```java
@WebMvcTest(GreetingController.class)
class GreetingControllerTest {
    @Autowired
    private MockMvc mockMvc;

    @Test
    void helloReturns200() throws Exception {
        mockMvc.perform(get("/hello"))
            .andExpect(status().isOk())
            .andExpect(content().string("hi"));
    }
}
```

The test verifies controller behavior quickly without deploying a full application context.
