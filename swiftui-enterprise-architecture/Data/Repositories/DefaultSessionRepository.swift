import Foundation

class DefaultSessionRepository: SessionRepository {
    private let sessionStorage: SessionStorage

    init(sessionStorage: SessionStorage) {
        self.sessionStorage = sessionStorage
    }

    func isLoggedIn() -> Bool {
        return sessionStorage.isLoggedIn()
    }

    func login() {
        sessionStorage.save(isLoggedIn: true)
    }

    func logout() {
        sessionStorage.save(isLoggedIn: false)
    }
}
