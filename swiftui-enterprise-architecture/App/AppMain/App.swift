import SwiftUI

@main
struct AppMain: App {
    @StateObject private var appCoordinator = AppCoordinator(appContainer: AppContainer())

    var body: some Scene {
        WindowGroup {
            if let root = appCoordinator.currentRoot {
                NavigationStack(path: $appCoordinator.path) {
                    appCoordinator.build(root)
                        .navigationDestination(for: Page.self) { page in
                            appCoordinator.build(page)
                        }
                }
            } else {
                SplashView()
            }
        }
    }
}
