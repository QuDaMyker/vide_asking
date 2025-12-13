//
//  CustomCameraView.swift
//  Rocket
//
//  Created by Quốc Danh Phạm on 11/11/25.
//

import SwiftUI
import AVFoundation

struct CustomCameraView: UIViewRepresentable {
    class CameraPreview: UIView {
        private var session: AVCaptureSession?
        private var photoOutput: AVCapturePhotoOutput?

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }

        func setupCamera() {
            let session = AVCaptureSession()
            session.sessionPreset = .photo

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera) else { return }

            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCapturePhotoOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
            
            self.session = session
            self.photoOutput = output
            
            Task {
                session.startRunning()
            }
        }
        
        func capturePhoto(delegate: AVCapturePhotoCaptureDelegate) {
            guard let photoOutput = photoOutput else { return }
            
            let settings = AVCapturePhotoSettings()
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings.photoCodecType = .hevc
            }
            
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
        
        func stopSession() {
            session?.stopRunning()
        }
    }

    func makeUIView(context: Context) -> CameraPreview {
        let view = CameraPreview()
        view.setupCamera()
        return view
    }

    func updateUIView(_ uiView: CameraPreview, context: Context) {}
    
    static func dismantleUIView(_ uiView: CameraPreview, coordinator: ()) {
        uiView.stopSession()
    }
}
