import Foundation

class DefaultUserRepository: UserRepository {
    private let remoteDataSource: UserRemoteDataSource
    private let localDataSource: UserLocalDataSource

    init(remoteDataSource: UserRemoteDataSource, localDataSource: UserLocalDataSource) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func getUser(id: String) async throws -> User {
        // Logic to fetch from local or remote data source
        let userDTO = try await remoteDataSource.getUser(id: id)
        return userDTO.toDomain()
    }
}
