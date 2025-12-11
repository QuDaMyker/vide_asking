# Backend Engineering Interview Questions (Junior & Middle)

## 1. Eventual Consistency (Junior)

**Question:** What is eventual consistency?

**Answer:** Eventual consistency means writes propagate asynchronously, so reads may briefly observe stale data. Systems adopt it to prioritize availability and partition tolerance at the cost of temporary divergence.

**Example:**

```text
A user updates their profile photo. The write hits a primary region immediately, but the CDN node serving another region updates a few seconds later. During that window, readers may still get the old photo, yet the system converges without a global lock.
```

The example highlights how geo-replicated services tolerate small staleness windows to maintain uptime.

## 2. Caching Benefits (Junior)

**Question:** How does caching improve backend performance?

**Answer:** Caches store recently computed or fetched results, cutting latency, relieving databases, and lowering costs. The trade-offs are eviction, invalidation complexity, and ensuring data freshness.

**Example:**

```text
An API layer stores product details in Redis with a 60-second TTL. Popular items become cache hits, reducing database queries from thousands per second to a handful, while stale data expires quickly.
```

The cache absorbs read bursts and shields the primary database.

## 3. Designing a Rate Limiter (Middle)

**Question:** Walk through designing a rate limiter for an API.

**Answer:** Choose an algorithm like token bucket, store per-identity counters (often in Redis), enforce quotas atomically, and return 429 responses when limits exceed. Include distributed locking or Lua scripts to avoid race conditions, and expose metrics for tuning.

**Example:**

```text
Use Redis with a Lua script that removes tokens from a bucket key `bucket:user123`. If the script returns a positive count, the request proceeds; otherwise, it responds with HTTP 429 and a `Retry-After` header. Horizontal API pods share the same Redis store, ensuring consistent enforcement.
```

The token bucket balances burst tolerance with sustained throughput limits.

## 4. Debugging High Latency (Middle)

**Question:** How would you debug high latency in a distributed request path?

**Answer:** Capture distributed traces, inspect spans for slow hops, correlate with metrics (CPU, GC, queue depth), and inspect logs for errors. Focus on anomaly detection, verify resource saturation, and experiment with caching, partitioning, or capacity adjustments.

**Example:**

```text
A checkout request shows a 2-second spike in Jaeger traces. The slow span targets the inventory service, whose CPU dashboards reveal 90% utilization and queue backlog. Scaling the deployment and adding connection pooling restores latency to 150 ms.
```

Tracing surfaces the bottleneck, allowing targeted mitigation.

## 5. Idempotent APIs (Junior)

**Question:** Why is idempotency important for backend endpoints?

**Answer:** Idempotent operations produce the same result when retried, which is critical when clients repeat requests due to timeouts or network failures. Implementing idempotency prevents duplicate side effects like double billing.

**Example:**

```text
A payment API requires an `Idempotency-Key` header. The server stores request hashes in Redis keyed by customer and key value. Retries with the same key return the cached response instead of recharging the card.
```

This approach tolerates client retries triggered by flaky networks.

## 6. Backpressure Strategies (Middle)

**Question:** How do you apply backpressure in high-concurrency systems?

**Answer:** Limit queue sizes, reject or shed load with HTTP 429/503 responses, slow producers via adaptive throttling, and leverage bounded worker pools. Monitoring queue depth and latency guides adjustments.

**Example:**

```text
An order ingestion service caps its Kafka consumer poll to 10k messages and uses a worker pool of 200 goroutines. When the job channel fills, new messages pause until capacity frees, preventing database overload.
```

The system remains stable even when upstream sends bursts of traffic.

## 7. Event Sourcing Trade-offs (Middle)

**Question:** What benefits and challenges come with event sourcing?

**Answer:** Event sourcing stores immutable events, enabling rebuilds of state, audit trails, and temporal queries. Challenges include handling schema evolution, ensuring idempotent consumers, and crafting read projections for queries.

**Example:**

```text
The ledger service saves `OrderCreated` and `OrderPaid` events. A projector consumes them to maintain a balance read model. If a bug occurs, developers replay the event log into a new projector version to regenerate accurate balances.
```

Replayability simplifies recovery but requires thoughtful versioning.

## 8. API Versioning (Junior)

**Question:** How should you approach API versioning?

**Answer:** Maintain backwards compatibility by versioning URIs (`/v1/orders`), headers, or query parameters. Deprecate old versions gradually, communicate timelines, and keep documentation synchronized.

**Example:**

```text
The platform introduces `/v2/orders` with async processing fields. Clients opt-in by calling the new path while `/v1` continues to operate until a sunset date announced in API changelogs.
```

Versioning isolates breaking changes and gives consumers time to migrate.

## 9. Message Queue vs Direct Calls (Middle)

**Question:** When do you choose asynchronous messaging over synchronous HTTP?

**Answer:** Use queues for workflows that can tolerate eventual consistency, require buffering, or fan-out to multiple consumers. Keep synchronous calls for low-latency, user-facing operations that demand immediate confirmation.

**Example:**

```text
Creating an invoice triggers a synchronous response indicating acceptance, then publishes an `invoice.created` event to process tax calculations asynchronously in separate services.
```

Combining patterns keeps the UI snappy and decouples heavy background work.

## 10. Observability Pillars (Middle)

**Question:** What observability pillars should backends implement?

**Answer:** Metrics track quantitative trends, logs capture contextual events, and traces map request flows. Together with structured events and dashboards, they enable quick incident response and capacity planning.

**Example:**

```text
The team instruments Prometheus metrics for latency percentiles, sends JSON logs to ELK, and exports OpenTelemetry traces to Tempo. During an outage, SREs correlate increased 500s with spikes in database latency visible across dashboards.
```

Combining data sources shortens mean time to detect and resolve incidents.
