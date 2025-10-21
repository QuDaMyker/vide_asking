package com.vibe.network

/**
 * A sealed class that represents the result of a network operation.
 * It can be either Success or Error.
 */
sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(
        val exception: Throwable,
        val message: String = exception.message ?: "Unknown error"
    ) : Result<Nothing>()
    data object Loading : Result<Nothing>()

    fun <R> map(transform: (T) -> R): Result<R> {
        return when (this) {
            is Success -> Success(transform(data))
            is Error -> Error(exception, message)
            Loading -> Loading
        }
    }

    suspend fun <R> flatMap(transform: suspend (T) -> Result<R>): Result<R> {
        return when (this) {
            is Success -> transform(data)
            is Error -> Error(exception, message)
            Loading -> Loading
        }
    }

    fun getOrNull(): T? = when (this) {
        is Success -> data
        else -> null
    }

    fun exceptionOrNull(): Throwable? = when (this) {
        is Error -> exception
        else -> null
    }
}

inline fun <T, R> Result<T>.fold(
    onSuccess: (T) -> R,
    onError: (Result.Error) -> R,
    onLoading: () -> R = { throw IllegalStateException("Loading state not handled") }
): R = when (this) {
    is Result.Success -> onSuccess(data)
    is Result.Error -> onError(this)
    Result.Loading -> onLoading()
}
