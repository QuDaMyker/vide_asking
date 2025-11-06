import Foundation
import Combine

@Observable
class ProfileViewModel {
    // Callback for navigation - the coordinator will set this
    var onNavigateToTab: ((Int) -> Void)?
    
    init() {
        // Initialize with dependencies if needed
    }
    
    func navigateBackToFeed() {
        // Use the callback instead of directly manipulating state
        onNavigateToTab?(1)
    }
    
    func navigateToMessages() {
        onNavigateToTab?(2)
    }
}

@Observable
class FeedViewModel {
    init() {
        // Initialize with dependencies
    }
}

@Observable
class MessagesViewModel {
    init() {
        // Initialize with dependencies
    }
}
