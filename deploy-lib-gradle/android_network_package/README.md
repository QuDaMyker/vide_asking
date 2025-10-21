# Android Network Package

A comprehensive Kotlin-based network handling package for Android with Jetpack Compose support.

## Features

- ✅ **Retrofit + OkHttp** for HTTP networking
- ✅ **Kotlinx Serialization** for JSON handling
- ✅ **Result sealed class** for proper error handling
- ✅ **Repository pattern** for data management
- ✅ **ViewModel integration** with Jetpack Compose
- ✅ **Authentication interceptor** for token management
- ✅ **HTTP logging interceptor** for debugging
- ✅ **Composable UI helpers** for loading/error states
- ✅ **Type-safe API** with Kotlin coroutines

## Project Structure

```
network/
├── client/
│   └── HttpClientFactory.kt          # OkHttp client factory
├── service/
│   ├── ApiService.kt                 # API interface and models
│   └── RetrofitFactory.kt            # Retrofit builder
├── interceptor/
│   ├── AuthInterceptor.kt            # Authentication handling
│   └── LoggingInterceptor.kt         # HTTP logging
└── Result.kt                          # Result sealed class

data/
├── model/
│   └── User.kt                       # Domain models
└── repository/
    └── UserRepository.kt             # Data repository

ui/
├── viewmodel/
│   └── UserViewModel.kt              # Jetpack ViewModel
└── compose/
    ├── NetworkStateComposables.kt    # State UI helpers
    └── UserComposables.kt            # User UI components
```

## Setup Instructions

### 1. Add to Your Project

Copy the `android_network_package` folder to your project's `src/main/java/com/vibe` directory.

### 2. Update build.gradle.kts (App-level)

```gradle
dependencies {
    // Network module
    implementation(project(":android_network_package"))
    
    // Add other dependencies as needed
}
```

### 3. Configure API Endpoint

In your application or activity:

```kotlin
// Create API service
val apiService = RetrofitFactory.createInline<ApiService>(
    baseUrl = "https://api.example.com",
    tokenProvider = { /* return your auth token */ },
    enableLogging = BuildConfig.DEBUG
)

// Create repository
val userRepository = UserRepository(apiService)

// Create ViewModel
val userViewModel = UserViewModel(userRepository)
```

## Usage Examples

### Example 1: Display User List

```kotlin
@Composable
fun MyScreen(viewModel: UserViewModel) {
    UserListScreen(
        viewModel = viewModel,
        onUserClick = { user ->
            // Handle user click
            println("User clicked: ${user.name}")
        }
    )
}
```

### Example 2: Custom Network State Handling

```kotlin
@Composable
fun MyCustomScreen(viewModel: UserViewModel) {
    val usersState = viewModel.usersListState.collectAsState()
    
    NetworkStateList(
        state = usersState.value,
        onLoading = {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("Loading your data...")
            }
        },
        onError = { error ->
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("Failed to load: ${error.message}")
            }
        },
        listContent = { users ->
            LazyColumn {
                items(users) { user ->
                    Text(user.name)
                }
            }
        }
    )
}
```

### Example 3: Create a User

```kotlin
@Composable
fun CreateUserScreen(viewModel: UserViewModel) {
    val userState = viewModel.userState.collectAsState()
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    
    Column {
        TextField(value = name, onValueChange = { name = it })
        TextField(value = email, onValueChange = { email = it })
        TextField(value = password, onValueChange = { password = it })
        
        Button(
            onClick = {
                viewModel.createUser(name, email, password)
            }
        ) {
            Text("Create User")
        }
        
        NetworkStateItem(state = userState.value) { user ->
            Text("User created: ${user.name}")
        }
    }
}
```

### Example 4: Custom API Service

Extend `ApiService.kt` to add your own endpoints:

```kotlin
interface ApiService {
    // Existing endpoints...
    
    @GET("/api/v1/posts")
    suspend fun getPosts(): List<Post>
    
    @POST("/api/v1/posts")
    suspend fun createPost(@Body request: CreatePostRequest): Post
}

@Serializable
data class Post(
    val id: String,
    val title: String,
    val content: String
)

@Serializable
data class CreatePostRequest(
    val title: String,
    val content: String
)
```

## Advanced Configuration

### Custom HTTP Client

```kotlin
val customOkHttpClient = OkHttpClient.Builder()
    .connectTimeout(60, TimeUnit.SECONDS)
    .readTimeout(60, TimeUnit.SECONDS)
    .writeTimeout(60, TimeUnit.SECONDS)
    .build()

val apiService = RetrofitFactory.create(
    ApiService::class.java,
    baseUrl = "https://api.example.com",
    okHttpClient = customOkHttpClient
)
```

### Custom Token Provider

```kotlin
val tokenProvider: () -> String? = {
    // Fetch token from your secure storage
    MySecureStorage.getAuthToken()
}

val apiService = RetrofitFactory.createInline<ApiService>(
    baseUrl = "https://api.example.com",
    tokenProvider = tokenProvider
)
```

### Error Handling

```kotlin
val userState = viewModel.userState.collectAsState()

when (val result = userState.value) {
    is Result.Success -> {
        println("Success: ${result.data.name}")
    }
    is Result.Error -> {
        println("Error: ${result.message}")
        result.exception.printStackTrace()
    }
    Result.Loading -> {
        println("Loading...")
    }
}
```

## Result Sealed Class

The `Result` sealed class provides a type-safe way to handle network operations:

```kotlin
sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val exception: Throwable, val message: String) : Result<Nothing>()
    data object Loading : Result<Nothing>()
}
```

### Utility Functions

```kotlin
// Map success values
val mappedResult = result.map { it.name.uppercase() }

// Flat map for chaining operations
val chainedResult = result.flatMap { user ->
    repository.getUserPosts(user.id)
}

// Get value or null
val user: User? = result.getOrNull()

// Get exception or null
val exception: Throwable? = result.exceptionOrNull()

// Fold for exhaustive handling
result.fold(
    onSuccess = { user -> println(user.name) },
    onError = { error -> println(error.message) },
    onLoading = { println("Loading...") }
)
```

## Dependencies

- Kotlin Coroutines
- Retrofit 2
- OkHttp 3
- Kotlinx Serialization
- Jetpack Compose
- Jetpack Lifecycle

## Best Practices

1. **Always use the Result type** for consistent error handling
2. **Create repository classes** for each resource type
3. **Use ViewModels** to manage UI state properly
4. **Implement custom interceptors** for authentication, logging, etc.
5. **Make API calls in coroutines** using `viewModelScope`
6. **Handle loading states** in your UI composables
7. **Never make API calls in Composables directly**

## License

MIT License
