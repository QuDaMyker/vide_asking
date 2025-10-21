package com.vibe.network.service

import com.vibe.network.client.HttpClientFactory
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory

/**
 * Factory for creating Retrofit instances
 */
object RetrofitFactory {
    
    private val jsonSerializer = Json {
        ignoreUnknownKeys = true
        isLenient = true
        coerceInputValues = true
    }
    
    fun <T> create(
        serviceClass: Class<T>,
        baseUrl: String = "https://api.example.com",
        okHttpClient: OkHttpClient? = null,
        tokenProvider: (() -> String?)? = null,
        enableLogging: Boolean = true
    ): T {
        val client = okHttpClient ?: HttpClientFactory.create(
            baseUrl = baseUrl,
            tokenProvider = tokenProvider,
            enableLogging = enableLogging
        )
        
        val contentType = "application/json".toMediaType()
        
        return Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(client)
            .addConverterFactory(jsonSerializer.asConverterFactory(contentType))
            .build()
            .create(serviceClass)
    }
    
    inline fun <reified T> createInline(
        baseUrl: String = "https://api.example.com",
        okHttpClient: OkHttpClient? = null,
        tokenProvider: (() -> String?)? = null,
        enableLogging: Boolean = true
    ): T = create(T::class.java, baseUrl, okHttpClient, tokenProvider, enableLogging)
}
