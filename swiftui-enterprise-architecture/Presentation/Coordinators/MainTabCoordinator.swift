import SwiftUI
import Combine

@Observable
class MainTabCoordinator {
    var selectedTab: Int = 1
    private let appContainer: AppContainer
    
    // Keep view models alive for the lifecycle of tabs
    private var profileViewModel: ProfileViewModel?
    private var feedViewModel: FeedViewModel?
    private var messagesViewModel: MessagesViewModel?
    
    init(appContainer: AppContainer) {
        self.appContainer = appContainer
    }
    
    func getProfileViewModel() -> ProfileViewModel {
        if profileViewModel == nil {
            profileViewModel = ProfileViewModel()
            
            // Set up navigation callback
            profileViewModel?.onNavigateToTab = { [weak self] tabIndex in
                self?.selectedTab = tabIndex
            }
        }
        return profileViewModel!
    }
    
    func getFeedViewModel() -> FeedViewModel {
        if feedViewModel == nil {
            feedViewModel = FeedViewModel()
        }
        return feedViewModel!
    }
    
    func getMessagesViewModel() -> MessagesViewModel {
        if messagesViewModel == nil {
            messagesViewModel = MessagesViewModel()
        }
        return messagesViewModel!
    }
}
