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
