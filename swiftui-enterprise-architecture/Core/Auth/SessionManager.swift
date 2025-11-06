import Foundation
import Combine

class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool = false

    func updateLoginStatus(isLoggedIn: Bool) {
        self.isLoggedIn = isLoggedIn
    }
}
