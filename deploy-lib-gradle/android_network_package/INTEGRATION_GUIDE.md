# Integration Guide - Android Network Package

This guide shows how to integrate the Network Package into your existing Android project.

## Step 1: Module Setup

### Option A: Copy as Library Module

1. Copy the `android_network_package` folder to your project's root directory
2. Rename it to `network` (optional)
3. Update `settings.gradle.kts`:

```gradle
include(":app")
include(":network")
```

### Option B: Copy as Source Files

Copy all files into your app's `src/main/java/com/vibe/network` directory structure.

## Step 2: Update Dependencies

### In your `build.gradle.kts` (app-level):

```gradle
dependencies {
    // If using module approach
    implementation(project(":network"))
    
    // Or if copied as source, ensure you have:
    
    // Kotlin & Coroutines
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.23")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Jetpack Compose
    implementation("androidx.compose.ui:ui:1.6.8")
    implementation("androidx.compose.runtime:runtime:1.6.8")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")

    // Serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")

    // Networking
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-kotlinx-serialization:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
}
```

## Step 3: Create Your API Service

Extend the provided `ApiService.kt` with your own endpoints:

```kotlin
// File: app/src/main/java/com/example/myapp/network/api/MyApiService.kt
package com.example.myapp.network.api

import com.vibe.network.service.ApiService
import kotlinx.serialization.Serializable
import retrofit2.http.*

interface MyApiService : ApiService {
    
    @GET("/api/v1/posts")
    suspend fun getPosts(
        @Query("page") page: Int = 1
    ): PostListResponse
    
    @GET("/api/v1/posts/{id}")
    suspend fun getPost(@Path("id") postId: String): PostResponse
    
    @POST("/api/v1/posts")
    suspend fun createPost(@Body request: CreatePostRequest): PostResponse
}

@Serializable
data class PostResponse(
    val id: String,
    val title: String,
    val content: String,
    val author: String,
    val createdAt: String
)

@Serializable
data class PostListResponse(
    val data: List<PostResponse>,
    val total: Int,
    val page: Int
)

@Serializable
data class CreatePostRequest(
    val title: String,
    val content: String
)
```

## Step 4: Create Your Repository

```kotlin
// File: app/src/main/java/com/example/myapp/data/repository/PostRepository.kt
package com.example.myapp.data.repository

import com.vibe.network.Result
import com.example.myapp.network.api.MyApiService
import com.example.myapp.network.api.PostResponse

class PostRepository(
    private val apiService: MyApiService
) {
    
    suspend fun getPosts(page: Int = 1): Result<List<PostResponse>> {
        return try {
            val response = apiService.getPosts(page)
            Result.Success(response.data)
        } catch (e: Exception) {
            Result.Error(e)
        }
    }
    
    suspend fun getPost(postId: String): Result<PostResponse> {
        return try {
            Result.Success(apiService.getPost(postId))
        } catch (e: Exception) {
            Result.Error(e)
        }
    }
    
    suspend fun createPost(title: String, content: String): Result<PostResponse> {
        return try {
            val request = CreatePostRequest(title, content)
            Result.Success(apiService.createPost(request))
        } catch (e: Exception) {
            Result.Error(e)
        }
    }
}
```

## Step 5: Setup Hilt (Optional but Recommended)

### Add Hilt Dependencies

```gradle
dependencies {
    implementation("com.google.dagger:hilt-android:2.50")
    kapt("com.google.dagger:hilt-compiler:2.50")
    
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")
}
```

### Create Dependency Injection Module

```kotlin
// File: app/src/main/java/com/example/myapp/di/NetworkModule.kt
package com.example.myapp.di

import com.vibe.network.service.RetrofitFactory
import com.example.myapp.network.api.MyApiService
import com.example.myapp.data.repository.PostRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    
    @Provides
    @Singleton
    fun provideMyApiService(): MyApiService {
        return RetrofitFactory.createInline(
            baseUrl = "https://api.example.com",
            enableLogging = BuildConfig.DEBUG
        )
    }
    
    @Provides
    @Singleton
    fun providePostRepository(apiService: MyApiService): PostRepository {
        return PostRepository(apiService)
    }
}
```

## Step 6: Create Your ViewModel

```kotlin
// File: app/src/main/java/com/example/myapp/ui/viewmodel/PostViewModel.kt
package com.example.myapp.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.vibe.network.Result
import com.example.myapp.data.repository.PostRepository
import com.example.myapp.network.api.PostResponse
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PostViewModel @Inject constructor(
    private val repository: PostRepository
) : ViewModel() {
    
    private val _postsState = MutableStateFlow<Result<List<PostResponse>>>(Result.Loading)
    val postsState: StateFlow<Result<List<PostResponse>>> = _postsState.asStateFlow()
    
    private val _currentPage = MutableStateFlow(1)
    val currentPage: StateFlow<Int> = _currentPage.asStateFlow()
    
    init {
        loadPosts()
    }
    
    fun loadPosts(page: Int = 1) {
        viewModelScope.launch {
            _postsState.value = Result.Loading
            _currentPage.value = page
            _postsState.value = repository.getPosts(page)
        }
    }
    
    fun nextPage() {
        val nextPage = currentPage.value + 1
        loadPosts(nextPage)
    }
}
```

## Step 7: Use in Jetpack Compose

```kotlin
// File: app/src/main/java/com/example/myapp/ui/screen/PostListScreen.kt
package com.example.myapp.ui.screen

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.vibe.network.ui.compose.NetworkStateList
import com.example.myapp.ui.viewmodel.PostViewModel
import com.example.myapp.network.api.PostResponse

@Composable
fun PostListScreen(
    viewModel: PostViewModel = hiltViewModel()
) {
    val postsState = viewModel.postsState.collectAsState()
    
    NetworkStateList(
        state = postsState.value,
        listContent = { posts ->
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(posts, key = { it.id }) { post ->
                    PostCard(post = post)
                }
            }
        }
    )
}

@Composable
fun PostCard(post: PostResponse) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = post.title,
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = post.content,
                style = MaterialTheme.typography.bodySmall
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "By: ${post.author}",
                    style = MaterialTheme.typography.labelSmall
                )
                Text(
                    text = post.createdAt,
                    style = MaterialTheme.typography.labelSmall
                )
            }
        }
    }
}
```

## Step 8: Setup in MainActivity

```kotlin
// File: app/src/main/java/com/example/myapp/MainActivity.kt
package com.example.myapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import com.example.myapp.ui.screen.PostListScreen
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface {
                    PostListScreen()
                }
            }
        }
    }
}
```

## Step 9: Update AndroidManifest.xml

Add internet permission:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## Testing

### Unit Test Example

```kotlin
// File: app/src/test/java/com/example/myapp/repository/PostRepositoryTest.kt
package com.example.myapp.repository

import com.vibe.network.Result
import com.example.myapp.data.repository.PostRepository
import com.example.myapp.network.api.MyApiService
import com.example.myapp.network.api.PostResponse
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.Mock
import org.mockito.MockitoAnnotations
import org.mockito.kotlin.whenever

class PostRepositoryTest {
    
    @Mock
    private lateinit var apiService: MyApiService
    
    private lateinit var repository: PostRepository
    
    @Before
    fun setUp() {
        MockitoAnnotations.openMocks(this)
        repository = PostRepository(apiService)
    }
    
    @Test
    fun getPosts_success() = runTest {
        val mockPosts = listOf(
            PostResponse("1", "Title 1", "Content 1", "Author 1", "2024-01-01"),
            PostResponse("2", "Title 2", "Content 2", "Author 2", "2024-01-02")
        )
        
        whenever(apiService.getPosts()).thenReturn(
            PostListResponse(mockPosts, 2, 1)
        )
        
        val result = repository.getPosts()
        
        assertTrue(result is Result.Success)
        assertEquals(2, (result as Result.Success).data.size)
    }
}
```

## Troubleshooting

### Issue: "Cannot resolve symbol 'com.vibe.network'"
**Solution:** Make sure the network package is properly included in your project structure and all dependencies are added.

### Issue: "Serialization not working"
**Solution:** Ensure `kotlinx-serialization-json` dependency is added and the `@Serializable` annotation is on your data classes.

### Issue: "OkHttp client not building"
**Solution:** Verify all interceptor dependencies are properly imported.

## Next Steps

1. Customize `ApiService.kt` with your actual API endpoints
2. Create service-specific repositories for each resource type
3. Build your UI screens using the provided composables
4. Implement custom error handling and retry logic as needed
5. Add authentication token management

## Support

For issues or questions, refer to the main README.md or check the example implementations in the package.
