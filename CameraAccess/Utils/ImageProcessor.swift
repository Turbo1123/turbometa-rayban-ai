/*
 * Image Processor
 * 图片处理工具类 - 提供图片压缩、格式转换等功能
 */

import UIKit
import Accelerate

class ImageProcessor {

    // MARK: - Constants

    private enum Constants {
        static let maxImageSize: CGFloat = 4096 // 最大图片尺寸
        static let jpegCompressionQuality: CGFloat = 0.85
        static let thumbnailSize: CGFloat = 200
    }

    // MARK: - Image Compression

    /// 压缩图片到指定大小以下
    /// - Parameters:
    ///   - image: 原始图片
    ///   - maxFileSizeKB: 最大文件大小（KB）
    /// - Returns: 压缩后的图片数据
    static func compressImage(_ image: UIImage, maxFileSizeKB: Int = 500) -> Data? {
        var compression: CGFloat = Constants.jpegCompressionQuality
        var imageData = image.jpegData(compressionQuality: compression)

        // 如果图片已经足够小，直接返回
        if let data = imageData, data.count / 1024 <= maxFileSizeKB {
            return data
        }

        // 二分法寻找最佳压缩质量
        var minQuality: CGFloat = 0.1
        var maxQuality: CGFloat = Constants.jpegCompressionQuality

        while maxQuality - minQuality > 0.05 {
            let midQuality = (minQuality + maxQuality) / 2
            guard let data = image.jpegData(compressionQuality: midQuality) else {
                break
            }

            if data.count / 1024 <= maxFileSizeKB {
                imageData = data
                minQuality = midQuality
            } else {
                maxQuality = midQuality
            }
        }

        return imageData
    }

    /// 将图片缩放到指定尺寸
    /// - Parameters:
    ///   - image: 原始图片
    ///   - maxWidth: 最大宽度
    ///   - maxHeight: 最大高度
    /// - Returns: 缩放后的图片
    static func scaleImage(_ image: UIImage, maxWidth: CGFloat = Constants.maxImageSize, maxHeight: CGFloat = Constants.maxImageSize) -> UIImage {
        let size = calculateScaledSize(for: image.size, maxWidth: maxWidth, maxHeight: maxHeight)

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        return scaledImage
    }

    /// 创建缩略图
    /// - Parameter image: 原始图片
    /// - Returns: 缩略图
    static func createThumbnail(_ image: UIImage) -> UIImage? {
        let size = calculateScaledSize(for: image.size, maxWidth: Constants.thumbnailSize, maxHeight: Constants.thumbnailSize)

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumbnail
    }

    // MARK: - Image Format Conversion

    /// 将图片转换为 Base64 编码
    /// - Parameter image: 图片
    /// - Returns: Base64 字符串
    static func toBase64(_ image: UIImage, compressionQuality: CGFloat = Constants.jpegCompressionQuality) -> String? {
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return imageData.base64EncodedString()
    }

    /// 从 Base64 字符串创建图片
    /// - Parameter base64String: Base64 字符串
    /// - Returns: 图片
    static func fromBase64(_ base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }
        return UIImage(data: data)
    }

    // MARK: - Image Validation

    /// 验证图片是否有效
    /// - Parameter image: 图片
    /// - Returns: 是否有效
    static func isValidImage(_ image: UIImage) -> Bool {
        // 检查尺寸
        guard image.size.width > 0 && image.size.height > 0 else {
            return false
        }

        // 检查CGImage
        guard image.cgImage != nil else {
            return false
        }

        return true
    }

    /// 获取图片大小（MB）
    /// - Parameter image: 图片
    /// - Returns: 图片大小
    static func getImageSizeMB(_ image: UIImage) -> Double {
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            return 0
        }
        return Double(data.count) / (1024.0 * 1024.0)
    }

    // MARK: - Private Helpers

    /// 计算缩放后的尺寸
    private static func calculateScaledSize(for originalSize: CGSize, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        var width = originalSize.width
        var height = originalSize.height

        // 如果图片尺寸已经小于限制，直接返回
        if width <= maxWidth && height <= maxHeight {
            return originalSize
        }

        // 计算缩放比例
        let widthRatio = maxWidth / width
        let heightRatio = maxHeight / height
        let ratio = min(widthRatio, heightRatio)

        width *= ratio
        height *= ratio

        return CGSize(width: width, height: height)
    }
}

// MARK: - UIImage Extension

extension UIImage {

    /// 压缩图片
    func compressed(maxFileSizeKB: Int = 500) -> Data? {
        return ImageProcessor.compressImage(self, maxFileSizeKB: maxFileSizeKB)
    }

    /// 缩放图片
    func scaled(maxWidth: CGFloat = 4096, maxHeight: CGFloat = 4096) -> UIImage {
        return ImageProcessor.scaleImage(self, maxWidth: maxWidth, maxHeight: maxHeight)
    }

    /// 创建缩略图
    var thumbnail: UIImage? {
        return ImageProcessor.createThumbnail(self)
    }

    /// 转换为 Base64
    func toBase64(compressionQuality: CGFloat = 0.85) -> String? {
        return ImageProcessor.toBase64(self, compressionQuality: compressionQuality)
    }

    /// 验证图片是否有效
    var isValid: Bool {
        return ImageProcessor.isValidImage(self)
    }

    /// 获取图片大小（MB）
    var sizeInMB: Double {
        return ImageProcessor.getImageSizeMB(self)
    }
}
