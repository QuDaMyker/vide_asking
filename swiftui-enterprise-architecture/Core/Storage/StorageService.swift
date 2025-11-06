import Foundation

protocol StorageService {
    func save(value: Any, forKey key: String)
    func getValue(forKey key: String) -> Any?
}

class UserDefaultsStorageService: StorageService {
    private let userDefaults = UserDefaults.standard

    func save(value: Any, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    func getValue(forKey key: String) -> Any? {
        return userDefaults.value(forKey: key)
    }
}
