import Foundation

protocol SessionRepository {
    func isLoggedIn() -> Bool
    func login()
    func logout()
}
