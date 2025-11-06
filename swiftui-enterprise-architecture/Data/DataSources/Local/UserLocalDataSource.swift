import Foundation

protocol UserLocalDataSource {
    func getUser(id: String) -> UserDTO?
    func saveUser(_ user: UserDTO)
}

class DefaultUserLocalDataSource: UserLocalDataSource {
    func getUser(id: String) -> UserDTO? {
        // Logic to fetch user from a local database (e.g., Core Data, Realm)
        return nil
    }

    func saveUser(_ user: UserDTO) {
        // Logic to save user to a local database
    }
}
