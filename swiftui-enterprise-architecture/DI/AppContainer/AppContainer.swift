import Foundation

class AppContainer {
    // Create and provide dependencies for the application
    
    // Session
    lazy var sessionStorage: SessionStorage = UserDefaultsSessionStorage()
    lazy var sessionRepository: SessionRepository = DefaultSessionRepository(sessionStorage: sessionStorage)
    lazy var checkSessionUseCase: CheckSessionUseCase = DefaultCheckSessionUseCase(sessionRepository: sessionRepository)
    lazy var loginUseCase: LoginUseCase = DefaultLoginUseCase(sessionRepository: sessionRepository)
    lazy var logoutUseCase: LogoutUseCase = DefaultLogoutUseCase(sessionRepository: sessionRepository)

    // Example:
    lazy var apiClient: APIClient = DefaultAPIClient()
    
    lazy var userRemoteDataSource: UserRemoteDataSource = DefaultUserRemoteDataSource(apiClient: apiClient)
    lazy var userLocalDataSource: UserLocalDataSource = DefaultUserLocalDataSource()
    
    lazy var userRepository: UserRepository = DefaultUserRepository(
        remoteDataSource: userRemoteDataSource,
        localDataSource: userLocalDataSource
    )
    
    lazy var getUserUseCase: GetUserUseCase = DefaultGetUserUseCase(userRepository: userRepository)
}
