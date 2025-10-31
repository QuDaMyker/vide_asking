package com.example.cloud.aws

import android.content.Context
import com.amplifyframework.AmplifyException
import com.amplifyframework.auth.cognito.AWSCognitoAuthPlugin
import com.amplifyframework.core.Amplify
import com.amplifyframework.datastore.AWSDataStorePlugin
import com.amplifyframework.storage.s3.AWSS3StoragePlugin
import com.amplifyframework.api.aws.AWSApiPlugin
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * AWS Amplify Manager for Android
 * Handles initialization and configuration of AWS Amplify SDK
 */
class AmplifyManager(private val context: Context) {
    
    private var isInitialized = false
    
    /**
     * Initialize AWS Amplify with all plugins
     */
    suspend fun initialize(): Result<Unit> = suspendCancellableCoroutine { continuation ->
        if (isInitialized) {
            continuation.resume(Result.success(Unit))
            return@suspendCancellableCoroutine
        }
        
        try {
            // Add plugins
            Amplify.addPlugin(AWSCognitoAuthPlugin())
            Amplify.addPlugin(AWSS3StoragePlugin())
            Amplify.addPlugin(AWSDataStorePlugin())
            Amplify.addPlugin(AWSApiPlugin())
            
            // Configure Amplify
            Amplify.configure(context)
            
            isInitialized = true
            continuation.resume(Result.success(Unit))
            
        } catch (error: AmplifyException) {
            continuation.resumeWithException(error)
        }
    }
    
    /**
     * Check if Amplify is initialized
     */
    fun isConfigured(): Boolean = isInitialized
    
    /**
     * Get Amplify configuration status
     */
    fun getStatus(): AmplifyStatus {
        return AmplifyStatus(
            isConfigured = isInitialized,
            hasAuth = try {
                Amplify.Auth
                true
            } catch (e: Exception) {
                false
            },
            hasStorage = try {
                Amplify.Storage
                true
            } catch (e: Exception) {
                false
            },
            hasDataStore = try {
                Amplify.DataStore
                true
            } catch (e: Exception) {
                false
            },
            hasAPI = try {
                Amplify.API
                true
            } catch (e: Exception) {
                false
            }
        )
    }
}

/**
 * Amplify status data class
 */
data class AmplifyStatus(
    val isConfigured: Boolean,
    val hasAuth: Boolean,
    val hasStorage: Boolean,
    val hasDataStore: Boolean,
    val hasAPI: Boolean
)
