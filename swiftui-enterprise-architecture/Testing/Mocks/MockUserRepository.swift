import Foundation
@testable import swiftui_enterprise_architecture

class MockUserRepository: UserRepository {
    var user: User?
    var error: Error?

    func getUser(id: String) async throws -> User {
        if let error = error {
            throw error
        }
        guard let user = user else {
            throw NSError(domain: "MockUserRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        return user
    }
}
