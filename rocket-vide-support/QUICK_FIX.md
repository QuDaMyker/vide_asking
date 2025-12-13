# Quick Fix - Authorization Header Not Set

## The Problem

You have the token, but it's not being sent in the Authorization header.

## The Fix (3 Steps)

### Step 1: Replace APIInterceptor.swift

Replace your current `APIInterceptor.swift` with `APIInterceptor_Fixed.swift` (already created).

**Key changes:**
- Thread-safe token storage
- Better debug logging
- Removed `@unchecked Sendable`

### Step 2: Call updateAccessToken After Login

**WHERE:** After your login API call succeeds

**BEFORE (Wrong ❌):**
```swift
let response = try await APIClient.shared.request(...)
// Token never set! ❌
```

**AFTER (Correct ✅):**
```swift
let response = try await APIClient.shared.request(...)
guard let token = response.data?.accessToken else { return }

// ✅ MUST call this!
APIClient.shared.updateAccessToken(newAccessToken: token)
```

### Step 3: Restore Token on App Launch

**WHERE:** In your App initialization or root view

```swift
@main
struct RocketApp: App {
    init() {
        // Load saved token from storage
        if let savedToken = UserDefaults.standard.string(forKey: "access_token") {
            APIClient.shared.updateAccessToken(newAccessToken: savedToken)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Example: Complete Login Flow

```swift
struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack {
            TextField("Email", text: $email)
            SecureField("Password", text: $password)
            
            Button("Login") {
                Task { await login() }
            }
        }
    }
    
    private func login() async {
        do {
            // 1. Login
            let response: APIResponse<AuthResponse> = try await APIClient.shared.request(
                "/auth/login",
                method: .post,
                body: ["email": email, "password": password],
                responseType: AuthResponse.self
            )
            
            guard let token = response.data?.accessToken else {
                print("❌ No token in response")
                return
            }
            
            // 2. ✅ Update token in APIClient
            APIClient.shared.updateAccessToken(newAccessToken: token)
            
            // 3. Save for next app launch
            UserDefaults.standard.set(token, forKey: "access_token")
            
            print("✅ Login successful")
            
        } catch {
            print("❌ Login failed: \(error)")
        }
    }
}

struct AuthResponse: Decodable {
    let accessToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}
```

## Verification

After making these changes, you should see:

```
🔐 Updated access token = eyJhbGc...
➡️ [Request] GET https://rocket-dev.builtlab.io.vn/api/v1/photos
✅ Authorization header set: Bearer eyJhbGc...
📋 [Headers]: ["Authorization": "Bearer eyJ...", ...]
⬅️ [Response] 200 from https://...
```

## Common Mistakes

### ❌ Mistake 1: Never calling updateAccessToken
```swift
// Login succeeds but token never passed to interceptor
let response = try await APIClient.shared.request(...)
// Missing: APIClient.shared.updateAccessToken(...)
```

### ❌ Mistake 2: Token not persisted
```swift
// Token works this session but lost after app restart
APIClient.shared.updateAccessToken(newAccessToken: token)
// Missing: UserDefaults.standard.set(token, forKey: "access_token")
```

### ❌ Mistake 3: Token set after API call
```swift
// Race condition - API call happens before token is set
Task {
    APIClient.shared.updateAccessToken(newAccessToken: token)
}
Task {
    let data = try await APIClient.shared.request(...) // ❌ May run before token is set
}
```

## Need Help?

Check the logs for:
1. `🔐 Updated access token = ...` - Token was set
2. `✅ Authorization header set: Bearer ...` - Header was added
3. `⬅️ [Response] 200` - Request succeeded

If you see 401, check:
- Is `updateAccessToken` being called?
- Is it called BEFORE the API request?
- Is the token restored on app launch?
