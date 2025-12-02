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
