import SwiftUI

protocol Coordinator {
    func start() -> AnyView
}

class HomeCoordinator: Coordinator {
    func start() -> AnyView {
        let homeView = HomeView()
        return AnyView(homeView)
    }
}
