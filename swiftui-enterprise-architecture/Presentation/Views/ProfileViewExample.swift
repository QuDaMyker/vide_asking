import SwiftUI

struct ProfileView: View {
    let viewModel: ProfileViewModel
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.1).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("Your Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Example: Navigate back to feed
                    Button("Back to Feed") {
                        viewModel.navigateBackToFeed()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    // Example: Navigate to messages
                    Button("Go to Messages") {
                        viewModel.navigateToMessages()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}
