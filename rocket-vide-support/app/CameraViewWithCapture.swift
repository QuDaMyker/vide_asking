//
//  CameraViewWithCapture.swift
//  Rocket
//
//  Created by Quốc Danh Phạm on 14/11/25.
//

import SwiftUI

struct CameraViewWithCapture: View {
    @Binding var capturedImage: UIImage?
    @State private var cameraView: CustomCameraView.CameraPreview?
    @State private var coordinator: CustomCameraView.Coordinator?
    
    var body: some View {
        ZStack {
            CustomCameraViewCapture(
                capturedImage: $capturedImage,
                cameraView: $cameraView,
                coordinator: $coordinator
            )
            
            VStack {
                Spacer()
                
                Button(action: {
                    capturePhoto()
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 4)
                                .frame(width: 80, height: 80)
                        )
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func capturePhoto() {
        guard let cameraView = cameraView,
              let coordinator = coordinator else { return }
        
        cameraView.capturePhoto(delegate: coordinator)
    }
}

// Helper view to bridge UIViewRepresentable with state
private struct CustomCameraViewCapture: UIViewRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var cameraView: CustomCameraView.CameraPreview?
    @Binding var coordinator: CustomCameraView.Coordinator?
    
    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        var parent: CustomCameraViewCapture
        
        init(_ parent: CustomCameraViewCapture) {
            self.parent = parent
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard error == nil,
                  let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData) else {
                return
            }
            
            DispatchQueue.main.async {
                self.parent.capturedImage = image
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        let coord = Coordinator(self)
        DispatchQueue.main.async {
            self.coordinator = coord
        }
        return coord
    }
    
    func makeUIView(context: Context) -> CustomCameraView.CameraPreview {
        let view = CustomCameraView.CameraPreview()
        view.coordinator = context.coordinator
        view.setupCamera()
        
        DispatchQueue.main.async {
            self.cameraView = view
        }
        
        return view
    }
    
    func updateUIView(_ uiView: CustomCameraView.CameraPreview, context: Context) {}
    
    static func dismantleUIView(_ uiView: CustomCameraView.CameraPreview, coordinator: Coordinator) {
        uiView.stopSession()
    }
}
