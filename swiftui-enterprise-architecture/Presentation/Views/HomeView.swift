import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Hello, Enterprise SwiftUI!")
                .navigationTitle("Home")
                .navigationBarBackButtonHidden(true)

            Button("Go to Detail") {
                viewModel.navigateToDetail()
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)

            Button("Log Out") {
                viewModel.logout()
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}
