package com.example.cloud.firebase

import com.google.firebase.auth.*
import com.google.firebase.auth.ktx.auth
import com.google.firebase.ktx.Firebase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.tasks.await
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Firebase Authentication Manager
 * Handles user authentication with Firebase Auth
 */
class FirebaseAuthManager {
    
    private val auth: FirebaseAuth = Firebase.auth
    private val _authState = MutableStateFlow<FirebaseAuthState>(FirebaseAuthState.Unauthenticated)
    val authState: Flow<FirebaseAuthState> = _authState
    
    init {
        // Listen to auth state changes
        auth.addAuthStateListener { firebaseAuth ->
            val user = firebaseAuth.currentUser
            _authState.value = if (user != null) {
                FirebaseAuthState.Authenticated(user)
            } else {
                FirebaseAuthState.Unauthenticated
            }
        }
    }
    
    /**
     * Sign up with email and password
     */
    suspend fun signUpWithEmail(
        email: String,
        password: String
    ): Result<FirebaseUser> {
        return try {
            val result = auth.createUserWithEmailAndPassword(email, password).await()
            result.user?.let {
                Result.success(it)
            } ?: Result.failure(Exception("User creation failed"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Sign in with email and password
     */
    suspend fun signInWithEmail(
        email: String,
        password: String
    ): Result<FirebaseUser> {
        return try {
            val result = auth.signInWithEmailAndPassword(email, password).await()
            result.user?.let {
                _authState.value = FirebaseAuthState.Authenticated(it)
                Result.success(it)
            } ?: Result.failure(Exception("Sign in failed"))
        } catch (e: Exception) {
            _authState.value = FirebaseAuthState.Error(e.message ?: "Sign in failed")
            Result.failure(e)
        }
    }
    
    /**
     * Sign in with Google
     */
    suspend fun signInWithGoogle(
        idToken: String
    ): Result<FirebaseUser> {
        return try {
            val credential = GoogleAuthProvider.getCredential(idToken, null)
            val result = auth.signInWithCredential(credential).await()
            result.user?.let {
                _authState.value = FirebaseAuthState.Authenticated(it)
                Result.success(it)
            } ?: Result.failure(Exception("Google sign in failed"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Sign in with Apple
     */
    suspend fun signInWithApple(
        idToken: String,
        rawNonce: String
    ): Result<FirebaseUser> {
        return try {
            val credential = OAuthProvider.newCredentialBuilder("apple.com")
                .setIdToken(idToken)
                .setRawNonce(rawNonce)
                .build()
            
            val result = auth.signInWithCredential(credential).await()
            result.user?.let {
                _authState.value = FirebaseAuthState.Authenticated(it)
                Result.success(it)
            } ?: Result.failure(Exception("Apple sign in failed"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Sign in with Facebook
     */
    suspend fun signInWithFacebook(
        accessToken: String
    ): Result<FirebaseUser> {
        return try {
            val credential = FacebookAuthProvider.getCredential(accessToken)
            val result = auth.signInWithCredential(credential).await()
            result.user?.let {
                _authState.value = FirebaseAuthState.Authenticated(it)
                Result.success(it)
            } ?: Result.failure(Exception("Facebook sign in failed"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Sign in with phone number
     */
    suspend fun signInWithPhoneNumber(
        phoneNumber: String,
        activity: android.app.Activity
    ): Result<PhoneAuthCredential> = suspendCancellableCoroutine { continuation ->
        val callbacks = object : PhoneAuthProvider.OnVerificationStateChangedCallbacks() {
            override fun onVerificationCompleted(credential: PhoneAuthCredential) {
                continuation.resume(Result.success(credential))
            }
            
            override fun onVerificationFailed(e: FirebaseException) {
                continuation.resumeWithException(e)
            }
            
            override fun onCodeSent(
                verificationId: String,
                token: PhoneAuthProvider.ForceResendingToken
            ) {
                // You would store these for later use
            }
        }
        
        val options = PhoneAuthOptions.newBuilder(auth)
            .setPhoneNumber(phoneNumber)
            .setTimeout(60L, java.util.concurrent.TimeUnit.SECONDS)
            .setActivity(activity)
            .setCallbacks(callbacks)
            .build()
        
        PhoneAuthProvider.verifyPhoneNumber(options)
    }
    
    /**
     * Verify phone number code
     */
    suspend fun verifyPhoneCode(
        verificationId: String,
        code: String
    ): Result<FirebaseUser> {
        return try {
            val credential = PhoneAuthProvider.getCredential(verificationId, code)
            val result = auth.signInWithCredential(credential).await()
            result.user?.let {
                _authState.value = FirebaseAuthState.Authenticated(it)
                Result.success(it)
            } ?: Result.failure(Exception("Phone verification failed"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Sign in anonymously
     */
    suspend fun signInAnonymously(): Result<FirebaseUser> {
        return try {
            val result = auth.signInAnonymously().await()
            result.user?.let {
                _authState.value = FirebaseAuthState.Authenticated(it)
                Result.success(it)
            } ?: Result.failure(Exception("Anonymous sign in failed"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Sign out
     */
    fun signOut() {
        auth.signOut()
        _authState.value = FirebaseAuthState.Unauthenticated
    }
    
    /**
     * Get current user
     */
    fun getCurrentUser(): FirebaseUser? = auth.currentUser
    
    /**
     * Check if user is authenticated
     */
    fun isAuthenticated(): Boolean = auth.currentUser != null
    
    /**
     * Send email verification
     */
    suspend fun sendEmailVerification(): Result<Unit> {
        return try {
            auth.currentUser?.sendEmailVerification()?.await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Send password reset email
     */
    suspend fun sendPasswordResetEmail(email: String): Result<Unit> {
        return try {
            auth.sendPasswordResetEmail(email).await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Update email
     */
    suspend fun updateEmail(newEmail: String): Result<Unit> {
        return try {
            auth.currentUser?.updateEmail(newEmail)?.await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Update password
     */
    suspend fun updatePassword(newPassword: String): Result<Unit> {
        return try {
            auth.currentUser?.updatePassword(newPassword)?.await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Update profile
     */
    suspend fun updateProfile(
        displayName: String? = null,
        photoUrl: String? = null
    ): Result<Unit> {
        return try {
            val profileUpdates = UserProfileChangeRequest.Builder()
                .apply {
                    displayName?.let { setDisplayName(it) }
                    photoUrl?.let { setPhotoUri(android.net.Uri.parse(it)) }
                }
                .build()
            
            auth.currentUser?.updateProfile(profileUpdates)?.await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Delete user account
     */
    suspend fun deleteAccount(): Result<Unit> {
        return try {
            auth.currentUser?.delete()?.await()
            _authState.value = FirebaseAuthState.Unauthenticated
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Get ID token
     */
    suspend fun getIdToken(forceRefresh: Boolean = false): Result<String> {
        return try {
            val result = auth.currentUser?.getIdToken(forceRefresh)?.await()
            result?.token?.let {
                Result.success(it)
            } ?: Result.failure(Exception("No token available"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Link email credential to current user
     */
    suspend fun linkEmailCredential(
        email: String,
        password: String
    ): Result<FirebaseUser> {
        return try {
            val credential = EmailAuthProvider.getCredential(email, password)
            val result = auth.currentUser?.linkWithCredential(credential)?.await()
            result?.user?.let {
                Result.success(it)
            } ?: Result.failure(Exception("Link failed"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Re-authenticate user
     */
    suspend fun reauthenticate(
        email: String,
        password: String
    ): Result<Unit> {
        return try {
            val credential = EmailAuthProvider.getCredential(email, password)
            auth.currentUser?.reauthenticate(credential)?.await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

/**
 * Firebase authentication state
 */
sealed class FirebaseAuthState {
    object Unauthenticated : FirebaseAuthState()
    data class Authenticated(val user: FirebaseUser) : FirebaseAuthState()
    data class Error(val message: String) : FirebaseAuthState()
}
