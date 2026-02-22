import Foundation
import CoreGraphics

/// Converts grayscale pixels to monochrome using Floyd-Steinberg dithering.
enum DitheredConverter {
    /// Apply Floyd-Steinberg error diffusion dithering.
    ///
    /// - Parameters:
    ///   - pixels: Grayscale pixel array (0-255). Modified in place to contain only 0 or 255.
    ///   - width: Image width in pixels.
    ///   - height: Image height in pixels.
    static func convert(pixels: inout [UInt8], width: Int, height: Int) {
        // Use Float buffer for error accumulation
        var buffer = [Float](repeating: 0, count: width * height)
        for i in 0..<pixels.count {
            buffer[i] = Float(pixels[i])
        }

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                let oldPixel = buffer[idx]
                let newPixel: Float = oldPixel < 128 ? 0 : 255
                let error = oldPixel - newPixel
                buffer[idx] = newPixel

                // Distribute error to neighboring pixels (Floyd-Steinberg coefficients)
                if x + 1 < width {
                    buffer[idx + 1] += error * 7.0 / 16.0
                }
                if y + 1 < height {
                    if x > 0 {
                        buffer[idx + width - 1] += error * 3.0 / 16.0
                    }
                    buffer[idx + width] += error * 5.0 / 16.0
                    if x + 1 < width {
                        buffer[idx + width + 1] += error * 1.0 / 16.0
                    }
                }
            }
        }

        // Write back to pixel array
        for i in 0..<pixels.count {
            pixels[i] = buffer[i] < 128 ? 0 : 255
        }
    }
}
