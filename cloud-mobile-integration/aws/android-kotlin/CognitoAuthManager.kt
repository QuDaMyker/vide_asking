package com.example.cloud.aws

import com.amplifyframework.auth.AuthUser
import com.amplifyframework.auth.AuthUserAttribute
import com.amplifyframework.auth.AuthUserAttributeKey
import com.amplifyframework.auth.cognito.AWSCognitoAuthSession
import com.amplifyframework.auth.options.AuthSignUpOptions
import com.amplifyframework.auth.result.AuthSignInResult
import com.amplifyframework.auth.result.AuthSignUpResult
import com.amplifyframework.core.Amplify
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * AWS Cognito Authentication Manager
 * Handles user authentication, registration, and session management
 */
class CognitoAuthManager {
    
    private val _authState = MutableStateFlow<AuthState>(AuthState.Unauthenticated)
    val authState: Flow<AuthState> = _authState
    
    /**
     * Sign up a new user
     */
    suspend fun signUp(
        email: String,
        password: String,
        attributes: Map<String, String> = emptyMap()
    ): Result<AuthSignUpResult> = suspendCancellableCoroutine { continuation ->
        
        val options = AuthSignUpOptions.builder()
            .userAttributes(attributes.map { (key, value) ->
                AuthUserAttribute(AuthUserAttributeKey.custom(key), value)
            })
            .build()
        
        Amplify.Auth.signUp(
            email,
            password,
            options,
            { result ->
                continuation.resume(Result.success(result))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Confirm sign up with verification code
     */
    suspend fun confirmSignUp(
        email: String,
        confirmationCode: String
    ): Result<Unit> = suspendCancellableCoroutine { continuation ->
        Amplify.Auth.confirmSignUp(
            email,
            confirmationCode,
            { 
                continuation.resume(Result.success(Unit))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Sign in existing user
     */
    suspend fun signIn(
        email: String,
        password: String
    ): Result<AuthSignInResult> = suspendCancellableCoroutine { continuation ->
        Amplify.Auth.signIn(
            email,
            password,
            { result ->
                if (result.isSignedIn) {
                    _authState.value = AuthState.Authenticated(getCurrentUser())
                }
                continuation.resume(Result.success(result))
            },
            { error ->
                _authState.value = AuthState.Error(error.message ?: "Sign in failed")
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Sign in with social provider (Google, Facebook, Apple)
     */
    suspend fun signInWithSocialProvider(
        provider: AuthProvider
    ): Result<AuthSignInResult> = suspendCancellableCoroutine { continuation ->
        val amplifyProvider = when (provider) {
            AuthProvider.GOOGLE -> com.amplifyframework.auth.AuthProvider.google()
            AuthProvider.FACEBOOK -> com.amplifyframework.auth.AuthProvider.facebook()
            AuthProvider.APPLE -> com.amplifyframework.auth.AuthProvider.apple()
        }
        
        Amplify.Auth.signInWithSocialWebUI(
            amplifyProvider,
            androidx.core.app.ActivityCompat.getActivity(null)!!,
            { result ->
                if (result.isSignedIn) {
                    _authState.value = AuthState.Authenticated(getCurrentUser())
                }
                continuation.resume(Result.success(result))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Sign out current user
     */
    suspend fun signOut(): Result<Unit> = suspendCancellableCoroutine { continuation ->
        Amplify.Auth.signOut(
            {
                _authState.value = AuthState.Unauthenticated
                continuation.resume(Result.success(Unit))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Get current authenticated user
     */
    fun getCurrentUser(): AuthUser? {
        return try {
            Amplify.Auth.currentUser
        } catch (e: Exception) {
            null
        }
    }
    
    /**
     * Check if user is authenticated
     */
    fun isAuthenticated(): Boolean {
        return getCurrentUser() != null
    }
    
    /**
     * Get user attributes
     */
    suspend fun fetchUserAttributes(): Result<List<AuthUserAttribute>> = 
        suspendCancellableCoroutine { continuation ->
            Amplify.Auth.fetchUserAttributes(
                { attributes ->
                    continuation.resume(Result.success(attributes))
                },
                { error ->
                    continuation.resumeWithException(error)
                }
            )
        }
    
    /**
     * Update user attribute
     */
    suspend fun updateUserAttribute(
        key: String,
        value: String
    ): Result<Unit> = suspendCancellableCoroutine { continuation ->
        val attribute = AuthUserAttribute(AuthUserAttributeKey.custom(key), value)
        
        Amplify.Auth.updateUserAttribute(
            attribute,
            {
                continuation.resume(Result.success(Unit))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Change password
     */
    suspend fun changePassword(
        oldPassword: String,
        newPassword: String
    ): Result<Unit> = suspendCancellableCoroutine { continuation ->
        Amplify.Auth.updatePassword(
            oldPassword,
            newPassword,
            {
                continuation.resume(Result.success(Unit))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Reset password
     */
    suspend fun resetPassword(email: String): Result<Unit> = 
        suspendCancellableCoroutine { continuation ->
            Amplify.Auth.resetPassword(
                email,
                {
                    continuation.resume(Result.success(Unit))
                },
                { error ->
                    continuation.resumeWithException(error)
                }
            )
        }
    
    /**
     * Confirm password reset
     */
    suspend fun confirmResetPassword(
        email: String,
        newPassword: String,
        confirmationCode: String
    ): Result<Unit> = suspendCancellableCoroutine { continuation ->
        Amplify.Auth.confirmResetPassword(
            email,
            newPassword,
            confirmationCode,
            {
                continuation.resume(Result.success(Unit))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Get access token
     */
    suspend fun getAccessToken(): Result<String> = suspendCancellableCoroutine { continuation ->
        Amplify.Auth.fetchAuthSession(
            { session ->
                val cognitoSession = session as AWSCognitoAuthSession
                when (val tokenResult = cognitoSession.userPoolTokensResult.value) {
                    null -> continuation.resumeWithException(
                        Exception("No tokens available")
                    )
                    else -> continuation.resume(Result.success(tokenResult.accessToken))
                }
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Get ID token
     */
    suspend fun getIdToken(): Result<String> = suspendCancellableCoroutine { continuation ->
        Amplify.Auth.fetchAuthSession(
            { session ->
                val cognitoSession = session as AWSCognitoAuthSession
                when (val tokenResult = cognitoSession.userPoolTokensResult.value) {
                    null -> continuation.resumeWithException(
                        Exception("No tokens available")
                    )
                    else -> continuation.resume(Result.success(tokenResult.idToken))
                }
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
    
    /**
     * Refresh session
     */
    suspend fun refreshSession(): Result<Unit> = suspendCancellableCoroutine { continuation ->
        Amplify.Auth.fetchAuthSession(
            {
                continuation.resume(Result.success(Unit))
            },
            { error ->
                continuation.resumeWithException(error)
            }
        )
    }
}

/**
 * Authentication state
 */
sealed class AuthState {
    object Unauthenticated : AuthState()
    data class Authenticated(val user: AuthUser?) : AuthState()
    data class Error(val message: String) : AuthState()
}

/**
 * Supported authentication providers
 */
enum class AuthProvider {
    GOOGLE,
    FACEBOOK,
    APPLE
}
