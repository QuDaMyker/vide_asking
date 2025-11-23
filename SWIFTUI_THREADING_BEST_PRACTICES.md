# SwiftUI Threading Best Practices

## Table of Contents
- [Overview](#overview)
- [Modern Concurrency (Swift 5.5+)](#modern-concurrency-swift-55)
- [Legacy Threading (GCD)](#legacy-threading-gcd)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Anti-Patterns to Avoid](#anti-patterns-to-avoid)

---

## Overview

### Thread Management Hierarchy (Preferred Order)

1. **`Task` / `async-await`** - Modern, structured concurrency (PREFERRED)
2. **`Task.detached`** - Unstructured tasks when needed
3. **`DispatchQueue`** - Legacy GCD for specific use cases
4. **`Dispatch` barriers/groups** - Advanced synchronization

---

## Modern Concurrency (Swift 5.5+)

### ✅ 1. Task - Structured Concurrency (BEST)

**Use When:**
- Performing async operations in SwiftUI views
- Need automatic cancellation when view disappears
- Working with modern async/await APIs

```swift
struct UserProfileView: View {
    @State private var user: User?
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            if let user = user {
                Text(user.name)
            }
        }
        .task {
            // ✅ Automatically cancelled when view disappears
            await loadUser()
        }
    }
    
    func loadUser() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Network call runs on background thread
            let fetchedUser = try await APIClient.shared.fetchUser()
            
            // ✅ State update automatically on MainActor
            self.user = fetchedUser
        } catch {
            print("Error: \(error)")
        }
    }
}
```

**Key Benefits:**
- ✅ Automatic cancellation on view dismissal
- ✅ Inherits context (MainActor) from parent
- ✅ Structured cancellation propagation
- ✅ Better error handling with try/catch

---

### ⚠️ 2. Task { } - Manual Task Creation

**Use When:**
- Responding to button taps or user actions
- Need to bridge sync code to async code
- Starting background work from synchronous context

```swift
struct PhotoUploadView: View {
    @State private var uploadStatus: String = ""
    
    var body: some View {
        VStack {
            Button("Upload Photo") {
                // ✅ Create task for async work
                Task {
                    await uploadPhoto()
                }
            }
            
            Text(uploadStatus)
        }
    }
    
    func uploadPhoto() async {
        uploadStatus = "Uploading..."
        
        do {
            // Heavy work on background thread
            let result = try await uploadToServer()
            
            // ✅ UI update on main thread (inherited MainActor)
            uploadStatus = "Success: \(result.id)"
        } catch {
            uploadStatus = "Failed: \(error.localizedDescription)"
        }
    }
}
```

**Task Priority:**
```swift
// High priority for user-facing work
Task(priority: .high) {
    await loadCriticalData()
}

// Low priority for background sync
Task(priority: .low) {
    await syncCache()
}
```

---

### 🔧 3. Task.detached - Unstructured Concurrency

**Use When:**
- Need to break out of MainActor context
- Long-running background work that shouldn't block UI
- Don't need automatic cancellation
- Processing large data sets

```swift
final class DataProcessor: ObservableObject {
    @Published var progress: Double = 0
    
    func processLargeDataset(_ data: [Data]) async {
        // ✅ Runs on background thread pool
        Task.detached { [weak self] in
            var processed = 0
            
            for item in data {
                // Heavy processing
                await self?.processItem(item)
                processed += 1
                
                // ✅ Update UI on main thread
                await MainActor.run {
                    self?.progress = Double(processed) / Double(data.count)
                }
            }
        }
    }
    
    private func processItem(_ data: Data) async {
        // CPU-intensive work
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
}
```

**Task vs Task.detached:**
```swift
// ❌ BAD: Blocks main thread
func loadData() {
    Task { @MainActor in
        // This runs on main thread - might block UI
        let result = heavyComputation()
    }
}

// ✅ GOOD: Runs on background
func loadData() {
    Task.detached {
        let result = await heavyComputation()
        
        // Explicitly return to main for UI update
        await MainActor.run {
            self.data = result
        }
    }
}
```

---

### 🎯 4. MainActor - Ensuring Main Thread

**Use When:**
- Need to guarantee code runs on main thread
- Updating UI from background contexts
- Publishing changes to @Published properties

```swift
// ✅ BEST: Mark entire class
@MainActor
final class UserViewModel: ObservableObject {
    @Published var users: [User] = []
    
    func loadUsers() async {
        // Runs on main thread (inherited MainActor)
        let fetchedUsers = await fetchFromBackground()
        self.users = fetchedUsers // ✅ Safe
    }
    
    nonisolated func fetchFromBackground() async -> [User] {
        // This runs on background thread
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return []
    }
}
```

**Explicit MainActor:**
```swift
func updateUI() {
    Task {
        // Background work
        let data = await fetchData()
        
        // ✅ Explicitly switch to main
        await MainActor.run {
            self.displayData = data
            self.isLoading = false
        }
    }
}
```

---

## Legacy Threading (GCD)

### 📦 5. DispatchQueue - Grand Central Dispatch

**Use When:**
- Working with legacy code/APIs
- Need fine-grained queue control
- Synchronous operations
- No async/await available

#### Main Queue - UI Updates

```swift
class LegacyViewModel: ObservableObject {
    @Published var items: [Item] = []
    
    func loadItems() {
        // ⚠️ Legacy pattern
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchedItems = self.fetchItemsSync()
            
            // ✅ MUST return to main for UI
            DispatchQueue.main.async {
                self.items = fetchedItems
            }
        }
    }
    
    func fetchItemsSync() -> [Item] {
        // Synchronous network/DB call
        return []
    }
}
```

#### Background Queue - Heavy Processing

```swift
// Quality of Service levels
DispatchQueue.global(qos: .userInitiated).async {
    // User-initiated work (0.5s)
}

DispatchQueue.global(qos: .utility).async {
    // Long-running work (seconds to minutes)
}

DispatchQueue.global(qos: .background).async {
    // Background maintenance (minutes to hours)
}
```

---

### 🔒 6. Dispatch Barriers - Thread-Safe Access

**Use When:**
- Multiple readers, single writer pattern
- Thread-safe data access
- Protecting shared mutable state

```swift
final class ThreadSafeCache<Key: Hashable, Value> {
    private var cache: [Key: Value] = [:]
    private let queue = DispatchQueue(
        label: "com.app.cache",
        attributes: .concurrent
    )
    
    // ✅ Multiple readers can access simultaneously
    func get(_ key: Key) -> Value? {
        queue.sync {
            return cache[key]
        }
    }
    
    // ✅ Writer gets exclusive access
    func set(_ value: Value, forKey key: Key) {
        queue.async(flags: .barrier) {
            self.cache[key] = value
        }
    }
}
```

---

### 👥 7. DispatchGroup - Coordinating Multiple Tasks

**Use When:**
- Need to wait for multiple async operations
- Coordinating parallel work
- Legacy code without async/await

```swift
class BatchProcessor {
    func processBatch(items: [Item], completion: @escaping ([Result]) -> Void) {
        let group = DispatchGroup()
        var results: [Result] = []
        let resultsQueue = DispatchQueue(label: "results.sync")
        
        for item in items {
            group.enter()
            
            DispatchQueue.global().async {
                let result = self.process(item)
                
                resultsQueue.async {
                    results.append(result)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
}
```

**Modern Equivalent:**
```swift
// ✅ BETTER: Use async/await
func processBatch(items: [Item]) async -> [Result] {
    await withTaskGroup(of: Result.self) { group in
        for item in items {
            group.addTask {
                await self.process(item)
            }
        }
        
        var results: [Result] = []
        for await result in group {
            results.append(result)
        }
        return results
    }
}
```

---

## Best Practices

### ✅ DO's

#### 1. Use `.task` for View Lifecycle
```swift
struct ContentView: View {
    @State private var data: [Item] = []
    
    var body: some View {
        List(data) { item in
            Text(item.name)
        }
        .task {
            // ✅ Automatically cancelled when view disappears
            data = await fetchData()
        }
    }
}
```

#### 2. Mark ViewModels with @MainActor
```swift
@MainActor
final class ContentViewModel: ObservableObject {
    @Published var items: [Item] = []
    
    func refresh() async {
        // All code runs on main thread by default
        items = await fetchItems()
    }
}
```

#### 3. Use Task Priority
```swift
// User-facing work
Task(priority: .high) {
    await loadCriticalData()
}

// Background sync
Task(priority: .low) {
    await syncAnalytics()
}
```

#### 4. Handle Cancellation
```swift
func performLongOperation() async throws {
    for i in 0..<1000 {
        // ✅ Check for cancellation
        try Task.checkCancellation()
        
        await processItem(i)
    }
}
```

#### 5. Use AsyncSequence for Streams
```swift
struct NotificationView: View {
    @State private var messages: [String] = []
    
    var body: some View {
        List(messages, id: \.self) { Text($0) }
            .task {
                // ✅ Process stream of notifications
                for await notification in NotificationCenter.default
                    .notifications(named: .newMessage)
                {
                    messages.append(notification.object as! String)
                }
            }
    }
}
```

---

### ❌ DON'Ts

#### 1. DON'T Block Main Thread
```swift
// ❌ BAD: Blocks UI
func loadData() {
    let data = URLSession.shared.data(from: url) // Synchronous
    self.data = data
}

// ✅ GOOD: Async
func loadData() async {
    let (data, _) = try? await URLSession.shared.data(from: url)
    self.data = data
}
```

#### 2. DON'T Update UI from Background
```swift
// ❌ BAD: Crashes or undefined behavior
DispatchQueue.global().async {
    self.isLoading = false // @Published property
}

// ✅ GOOD: Update on main
DispatchQueue.global().async {
    DispatchQueue.main.async {
        self.isLoading = false
    }
}

// ✅ BETTER: Use async/await
Task.detached {
    await MainActor.run {
        self.isLoading = false
    }
}
```

#### 3. DON'T Mix Patterns Unnecessarily
```swift
// ❌ BAD: Mixing GCD with async/await
func loadData() async {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            let result = self.fetch()
            continuation.resume(returning: result)
        }
    }
}

// ✅ GOOD: Pure async/await
func loadData() async -> Data {
    return await fetch()
}
```

#### 4. DON'T Forget Weak Self in Detached Tasks
```swift
// ❌ BAD: Retain cycle
Task.detached {
    await self.processData() // Strong reference
}

// ✅ GOOD: Weak capture
Task.detached { [weak self] in
    await self?.processData()
}
```

#### 5. DON'T Overuse Task.detached
```swift
// ❌ BAD: Unnecessary detachment
Button("Load") {
    Task.detached {
        await loadData() // Could use regular Task
    }
}

// ✅ GOOD: Regular Task inherits context
Button("Load") {
    Task {
        await loadData()
    }
}
```

---

## Common Patterns

### 1. Image Loading with Caching

```swift
@MainActor
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private static let cache = NSCache<NSURL, UIImage>()
    
    func load(url: URL) async {
        // Check cache on main thread (fast)
        if let cached = Self.cache.object(forKey: url as NSURL) {
            self.image = cached
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // ✅ Network fetch happens on background
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let loadedImage = UIImage(data: data) else {
            return
        }
        
        // Cache and update UI on main thread
        Self.cache.setObject(loadedImage, forKey: url as NSURL)
        self.image = loadedImage
    }
}

// Usage
struct AsyncImageView: View {
    @StateObject private var loader = ImageLoader()
    let url: URL
    
    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
            } else if loader.isLoading {
                ProgressView()
            }
        }
        .task {
            await loader.load(url: url)
        }
    }
}
```

---

### 2. Parallel Data Fetching

```swift
struct DashboardViewModel {
    func loadDashboard() async -> Dashboard {
        // ✅ Fetch multiple resources in parallel
        async let user = fetchUser()
        async let posts = fetchPosts()
        async let notifications = fetchNotifications()
        
        return await Dashboard(
            user: user,
            posts: posts,
            notifications: notifications
        )
    }
}
```

---

### 3. Debounced Search

```swift
@MainActor
final class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var results: [Item] = []
    
    private var searchTask: Task<Void, Never>?
    
    func search() {
        // Cancel previous search
        searchTask?.cancel()
        
        searchTask = Task {
            // ✅ Debounce
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            
            guard !Task.isCancelled else { return }
            
            // Perform search
            let query = searchText
            let items = await performSearch(query)
            
            guard !Task.isCancelled else { return }
            results = items
        }
    }
}
```

---

### 4. Progress Reporting

```swift
@MainActor
final class UploadViewModel: ObservableObject {
    @Published var progress: Double = 0
    @Published var status: String = ""
    
    func uploadFiles(_ files: [URL]) async {
        let total = Double(files.count)
        
        for (index, file) in files.enumerated() {
            status = "Uploading \(index + 1) of \(files.count)"
            
            // ✅ Heavy work on background
            await Task.detached {
                try? await self.upload(file)
            }.value
            
            // UI update on main (inherited @MainActor)
            progress = Double(index + 1) / total
        }
        
        status = "Complete"
    }
}
```

---

### 5. Retry Logic

```swift
func fetchWithRetry<T>(
    maxRetries: Int = 3,
    operation: @escaping () async throws -> T
) async throws -> T {
    for attempt in 0..<maxRetries {
        do {
            return try await operation()
        } catch {
            if attempt == maxRetries - 1 {
                throw error
            }
            
            // ✅ Exponential backoff
            let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
            try await Task.sleep(nanoseconds: delay)
        }
    }
    
    fatalError("Unreachable")
}

// Usage
let data = try await fetchWithRetry {
    try await URLSession.shared.data(from: url)
}
```

---

## Anti-Patterns to Avoid

### ❌ 1. Serial Processing When Parallel is Possible

```swift
// ❌ BAD: Processes one at a time (slow)
func processItems(_ items: [Item]) async -> [Result] {
    var results: [Result] = []
    for item in items {
        let result = await process(item)
        results.append(result)
    }
    return results
}

// ✅ GOOD: Process in parallel
func processItems(_ items: [Item]) async -> [Result] {
    await withTaskGroup(of: Result.self) { group in
        for item in items {
            group.addTask { await self.process(item) }
        }
        
        var results: [Result] = []
        for await result in group {
            results.append(result)
        }
        return results
    }
}
```

---

### ❌ 2. Nested Dispatch Queues

```swift
// ❌ BAD: Callback hell
DispatchQueue.global().async {
    let data1 = fetch1()
    DispatchQueue.main.async {
        self.data1 = data1
        DispatchQueue.global().async {
            let data2 = fetch2()
            DispatchQueue.main.async {
                self.data2 = data2
            }
        }
    }
}

// ✅ GOOD: Clean async/await
Task {
    let data1 = await fetch1()
    self.data1 = data1
    let data2 = await fetch2()
    self.data2 = data2
}
```

---

### ❌ 3. Ignoring Cancellation

```swift
// ❌ BAD: Continues even when cancelled
func longOperation() async {
    for i in 0..<10000 {
        await process(i) // Waste of resources if cancelled
    }
}

// ✅ GOOD: Respects cancellation
func longOperation() async throws {
    for i in 0..<10000 {
        try Task.checkCancellation()
        await process(i)
    }
}
```

---

### ❌ 4. Creating Too Many Tasks

```swift
// ❌ BAD: Creates 10,000 tasks
for item in items { // items.count = 10,000
    Task {
        await process(item)
    }
}

// ✅ GOOD: Controlled concurrency
await withTaskGroup(of: Void.self) { group in
    for item in items {
        // TaskGroup manages concurrency automatically
        group.addTask { await self.process(item) }
    }
}
```

---

## Decision Flow Chart

```
Need to run async work?
│
├─ In SwiftUI View lifecycle?
│  └─ ✅ Use .task { }
│
├─ From button tap or user action?
│  └─ ✅ Use Task { }
│
├─ Heavy CPU work that might block UI?
│  └─ ✅ Use Task.detached { }
│
├─ Working with legacy sync APIs?
│  └─ ✅ Use DispatchQueue.global().async { }
│
├─ Need thread-safe data structure?
│  └─ ✅ Use DispatchQueue with barriers
│
└─ Coordinating multiple operations?
   └─ ✅ Use TaskGroup or async let
```

---

## Quick Reference

| Use Case | Solution | Priority |
|----------|----------|----------|
| View lifecycle | `.task { }` | ⭐⭐⭐⭐⭐ |
| Button actions | `Task { }` | ⭐⭐⭐⭐⭐ |
| Heavy processing | `Task.detached { }` | ⭐⭐⭐⭐ |
| UI updates | `@MainActor` | ⭐⭐⭐⭐⭐ |
| Parallel work | `async let` / `TaskGroup` | ⭐⭐⭐⭐⭐ |
| Legacy APIs | `DispatchQueue` | ⭐⭐⭐ |
| Thread safety | Barriers / Actors | ⭐⭐⭐⭐ |
| Coordinating ops | `DispatchGroup` (legacy) | ⭐⭐ |

---

## Performance Tips

1. **Avoid excessive Task creation** - Use TaskGroup for batching
2. **Use appropriate QoS/Priority** - Match importance to work type
3. **Cache expensive operations** - Especially image/data loading
4. **Debounce user input** - Cancel previous tasks
5. **Respect cancellation** - Check `Task.isCancelled` in loops
6. **Profile with Instruments** - Use Time Profiler and Thread State

---

## Summary

**Modern Swift (5.5+):**
- ✅ Prefer `async/await` and `Task` over GCD
- ✅ Use `@MainActor` for view models
- ✅ Use `.task` for view lifecycle
- ✅ Use `Task.detached` sparingly for heavy work

**Legacy/Special Cases:**
- ⚠️ Use `DispatchQueue` only when necessary
- ⚠️ Use barriers for thread-safe collections
- ⚠️ Migrate to actors for mutable shared state

**Remember:** The goal is **responsive UI + efficient background work**.
