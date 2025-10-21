package com.vibe.network.client

import com.vibe.network.interceptor.AuthInterceptor
import com.vibe.network.interceptor.LoggingInterceptorFactory
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/**
 * Factory for creating OkHttp client with custom configuration
 */
object HttpClientFactory {
    
    fun create(
        baseUrl: String = "https://api.example.com",
        connectTimeout: Long = 30,
        readTimeout: Long = 30,
        writeTimeout: Long = 30,
        timeoutUnit: TimeUnit = TimeUnit.SECONDS,
        tokenProvider: (() -> String?)? = null,
        enableLogging: Boolean = true
    ): OkHttpClient {
        return OkHttpClient.Builder()
            .connectTimeout(connectTimeout, timeoutUnit)
            .readTimeout(readTimeout, timeoutUnit)
            .writeTimeout(writeTimeout, timeoutUnit)
            .apply {
                addInterceptor(LoggingInterceptorFactory.create(enableLogging))
                if (tokenProvider != null) {
                    addInterceptor(AuthInterceptor(tokenProvider))
                }
            }
            .build()
    }
}
