//
//  RequestDebouncer.swift
//  SwiftUI Enterprise Architecture
//
//  Created on 2025-11-07
//  Request debouncing to prevent excessive API calls
//

import Foundation
import Combine

// MARK: - Request Debouncer

class RequestDebouncer {
    private var workItems: [String: DispatchWorkItem] = [:]
    private let queue = DispatchQueue(label: "com.app.debouncer", attributes: .concurrent)
    private let delay: TimeInterval
    
    init(delay: TimeInterval = 0.5) {
        self.delay = delay
    }
    
    /// Debounce an action with a specific key
    func debounce(key: String, action: @escaping () -> Void) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Cancel previous work item
            self.workItems[key]?.cancel()
            
            // Create new work item
            let workItem = DispatchWorkItem(block: action)
            self.workItems[key] = workItem
            
            // Schedule execution
            DispatchQueue.main.asyncAfter(deadline: .now() + self.delay, execute: workItem)
        }
    }
    
    /// Cancel a specific debounced action
    func cancel(key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.workItems[key]?.cancel()
            self?.workItems.removeValue(forKey: key)
        }
    }
    
    /// Cancel all debounced actions
    func cancelAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.workItems.values.forEach { $0.cancel() }
            self?.workItems.removeAll()
        }
    }
}

// MARK: - Combine Publisher Extensions

extension Publisher {
    /// Debounce requests with default scheduler
    func debounceRequest(
        for delay: TimeInterval = 0.5,
        scheduler: DispatchQueue = .main
    ) -> Publishers.Debounce<Self, DispatchQueue> {
        return self.debounce(for: .seconds(delay), scheduler: scheduler)
    }
    
    /// Remove duplicates and debounce
    func removeDuplicatesAndDebounce<H: Hashable>(
        _ keyPath: KeyPath<Output, H>,
        for delay: TimeInterval = 0.5
    ) -> AnyPublisher<Output, Failure> {
        return self
            .removeDuplicates(by: { $0[keyPath: keyPath] == $1[keyPath: keyPath] })
            .debounce(for: .seconds(delay), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - Debounced Property Wrapper

@propertyWrapper
class Debounced<Value> {
    private var value: Value
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval
    private let queue: DispatchQueue
    private let onChange: (Value) -> Void
    
    var wrappedValue: Value {
        get { value }
        set {
            value = newValue
            workItem?.cancel()
            
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.onChange(self.value)
            }
            
            workItem = item
            queue.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }
    
    var projectedValue: Debounced<Value> {
        return self
    }
    
    init(
        wrappedValue: Value,
        delay: TimeInterval = 0.5,
        queue: DispatchQueue = .main,
        onChange: @escaping (Value) -> Void
    ) {
        self.value = wrappedValue
        self.delay = delay
        self.queue = queue
        self.onChange = onChange
    }
    
    func cancel() {
        workItem?.cancel()
    }
}

// MARK: - Throttler (Alternative to Debouncing)

class RequestThrottler {
    private var lastExecutionTime: Date?
    private let minimumInterval: TimeInterval
    private let queue = DispatchQueue(label: "com.app.throttler")
    
    init(minimumInterval: TimeInterval = 1.0) {
        self.minimumInterval = minimumInterval
    }
    
    /// Throttle an action to execute at most once per interval
    func throttle(action: @escaping () -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            
            if let lastTime = self.lastExecutionTime,
               now.timeIntervalSince(lastTime) < self.minimumInterval {
                // Too soon, skip this execution
                return
            }
            
            self.lastExecutionTime = now
            DispatchQueue.main.async {
                action()
            }
        }
    }
    
    func reset() {
        queue.async { [weak self] in
            self?.lastExecutionTime = nil
        }
    }
}

// MARK: - Usage Examples

/*
 
 // 1. Basic Debouncer
 let debouncer = RequestDebouncer(delay: 0.5)
 
 func searchUsers(query: String) {
     debouncer.debounce(key: "userSearch") {
         // This will only execute after user stops typing for 0.5s
         performSearch(query)
     }
 }
 
 // 2. With Combine
 class SearchViewModel: ObservableObject {
     @Published var searchText = ""
     private var cancellables = Set<AnyCancellable>()
     
     init() {
         $searchText
             .debounceRequest(for: 0.3)
             .sink { [weak self] query in
                 self?.performSearch(query)
             }
             .store(in: &cancellables)
     }
 }
 
 // 3. Property Wrapper
 @Debounced(delay: 0.5) var searchQuery: String = "" { newValue in
     performSearch(newValue)
 }
 
 // 4. Throttler for button taps
 let throttler = RequestThrottler(minimumInterval: 2.0)
 
 func handleButtonTap() {
     throttler.throttle {
         submitForm()
     }
 }
 
 */
