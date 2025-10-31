import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:flutter/foundation.dart';

/// AWS S3 Storage Manager for Flutter
/// Handles file uploads, downloads, and management in Amazon S3
class S3Manager {
  static final S3Manager _instance = S3Manager._internal();
  factory S3Manager() => _instance;
  S3Manager._internal();

  /// Upload file to S3
  Future<String> uploadFile({
    required File file,
    required String key,
    StorageAccessLevel accessLevel = StorageAccessLevel.guest,
    Map<String, String>? metadata,
    void Function(StorageTransferProgress)? onProgress,
  }) async {
    try {
      final operation = Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(file.path),
        key: key,
        options: StorageUploadFileOptions(
          accessLevel: accessLevel,
          metadata: metadata,
        ),
      );

      // Listen to progress
      if (onProgress != null) {
        operation.progress.listen(onProgress);
      }

      final result = await operation.result;
      debugPrint('Upload successful: ${result.uploadedItem.key}');

      return result.uploadedItem.key;
    } on StorageException catch (e) {
      debugPrint('Error uploading file: ${e.message}');
      rethrow;
    }
  }

  /// Upload file with automatic retry
  Future<String> uploadFileWithRetry({
    required File file,
    required String key,
    int maxRetries = 3,
    StorageAccessLevel accessLevel = StorageAccessLevel.guest,
    void Function(StorageTransferProgress)? onProgress,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < maxRetries) {
      try {
        return await uploadFile(
          file: file,
          key: key,
          accessLevel: accessLevel,
          onProgress: onProgress,
        );
      } on StorageException catch (e) {
        lastException = e;
        attempts++;

        if (attempts < maxRetries) {
          // Exponential backoff
          await Future.delayed(Duration(seconds: attempts * 2));
          debugPrint('Retrying upload (attempt $attempts)...');
        }
      }
    }

    throw lastException ?? Exception('Upload failed after $maxRetries attempts');
  }

  /// Download file from S3
  Future<File> downloadFile({
    required String key,
    required File localFile,
    StorageAccessLevel accessLevel = StorageAccessLevel.guest,
    void Function(StorageTransferProgress)? onProgress,
  }) async {
    try {
      final operation = Amplify.Storage.downloadFile(
        key: key,
        localFile: AWSFile.fromPath(localFile.path),
        options: StorageDownloadFileOptions(
          accessLevel: accessLevel,
        ),
      );

      // Listen to progress
      if (onProgress != null) {
        operation.progress.listen(onProgress);
      }

      final result = await operation.result;
      debugPrint('Download successful: ${result.localFile.path}');

      return File(result.localFile.path);
    } on StorageException catch (e) {
      debugPrint('Error downloading file: ${e.message}');
      rethrow;
    }
  }

  /// Get presigned URL for file
  Future<String> getUrl({
    required String key,
    StorageAccessLevel accessLevel = StorageAccessLevel.guest,
    int expiresInSeconds = 3600,
  }) async {
    try {
      final result = await Amplify.Storage.getUrl(
        key: key,
        options: StorageGetUrlOptions(
          accessLevel: accessLevel,
          pluginOptions: S3GetUrlPluginOptions(
            expiresIn: Duration(seconds: expiresInSeconds),
          ),
        ),
      );

      return result.url.toString();
    } on StorageException catch (e) {
      debugPrint('Error getting URL: ${e.message}');
      rethrow;
    }
  }

  /// List files in S3 bucket
  Future<List<StorageItem>> listFiles({
    String? path,
    StorageAccessLevel accessLevel = StorageAccessLevel.guest,
  }) async {
    try {
      final result = await Amplify.Storage.list(
        path: path != null ? StoragePath.fromString(path) : null,
        options: StorageListOptions(
          accessLevel: accessLevel,
        ),
      );

      return result.items;
    } on StorageException catch (e) {
      debugPrint('Error listing files: ${e.message}');
      rethrow;
    }
  }

  /// Delete file from S3
  Future<void> deleteFile({
    required String key,
    StorageAccessLevel accessLevel = StorageAccessLevel.guest,
  }) async {
    try {
      await Amplify.Storage.remove(
        key: key,
        options: StorageRemoveOptions(
          accessLevel: accessLevel,
        ),
      );

      debugPrint('File deleted: $key');
    } on StorageException catch (e) {
      debugPrint('Error deleting file: ${e.message}');
      rethrow;
    }
  }

  /// Upload data (bytes) to S3
  Future<String> uploadData({
    required Uint8List data,
    required String key,
    StorageAccessLevel accessLevel = StorageAccessLevel.guest,
    Map<String, String>? metadata,
    void Function(StorageTransferProgress)? onProgress,
  }) async {
    try {
      final operation = Amplify.Storage.uploadData(
        data: StorageDataPayload.bytes(data),
        key: key,
        options: StorageUploadDataOptions(
          accessLevel: accessLevel,
          metadata: metadata,
        ),
      );

      // Listen to progress
      if (onProgress != null) {
        operation.progress.listen(onProgress);
      }

      final result = await operation.result;
      debugPrint('Upload data successful: ${result.uploadedItem.key}');

      return result.uploadedItem.key;
    } on StorageException catch (e) {
      debugPrint('Error uploading data: ${e.message}');
      rethrow;
    }
  }

  /// Download data (bytes) from S3
  Future<Uint8List> downloadData({
    required String key,
    StorageAccessLevel accessLevel = StorageAccessLevel.guest,
    void Function(StorageTransferProgress)? onProgress,
  }) async {
    try {
      final operation = Amplify.Storage.downloadData(
        key: key,
        options: StorageDownloadDataOptions(
          accessLevel: accessLevel,
        ),
      );

      // Listen to progress
      if (onProgress != null) {
        operation.progress.listen(onProgress);
      }

      final result = await operation.result;
      debugPrint('Download data successful');

      return result.bytes;
    } on StorageException catch (e) {
      debugPrint('Error downloading data: ${e.message}');
      rethrow;
    }
  }

  /// Cancel ongoing operation
  void cancelOperation(StorageOperation operation) {
    try {
      operation.cancel();
      debugPrint('Operation cancelled');
    } catch (e) {
      debugPrint('Error cancelling operation: $e');
    }
  }

  /// Upload image with compression
  Future<String> uploadImage({
    required File file,
    required String key,
    int maxWidth = 1920,
    int maxHeight = 1080,
    int quality = 85,
    StorageAccessLevel accessLevel = StorageAccessLevel.guest,
    void Function(StorageTransferProgress)? onProgress,
  }) async {
    // Note: In production, you'd compress the image first using a package like image_picker or flutter_image_compress
    // For now, just upload the original file
    return uploadFile(
      file: file,
      key: key,
      accessLevel: accessLevel,
      metadata: {
        'content-type': 'image/jpeg',
      },
      onProgress: onProgress,
    );
  }

  /// Get file metadata
  Future<Map<String, String>?> getFileMetadata({
    required String key,
    StorageAccessLevel accessLevel = StorageAccessLevel.guest,
  }) async {
    try {
      final result = await Amplify.Storage.getProperties(
        key: key,
        options: StorageGetPropertiesOptions(
          accessLevel: accessLevel,
        ),
      );

      return result.storageItem.metadata;
    } on StorageException catch (e) {
      debugPrint('Error getting metadata: ${e.message}');
      rethrow;
    }
  }
}

/// Storage operation with progress tracking
class S3UploadOperation {
  final StorageUploadFileOperation operation;
  final String key;

  S3UploadOperation({
    required this.operation,
    required this.key,
  });

  Stream<StorageTransferProgress> get progress => operation.progress;

  Future<StorageUploadFileResult> get result => operation.result;

  void cancel() => operation.cancel();
}
