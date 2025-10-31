import Foundation
import Amplify
import AWSCognitoAuthPlugin
import AWSS3StoragePlugin
import AWSAPIPlugin
import AWSDataStorePlugin

/// AWS Amplify Manager for SwiftUI
/// Handles initialization and configuration of AWS Amplify SDK
@MainActor
class AmplifyManager: ObservableObject {
    static let shared = AmplifyManager()
    
    @Published var isConfigured = false
    @Published var configurationError: Error?
    
    private init() {}
    
    /// Initialize AWS Amplify with all plugins
    func initialize() async throws {
        guard !isConfigured else {
            print("Amplify already configured")
            return
        }
        
        do {
            // Add plugins
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSS3StoragePlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.add(plugin: AWSDataStorePlugin(modelRegistration: AmplifyModels()))
            
            // Configure Amplify
            try Amplify.configure()
            
            isConfigured = true
            print("Amplify configured successfully")
            
        } catch {
            configurationError = error
            print("Error configuring Amplify: \(error)")
            throw error
        }
    }
    
    /// Get configuration status
    func getStatus() -> AmplifyStatus {
        return AmplifyStatus(
            isConfigured: isConfigured,
            hasAuth: hasPlugin(AWSCognitoAuthPlugin.self),
            hasStorage: hasPlugin(AWSS3StoragePlugin.self),
            hasAPI: hasPlugin(AWSAPIPlugin.self),
            hasDataStore: hasPlugin(AWSDataStorePlugin.self)
        )
    }
    
    private func hasPlugin<P: Plugin>(_ pluginType: P.Type) -> Bool {
        do {
            _ = try Amplify.plugin(for: pluginType)
            return true
        } catch {
            return false
        }
    }
}

/// Amplify status
struct AmplifyStatus {
    let isConfigured: Bool
    let hasAuth: Bool
    let hasStorage: Bool
    let hasAPI: Bool
    let hasDataStore: Bool
    
    var description: String {
        """
        AmplifyStatus(
            configured: \(isConfigured),
            auth: \(hasAuth),
            storage: \(hasStorage),
            api: \(hasAPI),
            dataStore: \(hasDataStore)
        )
        """
    }
}

/// Amplify models registration
struct AmplifyModels: AmplifyModelRegistration {
    public let version: String = "1.0"
    
    func registerModels(registry: ModelRegistry.Type) {
        // Register your DataStore models here
        // ModelRegistry.register(modelType: YourModel.self)
    }
}
