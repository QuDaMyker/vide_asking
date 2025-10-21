package com.vibe.network.data.model

import kotlinx.serialization.Serializable

/**
 * Domain model for User
 */
@Serializable
data class User(
    val id: String,
    val name: String,
    val email: String,
    val avatar: String? = null,
    val createdAt: String? = null
)
