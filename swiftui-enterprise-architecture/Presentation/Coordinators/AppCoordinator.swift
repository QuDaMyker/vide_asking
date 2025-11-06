import SwiftUI
import Combine

enum Page: String, Hashable, Identifiable {
    case login, home, detail

    var id: String { self.rawValue }
}

class AppCoordinator: ObservableObject {
    @Published var path = NavigationPath()
    @Published var currentRoot: Page?

    private let appContainer: AppContainer
    private var cancellables = Set<AnyCancellable>()

    init(appContainer: AppContainer) {
        self.appContainer = appContainer
        start()
    }

    func start() {
        // Show splash screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkSession()
        }
    }

    private func checkSession() {
        let isLoggedIn = appContainer.checkSessionUseCase.execute()
        if isLoggedIn {
            currentRoot = .home
        } else {
            currentRoot = .login
        }
    }

    func push(_ page: Page) {
        path.append(page)
    }

    @ViewBuilder
    func build(_ page: Page) -> some View {
        switch page {
        case .login:
            let loginViewModel = LoginViewModel(loginUseCase: appContainer.loginUseCase)
            loginViewModel.onLoginSuccess = { [weak self] in
                self?.currentRoot = .home
            }
            LoginView(viewModel: loginViewModel)
        case .home:
            let homeViewModel = HomeViewModel(logoutUseCase: appContainer.logoutUseCase)
            homeViewModel.onLogout = { [weak self] in
                self?.path.removeLast(self?.path.count ?? 0)
                self?.currentRoot = .login
            }
            homeViewModel.onNavigateToDetail = { [weak self] in
                self?.push(.detail)
            }
            HomeView(viewModel: homeViewModel)
        case .detail:
            DetailView()
        }
    }
}
