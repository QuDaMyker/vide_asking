import Foundation

protocol SessionStorage {
    func isLoggedIn() -> Bool
    func save(isLoggedIn: Bool)
}

class UserDefaultsSessionStorage: SessionStorage {
    private let isLoggedInKey = "isLoggedIn"

    func isLoggedIn() -> Bool {
        return UserDefaults.standard.bool(forKey: isLoggedInKey)
    }

    func save(isLoggedIn: Bool) {
        UserDefaults.standard.set(isLoggedIn, forKey: isLoggedInKey)
    }
}
