import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Isolate worker for handling heavy sync operations
class SyncIsolateWorker {
  final SendPort sendPort;
  
  SyncIsolateWorker(this.sendPort);
  
  /// Entry point for the sync isolate
  static void isolateEntryPoint(SyncIsolateMessage message) async {
    try {
      final worker = SyncIsolateWorker(message.sendPort);
      await worker.performSync(message);
    } catch (e, stackTrace) {
      message.sendPort.send(SyncProgress(
        type: SyncProgressType.error,
        error: e.toString(),
        stackTrace: stackTrace.toString(),
      ));
    }
  }
  
  Future<void> performSync(SyncIsolateMessage message) async {
    try {
      // Send initial progress
      _sendProgress(0.0, 'Starting sync...');
      
      // Note: In isolate, we need to reinitialize dependencies
      // since we can't pass repository instances across isolates.
      // This is a simplified version - you'll need to set up your DI container
      // in the isolate or use a different approach.
      
      // For now, simulate the sync process
      final totalSteps = 100;
      for (var step = 0; step < totalSteps; step++) {
        // Check if cancelled
        if (message.shouldCancel != null && message.shouldCancel!()) {
          _sendProgress(step / totalSteps, 'Sync cancelled');
          sendPort.send(SyncProgress(type: SyncProgressType.cancelled));
          return;
        }
        
        // Simulate work
        await Future.delayed(Duration(milliseconds: 10));
        
        // Send progress updates
        if (step % 10 == 0) {
          _sendProgress(
            step / totalSteps,
            'Syncing step $step of $totalSteps',
          );
        }
      }
      
      // Send completion
      _sendProgress(1.0, 'Sync completed successfully');
      sendPort.send(SyncProgress(
        type: SyncProgressType.complete,
        progress: 1.0,
      ));
    } catch (e, stackTrace) {
      sendPort.send(SyncProgress(
        type: SyncProgressType.error,
        error: e.toString(),
        stackTrace: stackTrace.toString(),
      ));
    }
  }
  
  void _sendProgress(double progress, String message) {
    sendPort.send(SyncProgress(
      type: SyncProgressType.progress,
      progress: progress,
      message: message,
    ));
  }
}

/// Message to send to the isolate
class SyncIsolateMessage {
  final SendPort sendPort;
  final String? projectId;
  final String? workspaceId;
  final String? selectedPeriod;
  final String? selectedStatus;
  final bool isAppStart;
  final bool Function()? shouldCancel;
  
  SyncIsolateMessage({
    required this.sendPort,
    this.projectId,
    this.workspaceId,
    this.selectedPeriod,
    this.selectedStatus,
    this.isAppStart = false,
    this.shouldCancel,
  });
}

/// Progress update from the isolate
class SyncProgress {
  final SyncProgressType type;
  final double? progress;
  final String? message;
  final String? error;
  final String? stackTrace;
  
  SyncProgress({
    required this.type,
    this.progress,
    this.message,
    this.error,
    this.stackTrace,
  });
  
  @override
  String toString() {
    return 'SyncProgress(type: $type, progress: $progress, message: $message)';
  }
}

enum SyncProgressType {
  progress,
  complete,
  error,
  cancelled,
}
