import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Firebase Storage Manager for Flutter
/// Handles file uploads, downloads, and management
class StorageManager {
  static final StorageManager _instance = StorageManager._internal();
  factory StorageManager() => _instance;
  StorageManager._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Map<String, UploadTask> _uploadTasks = {};
  final Map<String, DownloadTask> _downloadTasks = {};

  final ValueNotifier<Map<String, double>> uploadProgress = ValueNotifier({});
  final ValueNotifier<Map<String, double>> downloadProgress = ValueNotifier({});

  /// Get storage reference
  Reference getReference(String path) {
    return _storage.ref().child(path);
  }

  // MARK: - Upload Operations

  /// Upload file
  Future<String> uploadFile({
    required File file,
    required String storagePath,
    SettableMetadata? metadata,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref().child(storagePath);
    final uploadTask = ref.putFile(file, metadata);

    _uploadTasks[storagePath] = uploadTask;

    // Listen to upload progress
    uploadTask.snapshotEvents.listen((snapshot) {
      final progress =
          snapshot.bytesTransferred.toDouble() / snapshot.totalBytes.toDouble();

      // Update progress map
      final currentProgress = Map<String, double>.from(uploadProgress.value);
      currentProgress[storagePath] = progress;
      uploadProgress.value = currentProgress;

      // Call callback
      onProgress?.call(progress);
    });

    try {
      await uploadTask;

      // Remove from tracking
      _uploadTasks.remove(storagePath);
      final currentProgress = Map<String, double>.from(uploadProgress.value);
      currentProgress.remove(storagePath);
      uploadProgress.value = currentProgress;

      // Get download URL
      final downloadURL = await ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      _uploadTasks.remove(storagePath);
      final currentProgress = Map<String, double>.from(uploadProgress.value);
      currentProgress.remove(storagePath);
      uploadProgress.value = currentProgress;
      rethrow;
    }
  }

  /// Upload data
  Future<String> uploadData({
    required Uint8List data,
    required String storagePath,
    SettableMetadata? metadata,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref().child(storagePath);
    final uploadTask = ref.putData(data, metadata);

    _uploadTasks[storagePath] = uploadTask;

    uploadTask.snapshotEvents.listen((snapshot) {
      final progress =
          snapshot.bytesTransferred.toDouble() / snapshot.totalBytes.toDouble();

      final currentProgress = Map<String, double>.from(uploadProgress.value);
      currentProgress[storagePath] = progress;
      uploadProgress.value = currentProgress;

      onProgress?.call(progress);
    });

    try {
      await uploadTask;

      _uploadTasks.remove(storagePath);
      final currentProgress = Map<String, double>.from(uploadProgress.value);
      currentProgress.remove(storagePath);
      uploadProgress.value = currentProgress;

      final downloadURL = await ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      _uploadTasks.remove(storagePath);
      final currentProgress = Map<String, double>.from(uploadProgress.value);
      currentProgress.remove(storagePath);
      uploadProgress.value = currentProgress;
      rethrow;
    }
  }

  /// Upload string
  Future<String> uploadString({
    required String data,
    required String storagePath,
    PutStringFormat format = PutStringFormat.raw,
    SettableMetadata? metadata,
  }) async {
    final ref = _storage.ref().child(storagePath);
    await ref.putString(data, format: format, metadata: metadata);
    return await ref.getDownloadURL();
  }

  /// Upload with retry
  Future<String> uploadWithRetry({
    required File file,
    required String storagePath,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    Exception? lastError;

    while (attempts < maxRetries) {
      try {
        return await uploadFile(file: file, storagePath: storagePath);
      } catch (e) {
        lastError = e as Exception;
        attempts++;

        if (attempts < maxRetries) {
          await Future.delayed(retryDelay * attempts);
        }
      }
    }

    throw lastError ??
        Exception('Upload failed after $maxRetries attempts');
  }

  // MARK: - Download Operations

  /// Download file
  Future<void> downloadFile({
    required String storagePath,
    required File destinationFile,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref().child(storagePath);
    final downloadTask = ref.writeToFile(destinationFile);

    _downloadTasks[storagePath] = downloadTask;

    downloadTask.snapshotEvents.listen((snapshot) {
      final progress =
          snapshot.bytesTransferred.toDouble() / snapshot.totalBytes.toDouble();

      final currentProgress = Map<String, double>.from(downloadProgress.value);
      currentProgress[storagePath] = progress;
      downloadProgress.value = currentProgress;

      onProgress?.call(progress);
    });

    try {
      await downloadTask;

      _downloadTasks.remove(storagePath);
      final currentProgress = Map<String, double>.from(downloadProgress.value);
      currentProgress.remove(storagePath);
      downloadProgress.value = currentProgress;
    } catch (e) {
      _downloadTasks.remove(storagePath);
      final currentProgress = Map<String, double>.from(downloadProgress.value);
      currentProgress.remove(storagePath);
      downloadProgress.value = currentProgress;
      rethrow;
    }
  }

  /// Download data
  Future<Uint8List?> downloadData({
    required String storagePath,
    int maxSize = 10 * 1024 * 1024, // 10MB
  }) async {
    final ref = _storage.ref().child(storagePath);
    return await ref.getData(maxSize);
  }

  // MARK: - URL Operations

  /// Get download URL
  Future<String> getDownloadURL(String storagePath) async {
    final ref = _storage.ref().child(storagePath);
    return await ref.getDownloadURL();
  }

  // MARK: - Metadata Operations

  /// Get metadata
  Future<FullMetadata> getMetadata(String storagePath) async {
    final ref = _storage.ref().child(storagePath);
    return await ref.getMetadata();
  }

  /// Update metadata
  Future<FullMetadata> updateMetadata({
    required String storagePath,
    required SettableMetadata metadata,
  }) async {
    final ref = _storage.ref().child(storagePath);
    return await ref.updateMetadata(metadata);
  }

  /// Set custom metadata
  Future<void> setCustomMetadata({
    required String storagePath,
    required Map<String, String> customMetadata,
  }) async {
    final metadata = SettableMetadata(
      customMetadata: customMetadata,
    );
    await updateMetadata(storagePath: storagePath, metadata: metadata);
  }

  // MARK: - Delete Operations

  /// Delete file
  Future<void> deleteFile(String storagePath) async {
    final ref = _storage.ref().child(storagePath);
    await ref.delete();
  }

  /// Delete multiple files
  Future<void> deleteFiles(List<String> storagePaths) async {
    await Future.wait(
      storagePaths.map((path) => deleteFile(path)),
    );
  }

  // MARK: - List Operations

  /// List files in directory
  Future<List<Reference>> listFiles({
    required String path,
    int maxResults = 100,
  }) async {
    final ref = _storage.ref().child(path);
    final result = await ref.list(ListOptions(maxResults: maxResults));
    return result.items;
  }

  /// List all files in directory
  Future<List<Reference>> listAllFiles(String path) async {
    final ref = _storage.ref().child(path);
    final result = await ref.listAll();
    return result.items;
  }

  /// List with pagination
  Future<ListResult> listWithPagination({
    required String path,
    int maxResults = 100,
    String? pageToken,
  }) async {
    final ref = _storage.ref().child(path);
    return await ref.list(
      ListOptions(
        maxResults: maxResults,
        pageToken: pageToken,
      ),
    );
  }

  // MARK: - Task Management

  /// Cancel upload
  Future<bool> cancelUpload(String storagePath) async {
    final task = _uploadTasks[storagePath];
    if (task != null) {
      final result = await task.cancel();
      _uploadTasks.remove(storagePath);

      final currentProgress = Map<String, double>.from(uploadProgress.value);
      currentProgress.remove(storagePath);
      uploadProgress.value = currentProgress;

      return result;
    }
    return false;
  }

  /// Cancel download
  Future<bool> cancelDownload(String storagePath) async {
    final task = _downloadTasks[storagePath];
    if (task != null) {
      final result = await task.cancel();
      _downloadTasks.remove(storagePath);

      final currentProgress = Map<String, double>.from(downloadProgress.value);
      currentProgress.remove(storagePath);
      downloadProgress.value = currentProgress;

      return result;
    }
    return false;
  }

  /// Pause upload
  Future<bool> pauseUpload(String storagePath) async {
    final task = _uploadTasks[storagePath];
    return task?.pause() ?? false;
  }

  /// Resume upload
  Future<bool> resumeUpload(String storagePath) async {
    final task = _uploadTasks[storagePath];
    return task?.resume() ?? false;
  }

  /// Cancel all uploads
  Future<void> cancelAllUploads() async {
    await Future.wait(
      _uploadTasks.keys.map((key) => cancelUpload(key)),
    );
  }

  /// Cancel all downloads
  Future<void> cancelAllDownloads() async {
    await Future.wait(
      _downloadTasks.keys.map((key) => cancelDownload(key)),
    );
  }

  // MARK: - Helper Methods

  /// Check if file exists
  Future<bool> fileExists(String storagePath) async {
    try {
      await getMetadata(storagePath);
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return false;
      }
      rethrow;
    }
  }

  /// Get file size
  Future<int> getFileSize(String storagePath) async {
    final metadata = await getMetadata(storagePath);
    return metadata.size ?? 0;
  }

  /// Generate unique path
  String generateUniquePath({
    required String directory,
    required String fileName,
    String? userId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuid = DateTime.now().microsecondsSinceEpoch.toString();

    if (userId != null) {
      return '$directory/$userId/${timestamp}_${uuid}_$fileName';
    } else {
      return '$directory/${timestamp}_${uuid}_$fileName';
    }
  }

  /// Get storage bucket URL
  String? getStorageBucket() {
    return _storage.bucket;
  }

  /// Set max operation retry time
  void setMaxOperationRetryTime(Duration duration) {
    _storage.setMaxOperationRetryTime(duration);
  }

  /// Set max upload retry time
  void setMaxUploadRetryTime(Duration duration) {
    _storage.setMaxUploadRetryTime(duration);
  }

  /// Dispose
  void dispose() {
    cancelAllUploads();
    cancelAllDownloads();
    uploadProgress.dispose();
    downloadProgress.dispose();
  }
}

/// Storage item model
class StorageItem {
  final String name;
  final String path;
  final String? url;
  final int? size;
  final String? contentType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StorageItem({
    required this.name,
    required this.path,
    this.url,
    this.size,
    this.contentType,
    this.createdAt,
    this.updatedAt,
  });

  factory StorageItem.fromReference(
    Reference reference, {
    FullMetadata? metadata,
  }) {
    return StorageItem(
      name: reference.name,
      path: reference.fullPath,
      url: null,
      size: metadata?.size,
      contentType: metadata?.contentType,
      createdAt: metadata?.timeCreated,
      updatedAt: metadata?.updated,
    );
  }

  factory StorageItem.fromMetadata(FullMetadata metadata) {
    return StorageItem(
      name: metadata.name ?? '',
      path: metadata.fullPath,
      url: null,
      size: metadata.size,
      contentType: metadata.contentType,
      createdAt: metadata.timeCreated,
      updatedAt: metadata.updated,
    );
  }
}
