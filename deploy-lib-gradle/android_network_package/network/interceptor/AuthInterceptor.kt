package com.vibe.network.interceptor

import okhttp3.Interceptor
import okhttp3.Response

/**
 * Authentication interceptor for adding auth tokens to requests
 */
class AuthInterceptor(
    private val tokenProvider: () -> String? = { null }
) : Interceptor {
    
    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()
        
        val token = tokenProvider()
        
        if (token.isNullOrEmpty()) {
            return chain.proceed(originalRequest)
        }

        val authenticatedRequest = originalRequest.newBuilder()
            .header("Authorization", "Bearer $token")
            .build()

        return chain.proceed(authenticatedRequest)
    }
}
