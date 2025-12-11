# Authentication Setup Guide - Rocket App

## Problem
The Authorization header is not being set in API requests, causing 401 errors even though the access token exists.

## Root Cause
1. The access token was not being passed to the `APIInterceptor` after login
2. Thread safety issue with the `accessToken` property in `APIInterceptor`

## Solution

### 1. Update APIInterceptor (Already Fixed)
The `APIInterceptor_Fixed.swift` file includes:
- Thread-safe access token storage using `NSLock`
- Better debug logging to verify Authorization header is set
- Removed `@unchecked Sendable` which can hide concurrency issues

### 2. Update Your Login Flow

After successful login, you MUST call `updateAccessToken`:

```swift
// Example: In your AuthService or LoginViewModel
class AuthService {
    func login(email: String, password: String) async throws -> AuthResponse {
        // Make login API call
        let response: APIResponse<AuthResponse> = try await APIClient.shared.request(
            "/auth/login",
            method: .post,
            body: ["email": email, "password": password],
            responseType: AuthResponse.self
        )
        
        guard let authData = response.data else {
            throw NetworkError.noData
        }
        
        // ✅ CRITICAL: Update the access token in APIClient
        APIClient.shared.updateAccessToken(newAccessToken: authData.accessToken)
        
        // Save token to persistent storage (UserDefaults, Keychain, etc.)
        saveTokenToKeychain(authData.accessToken)
        
        return authData
    }
}
```

### 3. Update Your App Initialization

When the app launches, restore the saved token:

```swift
// In your App or root View
@main
struct RocketApp: App {
    init() {
        setupAPIClient()
    }
    
    private func setupAPIClient() {
        // Restore saved token from Keychain/UserDefaults
        if let savedToken = loadTokenFromKeychain() {
            APIClient.shared.updateAccessToken(newAccessToken: savedToken)
            print("✅ Token restored from storage")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 4. Token Storage Helper

Create a simple token manager:

```swift
enum TokenManager {
    private static let tokenKey = "access_token"
    
    static func saveToken(_ token: String) {
        // Option 1: UserDefaults (less secure)
        UserDefaults.standard.set(token, forKey: tokenKey)
        
        // Option 2: Keychain (recommended)
        // Use KeychainAccess or your keychain wrapper
        KeychainHelper.save(token, forKey: tokenKey)
        
        // Update APIClient
        APIClient.shared.updateAccessToken(newAccessToken: token)
    }
    
    static func loadToken() -> String? {
        // Option 1: UserDefaults
        return UserDefaults.standard.string(forKey: tokenKey)
        
        // Option 2: Keychain
        // return KeychainHelper.load(forKey: tokenKey)
    }
    
    static func clearToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        // or KeychainHelper.delete(forKey: tokenKey)
        
        APIClient.shared.updateAccessToken(newAccessToken: "")
    }
}
```

### 5. Complete Login Example

```swift
struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack {
            TextField("Email", text: $email)
            SecureField("Password", text: $password)
            
            Button("Login") {
                Task {
                    await performLogin()
                }
            }
            .disabled(isLoading)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    private func performLogin() async {
        isLoading = true
        errorMessage = ""
        
        do {
            // 1. Make login request
            let response: APIResponse<AuthResponse> = try await APIClient.shared.request(
                "/auth/login",
                method: .post,
                body: LoginRequest(email: email, password: password),
                responseType: AuthResponse.self
            )
            
            guard let authData = response.data else {
                errorMessage = response.message ?? "Login failed"
                return
            }
            
            // 2. ✅ CRITICAL: Update the token
            TokenManager.saveToken(authData.accessToken)
            
            // 3. Navigate to main screen
            // Your navigation logic here
            print("✅ Login successful")
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let user: User?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct User: Decodable {
    let id: String
    let email: String
    let username: String?
}
```

## Verification Steps

1. **Check Token is Set After Login:**
   ```
   🔐 Updated access token = eyJhbGc...
   ```

2. **Check Authorization Header in Requests:**
   ```
   ✅ Authorization header set: Bearer eyJhbGc...
   📋 [Headers]: ["Authorization": "Bearer eyJ...", ...]
   ```

3. **Verify API Response:**
   ```
   ⬅️ [Response] 200 from https://rocket-dev.builtlab.io.vn/api/v1/photos
   ```

## Common Issues

### Issue 1: Token Not Persisting Between App Launches
**Solution:** Implement proper token storage (see TokenManager above)

### Issue 2: Token Set But Still Getting 401
**Solution:** 
- Verify token format (should be just the token, not "Bearer token")
- Check token hasn't expired
- Verify backend expects "Bearer" prefix

### Issue 3: Race Condition (Token Set After API Call Started)
**Solution:**
- Always set token BEFORE making API calls
- Use async/await to ensure proper sequencing
- Implement a "ready" state in your API client

## Testing Checklist

- [ ] Token is saved after login
- [ ] Token is loaded on app launch
- [ ] Authorization header appears in request logs
- [ ] API returns 200 instead of 401
- [ ] Token persists after app restart
- [ ] Logout clears token properly
