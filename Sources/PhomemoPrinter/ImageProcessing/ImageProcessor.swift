import Foundation
import CoreGraphics
import UIKit

/// Processes UIImage/CGImage into 1-bit packed bitmap data ready for printer encoding.
///
/// Pipeline: normalize → auto-rotate landscape → resize to print width → dither/threshold → 1-bit pack
enum ImageProcessor {
    /// Process a UIImage into packed 1-bit bitmap data for printing.
    ///
    /// - Parameters:
    ///   - image: The source image.
    ///   - printWidth: Target width in dots (e.g. 384 for T02).
    ///   - options: Print options controlling dithering and threshold.
    /// - Returns: Tuple of (bitmap data, width in bytes, height in dots), or nil on failure.
    static func process(
        image: UIImage,
        printWidth: Int,
        options: PrintOptions = .default
    ) -> (bitmap: Data, widthBytes: Int, height: Int)? {
        guard let cgImage = image.cgImage else { return nil }
        return process(cgImage: cgImage, printWidth: printWidth, options: options)
    }

    /// Process a CGImage into packed 1-bit bitmap data for printing.
    static func process(
        cgImage: CGImage,
        printWidth: Int,
        options: PrintOptions = .default
    ) -> (bitmap: Data, widthBytes: Int, height: Int)? {
        // 1. Normalize to consistent color space
        guard let normalized = ImageUtilities.normalize(cgImage) else { return nil }

        // 2. Auto-rotate landscape images
        let oriented: CGImage
        if normalized.width > normalized.height {
            guard let rotated = ImageUtilities.rotate90(normalized) else { return nil }
            oriented = rotated
        } else {
            oriented = normalized
        }

        // 3. Resize to print width, maintaining aspect ratio
        let aspectRatio = CGFloat(oriented.height) / CGFloat(oriented.width)
        let targetHeight = Int(CGFloat(printWidth) * aspectRatio)
        guard let resized = ImageUtilities.resize(
            oriented,
            to: CGSize(width: CGFloat(printWidth), height: CGFloat(targetHeight))
        ) else { return nil }

        // 4. Convert to grayscale pixels
        guard var pixels = ImageUtilities.toGrayscalePixels(resized) else { return nil }

        let width = resized.width
        let height = resized.height

        // 5. Apply dithering or threshold
        if options.dithered {
            DitheredConverter.convert(pixels: &pixels, width: width, height: height)
        } else {
            MonochromeConverter.convert(pixels: &pixels, threshold: options.threshold)
        }

        // 6. Pack to 1-bit bitmap
        let bitmap = ImageUtilities.packToBitmap(pixels: pixels, width: width, height: height)
        let widthBytes = width / 8

        return (bitmap, widthBytes, height)
    }

    /// Render text into a UIImage suitable for printing.
    ///
    /// - Parameters:
    ///   - text: The body text to render.
    ///   - title: Optional title rendered in bold above the text.
    ///   - printWidth: Target width in dots.
    /// - Returns: A UIImage of the rendered text, or nil on failure.
    static func renderText(
        _ text: String,
        title: String? = nil,
        printWidth: Int
    ) -> UIImage? {
        let targetWidth = CGFloat(printWidth)
        let titleFont = UIFont.systemFont(ofSize: 32, weight: .black)
        let bodyFont = UIFont.systemFont(ofSize: 32, weight: .regular)

        let titleParagraphStyle = NSMutableParagraphStyle()
        titleParagraphStyle.alignment = .left
        titleParagraphStyle.lineBreakMode = .byWordWrapping
        titleParagraphStyle.lineSpacing = 1

        let bodyParagraphStyle = NSMutableParagraphStyle()
        bodyParagraphStyle.alignment = .left
        bodyParagraphStyle.lineBreakMode = .byWordWrapping

        let attributed = NSMutableAttributedString()

        if let title = title, !title.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black,
                .paragraphStyle: titleParagraphStyle,
            ]
            attributed.append(NSAttributedString(string: title + "\n", attributes: attrs))
        }

        if !text.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.black,
                .paragraphStyle: bodyParagraphStyle,
            ]
            attributed.append(NSAttributedString(string: text, attributes: attrs))
        }

        let padding: CGFloat = 10
        let constraints = CGSize(width: targetWidth - padding * 2, height: .greatestFiniteMagnitude)
        let boundingRect = attributed.boundingRect(
            with: constraints,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        let finalHeight = max(ceil(boundingRect.height) + padding, 8)
        let finalSize = CGSize(width: targetWidth, height: finalHeight)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        return UIGraphicsImageRenderer(size: finalSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: finalSize))
            let textRect = CGRect(x: padding, y: padding / 2, width: targetWidth - padding * 2, height: finalHeight)
            attributed.draw(in: textRect)
        }
    }
}
