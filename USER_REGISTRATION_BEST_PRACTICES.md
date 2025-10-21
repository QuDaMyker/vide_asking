# User Registration Best Practices: Email & OAuth

## Table of Contents
1. [Overview](#overview)
2. [Registration Flow Types](#registration-flow-types)
3. [Database Design](#database-design)
4. [Backend Implementation](#backend-implementation)
5. [Mobile Implementation](#mobile-implementation)
6. [Security Best Practices](#security-best-practices)
7. [Error Handling](#error-handling)
8. [Testing Considerations](#testing-considerations)

---

## Overview

This document outlines best practices for implementing user registration systems supporting both email/password and OAuth authentication methods.

### Key Principles
- **Security First**: Protect user data and credentials
- **User Experience**: Minimize friction in the registration process
- **Scalability**: Design for growth and future requirements
- **Flexibility**: Support multiple authentication methods seamlessly

---

## Registration Flow Types

### 1. Email/Password Registration

```
User Flow:
1. User enters email, password, and optional profile info
2. Backend validates input and checks for existing account
3. Password is hashed and stored
4. Verification email is sent
5. User clicks verification link
6. Account is activated
7. User is logged in
```

**Key Features:**
- Email validation
- Password strength requirements
- Email verification
- Rate limiting to prevent abuse

### 2. OAuth Registration (Google, Facebook, Apple, etc.)

```
User Flow:
1. User clicks "Sign up with [Provider]"
2. Redirect to OAuth provider
3. User authorizes the app
4. Provider redirects back with authorization code
5. Backend exchanges code for access token
6. Backend fetches user profile from provider
7. Account is created or linked
8. User is logged in
```

**Key Features:**
- No password management required
- Faster registration process
- Access to provider profile data
- Automatic email verification (if email from provider)

### 3. Hybrid Approach (Recommended)

Allow users to:
- Register with email/password OR OAuth
- Link multiple OAuth providers to one account
- Add email/password to OAuth account later
- Recover account through any linked method

---

## Database Design

### Core Tables

#### 1. `users` Table
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    phone_number VARCHAR(20),
    phone_verified BOOLEAN DEFAULT FALSE,
    
    -- Profile information
    full_name VARCHAR(255),
    display_name VARCHAR(100),
    avatar_url TEXT,
    bio TEXT,
    date_of_birth DATE,
    
    -- Account status
    status VARCHAR(20) DEFAULT 'active', -- active, suspended, deleted
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP,
    deleted_at TIMESTAMP, -- Soft delete
    
    -- Indexes
    INDEX idx_email (email),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);
```

#### 2. `user_credentials` Table (For Email/Password)
```sql
CREATE TABLE user_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    password_hash VARCHAR(255) NOT NULL,
    password_salt VARCHAR(255),
    
    -- Password history for preventing reuse
    password_changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    must_change_password BOOLEAN DEFAULT FALSE,
    
    -- Security
    failed_login_attempts INT DEFAULT 0,
    locked_until TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id)
);
```

#### 3. `oauth_providers` Table
```sql
CREATE TABLE oauth_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    provider VARCHAR(50) NOT NULL, -- google, facebook, apple, github, etc.
    provider_user_id VARCHAR(255) NOT NULL, -- ID from the OAuth provider
    
    -- OAuth tokens
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMP,
    
    -- Provider profile data (cached)
    provider_email VARCHAR(255),
    provider_name VARCHAR(255),
    provider_avatar_url TEXT,
    raw_profile_data JSONB, -- Store full provider response
    
    -- Metadata
    connected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP,
    
    -- Constraints
    UNIQUE(provider, provider_user_id),
    INDEX idx_user_provider (user_id, provider),
    INDEX idx_provider_user_id (provider, provider_user_id)
);
```

#### 4. `email_verifications` Table
```sql
CREATE TABLE email_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    
    expires_at TIMESTAMP NOT NULL,
    verified_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_token (token),
    INDEX idx_user_email (user_id, email)
);
```

#### 5. `refresh_tokens` Table
```sql
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    
    device_info JSONB, -- Device type, OS, app version, etc.
    ip_address INET,
    user_agent TEXT,
    
    expires_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP,
    
    INDEX idx_token (token),
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at)
);
```

#### 6. `audit_logs` Table (Optional but Recommended)
```sql
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    event_type VARCHAR(100) NOT NULL, -- registration, login, password_change, etc.
    event_data JSONB,
    
    ip_address INET,
    user_agent TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user_event (user_id, event_type),
    INDEX idx_created_at (created_at)
);
```

### Database Design Principles

1. **Normalization**: Separate authentication methods (email/password vs OAuth) into different tables
2. **Flexibility**: Use JSONB for provider-specific data that varies
3. **Security**: Never store plain-text passwords; use strong hashing (bcrypt, Argon2)
4. **Audit Trail**: Log important events for security and debugging
5. **Soft Deletes**: Use `deleted_at` instead of hard deletes for user accounts
6. **Indexing**: Index frequently queried columns (email, tokens, user_id)

---

## Backend Implementation

### Technology Stack Recommendations

**Node.js/Express Example:**
- `bcrypt` or `argon2` for password hashing
- `jsonwebtoken` for JWT tokens
- `passport` for OAuth strategies
- `nodemailer` for email sending
- `express-rate-limit` for rate limiting
- `joi` or `zod` for validation

### 1. Email/Password Registration Endpoint

```javascript
// POST /api/auth/register
const registerWithEmail = async (req, res) => {
  try {
    const { email, password, fullName } = req.body;
    
    // 1. Validate input
    const validationSchema = Joi.object({
      email: Joi.string().email().required(),
      password: Joi.string().min(8).pattern(/[A-Z]/).pattern(/[0-9]/).required(),
      fullName: Joi.string().min(2).max(100).required()
    });
    
    const { error, value } = validationSchema.validate({ email, password, fullName });
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }
    
    // 2. Check if user already exists
    const existingUser = await db.users.findByEmail(email.toLowerCase());
    if (existingUser) {
      return res.status(409).json({ error: 'Email already registered' });
    }
    
    // 3. Hash password
    const passwordHash = await bcrypt.hash(password, 12); // 12 rounds
    
    // 4. Create user in transaction
    const user = await db.transaction(async (trx) => {
      // Create user record
      const newUser = await trx.users.create({
        email: email.toLowerCase(),
        full_name: fullName,
        email_verified: false,
        status: 'active'
      });
      
      // Create credentials
      await trx.userCredentials.create({
        user_id: newUser.id,
        password_hash: passwordHash
      });
      
      // Create verification token
      const verificationToken = crypto.randomBytes(32).toString('hex');
      await trx.emailVerifications.create({
        user_id: newUser.id,
        email: email.toLowerCase(),
        token: verificationToken,
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours
      });
      
      return { user: newUser, verificationToken };
    });
    
    // 5. Send verification email (async, don't block response)
    emailService.sendVerificationEmail(email, user.verificationToken)
      .catch(err => logger.error('Failed to send verification email', err));
    
    // 6. Log audit event
    await auditLog.create({
      user_id: user.user.id,
      event_type: 'registration',
      event_data: { method: 'email', email },
      ip_address: req.ip,
      user_agent: req.headers['user-agent']
    });
    
    // 7. Generate tokens
    const accessToken = generateAccessToken(user.user.id);
    const refreshToken = await generateAndStoreRefreshToken(user.user.id, req);
    
    res.status(201).json({
      user: {
        id: user.user.id,
        email: user.user.email,
        fullName: user.user.full_name,
        emailVerified: false
      },
      tokens: {
        accessToken,
        refreshToken
      }
    });
    
  } catch (error) {
    logger.error('Registration error', error);
    res.status(500).json({ error: 'Registration failed' });
  }
};
```

### 2. OAuth Registration/Login Endpoint

```javascript
// GET /api/auth/oauth/:provider (Initiate OAuth flow)
const initiateOAuth = (req, res) => {
  const { provider } = req.params; // google, facebook, apple
  const state = crypto.randomBytes(16).toString('hex');
  
  // Store state in session or Redis with expiration
  req.session.oauthState = state;
  
  const authUrl = oauthService.getAuthorizationUrl(provider, state);
  res.redirect(authUrl);
};

// GET /api/auth/oauth/:provider/callback
const handleOAuthCallback = async (req, res) => {
  try {
    const { provider } = req.params;
    const { code, state } = req.query;
    
    // 1. Verify state to prevent CSRF
    if (state !== req.session.oauthState) {
      return res.status(400).json({ error: 'Invalid state parameter' });
    }
    
    // 2. Exchange code for access token
    const tokenResponse = await oauthService.exchangeCodeForToken(provider, code);
    const { access_token, refresh_token, expires_in } = tokenResponse;
    
    // 3. Fetch user profile from provider
    const profile = await oauthService.getUserProfile(provider, access_token);
    
    // 4. Find or create user
    const result = await db.transaction(async (trx) => {
      // Check if OAuth account already exists
      let oauthAccount = await trx.oauthProviders.findOne({
        provider,
        provider_user_id: profile.id
      });
      
      let user;
      let isNewUser = false;
      
      if (oauthAccount) {
        // Existing OAuth account - get user
        user = await trx.users.findById(oauthAccount.user_id);
        
        // Update OAuth tokens
        await trx.oauthProviders.update(oauthAccount.id, {
          access_token,
          refresh_token,
          token_expires_at: new Date(Date.now() + expires_in * 1000),
          last_used_at: new Date()
        });
      } else {
        // Check if user with this email exists
        user = await trx.users.findByEmail(profile.email?.toLowerCase());
        
        if (!user) {
          // Create new user
          user = await trx.users.create({
            email: profile.email?.toLowerCase(),
            full_name: profile.name,
            avatar_url: profile.picture,
            email_verified: profile.email_verified || false,
            status: 'active'
          });
          isNewUser = true;
        }
        
        // Link OAuth account to user
        await trx.oauthProviders.create({
          user_id: user.id,
          provider,
          provider_user_id: profile.id,
          access_token,
          refresh_token,
          token_expires_at: new Date(Date.now() + expires_in * 1000),
          provider_email: profile.email,
          provider_name: profile.name,
          provider_avatar_url: profile.picture,
          raw_profile_data: profile,
          last_used_at: new Date()
        });
      }
      
      return { user, isNewUser };
    });
    
    // 5. Log audit event
    await auditLog.create({
      user_id: result.user.id,
      event_type: result.isNewUser ? 'registration' : 'login',
      event_data: { method: 'oauth', provider },
      ip_address: req.ip,
      user_agent: req.headers['user-agent']
    });
    
    // 6. Generate app tokens
    const accessToken = generateAccessToken(result.user.id);
    const refreshToken = await generateAndStoreRefreshToken(result.user.id, req);
    
    // 7. Redirect to mobile app or web dashboard
    const redirectUrl = buildDeepLink({
      accessToken,
      refreshToken,
      isNewUser: result.isNewUser
    });
    
    res.redirect(redirectUrl);
    
  } catch (error) {
    logger.error('OAuth callback error', error);
    res.redirect('/auth/error');
  }
};
```

### 3. Email Verification Endpoint

```javascript
// GET /api/auth/verify-email?token=xxx
const verifyEmail = async (req, res) => {
  try {
    const { token } = req.query;
    
    // 1. Find verification record
    const verification = await db.emailVerifications.findByToken(token);
    
    if (!verification) {
      return res.status(400).json({ error: 'Invalid verification token' });
    }
    
    if (verification.verified_at) {
      return res.status(400).json({ error: 'Email already verified' });
    }
    
    if (new Date() > verification.expires_at) {
      return res.status(400).json({ error: 'Verification token expired' });
    }
    
    // 2. Update user and verification records
    await db.transaction(async (trx) => {
      await trx.users.update(verification.user_id, {
        email_verified: true
      });
      
      await trx.emailVerifications.update(verification.id, {
        verified_at: new Date()
      });
    });
    
    // 3. Log audit event
    await auditLog.create({
      user_id: verification.user_id,
      event_type: 'email_verified',
      ip_address: req.ip
    });
    
    res.json({ message: 'Email verified successfully' });
    
  } catch (error) {
    logger.error('Email verification error', error);
    res.status(500).json({ error: 'Verification failed' });
  }
};
```

### 4. Token Management

```javascript
// Generate JWT access token (short-lived)
const generateAccessToken = (userId) => {
  return jwt.sign(
    { userId, type: 'access' },
    process.env.JWT_SECRET,
    { expiresIn: '15m' } // 15 minutes
  );
};

// Generate and store refresh token (long-lived)
const generateAndStoreRefreshToken = async (userId, req) => {
  const token = crypto.randomBytes(64).toString('hex');
  
  await db.refreshTokens.create({
    user_id: userId,
    token,
    expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
    device_info: {
      platform: req.headers['x-platform'],
      appVersion: req.headers['x-app-version']
    },
    ip_address: req.ip,
    user_agent: req.headers['user-agent']
  });
  
  return token;
};

// POST /api/auth/refresh
const refreshAccessToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    
    const tokenRecord = await db.refreshTokens.findByToken(refreshToken);
    
    if (!tokenRecord || tokenRecord.revoked_at || new Date() > tokenRecord.expires_at) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }
    
    // Update last used
    await db.refreshTokens.update(tokenRecord.id, {
      last_used_at: new Date()
    });
    
    // Generate new access token
    const accessToken = generateAccessToken(tokenRecord.user_id);
    
    res.json({ accessToken });
    
  } catch (error) {
    logger.error('Token refresh error', error);
    res.status(500).json({ error: 'Token refresh failed' });
  }
};
```

### Backend Best Practices

1. **Rate Limiting**: Limit registration attempts per IP (e.g., 5 per hour)
2. **Input Validation**: Validate all inputs on the backend, not just client-side
3. **Transaction Management**: Use database transactions for multi-step operations
4. **Async Operations**: Don't block responses for non-critical operations (emails)
5. **Error Handling**: Don't leak sensitive information in error messages
6. **Logging**: Log all authentication events for security monitoring
7. **Token Rotation**: Rotate refresh tokens periodically
8. **OAuth Token Security**: Encrypt OAuth tokens at rest if storing long-term

---

## Mobile Implementation

### Platform-Specific Considerations

#### iOS (Swift/SwiftUI)

```swift
// OAuth with Apple Sign In (Native)
import AuthenticationServices

class AuthenticationService: NSObject, ASAuthorizationControllerDelegate {
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, 
                                didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let identityToken = appleIDCredential.identityToken
            let authCode = appleIDCredential.authorizationCode
            
            // Send to backend
            sendToBackend(identityToken: identityToken, authCode: authCode)
        }
    }
}

// OAuth with Google Sign In
import GoogleSignIn

func signInWithGoogle() {
    GIDSignIn.sharedInstance.signIn(withPresenting: self) { result, error in
        guard error == nil else { return }
        guard let user = result?.user else { return }
        
        let idToken = user.idToken?.tokenString
        // Send to backend
        sendToBackend(idToken: idToken, provider: "google")
    }
}
```

#### Android (Kotlin)

```kotlin
// OAuth with Google Sign In
class AuthenticationActivity : AppCompatActivity() {
    private val googleSignInClient: GoogleSignInClient by lazy {
        GoogleSignIn.getClient(this, GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(getString(R.string.google_client_id))
            .requestEmail()
            .build())
    }
    
    private val signInLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
            handleGoogleSignInResult(task)
        }
    }
    
    fun signInWithGoogle() {
        signInLauncher.launch(googleSignInClient.signInIntent)
    }
    
    private fun handleGoogleSignInResult(completedTask: Task<GoogleSignInAccount>) {
        try {
            val account = completedTask.getResult(ApiException::class.java)
            val idToken = account?.idToken
            // Send to backend
            sendToBackend(idToken, "google")
        } catch (e: ApiException) {
            Log.e("GoogleSignIn", "Sign in failed", e)
        }
    }
}
```

#### React Native (Cross-Platform)

```javascript
// Email/Password Registration
import { useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

const RegisterScreen = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [loading, setLoading] = useState(false);

  const handleRegister = async () => {
    try {
      setLoading(true);
      
      // Validate inputs
      if (!email || !password || !fullName) {
        Alert.alert('Error', 'Please fill all fields');
        return;
      }
      
      if (password.length < 8) {
        Alert.alert('Error', 'Password must be at least 8 characters');
        return;
      }
      
      // Call API
      const response = await fetch('https://api.yourapp.com/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, fullName })
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        Alert.alert('Error', data.error || 'Registration failed');
        return;
      }
      
      // Store tokens
      await AsyncStorage.setItem('accessToken', data.tokens.accessToken);
      await AsyncStorage.setItem('refreshToken', data.tokens.refreshToken);
      
      // Navigate to verification screen
      navigation.navigate('EmailVerification');
      
    } catch (error) {
      Alert.alert('Error', 'Network error occurred');
    } finally {
      setLoading(false);
    }
  };

  return (
    <View>
      <TextInput
        placeholder="Full Name"
        value={fullName}
        onChangeText={setFullName}
      />
      <TextInput
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoCapitalize="none"
      />
      <TextInput
        placeholder="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
      />
      <Button title="Register" onPress={handleRegister} loading={loading} />
    </View>
  );
};

// Google Sign In
import { GoogleSignin } from '@react-native-google-signin/google-signin';

GoogleSignin.configure({
  webClientId: 'YOUR_WEB_CLIENT_ID',
  offlineAccess: true
});

const signInWithGoogle = async () => {
  try {
    await GoogleSignin.hasPlayServices();
    const userInfo = await GoogleSignin.signIn();
    
    // Send ID token to backend
    const response = await fetch('https://api.yourapp.com/auth/oauth/google', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: userInfo.idToken })
    });
    
    const data = await response.json();
    
    // Store tokens
    await AsyncStorage.setItem('accessToken', data.tokens.accessToken);
    await AsyncStorage.setItem('refreshToken', data.tokens.refreshToken);
    
    navigation.navigate('Home');
    
  } catch (error) {
    console.error('Google Sign In Error:', error);
  }
};

// Apple Sign In (iOS only)
import appleAuth from '@invertase/react-native-apple-authentication';

const signInWithApple = async () => {
  try {
    const appleAuthRequestResponse = await appleAuth.performRequest({
      requestedOperation: appleAuth.Operation.LOGIN,
      requestedScopes: [appleAuth.Scope.EMAIL, appleAuth.Scope.FULL_NAME],
    });
    
    const { identityToken, authorizationCode } = appleAuthRequestResponse;
    
    // Send to backend
    const response = await fetch('https://api.yourapp.com/auth/oauth/apple', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identityToken, authorizationCode })
    });
    
    const data = await response.json();
    
    // Store tokens
    await AsyncStorage.setItem('accessToken', data.tokens.accessToken);
    await AsyncStorage.setItem('refreshToken', data.tokens.refreshToken);
    
    navigation.navigate('Home');
    
  } catch (error) {
    console.error('Apple Sign In Error:', error);
  }
};
```

### Mobile Best Practices

1. **Secure Storage**: Use Keychain (iOS) or Keystore (Android) for tokens
2. **Deep Linking**: Handle OAuth callbacks via deep links/universal links
3. **Biometric Auth**: Implement Face ID/Touch ID for subsequent logins
4. **Token Refresh**: Implement automatic token refresh before expiration
5. **Network Handling**: Handle offline scenarios gracefully
6. **Loading States**: Show clear loading indicators during authentication
7. **Error Messages**: Provide user-friendly error messages
8. **Platform-Specific**: Use native OAuth flows when available (Sign in with Apple)

### Deep Linking Setup

**iOS (Info.plist):**
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>yourapp</string>
    </array>
  </dict>
</array>
```

**Android (AndroidManifest.xml):**
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="yourapp" android:host="auth" />
</intent-filter>
```

**React Native Handling:**
```javascript
import { Linking } from 'react-native';

useEffect(() => {
  const handleDeepLink = (event) => {
    const url = event.url;
    // yourapp://auth/callback?token=xxx
    const token = extractTokenFromUrl(url);
    if (token) {
      AsyncStorage.setItem('accessToken', token);
      navigation.navigate('Home');
    }
  };
  
  Linking.addEventListener('url', handleDeepLink);
  
  return () => {
    Linking.removeEventListener('url', handleDeepLink);
  };
}, []);
```

---

## Security Best Practices

### 1. Password Security

```javascript
// Password hashing with bcrypt
const bcrypt = require('bcrypt');

const hashPassword = async (password) => {
  const saltRounds = 12; // Higher is more secure but slower
  return await bcrypt.hash(password, saltRounds);
};

const verifyPassword = async (password, hash) => {
  return await bcrypt.compare(password, hash);
};

// Password requirements
const PASSWORD_REQUIREMENTS = {
  minLength: 8,
  requireUppercase: true,
  requireLowercase: true,
  requireNumbers: true,
  requireSpecialChars: true
};

const validatePassword = (password) => {
  if (password.length < PASSWORD_REQUIREMENTS.minLength) {
    return { valid: false, error: 'Password too short' };
  }
  if (PASSWORD_REQUIREMENTS.requireUppercase && !/[A-Z]/.test(password)) {
    return { valid: false, error: 'Password must contain uppercase letter' };
  }
  if (PASSWORD_REQUIREMENTS.requireLowercase && !/[a-z]/.test(password)) {
    return { valid: false, error: 'Password must contain lowercase letter' };
  }
  if (PASSWORD_REQUIREMENTS.requireNumbers && !/[0-9]/.test(password)) {
    return { valid: false, error: 'Password must contain number' };
  }
  if (PASSWORD_REQUIREMENTS.requireSpecialChars && !/[!@#$%^&*]/.test(password)) {
    return { valid: false, error: 'Password must contain special character' };
  }
  return { valid: true };
};
```

### 2. Rate Limiting

```javascript
const rateLimit = require('express-rate-limit');

const registrationLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // 5 requests per hour
  message: 'Too many registration attempts, please try again later',
  standardHeaders: true,
  legacyHeaders: false
});

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // 10 requests per 15 minutes
  skipSuccessfulRequests: true // Don't count successful logins
});

app.post('/api/auth/register', registrationLimiter, registerWithEmail);
app.post('/api/auth/login', loginLimiter, login);
```

### 3. Account Lockout

```javascript
const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION = 30 * 60 * 1000; // 30 minutes

const handleFailedLogin = async (userId) => {
  const credentials = await db.userCredentials.findByUserId(userId);
  
  const failedAttempts = credentials.failed_login_attempts + 1;
  
  if (failedAttempts >= MAX_FAILED_ATTEMPTS) {
    await db.userCredentials.update(credentials.id, {
      failed_login_attempts: failedAttempts,
      locked_until: new Date(Date.now() + LOCKOUT_DURATION)
    });
    throw new Error('Account locked due to too many failed attempts');
  }
  
  await db.userCredentials.update(credentials.id, {
    failed_login_attempts: failedAttempts
  });
};

const checkAccountLocked = async (userId) => {
  const credentials = await db.userCredentials.findByUserId(userId);
  
  if (credentials.locked_until && new Date() < credentials.locked_until) {
    throw new Error('Account is temporarily locked');
  }
  
  // Reset failed attempts if lockout period expired
  if (credentials.locked_until && new Date() >= credentials.locked_until) {
    await db.userCredentials.update(credentials.id, {
      failed_login_attempts: 0,
      locked_until: null
    });
  }
};
```

### 4. CSRF Protection

```javascript
const csrf = require('csurf');

// For web applications
const csrfProtection = csrf({ cookie: true });

app.get('/api/auth/csrf-token', csrfProtection, (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});

app.post('/api/auth/register', csrfProtection, registerWithEmail);
```

### 5. OAuth Security

```javascript
// Validate OAuth state parameter
const validateOAuthState = (receivedState, sessionState) => {
  if (!receivedState || receivedState !== sessionState) {
    throw new Error('Invalid OAuth state - possible CSRF attack');
  }
};

// Validate OAuth ID token (for providers that support it)
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

const verifyGoogleIdToken = async (idToken) => {
  const client = jwksClient({
    jwksUri: 'https://www.googleapis.com/oauth2/v3/certs'
  });
  
  const getKey = (header, callback) => {
    client.getSigningKey(header.kid, (err, key) => {
      const signingKey = key.publicKey || key.rsaPublicKey;
      callback(null, signingKey);
    });
  };
  
  return new Promise((resolve, reject) => {
    jwt.verify(idToken, getKey, {
      algorithms: ['RS256'],
      audience: process.env.GOOGLE_CLIENT_ID,
      issuer: 'https://accounts.google.com'
    }, (err, decoded) => {
      if (err) reject(err);
      else resolve(decoded);
    });
  });
};
```

### 6. Data Protection

- **Encryption at Rest**: Encrypt sensitive data in database
- **Encryption in Transit**: Always use HTTPS/TLS
- **PII Protection**: Minimize collection and storage of personal data
- **GDPR Compliance**: Implement data export and deletion
- **Audit Logging**: Log all authentication events with IP and user agent

### 7. Token Security

- **Short-lived Access Tokens**: 15 minutes max
- **Long-lived Refresh Tokens**: 30 days, revokable
- **Token Rotation**: Issue new refresh token on use
- **Secure Storage**: HttpOnly cookies for web, secure storage for mobile
- **Token Revocation**: Implement logout and revoke all sessions

---

## Error Handling

### User-Friendly Error Messages

```javascript
const ERROR_MESSAGES = {
  EMAIL_ALREADY_EXISTS: 'An account with this email already exists',
  INVALID_CREDENTIALS: 'Invalid email or password',
  ACCOUNT_LOCKED: 'Account temporarily locked due to too many failed attempts',
  EMAIL_NOT_VERIFIED: 'Please verify your email address',
  WEAK_PASSWORD: 'Password does not meet security requirements',
  INVALID_TOKEN: 'Invalid or expired token',
  OAUTH_FAILED: 'Authentication failed. Please try again',
  NETWORK_ERROR: 'Network error. Please check your connection',
  SERVER_ERROR: 'Something went wrong. Please try again later'
};

// Don't expose internal errors to users
const handleError = (error, res) => {
  logger.error('Error:', error);
  
  if (error.code === 'USER_EXISTS') {
    return res.status(409).json({ error: ERROR_MESSAGES.EMAIL_ALREADY_EXISTS });
  }
  
  if (error.code === 'INVALID_CREDENTIALS') {
    return res.status(401).json({ error: ERROR_MESSAGES.INVALID_CREDENTIALS });
  }
  
  // Generic error for unexpected issues
  return res.status(500).json({ error: ERROR_MESSAGES.SERVER_ERROR });
};
```

### Mobile Error Handling

```javascript
const handleAuthError = (error) => {
  switch (error.code) {
    case 'EMAIL_ALREADY_EXISTS':
      Alert.alert('Account Exists', 'An account with this email already exists. Would you like to log in?', [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Log In', onPress: () => navigation.navigate('Login') }
      ]);
      break;
      
    case 'WEAK_PASSWORD':
      Alert.alert('Weak Password', 'Password must be at least 8 characters with uppercase, lowercase, and numbers');
      break;
      
    case 'NETWORK_ERROR':
      Alert.alert('Connection Error', 'Please check your internet connection and try again');
      break;
      
    default:
      Alert.alert('Error', error.message || 'Something went wrong');
  }
};
```

---

## Testing Considerations

### Unit Tests

```javascript
// Backend - Jest example
describe('User Registration', () => {
  test('should create user with valid email and password', async () => {
    const userData = {
      email: 'test@example.com',
      password: 'Password123!',
      fullName: 'Test User'
    };
    
    const result = await authService.register(userData);
    
    expect(result.user).toBeDefined();
    expect(result.user.email).toBe(userData.email);
    expect(result.tokens).toBeDefined();
  });
  
  test('should reject weak passwords', async () => {
    const userData = {
      email: 'test@example.com',
      password: 'weak',
      fullName: 'Test User'
    };
    
    await expect(authService.register(userData)).rejects.toThrow('Password does not meet requirements');
  });
  
  test('should reject duplicate emails', async () => {
    const userData = {
      email: 'existing@example.com',
      password: 'Password123!',
      fullName: 'Test User'
    };
    
    await authService.register(userData);
    await expect(authService.register(userData)).rejects.toThrow('Email already registered');
  });
});
```

### Integration Tests

```javascript
// Backend - Supertest example
describe('POST /api/auth/register', () => {
  test('should return 201 and tokens on successful registration', async () => {
    const response = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'newuser@example.com',
        password: 'Password123!',
        fullName: 'New User'
      });
    
    expect(response.status).toBe(201);
    expect(response.body.user).toBeDefined();
    expect(response.body.tokens.accessToken).toBeDefined();
    expect(response.body.tokens.refreshToken).toBeDefined();
  });
  
  test('should return 409 for duplicate email', async () => {
    // Create user first
    await createTestUser({ email: 'existing@example.com' });
    
    const response = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'existing@example.com',
        password: 'Password123!',
        fullName: 'Test User'
      });
    
    expect(response.status).toBe(409);
  });
});
```

### Mobile Tests

```javascript
// React Native - Jest + React Testing Library
describe('RegisterScreen', () => {
  test('should display validation error for weak password', async () => {
    const { getByPlaceholder, getByText } = render(<RegisterScreen />);
    
    const passwordInput = getByPlaceholder('Password');
    fireEvent.changeText(passwordInput, 'weak');
    
    const registerButton = getByText('Register');
    fireEvent.press(registerButton);
    
    await waitFor(() => {
      expect(getByText(/password must be at least 8 characters/i)).toBeTruthy();
    });
  });
  
  test('should call API and navigate on successful registration', async () => {
    const mockNavigate = jest.fn();
    jest.mock('@react-navigation/native', () => ({
      useNavigation: () => ({ navigate: mockNavigate })
    }));
    
    fetch.mockResponseOnce(JSON.stringify({
      user: { id: '1', email: 'test@example.com' },
      tokens: { accessToken: 'xxx', refreshToken: 'yyy' }
    }));
    
    const { getByPlaceholder, getByText } = render(<RegisterScreen />);
    
    fireEvent.changeText(getByPlaceholder('Email'), 'test@example.com');
    fireEvent.changeText(getByPlaceholder('Password'), 'Password123!');
    fireEvent.changeText(getByPlaceholder('Full Name'), 'Test User');
    fireEvent.press(getByText('Register'));
    
    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith('EmailVerification');
    });
  });
});
```

### E2E Tests

```javascript
// Detox (React Native E2E)
describe('User Registration Flow', () => {
  beforeAll(async () => {
    await device.launchApp();
  });
  
  test('should complete registration flow', async () => {
    // Navigate to register screen
    await element(by.id('register-button')).tap();
    
    // Fill form
    await element(by.id('full-name-input')).typeText('Test User');
    await element(by.id('email-input')).typeText('test@example.com');
    await element(by.id('password-input')).typeText('Password123!');
    
    // Submit
    await element(by.id('submit-register')).tap();
    
    // Verify navigation to verification screen
    await expect(element(by.id('verification-screen'))).toBeVisible();
  });
});
```

---

## Summary Checklist

### Database
- [ ] Users table with proper indexes
- [ ] Separate credentials table for email/password
- [ ] OAuth providers table for multiple providers
- [ ] Email verification system
- [ ] Refresh tokens table
- [ ] Audit logging
- [ ] Soft deletes implemented

### Backend
- [ ] Email/password registration endpoint
- [ ] OAuth endpoints for each provider
- [ ] Email verification system
- [ ] Token generation and refresh
- [ ] Rate limiting on all auth endpoints
- [ ] Account lockout mechanism
- [ ] CSRF protection
- [ ] Input validation
- [ ] Secure password hashing (bcrypt/Argon2)
- [ ] Audit logging

### Mobile
- [ ] Email/password registration UI
- [ ] OAuth buttons for each provider
- [ ] Deep linking configured
- [ ] Secure token storage (Keychain/Keystore)
- [ ] Token refresh mechanism
- [ ] Biometric authentication (optional)
- [ ] Error handling
- [ ] Loading states
- [ ] Offline handling

### Security
- [ ] HTTPS enforced
- [ ] Password strength requirements
- [ ] Rate limiting
- [ ] Account lockout
- [ ] Token expiration
- [ ] OAuth state validation
- [ ] CSRF tokens
- [ ] SQL injection prevention
- [ ] XSS prevention
- [ ] Audit logging

### Testing
- [ ] Unit tests for business logic
- [ ] Integration tests for API endpoints
- [ ] Mobile component tests
- [ ] E2E tests for critical flows
- [ ] Security testing
- [ ] Load testing

---

## Additional Resources

### Recommended Libraries

**Backend:**
- Password Hashing: `bcrypt`, `argon2`
- JWT: `jsonwebtoken`
- OAuth: `passport`, `passport-google-oauth20`, `passport-facebook`
- Validation: `joi`, `zod`, `yup`
- Rate Limiting: `express-rate-limit`
- Email: `nodemailer`, `sendgrid`

**Mobile:**
- React Native: `@react-native-google-signin/google-signin`, `@invertase/react-native-apple-authentication`
- Storage: `@react-native-async-storage/async-storage`, `react-native-keychain`
- Deep Linking: `react-native-deep-linking`, built-in Linking API

### OAuth Provider Documentation
- [Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)
- [Facebook Login](https://developers.facebook.com/docs/facebook-login)
- [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/)
- [GitHub OAuth](https://docs.github.com/en/developers/apps/building-oauth-apps)
- [Twitter OAuth 2.0](https://developer.twitter.com/en/docs/authentication/oauth-2-0)

### Security Resources
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [NIST Digital Identity Guidelines](https://pages.nist.gov/800-63-3/)
- [OAuth 2.0 Security Best Practices](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)

---

**Document Version:** 1.0  
**Last Updated:** October 10, 2025  
**Maintained By:** Development Team
