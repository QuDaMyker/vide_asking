import Foundation
import Combine

class LoginViewModel: ObservableObject {
    private let loginUseCase: LoginUseCase
    var onLoginSuccess: () -> Void = {}

    init(loginUseCase: LoginUseCase) {
        self.loginUseCase = loginUseCase
    }

    func login() {
        loginUseCase.execute()
        onLoginSuccess()
    }
}
