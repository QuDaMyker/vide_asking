import Foundation

protocol UserRepository {
    func getUser(id: String) async throws -> User
}
