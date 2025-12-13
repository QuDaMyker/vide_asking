//
//  ScrollSnapExample.swift
//  Rocket
//
//  Created by Quốc Danh Phạm on 14/11/25.
//

import SwiftUI

/// Example: How to use ScrollViewDetector with LazyHStack and ForEach
struct ScrollSnapExample: View {
    @StateObject private var scrollState = PhotoScrollState()
    @State private var photos: [String] = [
        "photo1", "photo2", "photo3", "photo4", "photo5"
    ]
    
    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let itemWidth = screenWidth * 0.8  // Width of each item
            let spacing: CGFloat = 16           // Spacing between items
            
            VStack {
                Text("Current Index: \(scrollState.currentIndex)")
                    .padding()
                
                // STEP 1: Wrap ScrollView in ZStack
                ZStack {
                    // STEP 2: Create ScrollView with LazyHStack
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .center, spacing: spacing) {
                            // STEP 3: Use ForEach for your items
                            ForEach(photos.indices, id: \.self) { index in
                                // Your custom view for each item
                                ItemView(
                                    index: index,
                                    title: photos[index],
                                    width: itemWidth,
                                    isCurrent: scrollState.currentIndex == index
                                )
                            }
                        }
                        // STEP 4: Add horizontal padding
                        .padding(.horizontal, screenWidth * 0.1)
                    }
                    
                    // STEP 5: Add ScrollViewDetector as overlay
                    ScrollViewDetector(
                        itemWidth: itemWidth,
                        spacing: spacing,
                        currentIndex: $scrollState.currentIndex
                    )
                }
                .frame(height: 400)
            }
        }
    }
}

// Example item view
struct ItemView: View {
    let index: Int
    let title: String
    let width: CGFloat
    let isCurrent: Bool
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .foregroundColor(.white)
            
            Text("Index: \(index)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(width: width, height: width)
        .background(isCurrent ? Color.blue : Color.gray)
        .cornerRadius(20)
        .scaleEffect(isCurrent ? 1.0 : 0.8)
        .animation(.spring(), value: isCurrent)
    }
}

// MARK: - Complete Integration Example
struct FeedViewExample: View {
    @EnvironmentObject var feedVM: FeedViewModel
    @StateObject private var scrollState = PhotoScrollState()
    
    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let itemWidth = screenWidth * 0.8
            let spacing: CGFloat = 16
            
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack {
                    // SCROLLABLE PHOTO SECTION
                    ZStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .center, spacing: spacing) {
                                // Camera/First Item
                                CameraView(width: itemWidth)
                                
                                // Photo Items from ForEach
                                ForEach(feedVM.photos.indices, id: \.self) { index in
                                    PhotoItemView(
                                        index: index,
                                        photo: feedVM.photos[index].photoUrl,
                                        screenWidth: screenWidth,
                                        scrollState: scrollState,
                                        displayName: feedVM.photos[index].userName
                                    )
                                }
                            }
                            .padding(.horizontal, screenWidth * 0.1)
                        }
                        
                        // Add snap behavior
                        ScrollViewDetector(
                            itemWidth: itemWidth,
                            spacing: spacing,
                            currentIndex: $scrollState.currentIndex
                        )
                    }
                    .frame(height: screenWidth * 1.2)
                    
                    // Other content below
                    ActionButtons()
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Simple Camera View
struct CameraView: View {
    let width: CGFloat
    
    var body: some View {
        VStack {
            Text("Camera")
                .foregroundColor(.white)
        }
        .frame(width: width, height: width)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(26)
    }
}

#Preview {
    ScrollSnapExample()
}
