import SwiftUI

struct MainTabView: View {
    @State private var coordinator: MainTabCoordinator
    
    init(appContainer: AppContainer) {
        self.coordinator = MainTabCoordinator(appContainer: appContainer)
    }
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            ProfileView(viewModel: coordinator.getProfileViewModel())
                .tag(0)
            
            FeedView()
                .tag(1)
            
            ListMessagesView()
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

struct FeedView: View {
    var body: some View {
        Text("Feed View")
    }
}

struct ListMessagesView: View {
    var body: some View {
        Text("Messages View")
    }
}
