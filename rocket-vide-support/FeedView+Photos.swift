//
//  FeedView+Photos.swift
//  Rocket
//
//  Created by Quốc Danh Phạm on 14/11/25.
//

import SwiftUI

extension FeedView {
    @ViewBuilder
    func photosScrollView() -> some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let itemWidth = screenWidth * 0.8
            let spacing: CGFloat = 16
            
            ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: spacing) {
                        // First item - Camera view
                        cameraItemView(itemWidth: itemWidth)
                        
                        // Photo items
                        ForEach(feedVM.photos.indices, id: \.self) { index in
                            PhotoItemView(
                                index: index,
                                photo: feedVM.photos[index].photoUrl,
                                screenWidth: screenWidth,
                                scrollState: scrollState,
                                displayName: appState.displayNameOrEmpty
                            )
                        }
                    }
                    .padding(.horizontal, screenWidth * 0.1)
                }
                
                // Add the detector as overlay
                ScrollViewDetector(
                    itemWidth: itemWidth,
                    spacing: spacing,
                    currentIndex: $scrollState.currentIndex
                )
            }
        }
        .frame(height: UIScreen.main.bounds.height / 1.6)
    }
    
    @ViewBuilder
    private func cameraItemView(itemWidth: CGFloat) -> some View {
        VStack {
            Text("Hi buddy, let's shot now!")
                .appTextStyle(.caption)
                .foregroundColor(.white)
            
            ZStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    CameraViewWithCapture(capturedImage: $selectedImage)
                }
            }
            .frame(width: itemWidth, height: itemWidth)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            
            Text("Big smile and press capture")
                .appTextStyle(.caption)
                .foregroundColor(.white)
            
            Spacer()
        }
        .frame(width: itemWidth)
    }
}

// MARK: - Usage Example in FeedView Body
/*
struct FeedView: View {
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var rootViewModel: RootViewModel
    @EnvironmentObject var appState: AppState
    
    @State private var selectedImage: UIImage?
    @StateObject private var scrollState = PhotoScrollState()
    
    var body: some View {
        ZStack {
            AppColors.black.ignoresSafeArea()
            
            VStack(alignment: .center) {
                // Your app bar
                AppBarView()
                
                // Use the photos scroll view
                photosScrollView()
                
                // Action buttons
                ActionButtons()
                
                // History button
                TextButton(title: "History", onClick: {})
                
                Spacer(minLength: 40)
            }
        }
    }
}
*/
