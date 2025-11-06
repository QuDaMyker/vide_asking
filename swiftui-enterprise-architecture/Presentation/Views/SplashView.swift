import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack {
            Text("Loading...")
                .font(.largeTitle)
            ProgressView()
        }
    }
}
