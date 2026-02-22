import Foundation
import CoreGraphics
import UIKit

/// Utility functions for CGImage manipulation.
enum ImageUtilities {
    /// Normalize a CGImage to a consistent RGBA format.
    static func normalize(_ image: CGImage) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = image.width * 4
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage()
    }

    /// Resize a CGImage to the target size with high interpolation quality.
    static func resize(_ image: CGImage, to size: CGSize) -> CGImage? {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(origin: .zero, size: size))
        return ctx.makeImage()
    }

    /// Rotate a CGImage by 90 degrees clockwise (for landscape → portrait conversion).
    static func rotate90(_ image: CGImage) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil,
            width: Int(height),
            height: Int(width),
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else { return nil }

        ctx.translateBy(x: height / 2, y: width / 2)
        ctx.rotate(by: .pi / 2)
        ctx.draw(image, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        return ctx.makeImage()
    }

    /// Extract grayscale pixel values from a CGImage.
    /// Returns an array of width*height UInt8 values (0=black, 255=white).
    static func toGrayscalePixels(_ image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: 255, count: width * height)

        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        // Fill white first (transparent pixels become white)
        ctx.setFillColor(gray: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixels
    }

    /// Pack grayscale pixels (0 or 255) into 1-bit-per-pixel data.
    /// Black pixels (< 128) become 1 bits, white pixels become 0 bits. MSB first.
    static func packToBitmap(pixels: [UInt8], width: Int, height: Int) -> Data {
        let bytesPerRow = width / 8
        var bitmap = Data(count: bytesPerRow * height)

        for y in 0..<height {
            for x in 0..<bytesPerRow {
                var byte: UInt8 = 0
                for bit in 0..<8 {
                    let pixelIndex = y * width + x * 8 + bit
                    if pixelIndex < pixels.count && pixels[pixelIndex] < 128 {
                        byte |= 1 << (7 - bit)
                    }
                }
                bitmap[y * bytesPerRow + x] = byte
            }
        }

        return bitmap
    }
}
