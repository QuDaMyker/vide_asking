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
