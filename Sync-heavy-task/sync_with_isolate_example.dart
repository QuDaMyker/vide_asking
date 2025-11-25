import 'dart:isolate';
import 'package:flutter/foundation.dart';

/// Advanced sync implementation using isolates
/// This shows the CORRECT way to use isolates with your architecture
class SyncWithIsolate {
  
  /// Main approach: Keep I/O in main isolate, use isolates for CPU work only
  static Future<void> performSyncWithIsolates({
    required Future<List<Map<String, dynamic>>> Function() fetchData,
    required Future<void> Function(List<Map<String, dynamic>>) saveData,
    required Function(double) onProgress,
  }) async {
    
    // Step 1: Fetch data from network/DB (main isolate - async I/O)
    onProgress(0.1);
    final rawData = await fetchData();
    
    // Step 2: Process heavy data in isolate (CPU-intensive work)
    onProgress(0.3);
    final processedData = await compute(_processDataIsolate, rawData);
    
    // Step 3: Save to database (main isolate - async I/O)
    onProgress(0.7);
    await saveData(processedData);
    
    onProgress(1.0);
  }
  
  /// CPU-intensive processing in isolate
  static List<Map<String, dynamic>> _processDataIsolate(List<Map<String, dynamic>> data) {
    // Transform, validate, compute - CPU work only
    return data.map((item) {
      // Heavy computation here
      return {
        ...item,
        'processed': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }).toList();
  }
  
  /// Example: Batch processing with progress updates
  static Future<void> syncWithProgressIsolate({
    required List<SyncTask> tasks,
    required Function(double) onProgress,
    required Function(SyncTask, dynamic) onTaskComplete,
  }) async {
    
    var completed = 0;
    final total = tasks.length;
    
    for (final task in tasks) {
      // Network call in main isolate (async, non-blocking)
      final data = await task.fetchFunction();
      
      // Heavy processing in isolate if needed
      final processed = task.requiresHeavyProcessing
          ? await compute(_heavyProcess, data)
          : data;
      
      // Save in main isolate
      await task.saveFunction(processed);
      
      // Update progress
      completed++;
      onProgress(completed / total);
      onTaskComplete(task, processed);
      
      // Yield to event loop every 5 tasks
      if (completed % 5 == 0) {
        await Future.delayed(Duration.zero);
      }
    }
  }
  
  static dynamic _heavyProcess(dynamic data) {
    // Heavy CPU work here
    return data;
  }
}

/// Task definition for sync
class SyncTask {
  final String name;
  final Future<dynamic> Function() fetchFunction;
  final Future<void> Function(dynamic) saveFunction;
  final bool requiresHeavyProcessing;
  
  SyncTask({
    required this.name,
    required this.fetchFunction,
    required this.saveFunction,
    this.requiresHeavyProcessing = false,
  });
}

/// Example usage in your BLoC:
/// 
/// ```dart
/// Future<void> _syncWithIsolates() async {
///   final tasks = [
///     SyncTask(
///       name: 'projects',
///       fetchFunction: () => _projectRepository.fetchFromServer(),
///       saveFunction: (data) => _projectRepository.saveToLocal(data),
///       requiresHeavyProcessing: false, // Network I/O - no isolate needed
///     ),
///     SyncTask(
///       name: 'large_json',
///       fetchFunction: () => _repository.fetchHugeJson(),
///       saveFunction: (data) => _repository.saveProcessed(data),
///       requiresHeavyProcessing: true, // Parse in isolate
///     ),
///   ];
///   
///   await SyncWithIsolate.syncWithProgressIsolate(
///     tasks: tasks,
///     onProgress: (progress) {
///       emit(state.copyWith(progress: progress));
///     },
///     onTaskComplete: (task, result) {
///       print('${task.name} completed');
///     },
///   );
/// }
/// ```
