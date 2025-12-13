# PostgreSQL Interview Questions (Junior & Middle)

## 1. JOIN Semantics (Junior)

**Question:** What is the difference between `INNER JOIN` and `LEFT JOIN`?

**Answer:** `INNER JOIN` only returns rows with matching keys in both tables, while `LEFT JOIN` preserves all rows from the left table and fills missing columns from the right table with `NULL` when no match exists.

**Example:**

```sql
SELECT u.id, u.email, o.total
FROM users u
LEFT JOIN orders o ON o.user_id = u.id;
```

Every user row appears exactly once even if they have no orders, which would be omitted by an `INNER JOIN`.

## 2. Transaction Guarantees (Junior)

**Question:** How do transactions ensure consistency?

**Answer:** Transactions provide ACID properties: atomicity (all-or-nothing), consistency (constraints preserved), isolation (concurrent transactions act as if serialized), and durability (committed data survives crashes). PostgreSQL enforces isolation via MVCC and WAL.

**Example:**

```sql
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;
```

If any statement fails, the whole transfer rolls back, keeping balances consistent.

## 3. Handling High Write Concurrency (Middle)

**Question:** How do you handle high write concurrency on a table?

**Answer:** Spread writes across partitions or shards to avoid hot rows, batch operations, use prepared statements, and ensure appropriate indexing. Consider queueing writes via message brokers and apply advisory locks for critical sections to prevent contention.

**Example:**

```sql
CREATE TABLE events_2025 PARTITION OF events
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
```

Partitioning spreads inserts across child tables, reducing lock contention on a single heap.

## 4. Optimizing Slow Queries (Middle)

**Question:** How do you optimize a slow query?

**Answer:** Use `EXPLAIN ANALYZE` to find bottlenecks, add or adjust indexes, rewrite joins or filters, limit returned columns, and tune planner settings (e.g., `work_mem`). Caching results or using materialized views can help when recalculation is expensive.

**Example:**

```sql
EXPLAIN ANALYZE
SELECT * FROM orders
WHERE status = 'SHIPPED' AND shipped_at >= now() - interval '7 days';
```

The plan reveals whether a sequential scan or index scan executes, guiding whether to create an index on `(status, shipped_at)`.

## 5. Index Selection (Junior)

**Question:** What index types does PostgreSQL offer and when do you use them?

**Answer:** B-tree indexes cover equality and range queries, hash indexes suit equality-only cases, GIN indexes handle array/JSONB containment and full-text search, and BRIN indexes summarize large, naturally ordered tables. Choosing the right index aligns with query patterns.

**Example:**

```sql
CREATE INDEX idx_orders_status_shipped_at
    ON orders USING btree (status, shipped_at);
```

The composite B-tree accelerates status filters combined with recent ship dates.

## 6. MVCC Behavior (Middle)

**Question:** How does PostgreSQL's MVCC manage concurrency?

**Answer:** Multi-Version Concurrency Control keeps multiple row versions, allowing readers to see a snapshot while writers update new tuples. Vacuum cleans dead tuples, preventing bloat, while isolation levels dictate visibility rules.

**Example:**

```sql
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM accounts WHERE id = 1; -- snapshot view
```

The transaction sees a consistent snapshot even if another session updates the row concurrently.

## 7. Connection Pooling (Middle)

**Question:** Why is connection pooling important?

**Answer:** PostgreSQL spawns a server process per connection, so opening thousands of connections exhausts memory and CPU. Poolers like PgBouncer multiplex logical sessions onto fewer physical connections, reducing overhead and smoothing bursty traffic.

**Example:**

```text
PgBouncer runs in transaction pooling mode with a max of 200 server connections, serving 2,000 client sessions without overwhelming the database backend.
```

Pooling stabilizes throughput under high concurrency workloads.

## 8. Replication and Failover (Middle)

**Question:** How do streaming replicas work in PostgreSQL?

**Answer:** Primaries ship WAL segments to replicas over streaming replication. Replicas apply changes asynchronously (or synchronously if configured) and can serve read-only queries. Failover promotes a replica to primary when the original fails.

**Example:**

```text
`primary_conninfo = 'host=primary port=5432 user=replicator password=secret'` in recovery.conf enables a standby to stream WAL and stay within seconds of the primary.
```

Synchronous replicas can guarantee zero data loss at the cost of write latency.

## 9. Partitioning vs. Sharding (Middle)

**Question:** How does table partitioning differ from sharding?

**Answer:** Partitioning splits a single logical table into child tables managed by one database server, simplifying maintenance and pruning. Sharding distributes data across multiple servers, improving horizontal scalability but requiring application awareness.

**Example:**

```sql
CREATE TABLE measurements (device_id int, recorded_at timestamptz, value numeric)
    PARTITION BY RANGE (recorded_at);
```

Partitioning keeps queries fast within one cluster, while sharding might divide devices across separate clusters entirely.

## 10. Handling Deadlocks (Middle)

**Question:** How do you detect and resolve deadlocks?

**Answer:** PostgreSQL detects deadlocks automatically and aborts one transaction, returning `ERROR: deadlock detected`. To prevent them, lock tables in consistent order, keep transactions short, and use `NOWAIT` or `SKIP LOCKED` when appropriate.

**Example:**

```sql
SELECT * FROM jobs WHERE status = 'pending' FOR UPDATE SKIP LOCKED LIMIT 1;
```

Workers claim pending jobs without waiting on rows another worker already locked, reducing deadlock risk.
