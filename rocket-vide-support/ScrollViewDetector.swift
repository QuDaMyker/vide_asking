//
//  ScrollViewDetector.swift
//  Rocket
//
//  Created by Quốc Danh Phạm on 14/11/25.
//

import SwiftUI

struct ScrollViewDetector: UIViewRepresentable {
    let itemWidth: CGFloat
    let spacing: CGFloat
    @Binding var currentIndex: Int
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        
        // Delay to ensure ScrollView is in the view hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let scrollView = view.superview?.superview as? UIScrollView {
                scrollView.delegate = context.coordinator
                scrollView.decelerationRate = .fast
                scrollView.isPagingEnabled = false
                scrollView.showsHorizontalScrollIndicator = false
                
                // Enable snap behavior for all iOS versions
                if #available(iOS 11.0, *) {
                    scrollView.contentInsetAdjustmentBehavior = .never
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update delegate if needed
        if let scrollView = uiView.superview?.superview as? UIScrollView,
           scrollView.delegate !== context.coordinator {
            scrollView.delegate = context.coordinator
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(itemWidth: itemWidth, spacing: spacing, currentIndex: $currentIndex)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let itemWidth: CGFloat
        let spacing: CGFloat
        @Binding var currentIndex: Int
        private var isUserDragging = false
        
        init(itemWidth: CGFloat, spacing: CGFloat, currentIndex: Binding<Int>) {
            self.itemWidth = itemWidth
            self.spacing = spacing
            self._currentIndex = currentIndex
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserDragging = true
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            let totalWidth = itemWidth + spacing
            let currentOffset = targetContentOffset.pointee.x
            
            // Calculate the closest item index
            var targetIndex = round(currentOffset / totalWidth)
            
            // Add velocity consideration for more natural scrolling
            if abs(velocity.x) > 0.3 {
                if velocity.x > 0 {
                    targetIndex = ceil(currentOffset / totalWidth)
                } else {
                    targetIndex = floor(currentOffset / totalWidth)
                }
            }
            
            // Clamp index to valid range
            let clampedIndex = max(0, targetIndex)
            
            // Calculate the perfect center offset
            let newOffset = clampedIndex * totalWidth
            
            targetContentOffset.pointee.x = newOffset
            
            // Update current index
            DispatchQueue.main.async {
                self.currentIndex = Int(clampedIndex)
            }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                isUserDragging = false
                snapToNearestItem(scrollView)
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isUserDragging = false
            snapToNearestItem(scrollView)
        }
        
        private func snapToNearestItem(_ scrollView: UIScrollView) {
            let totalWidth = itemWidth + spacing
            let currentOffset = scrollView.contentOffset.x
            let index = round(currentOffset / totalWidth)
            let clampedIndex = max(0, index)
            
            DispatchQueue.main.async {
                self.currentIndex = Int(clampedIndex)
            }
        }
    }
}

extension UIView {
    func findScrollView() -> UIScrollView? {
        if let scrollView = self as? UIScrollView {
            return scrollView
        }
        
        if let superview = superview {
            return superview.findScrollView()
        }
        
        return nil
    }
}
