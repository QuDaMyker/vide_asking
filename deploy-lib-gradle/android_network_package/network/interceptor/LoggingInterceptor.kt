package com.vibe.network.interceptor

import okhttp3.logging.HttpLoggingInterceptor
import android.util.Log

/**
 * Provides HTTP logging interceptor with Logcat
 */
object LoggingInterceptorFactory {
    
    fun create(enableLogging: Boolean = true): HttpLoggingInterceptor {
        return HttpLoggingInterceptor { message ->
            if (enableLogging) {
                Log.d("HTTP_LOG", message)
            }
        }.apply {
            level = if (enableLogging) {
                HttpLoggingInterceptor.Level.BODY
            } else {
                HttpLoggingInterceptor.Level.NONE
            }
        }
    }
}
