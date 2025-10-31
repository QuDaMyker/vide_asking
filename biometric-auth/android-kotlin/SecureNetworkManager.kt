package com.example.security.network

import android.content.Context
import okhttp3.*
import okhttp3.logging.HttpLoggingInterceptor
import java.io.IOException
import java.security.KeyStore
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.util.concurrent.TimeUnit
import javax.net.ssl.*

/**
 * Secure Network Manager with Certificate Pinning and mTLS
 * Implements secure communication protocols
 */
class SecureNetworkManager(private val context: Context) {

    companion object {
        private const val TIMEOUT_SECONDS = 30L
        private const val MAX_RETRIES = 3
    }

    private lateinit var okHttpClient: OkHttpClient

    /**
     * Initialize with certificate pinning
     * @param pins Map of hostname to certificate SHA-256 pins
     */
    fun initializeWithCertificatePinning(
        pins: Map<String, List<String>>,
        enableLogging: Boolean = false
    ) {
        val certificatePinner = CertificatePinner.Builder().apply {
            pins.forEach { (hostname, pinList) ->
                pinList.forEach { pin ->
                    add(hostname, "sha256/$pin")
                }
            }
        }.build()

        val builder = OkHttpClient.Builder()
            .certificatePinner(certificatePinner)
            .connectTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .readTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .writeTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .addInterceptor(RetryInterceptor(MAX_RETRIES))
            .addInterceptor(SecurityHeadersInterceptor())

        if (enableLogging) {
            val loggingInterceptor = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            }
            builder.addInterceptor(loggingInterceptor)
        }

        okHttpClient = builder.build()
    }

    /**
     * Initialize with mutual TLS (mTLS)
     * @param clientCertificate Client certificate for authentication
     * @param clientKey Client private key
     * @param serverCertificate Server certificate to trust
     */
    fun initializeWithMutualTLS(
        clientCertificate: String, // PEM format
        clientKey: String, // PEM format
        serverCertificate: String, // PEM format
        enableLogging: Boolean = false
    ) {
        // Load client certificate and key
        val keyStore = createClientKeyStore(clientCertificate, clientKey)
        val keyManagerFactory = KeyManagerFactory.getInstance(
            KeyManagerFactory.getDefaultAlgorithm()
        )
        keyManagerFactory.init(keyStore, "".toCharArray())

        // Load server certificate to trust
        val trustStore = createTrustStore(serverCertificate)
        val trustManagerFactory = TrustManagerFactory.getInstance(
            TrustManagerFactory.getDefaultAlgorithm()
        )
        trustManagerFactory.init(trustStore)

        // Create SSL context
        val sslContext = SSLContext.getInstance("TLS")
        sslContext.init(
            keyManagerFactory.keyManagers,
            trustManagerFactory.trustManagers,
            null
        )

        val builder = OkHttpClient.Builder()
            .sslSocketFactory(
                sslContext.socketFactory,
                trustManagerFactory.trustManagers[0] as X509TrustManager
            )
            .connectTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .readTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .writeTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .addInterceptor(RetryInterceptor(MAX_RETRIES))
            .addInterceptor(SecurityHeadersInterceptor())

        if (enableLogging) {
            val loggingInterceptor = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.HEADERS
            }
            builder.addInterceptor(loggingInterceptor)
        }

        okHttpClient = builder.build()
    }

    /**
     * Initialize with TLS 1.3
     */
    fun initializeWithTLS13(
        enableLogging: Boolean = false
    ) {
        val connectionSpec = ConnectionSpec.Builder(ConnectionSpec.MODERN_TLS)
            .tlsVersions(TlsVersion.TLS_1_3, TlsVersion.TLS_1_2)
            .cipherSuites(
                CipherSuite.TLS_AES_128_GCM_SHA256,
                CipherSuite.TLS_AES_256_GCM_SHA384,
                CipherSuite.TLS_CHACHA20_POLY1305_SHA256
            )
            .build()

        val builder = OkHttpClient.Builder()
            .connectionSpecs(listOf(connectionSpec))
            .connectTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .readTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .writeTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .addInterceptor(RetryInterceptor(MAX_RETRIES))
            .addInterceptor(SecurityHeadersInterceptor())

        if (enableLogging) {
            val loggingInterceptor = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BASIC
            }
            builder.addInterceptor(loggingInterceptor)
        }

        okHttpClient = builder.build()
    }

    /**
     * Make secure GET request
     */
    suspend fun get(
        url: String,
        headers: Map<String, String> = emptyMap()
    ): Response {
        val requestBuilder = Request.Builder().url(url)
        headers.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        return okHttpClient.newCall(requestBuilder.build()).execute()
    }

    /**
     * Make secure POST request
     */
    suspend fun post(
        url: String,
        body: RequestBody,
        headers: Map<String, String> = emptyMap()
    ): Response {
        val requestBuilder = Request.Builder()
            .url(url)
            .post(body)

        headers.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        return okHttpClient.newCall(requestBuilder.build()).execute()
    }

    /**
     * Make secure PUT request
     */
    suspend fun put(
        url: String,
        body: RequestBody,
        headers: Map<String, String> = emptyMap()
    ): Response {
        val requestBuilder = Request.Builder()
            .url(url)
            .put(body)

        headers.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        return okHttpClient.newCall(requestBuilder.build()).execute()
    }

    /**
     * Make secure DELETE request
     */
    suspend fun delete(
        url: String,
        headers: Map<String, String> = emptyMap()
    ): Response {
        val requestBuilder = Request.Builder()
            .url(url)
            .delete()

        headers.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        return okHttpClient.newCall(requestBuilder.build()).execute()
    }

    // ==================== Helper Functions ====================

    private fun createClientKeyStore(certificate: String, privateKey: String): KeyStore {
        val keyStore = KeyStore.getInstance(KeyStore.getDefaultType())
        keyStore.load(null, null)

        // Parse certificate
        val certFactory = CertificateFactory.getInstance("X.509")
        val cert = certFactory.generateCertificate(certificate.byteInputStream())

        // Parse private key
        // Note: In production, use proper key parsing library
        // This is simplified for demonstration

        keyStore.setKeyEntry(
            "client",
            null, // Private key would be set here
            "".toCharArray(),
            arrayOf(cert)
        )

        return keyStore
    }

    private fun createTrustStore(certificate: String): KeyStore {
        val trustStore = KeyStore.getInstance(KeyStore.getDefaultType())
        trustStore.load(null, null)

        val certFactory = CertificateFactory.getInstance("X.509")
        val cert = certFactory.generateCertificate(certificate.byteInputStream())

        trustStore.setCertificateEntry("server", cert)

        return trustStore
    }

    /**
     * Get certificate pins from domain
     */
    fun getCertificatePinsFromDomain(domain: String): List<String> {
        // In production, fetch and pin certificates
        // This is a placeholder
        return emptyList()
    }
}

/**
 * Retry interceptor for failed requests
 */
class RetryInterceptor(private val maxRetries: Int) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        var response: Response? = null
        var exception: IOException? = null

        for (attempt in 0 until maxRetries) {
            try {
                response = chain.proceed(request)
                if (response.isSuccessful) {
                    return response
                }
                response.close()
            } catch (e: IOException) {
                exception = e
                if (attempt == maxRetries - 1) {
                    throw e
                }
            }

            // Exponential backoff
            Thread.sleep((1000L * (attempt + 1)))
        }

        return response ?: throw exception ?: IOException("Unknown error")
    }
}

/**
 * Security headers interceptor
 */
class SecurityHeadersInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()
        val requestWithHeaders = originalRequest.newBuilder()
            .header("X-Content-Type-Options", "nosniff")
            .header("X-Frame-Options", "DENY")
            .header("X-XSS-Protection", "1; mode=block")
            .header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
            .build()

        return chain.proceed(requestWithHeaders)
    }
}

/**
 * Request signing interceptor
 */
class RequestSigningInterceptor(
    private val keyAlias: String,
    private val cryptoManager: com.example.security.crypto.CryptoManager
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()
        
        // Get request body
        val buffer = okio.Buffer()
        originalRequest.body?.writeTo(buffer)
        val bodyBytes = buffer.readByteArray()

        // Sign request
        val privateKey = cryptoManager.getPrivateKey(keyAlias)
        if (privateKey != null) {
            val signature = cryptoManager.signData(bodyBytes, privateKey)
            val signatureBase64 = android.util.Base64.encodeToString(
                signature,
                android.util.Base64.NO_WRAP
            )

            // Add signature header
            val signedRequest = originalRequest.newBuilder()
                .header("X-Signature", signatureBase64)
                .header("X-Signature-Algorithm", "SHA256withECDSA")
                .build()

            return chain.proceed(signedRequest)
        }

        return chain.proceed(originalRequest)
    }
}
