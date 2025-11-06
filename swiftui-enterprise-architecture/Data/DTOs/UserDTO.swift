import Foundation

struct UserDTO: Codable {
    let id: String
    let name: String
    let email: String
}

extension UserDTO {
    func toDomain() -> User {
        return User(id: id, name: name, email: email)
    }
}
