package com.vibe.network.data.repository

import com.vibe.network.Result
import com.vibe.network.data.model.User
import com.vibe.network.service.ApiService
import com.vibe.network.service.CreateUserRequest
import com.vibe.network.service.UpdateUserRequest
import com.vibe.network.service.UserListResponse
import com.vibe.network.service.UserResponse

/**
 * Repository for user-related API operations
 */
class UserRepository(
    private val apiService: ApiService
) {
    
    suspend fun getUser(userId: String): Result<User> {
        return try {
            val response = apiService.getUser(userId)
            Result.Success(response.toDomain())
        } catch (e: Exception) {
            Result.Error(e)
        }
    }
    
    suspend fun listUsers(page: Int = 1, limit: Int = 20): Result<List<User>> {
        return try {
            val response = apiService.listUsers(page, limit)
            Result.Success(response.data.map { it.toDomain() })
        } catch (e: Exception) {
            Result.Error(e)
        }
    }
    
    suspend fun createUser(name: String, email: String, password: String): Result<User> {
        return try {
            val request = CreateUserRequest(name, email, password)
            val response = apiService.createUser(request)
            Result.Success(response.toDomain())
        } catch (e: Exception) {
            Result.Error(e)
        }
    }
    
    suspend fun updateUser(
        userId: String,
        name: String? = null,
        email: String? = null,
        avatar: String? = null
    ): Result<User> {
        return try {
            val request = UpdateUserRequest(name, email, avatar)
            val response = apiService.updateUser(userId, request)
            Result.Success(response.toDomain())
        } catch (e: Exception) {
            Result.Error(e)
        }
    }
    
    suspend fun deleteUser(userId: String): Result<Unit> {
        return try {
            apiService.deleteUser(userId)
            Result.Success(Unit)
        } catch (e: Exception) {
            Result.Error(e)
        }
    }
}

private fun UserResponse.toDomain(): User {
    return User(
        id = id,
        name = name,
        email = email,
        avatar = avatar,
        createdAt = createdAt
    )
}
