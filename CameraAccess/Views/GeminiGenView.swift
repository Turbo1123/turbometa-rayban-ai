/*
 * Gemini Generation View
 * Main UI for taking photos, selecting styles, and generating AI images
 */

import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

struct GeminiGenView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @StateObject private var viewModel: GeminiGenViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSharing = false
    @State private var imageToShare: UIImage? = nil
    @StateObject private var volumeHandler = VolumeButtonHandler.shared

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        self._viewModel = StateObject(wrappedValue: GeminiGenViewModel(apiKey: apiKey))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all) // Dark background for premium feel
                
                VStack(spacing: 0) {
                    if let generatedImage = viewModel.generatedImage {
                        // Result View
                        resultView(image: generatedImage)
                    } else if let originalImage = viewModel.originalImage {
                        // Setup / Preview View
                        setupView(image: originalImage)
                    } else {
                        // Empty State / Capture Mode
                        captureView
                    }
                }
            }
            .navigationTitle("AI 创意生成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if viewModel.originalImage != nil {
                            viewModel.resetAll()
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                
                if viewModel.generatedImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            viewModel.saveToAlbum()
                            viewModel.saveToAlbum()
                        }
                    }
                }
            }
            .onReceive(volumeHandler.$volumePressed) { pressed in
                 if pressed && streamViewModel.hasActiveDevice {
                     // Trigger capture
                     if let frame = streamViewModel.currentVideoFrame {
                          print("📸 [Gemini] Volume key capture triggering...")
                          viewModel.originalImage = frame
                          viewModel.saveOriginalToAlbum()
                     } else {
                         // Optional: Start stream if not running?
                         // For now, only capture if frame available to avoid accidental stream starts
                     }
                 }
            }
            .overlay(
                ZStack {
                     if viewModel.showToast {
                         VStack {
                             Spacer()
                             Text(viewModel.toastMessage)
                                 .foregroundColor(.white)
                                 .padding()
                                 .background(Color.black.opacity(0.7))
                                 .cornerRadius(20)
                                 .padding(.bottom, 60)
                         }
                         .transition(.opacity)
                         .zIndex(100)
                     }
                }
            )
            .sheet(isPresented: $viewModel.showingImagePicker) {
                ImagePicker(sourceType: viewModel.inputImageSourceType) { image in
                    viewModel.originalImage = image
                    // Auto-save original photo to album
                    if viewModel.inputImageSourceType == .camera {
                        viewModel.saveOriginalToAlbum()
                    }
                }
            }
        }
        .colorScheme(.dark) // Force dark mode for this view
        .sheet(isPresented: $isSharing) {
            if let image = imageToShare {
                GeminiShareSheet(activityItems: [image])
            }
        }
    
    .onAppear {
        volumeHandler.startHandler()
        if streamViewModel.hasActiveDevice {
            Task {
                if !streamViewModel.isStreaming {
                    await streamViewModel.handleStartStreaming()
                }
            }
        }
    }
    .onChange(of: streamViewModel.hasActiveDevice) { isConnected in
        if isConnected {
            Task {
                if !streamViewModel.isStreaming {
                    await streamViewModel.handleStartStreaming()
                }
            }
        }
    }
    .onDisappear {
        volumeHandler.stopHandler()
        Task {
            if streamViewModel.isStreaming {
                await streamViewModel.stopSession()
            }
        }
    }
    }


    
    // MARK: - Subviews
    
    var captureView: some View {
        ZStack {
            // Layer 1: Background / Preview
            if let frame = streamViewModel.currentVideoFrame {
                // Live Preview Full Screen
                GeometryReader { geometry in
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .edgesIgnoringSafeArea(.all)
            } else if streamViewModel.isStreaming {
                // Waiting for frame (Dark BG)
                Color.black.edgesIgnoringSafeArea(.all)
                VStack {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("正在获取眼镜画面...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top)
                }
            } else {
                // Placeholder / Initial State
                Color.black.edgesIgnoringSafeArea(.all)
                VStack(spacing: 30) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 80))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("拍摄或上传照片以开始")
                        .font(AppTypography.title2)
                        .foregroundColor(.gray)
                }
            }
            
            // Layer 2: Controls Overlay
            VStack {
                Spacer()
                
                // Gradient protection for buttons
                VStack(spacing: 20) {
                    if streamViewModel.hasActiveDevice {
                        Button(action: {
                            if let frame = streamViewModel.currentVideoFrame {
                                 viewModel.originalImage = frame
                                 viewModel.saveOriginalToAlbum() // Auto-save for glasses capture
                            } else {
                                 Task {
                                     if !streamViewModel.isStreaming {
                                         await streamViewModel.handleStartStreaming()
                                     }
                                 }
                            }
                        }) {
                            HStack {
                                Image(systemName: "eyeglasses")
                                Text(streamViewModel.isStreaming && streamViewModel.currentVideoFrame != nil ? "抓拍画面" : "开启眼镜摄像头")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppColors.liveAI)
                            .cornerRadius(28)
                            .shadow(radius: 4)
                        }
                    }

                    HStack(spacing: 16) {
                        Button(action: {
                            viewModel.inputImageSourceType = .camera
                            viewModel.showingImagePicker = true
                        }) {
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                            }
                            .foregroundColor(.black)
                            .frame(width: 56, height: 56)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                        }
                        
                        Button(action: {
                            viewModel.inputImageSourceType = .photoLibrary
                            viewModel.showingImagePicker = true
                        }) {
                            VStack {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title2)
                            }
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.3))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
                .background(
                    LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                        .padding(.top, -40)
                        .padding(.bottom, -50) // Extend beyond separate safe area
                )
            }
        }
    }
    
    func setupView(image: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Image Preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(16)
                    .frame(maxHeight: 350)
                    .padding(.horizontal)
                
                // Aspect Ratio Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("选择画幅")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    Picker("AspectRatio", selection: $viewModel.selectedAspectRatio) {
                        ForEach(GeminiGenViewModel.AspectRatio.allCases) { ratio in
                            Text(ratio.rawValue).tag(ratio)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .colorScheme(.dark) // Ensure readability on dark bg
                }

                // Style Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("选择风格")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(GeminiImageGenService.ImageStyle.allCases) { style in
                                StyleCard(
                                    style: style,
                                    isSelected: viewModel.selectedStyle == style
                                ) {
                                    withAnimation {
                                        viewModel.selectedStyle = style
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Prompt Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("补充描述 (可选)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    TextField("例如: 变换为夜晚背景...", text: $viewModel.customPrompt)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .foregroundColor(.white)
                }
                
                // Generate Button
                Button(action: {
                    Task {
                        await viewModel.generateImage()
                    }
                }) {
                    ZStack {
                        if viewModel.isGenerating {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("立即生成")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(viewModel.isGenerating ? Color.gray : AppColors.primary)
                    .cornerRadius(28)
                    .padding(.horizontal, 20)
                }
                .disabled(viewModel.isGenerating)
                .padding(.top, 10)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    func resultView(image: UIImage) -> some View {
        VStack(spacing: 20) {
            // Main Image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(16)
                .shadow(radius: 10)
                .padding()
            
            // Modification Input
            VStack(spacing: 12) {
                HStack {
                    TextField("输入修改指令...", text: $viewModel.customPrompt)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(25)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        Task {
                            await viewModel.modifyImage()
                        }
                    }) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(AppColors.primary)
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.isModifying || viewModel.customPrompt.isEmpty)
                }
                .padding(.horizontal)
                
                if viewModel.isModifying {
                    Text("正在修改...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 20) {
                    Button(action: {
                         imageToShare = image
                         isSharing = true
                    }) {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                            Text("分享")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 60)
                    }
                    
                    Button(action: {
                        viewModel.generatedImage = nil
                        // Keep original image to try another style
                    }) {
                         VStack {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.title2)
                            Text("重做")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 60)
                    }
                }
                .padding(.top, 10)
            }
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Components

struct StyleCard: View {
    let style: GeminiImageGenService.ImageStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                // Placeholder for style preview image could go here
                // For now just text or generic icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? AppColors.primary.opacity(0.2) : Color.white.opacity(0.05))
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.primary, lineWidth: 2)
                    }
                    
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? AppColors.primary : .gray)
                }
                .frame(width: 80, height: 80)
                
                Text(style.rawValue.components(separatedBy: " ").first ?? "")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .gray)
            }
        }
    }
}

// Simple internal ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .camera
    var onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct GeminiShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


