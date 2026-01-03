/*
 * Gemini Image Generation ViewModel
 * Manages state and logic for Image Generation View
 */

import SwiftUI
import UIKit

@MainActor
class GeminiGenViewModel: ObservableObject {
    // State
    @Published var originalImage: UIImage?
    @Published var generatedImage: UIImage?
    @Published var selectedStyle: GeminiImageGenService.ImageStyle = .realistic
    @Published var customPrompt: String = ""
    @Published var isGenerating: Bool = false
    @Published var isModifying: Bool = false
    @Published var errorMessage: String?
    @Published var selectedAspectRatio: AspectRatio = .square
    @Published var showingImagePicker = false
    @Published var inputImageSourceType: UIImagePickerController.SourceType = .camera
    
    // UI Feedback
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    
    enum AspectRatio: String, CaseIterable, Identifiable {
        case square = "1:1 (方形)"
        case portrait = "3:4 (竖屏)"
        case landscape = "4:3 (横屏)"
        case portrait9_16 = "9:16 (全屏竖)"
        case landscape16_9 = "16:9 (全屏横)"
        
        var id: String { rawValue }
        
        var ratio: CGFloat {
            switch self {
            case .square: return 1.0
            case .portrait: return 3.0 / 4.0
            case .landscape: return 4.0 / 3.0
            case .portrait9_16: return 9.0 / 16.0
            case .landscape16_9: return 16.0 / 9.0
            }
        }
    }
    
    // Services
    private let imageGenService: GeminiImageGenService
    
    // Computed props
    var canGenerate: Bool {
        originalImage != nil && !isGenerating && !isModifying
    }
    
    var canModify: Bool {
        generatedImage != nil && !isGenerating && !isModifying && !customPrompt.isEmpty
    }

    init(apiKey: String) {
        self.imageGenService = GeminiImageGenService(apiKey: apiKey)
    }

    // MARK: - Actions

    func generateImage() async {
        guard let originalImage = originalImage else { return }
        
        isGenerating = true
        errorMessage = nil
        
        do {
            // Crop image based on aspect ratio
            let croppedImage = cropImage(originalImage, to: selectedAspectRatio.ratio)
            
            let result = try await imageGenService.generateImage(
                originalImage: croppedImage,
                prompt: customPrompt,
                style: selectedStyle
            )
            self.generatedImage = result
            // Clear prompt after successful initial generation? Maybe keep it.
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isGenerating = false
    }
    
    func modifyImage() async {
        guard let currentImage = generatedImage else { return } // Use the generated image as base for modification?
        // Requirement: "Generated images can be further modified based on requirements".
        // Usually modification implies sending the image back + instruction.
        // It could also merely mean sending the *original* image + new prompt, but usually it implies iterative editing.
        // However, many APIs (like generic generateContent) might not support "edit this image" directly without specific endpoints.
        // But assuming our service `modifyImage` does "Image + Instruction -> Image" (e.g. Inpainting or just Image-to-Image with strong instruction).
        // Since `modifyImage` in service uses the same structure, it's effectively Image-to-Image.
        // We will use the *generated* image as source for the next step to support "further modification".
        
        isModifying = true
        errorMessage = nil
        
        do {
            let result = try await imageGenService.modifyImage(
                originalImage: currentImage,
                instruction: customPrompt
            )
            self.generatedImage = result
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isModifying = false
    }

    func clearResult() {
        generatedImage = nil
        errorMessage = nil
    }
    
    func resetAll() {
        originalImage = nil
        generatedImage = nil
        errorMessage = nil
        customPrompt = ""
    }
    
    func saveToAlbum() {
        guard let image = generatedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        PhotoStorageService.shared.savePhoto(image)
        showToast(message: "图片已保存到相册")
    }
    
    func saveOriginalToAlbum() {
        guard let image = originalImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        PhotoStorageService.shared.savePhoto(image)
        // No toast needed for auto-save usually, or concise one
        // showToast(message: "原图已保存") 
    }
    
    func showToast(message: String) {
        self.toastMessage = message
        self.showToast = true
        // Auto hide handled by view or simple timer here (but View is better for animation)
        Task {
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            self.showToast = false
        }
    }

    private func cropImage(_ image: UIImage, to ratio: CGFloat) -> UIImage {
        let originalSize = image.size
        let currentRatio = originalSize.width / originalSize.height
        
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        if currentRatio > ratio {
            // Too wide, scale to height and crop width
            newHeight = originalSize.height
            newWidth = newHeight * ratio
        } else {
            // Too tall, scale to width and crop height
            newWidth = originalSize.width
            newHeight = newWidth / ratio
        }
        
        let x = (originalSize.width - newWidth) / 2.0
        let y = (originalSize.height - newHeight) / 2.0
        let cropRect = CGRect(x: x, y: y, width: newWidth, height: newHeight)
        
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        
        return image
    }
}
