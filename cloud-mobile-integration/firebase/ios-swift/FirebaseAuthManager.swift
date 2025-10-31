import Foundation
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import Combine

/// Firebase Authentication Manager for SwiftUI
/// Handles user authentication with Firebase Auth
@MainActor
class FirebaseAuthManager: NSObject, ObservableObject {
    static let shared = FirebaseAuthManager()
    
    @Published var currentUser: User?
    @Published var authState: FirebaseAuthState = .unauthenticated
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    
    override private init() {
        super.init()
        setupAuthStateListener()
    }
    
    /// Setup auth state listener
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.authState = user != nil ? .authenticated(user!) : .unauthenticated
            print("Auth state changed: \(user?.uid ?? "nil")")
        }
        
        // Set initial user
        currentUser = Auth.auth().currentUser
        authState = currentUser != nil ? .authenticated(currentUser!) : .unauthenticated
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    /// Sign up with email and password
    func signUpWithEmail(
        email: String,
        password: String
    ) async throws -> User {
        let authResult = try await Auth.auth().createUser(
            withEmail: email,
            password: password
        )
        return authResult.user
    }
    
    /// Sign in with email and password
    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> User {
        let authResult = try await Auth.auth().signIn(
            withEmail: email,
            password: password
        )
        return authResult.user
    }
    
    /// Sign in with Google
    func signInWithGoogle() async throws -> User {
        // Get the client ID from Firebase
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(
                domain: "FirebaseAuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing Firebase client ID"]
            )
        }
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(
                domain: "FirebaseAuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No root view controller"]
            )
        }
        
        // Start sign-in flow
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController
        )
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(
                domain: "FirebaseAuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing ID token"]
            )
        }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user
    }
    
    /// Sign in with Apple
    func signInWithApple() async throws -> User {
        let provider = OAuthProvider(providerID: "apple.com")
        let authResult = try await Auth.auth().signIn(with: provider)
        return authResult.user
    }
    
    /// Sign in with Apple (using ASAuthorizationController)
    func signInWithAppleController(
        authorization: ASAuthorization
    ) async throws -> User {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw NSError(
                domain: "FirebaseAuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Apple ID credential"]
            )
        }
        
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw NSError(
                domain: "FirebaseAuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"]
            )
        }
        
        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        )
        
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user
    }
    
    /// Sign in with Facebook
    func signInWithFacebook(accessToken: String) async throws -> User {
        let credential = FacebookAuthProvider.credential(withAccessToken: accessToken)
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user
    }
    
    /// Sign in with phone number
    func signInWithPhoneNumber(
        phoneNumber: String
    ) async throws -> String {
        let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(
            phoneNumber,
            uiDelegate: nil
        )
        return verificationID
    }
    
    /// Verify phone code
    func verifyPhoneCode(
        verificationID: String,
        code: String
    ) async throws -> User {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user
    }
    
    /// Sign in anonymously
    func signInAnonymously() async throws -> User {
        let authResult = try await Auth.auth().signInAnonymously()
        return authResult.user
    }
    
    /// Sign out
    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
        authState = .unauthenticated
    }
    
    /// Get current user
    func getCurrentUser() -> User? {
        return Auth.auth().currentUser
    }
    
    /// Check if user is authenticated
    func isAuthenticated() -> Bool {
        return Auth.auth().currentUser != nil
    }
    
    /// Send email verification
    func sendEmailVerification() async throws {
        try await currentUser?.sendEmailVerification()
    }
    
    /// Send password reset email
    func sendPasswordResetEmail(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    /// Update email
    func updateEmail(newEmail: String) async throws {
        try await currentUser?.updateEmail(to: newEmail)
    }
    
    /// Update password
    func updatePassword(newPassword: String) async throws {
        try await currentUser?.updatePassword(to: newPassword)
    }
    
    /// Update profile
    func updateProfile(
        displayName: String? = nil,
        photoURL: URL? = nil
    ) async throws {
        let changeRequest = currentUser?.createProfileChangeRequest()
        
        if let displayName = displayName {
            changeRequest?.displayName = displayName
        }
        
        if let photoURL = photoURL {
            changeRequest?.photoURL = photoURL
        }
        
        try await changeRequest?.commitChanges()
    }
    
    /// Delete account
    func deleteAccount() async throws {
        try await currentUser?.delete()
        currentUser = nil
        authState = .unauthenticated
    }
    
    /// Get ID token
    func getIdToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = currentUser else {
            throw NSError(
                domain: "FirebaseAuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]
            )
        }
        
        return try await user.getIDToken(forcingRefresh: forceRefresh)
    }
    
    /// Link email credential
    func linkEmailCredential(
        email: String,
        password: String
    ) async throws -> User {
        let credential = EmailAuthProvider.credential(
            withEmail: email,
            password: password
        )
        
        let authResult = try await currentUser?.link(with: credential)
        return authResult!.user
    }
    
    /// Re-authenticate user
    func reauthenticate(
        email: String,
        password: String
    ) async throws {
        let credential = EmailAuthProvider.credential(
            withEmail: email,
            password: password
        )
        
        try await currentUser?.reauthenticate(with: credential)
    }
    
    /// Reload user data
    func reloadUser() async throws {
        try await currentUser?.reload()
    }
    
    /// Check if email is verified
    func isEmailVerified() -> Bool {
        return currentUser?.isEmailVerified ?? false
    }
    
    /// Get user metadata
    func getUserMetadata() -> UserMetadata? {
        return currentUser?.metadata
    }
    
    /// Unlink provider
    func unlinkProvider(_ providerID: String) async throws -> User {
        let user = try await currentUser?.unlink(fromProvider: providerID)
        return user!
    }
}

/// Firebase authentication state
enum FirebaseAuthState: Equatable {
    case authenticated(User)
    case unauthenticated
    case error(String)
    
    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
    
    static func == (lhs: FirebaseAuthState, rhs: FirebaseAuthState) -> Bool {
        switch (lhs, rhs) {
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.uid == rhsUser.uid
        case (.unauthenticated, .unauthenticated):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

#if canImport(UIKit)
import UIKit
import FirebaseCore
#endif
