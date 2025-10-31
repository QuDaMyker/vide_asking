import Foundation
import Amplify
import AWSCognitoAuthPlugin
import Combine

/// AWS Cognito Authentication Manager for SwiftUI
/// Handles user authentication with AWS Cognito
@MainActor
class CognitoAuthManager: ObservableObject {
    static let shared = CognitoAuthManager()
    
    @Published var authState: AuthState = .unauthenticated
    @Published var currentUser: AuthUser?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Subscribe to auth hub events
        subscribeToAuthEvents()
        
        // Check initial auth state
        Task {
            await updateAuthState()
        }
    }
    
    /// Subscribe to authentication events
    private func subscribeToAuthEvents() {
        Amplify.Hub.publisher(for: .auth)
            .sink { [weak self] payload in
                switch payload.eventName {
                case HubPayload.EventName.Auth.signedIn:
                    Task {
                        await self?.updateAuthState()
                    }
                case HubPayload.EventName.Auth.signedOut:
                    self?.authState = .unauthenticated
                    self?.currentUser = nil
                case HubPayload.EventName.Auth.sessionExpired:
                    self?.authState = .unauthenticated
                    self?.currentUser = nil
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    /// Update auth state
    private func updateAuthState() async {
        do {
            let user = try await getCurrentUser()
            currentUser = user
            authState = .authenticated(user)
        } catch {
            currentUser = nil
            authState = .unauthenticated
        }
    }
    
    /// Sign up a new user
    func signUp(
        email: String,
        password: String,
        attributes: [AuthUserAttributeKey: String] = [:]
    ) async throws -> AuthSignUpResult {
        let userAttributes = attributes.map { key, value in
            AuthUserAttribute(key, value: value)
        }
        
        let options = AuthSignUpRequest.Options(
            userAttributes: userAttributes
        )
        
        return try await Amplify.Auth.signUp(
            username: email,
            password: password,
            options: options
        )
    }
    
    /// Confirm sign up with verification code
    func confirmSignUp(
        email: String,
        confirmationCode: String
    ) async throws -> AuthSignUpResult {
        return try await Amplify.Auth.confirmSignUp(
            for: email,
            confirmationCode: confirmationCode
        )
    }
    
    /// Sign in with email and password
    func signIn(
        email: String,
        password: String
    ) async throws -> AuthSignInResult {
        let result = try await Amplify.Auth.signIn(
            username: email,
            password: password
        )
        
        if result.isSignedIn {
            await updateAuthState()
        }
        
        return result
    }
    
    /// Sign in with social provider
    func signInWithSocialProvider(
        provider: AuthProvider,
        presentationAnchor: AuthUIPresentationAnchor
    ) async throws -> AuthSignInResult {
        let result = try await Amplify.Auth.signInWithWebUI(
            for: provider,
            presentationAnchor: presentationAnchor
        )
        
        if result.isSignedIn {
            await updateAuthState()
        }
        
        return result
    }
    
    /// Sign out
    func signOut() async throws {
        _ = await Amplify.Auth.signOut()
        authState = .unauthenticated
        currentUser = nil
    }
    
    /// Sign out globally (all devices)
    func signOutGlobally() async throws {
        let options = AuthSignOutRequest.Options(globalSignOut: true)
        _ = await Amplify.Auth.signOut(options: options)
        authState = .unauthenticated
        currentUser = nil
    }
    
    /// Get current user
    func getCurrentUser() async throws -> AuthUser {
        return try await Amplify.Auth.getCurrentUser()
    }
    
    /// Check if user is authenticated
    func isAuthenticated() async -> Bool {
        do {
            _ = try await getCurrentUser()
            return true
        } catch {
            return false
        }
    }
    
    /// Fetch user attributes
    func fetchUserAttributes() async throws -> [AuthUserAttribute] {
        return try await Amplify.Auth.fetchUserAttributes()
    }
    
    /// Update user attribute
    func updateUserAttribute(
        key: AuthUserAttributeKey,
        value: String
    ) async throws -> AuthUpdateAttributeResult {
        let attribute = AuthUserAttribute(key, value: value)
        return try await Amplify.Auth.update(userAttribute: attribute)
    }
    
    /// Update user attributes
    func updateUserAttributes(
        _ attributes: [AuthUserAttributeKey: String]
    ) async throws -> [AuthUserAttributeKey: AuthUpdateAttributeResult] {
        let userAttributes = attributes.map { key, value in
            AuthUserAttribute(key, value: value)
        }
        return try await Amplify.Auth.update(userAttributes: userAttributes)
    }
    
    /// Reset password
    func resetPassword(email: String) async throws -> AuthResetPasswordResult {
        return try await Amplify.Auth.resetPassword(for: email)
    }
    
    /// Confirm reset password
    func confirmResetPassword(
        email: String,
        newPassword: String,
        confirmationCode: String
    ) async throws {
        try await Amplify.Auth.confirmResetPassword(
            for: email,
            with: newPassword,
            confirmationCode: confirmationCode
        )
    }
    
    /// Change password
    func changePassword(
        oldPassword: String,
        newPassword: String
    ) async throws {
        try await Amplify.Auth.update(
            oldPassword: oldPassword,
            to: newPassword
        )
    }
    
    /// Get access token
    func getAccessToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        
        guard let cognitoSession = session as? AuthCognitoTokensProvider else {
            throw AuthError.unknown("Unable to get Cognito session")
        }
        
        let tokens = try cognitoSession.getCognitoTokens().get()
        return tokens.accessToken
    }
    
    /// Get ID token
    func getIdToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        
        guard let cognitoSession = session as? AuthCognitoTokensProvider else {
            throw AuthError.unknown("Unable to get Cognito session")
        }
        
        let tokens = try cognitoSession.getCognitoTokens().get()
        return tokens.idToken
    }
    
    /// Resend sign up code
    func resendSignUpCode(email: String) async throws -> AuthCodeDeliveryDetails {
        return try await Amplify.Auth.resendSignUpCode(for: email)
    }
    
    /// Delete user account
    func deleteUser() async throws {
        try await Amplify.Auth.deleteUser()
        authState = .unauthenticated
        currentUser = nil
    }
}

/// Authentication state
enum AuthState: Equatable {
    case authenticated(AuthUser)
    case unauthenticated
    case error(String)
    
    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
}

/// Supported social providers
enum SocialAuthProvider {
    case google
    case facebook
    case apple
    case amazon
    
    var authProvider: AuthProvider {
        switch self {
        case .google:
            return .google
        case .facebook:
            return .facebook
        case .apple:
            return .apple
        case .amazon:
            return .amazon
        }
    }
}
