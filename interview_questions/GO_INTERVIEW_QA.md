# Go Interview Questions (Junior & Middle)

## 1. Goroutines vs OS Threads (Junior)

**Question:** How do goroutines differ from OS threads, and why are they useful?

**Answer:** Goroutines are lightweight user-space threads scheduled by the Go runtime. They use smaller, growable stacks and multiplex onto a small set of OS threads, allowing the runtime to schedule millions efficiently. This makes high-concurrency workloads practical without manual thread management.

**Example:**

```go
func main() {
    for i := 0; i < 1_000; i++ {
        go func(id int) {
            fmt.Printf("worker %d\n", id)
        }(i)
    }
    time.Sleep(100 * time.Millisecond)
}
```

The program launches a thousand goroutines with minimal overhead, something not feasible with raw OS threads in most environments.

## 2. Buffered Channels (Junior)

**Question:** What is a buffered channel and when would you use it?

**Answer:** A buffered channel has capacity to hold a fixed number of values before a sender blocks. It is useful for smoothing bursts, decoupling producers/consumers, or providing limited queueing without an external buffer.

**Example:**

```go
tasks := make(chan int, 5) // buffered so producers can enqueue a handful quickly
for i := 0; i < 5; i++ {
    tasks <- i
}
close(tasks)
for job := range tasks {
    fmt.Println("processing", job)
}
```

The producer fills the buffer and can finish without waiting for the consumer, absorbing a short burst.

## 3. Preventing Data Races (Middle)

**Question:** How would you prevent data races when multiple goroutines mutate shared state?

**Answer:** Guard shared state with synchronization primitives such as `sync.Mutex` or `sync.RWMutex`, or enforce ownership so only one goroutine mutates the data while others communicate via channels. Both approaches prevent simultaneous access that could corrupt state.

**Example:**

```go
type counter struct {
    mu sync.Mutex
    n  int
}

func (c *counter) Inc() {
    c.mu.Lock()
    c.n++
    c.mu.Unlock()
}
```

Locking ensures each increment happens atomically even under heavy concurrency.

## 4. Worker Pool Pattern (Middle)

**Question:** Describe a worker pool pattern in Go and its benefit.

**Answer:** Spawn a fixed number of worker goroutines that read tasks from a channel and push results to another channel or shared sink. A worker pool bounds concurrency, distributes load evenly, and provides a single place to apply backpressure.


**Example:**

```go
jobs := make(chan int)
results := make(chan int)
var wg sync.WaitGroup
for w := 0; w < 4; w++ {
    wg.Add(1)
    go func() {
        defer wg.Done()
        for job := range jobs {
            results <- job * 2
        }
    }()
}
go func() {
    for i := 0; i < 10; i++ {
        jobs <- i
    }
    close(jobs)
    wg.Wait()
    close(results)
}()
```

Four workers process ten jobs in parallel while respecting the concurrency limit.

## 5. Coordinating Goroutines with WaitGroup (Junior)

**Question:** How does `sync.WaitGroup` help coordinate goroutines?

**Answer:** `WaitGroup` tracks the completion of multiple goroutines. The main goroutine increments the counter before launching work, each worker calls `Done()` when finished, and `Wait()` blocks until the counter returns to zero, ensuring orderly shutdowns.

**Example:**

```go
var wg sync.WaitGroup
urls := []string{"https://api1", "https://api2"}
wg.Add(len(urls))
for _, url := range urls {
    go func(u string) {
        defer wg.Done()
        fetch(u)
    }(url)
}
wg.Wait()
```

The program waits for every fetch goroutine to complete before exiting the process.

## 6. Using `select` for Multiplexing (Junior)

**Question:** What does the `select` statement provide in Go?

**Answer:** `select` listens to multiple channel operations simultaneously, proceeding with whichever case becomes ready first. It is essential for implementing timeouts, cancellation, and fan-in patterns without busy waiting.

**Example:**

```go
select {
case msg := <-dataChan:
    fmt.Println("received", msg)
case <-time.After(200 * time.Millisecond):
    fmt.Println("timed out")
}
```

The timeout case prevents the goroutine from blocking indefinitely when no data arrives.

## 7. Context Cancellation (Middle)

**Question:** How do contexts help with cancellation and timeouts?

**Answer:** `context.Context` propagates cancellation signals and deadlines across goroutines. Functions accept a context, check `Done()`, and abort work when the caller cancels or the deadline expires, freeing resources promptly.

**Example:**

```go
ctx, cancel := context.WithTimeout(context.Background(), time.Second)
defer cancel()
req, _ := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
resp, err := http.DefaultClient.Do(req)
```

If the request exceeds one second, the context cancels the HTTP call and the goroutine returns early.

## 8. Error Wrapping (Middle)

**Question:** How do you wrap and inspect errors in Go?

**Answer:** Use `fmt.Errorf("...: %w", err)` to wrap errors, preserving the original for introspection. Consumers use `errors.Is` or `errors.As` to check for specific sentinel errors while retaining contextual information.

**Example:**

```go
if err := db.Save(user); err != nil {
    return fmt.Errorf("saving user %s: %w", user.ID, err)
}
```

Callers can detect `sql.ErrNoRows` with `errors.Is(err, sql.ErrNoRows)` while logging the added context.

## 9. Interfaces and Decoupling (Junior)

**Question:** Why are interfaces important in Go applications?

**Answer:** Interfaces define behavior contracts decoupled from concrete types, enabling dependency injection, mocking in tests, and plug-and-play implementations without inheritance.

**Example:**

```go
type Storage interface {
    Save(ctx context.Context, item Item) error
}

func Process(ctx context.Context, s Storage, item Item) error {
    return s.Save(ctx, item)
}
```

Code depends on the `Storage` contract, so a file-backed or cloud-backed implementation can be substituted easily.

## 10. Bounded Concurrency with Semaphores (Middle)

**Question:** How do you limit concurrency for resource-heavy operations?

**Answer:** Create a buffered channel acting as a semaphore. Workers acquire a slot before starting work and release it on completion. This bounds simultaneous operations, protecting downstream systems.

**Example:**

```go
sem := make(chan struct{}, 5)
for _, job := range jobs {
    sem <- struct{}{}
    go func(j Job) {
        defer func() { <-sem }()
        process(j)
    }(job)
}
```

Only five jobs run concurrently, even if hundreds are queued.
