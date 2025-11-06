import Foundation

protocol GetUserUseCase {
    func execute(id: String) async throws -> User
}

class DefaultGetUserUseCase: GetUserUseCase {
    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func execute(id: String) async throws -> User {
        return try await userRepository.getUser(id: id)
    }
}
