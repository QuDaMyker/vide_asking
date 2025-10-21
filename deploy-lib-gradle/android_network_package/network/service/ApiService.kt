package com.vibe.network.service

import retrofit2.http.*
import kotlinx.serialization.Serializable

/**
 * Example API service interface. Customize this based on your API endpoints.
 */
interface ApiService {
    
    @GET("/api/v1/users/{id}")
    suspend fun getUser(@Path("id") userId: String): UserResponse
    
    @GET("/api/v1/users")
    suspend fun listUsers(
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20
    ): UserListResponse
    
    @POST("/api/v1/users")
    suspend fun createUser(@Body request: CreateUserRequest): UserResponse
    
    @PUT("/api/v1/users/{id}")
    suspend fun updateUser(
        @Path("id") userId: String,
        @Body request: UpdateUserRequest
    ): UserResponse
    
    @DELETE("/api/v1/users/{id}")
    suspend fun deleteUser(@Path("id") userId: String)
}

/**
 * Data classes for API requests and responses
 */
@Serializable
data class UserResponse(
    val id: String,
    val name: String,
    val email: String,
    val avatar: String? = null,
    val createdAt: String? = null
)

@Serializable
data class UserListResponse(
    val data: List<UserResponse>,
    val total: Int,
    val page: Int,
    val limit: Int
)

@Serializable
data class CreateUserRequest(
    val name: String,
    val email: String,
    val password: String
)

@Serializable
data class UpdateUserRequest(
    val name: String? = null,
    val email: String? = null,
    val avatar: String? = null
)
