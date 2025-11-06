import Foundation
import Combine

class HomeViewModel: ObservableObject {
    private let logoutUseCase: LogoutUseCase
    var onLogout: () -> Void = {}
    var onNavigateToDetail: () -> Void = {}

    init(logoutUseCase: LogoutUseCase) {
        self.logoutUseCase = logoutUseCase
    }

    func logout() {
        logoutUseCase.execute()
        onLogout()
    }

    func navigateToDetail() {
        onNavigateToDetail()
    }
}
