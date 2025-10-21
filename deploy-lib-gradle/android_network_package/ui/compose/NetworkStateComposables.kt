package com.vibe.network.ui.compose

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.vibe.network.Result

/**
 * Generic composable for handling different network states
 */
@Composable
fun <T> NetworkStateContent(
    state: Result<T>,
    modifier: Modifier = Modifier,
    onLoading: @Composable () -> Unit = { DefaultLoadingContent() },
    onError: @Composable (Result.Error) -> Unit = { error -> DefaultErrorContent(error) },
    onSuccess: @Composable (T) -> Unit
) {
    when (state) {
        Result.Loading -> onLoading()
        is Result.Success -> onSuccess(state.data)
        is Result.Error -> onError(state)
    }
}

/**
 * Default loading UI
 */
@Composable
fun DefaultLoadingContent(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator()
    }
}

/**
 * Default error UI
 */
@Composable
fun DefaultErrorContent(
    error: Result.Error,
    modifier: Modifier = Modifier,
    onRetry: (() -> Unit)? = null
) {
    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Error Occurred",
                modifier = Modifier.padding(bottom = 8.dp)
            )
            Text(
                text = error.message,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(bottom = 16.dp)
            )
            if (onRetry != null) {
                androidx.compose.material3.Button(onClick = onRetry) {
                    Text("Retry")
                }
            }
        }
    }
}

/**
 * Composable for displaying a list with loading and error states
 */
@Composable
fun <T> NetworkStateList(
    state: Result<List<T>>,
    modifier: Modifier = Modifier,
    onLoading: @Composable () -> Unit = { DefaultLoadingContent() },
    onError: @Composable (Result.Error) -> Unit = { error -> DefaultErrorContent(error) },
    listContent: @Composable (List<T>) -> Unit
) {
    when (state) {
        Result.Loading -> onLoading()
        is Result.Success -> listContent(state.data)
        is Result.Error -> onError(state)
    }
}

/**
 * Composable for displaying a single item with loading and error states
 */
@Composable
fun <T> NetworkStateItem(
    state: Result<T>,
    modifier: Modifier = Modifier,
    onLoading: @Composable () -> Unit = { DefaultLoadingContent() },
    onError: @Composable (Result.Error) -> Unit = { error -> DefaultErrorContent(error) },
    itemContent: @Composable (T) -> Unit
) {
    when (state) {
        Result.Loading -> onLoading()
        is Result.Success -> itemContent(state.data)
        is Result.Error -> onError(state)
    }
}
