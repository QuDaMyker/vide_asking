import 'dart:isolate';
import 'package:flutter/foundation.dart';

/// Helper class to run heavy data processing in isolates
/// Note: Cannot be used for repository calls due to DI limitations
class SyncIsolateHelper {
  
  /// Process heavy data transformation in isolate
  /// Use this for CPU-intensive operations only (not I/O)
  static Future<List<ProcessedData>> processDataInIsolate({
    required List<Map<String, dynamic>> rawData,
  }) async {
    try {
      // Use compute for automatic isolate management
      final result = await compute(_processDataWorker, rawData);
      return result;
    } catch (e) {
      print('Isolate processing error: $e');
      return [];
    }
  }
  
  /// Worker function that runs in the isolate
  /// Must be top-level or static, can only receive/return simple types
  static List<ProcessedData> _processDataWorker(List<Map<String, dynamic>> data) {
    // This runs in a separate isolate
    // Good for: JSON parsing, data transformation, calculations
    // Bad for: Network calls, database access, repository methods
    
    return data.map((item) {
      // Heavy processing here
      return ProcessedData(
        id: item['id'] as String? ?? '',
        processedAt: DateTime.now().toIso8601String(),
      );
    }).toList();
  }
  
  /// Example: Parse large JSON in isolate
  static Future<Map<String, dynamic>> parseJsonInIsolate(String jsonString) async {
    return await compute(_parseJson, jsonString);
  }
  
  static Map<String, dynamic> _parseJson(String json) {
    // Heavy JSON parsing in isolate
    return {}; // Would use actual json.decode here
  }
}

/// Simple data class for isolate communication
class ProcessedData {
  final String id;
  final String processedAt;
  
  ProcessedData({required this.id, required this.processedAt});
}

/// Data to pass to the isolate worker
class SyncTaskData {
  final List<String> projectIds;
  final String? selectedPeriod;
  final String? selectedStatus;
  
  SyncTaskData({
    required this.projectIds,
    this.selectedPeriod,
    this.selectedStatus,
  });
}

/// Result from the isolate worker
class SyncResult {
  final bool success;
  final int? syncedCount;
  final String? error;
  
  SyncResult({
    required this.success,
    this.syncedCount,
    this.error,
  });
}
