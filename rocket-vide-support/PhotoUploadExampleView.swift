//
//  PhotoUploadExampleView.swift
//  Rocket
//
//  Created by AI Assistant on 11/18/25.
//

import SwiftUI
import PhotosUI

struct PhotoUploadExampleView: View {
    @StateObject private var viewModel = PhotoUploadViewModel()
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var caption = ""
    @State private var photoId = "00002103-6101-4065-b10a-3eaa12cccefe"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Image Preview
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 300)
                        .cornerRadius(12)
                        .overlay(
                            Text("No image selected")
                                .foregroundColor(.gray)
                        )
                }
                
                // Photo ID Input
                TextField("Photo ID", text: $photoId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                // Caption Input
                TextField("Caption (optional)", text: $caption)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Select Image Button
                Button {
                    showImagePicker = true
                } label: {
                    Label("Select Image", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(viewModel.isUploading)
                
                // Upload Button
                Button {
                    clickUploadImage(selectedImage)
                } label: {
                    if viewModel.isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Label("Upload Photo", systemImage: "arrow.up.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(selectedImage == nil ? Color.gray : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(selectedImage == nil || viewModel.isUploading)
                
                // Error Message
                if let error = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Upload Failed")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.red)
                        
                        if let statusCode = viewModel.statusCode {
                            Text("Status Code: \(statusCode)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        if let errorType = viewModel.errorType {
                            Text(errorType.userFriendlyMessage)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .italic()
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Success Message
                if let url = viewModel.uploadedPhotoURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✅ Upload successful!")
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                        
                        Text("URL: \(url)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(2)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Upload Photo")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }
    
    /// Main upload function - called from UI
    func clickUploadImage(_ image: UIImage?) {
        guard let image = image else {
            viewModel.errorMessage = "Please select an image first"
            return
        }
        
        Task {
            await viewModel.uploadPhoto(
                image,
                photoId: photoId,
                caption: caption.isEmpty ? nil : caption
            )
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    PhotoUploadExampleView()
}
