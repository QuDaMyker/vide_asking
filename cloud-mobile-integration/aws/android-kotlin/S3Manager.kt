package com.example.cloud.aws

import com.amplifyframework.core.Amplify
import com.amplifyframework.storage.StorageAccessLevel
import com.amplifyframework.storage.options.StorageDownloadFileOptions
import com.amplifyframework.storage.options.StorageListOptions
import com.amplifyframework.storage.options.StorageRemoveOptions
import com.amplifyframework.storage.options.StorageUploadFileOptions
import com.amplifyframework.storage.result.StorageDownloadFileResult
import com.amplifyframework.storage.result.StorageListResult
import com.amplifyframework.storage.result.StorageRemoveResult
import com.amplifyframework.storage.result.StorageUploadFileResult
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * AWS S3 Storage Manager
 * Handles file uploads, downloads, and management in Amazon S3
 */
class S3Manager {
    
    /**
     * Upload file to S3
     */
    suspend fun uploadFile(
        file: File,
        key: String,
        accessLevel: StorageAccessLevel = StorageAccessLevel.PRIVATE,
        contentType: String? = null,
        metadata: Map<String, String> = emptyMap(),
        onProgress: ((Long, Long) -> Unit)? = null
    ): Result<String> = suspendCancellableCoroutine { continuation ->
        
        val options = StorageUploadFileOptions.builder()
            .accessLevel(accessLevel)
            .apply {
                contentType?.let { contentType(it) }
                if (metadata.isNotEmpty()) {
                    metadata(metadata)
                }
            }
            .build()
        
        val operation = Amplify.Storage.uploadFile(
            key,
            file,
            options,
            { result ->
                continuation.resume(Result.success(result.key))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
        
        // Monitor progress
        onProgress?.let {
            operation.addProgressListener { progress ->
                it(progress.currentBytes, progress.totalBytes)
            }
        }
        
        continuation.invokeOnCancellation {
            operation.cancel()
        }
    }
    
    /**
     * Upload file with automatic retry
     */
    suspend fun uploadFileWithRetry(
        file: File,
        key: String,
        maxRetries: Int = 3,
        accessLevel: StorageAccessLevel = StorageAccessLevel.PRIVATE,
        onProgress: ((Long, Long) -> Unit)? = null
    ): Result<String> {
        var lastException: Exception? = null
        
        repeat(maxRetries) { attempt ->
            try {
                return uploadFile(file, key, accessLevel, null, emptyMap(), onProgress)
            } catch (e: Exception) {
                lastException = e
                if (attempt < maxRetries - 1) {
                    // Wait before retry (exponential backoff)
                    kotlinx.coroutines.delay((attempt + 1) * 1000L)
                }
            }
        }
        
        return Result.failure(lastException ?: Exception("Upload failed"))
    }
    
    /**
     * Download file from S3
     */
    suspend fun downloadFile(
        key: String,
        localFile: File,
        accessLevel: StorageAccessLevel = StorageAccessLevel.PRIVATE,
        onProgress: ((Long, Long) -> Unit)? = null
    ): Result<File> = suspendCancellableCoroutine { continuation ->
        
        val options = StorageDownloadFileOptions.builder()
            .accessLevel(accessLevel)
            .build()
        
        val operation = Amplify.Storage.downloadFile(
            key,
            localFile,
            options,
            { result ->
                continuation.resume(Result.success(result.file))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
        
        // Monitor progress
        onProgress?.let {
            operation.addProgressListener { progress ->
                it(progress.currentBytes, progress.totalBytes)
            }
        }
        
        continuation.invokeOnCancellation {
            operation.cancel()
        }
    }
    
    /**
     * Get presigned URL for file
     */
    suspend fun getUrl(
        key: String,
        accessLevel: StorageAccessLevel = StorageAccessLevel.PRIVATE,
        expiresInSeconds: Int = 3600
    ): Result<String> = suspendCancellableCoroutine { continuation ->
        
        val options = com.amplifyframework.storage.options.StorageGetUrlOptions.builder()
            .accessLevel(accessLevel)
            .expires(expiresInSeconds)
            .build()
        
        Amplify.Storage.getUrl(
            key,
            options,
            { result ->
                continuation.resume(Result.success(result.url.toString()))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * List files in S3 bucket
     */
    suspend fun listFiles(
        path: String = "",
        accessLevel: StorageAccessLevel = StorageAccessLevel.PRIVATE
    ): Result<List<StorageItem>> = suspendCancellableCoroutine { continuation ->
        
        val options = StorageListOptions.builder()
            .accessLevel(accessLevel)
            .targetIdentityId(null)
            .build()
        
        Amplify.Storage.list(
            path,
            options,
            { result ->
                val items = result.items.map { item ->
                    StorageItem(
                        key = item.key,
                        size = item.size,
                        lastModified = item.lastModified?.time,
                        eTag = item.eTag
                    )
                }
                continuation.resume(Result.success(items))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Delete file from S3
     */
    suspend fun deleteFile(
        key: String,
        accessLevel: StorageAccessLevel = StorageAccessLevel.PRIVATE
    ): Result<Unit> = suspendCancellableCoroutine { continuation ->
        
        val options = StorageRemoveOptions.builder()
            .accessLevel(accessLevel)
            .build()
        
        Amplify.Storage.remove(
            key,
            options,
            {
                continuation.resume(Result.success(Unit))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Upload image with compression
     */
    suspend fun uploadImage(
        file: File,
        key: String,
        maxWidth: Int = 1920,
        maxHeight: Int = 1080,
        quality: Int = 85,
        accessLevel: StorageAccessLevel = StorageAccessLevel.PRIVATE,
        onProgress: ((Long, Long) -> Unit)? = null
    ): Result<String> {
        // Compress image
        val compressedFile = ImageCompressor.compress(
            file,
            maxWidth,
            maxHeight,
            quality
        )
        
        // Upload compressed image
        return uploadFile(
            file = compressedFile,
            key = key,
            accessLevel = accessLevel,
            contentType = "image/jpeg",
            onProgress = onProgress
        )
    }
    
    /**
     * Upload with multipart for large files
     */
    suspend fun uploadLargeFile(
        file: File,
        key: String,
        partSize: Long = 5 * 1024 * 1024, // 5MB parts
        accessLevel: StorageAccessLevel = StorageAccessLevel.PRIVATE,
        onProgress: ((Long, Long) -> Unit)? = null
    ): Result<String> {
        // Amplify handles multipart automatically for files > 5MB
        return uploadFile(file, key, accessLevel, null, emptyMap(), onProgress)
    }
}

/**
 * Storage item data class
 */
data class StorageItem(
    val key: String,
    val size: Long,
    val lastModified: Long?,
    val eTag: String?
)

/**
 * Simple image compressor (you'd use a real library in production)
 */
object ImageCompressor {
    fun compress(
        file: File,
        maxWidth: Int,
        maxHeight: Int,
        quality: Int
    ): File {
        // Implementation would use Android Bitmap compression
        // For now, just return the original file
        return file
    }
}
