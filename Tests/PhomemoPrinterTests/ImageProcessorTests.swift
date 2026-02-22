import XCTest
@testable import PhomemoPrinter

final class ImageProcessorTests: XCTestCase {
    func testPackToBitmapAllBlack() {
        // All black pixels (0)
        let pixels: [UInt8] = Array(repeating: 0, count: 16)
        let bitmap = ImageUtilities.packToBitmap(pixels: pixels, width: 8, height: 2)
        // All black → all bits set
        XCTAssertEqual(bitmap, Data([0xFF, 0xFF]))
    }

    func testPackToBitmapAllWhite() {
        // All white pixels (255)
        let pixels: [UInt8] = Array(repeating: 255, count: 16)
        let bitmap = ImageUtilities.packToBitmap(pixels: pixels, width: 8, height: 2)
        // All white → no bits set
        XCTAssertEqual(bitmap, Data([0x00, 0x00]))
    }

    func testPackToBitmapAlternating() {
        // Alternating black/white pixels
        var pixels = [UInt8](repeating: 0, count: 8)
        for i in 0..<8 {
            pixels[i] = i % 2 == 0 ? 0 : 255  // B W B W B W B W
        }
        let bitmap = ImageUtilities.packToBitmap(pixels: pixels, width: 8, height: 1)
        // 1 0 1 0 1 0 1 0 = 0xAA
        XCTAssertEqual(bitmap, Data([0xAA]))
    }

    func testMonochromeConverterThreshold() {
        var pixels: [UInt8] = [0, 64, 127, 128, 200, 255]
        MonochromeConverter.convert(pixels: &pixels, threshold: 128)
        XCTAssertEqual(pixels, [0, 0, 0, 255, 255, 255])
    }

    func testMonochromeConverterCustomThreshold() {
        var pixels: [UInt8] = [0, 64, 127, 128, 200, 255]
        MonochromeConverter.convert(pixels: &pixels, threshold: 200)
        XCTAssertEqual(pixels, [0, 0, 0, 0, 255, 255])
    }

    func testDitheredConverterOutputIsBinary() {
        // Create a gradient
        var pixels = [UInt8](repeating: 0, count: 64)
        for i in 0..<64 {
            pixels[i] = UInt8(i * 4)
        }

        DitheredConverter.convert(pixels: &pixels, width: 8, height: 8)

        // All output values should be 0 or 255
        for pixel in pixels {
            XCTAssertTrue(pixel == 0 || pixel == 255, "Expected 0 or 255, got \(pixel)")
        }
    }

    func testDitheredConverterPreservesSize() {
        var pixels: [UInt8] = Array(repeating: 128, count: 100)
        DitheredConverter.convert(pixels: &pixels, width: 10, height: 10)
        XCTAssertEqual(pixels.count, 100)
    }

    func testMessageFormatterBasic() {
        let data = Data([0x01, 0x02])
        let message = MessageFormatter.formatMessage(command: 0xA0, data: data)

        // Header: 51 78 A0 00 02 00
        XCTAssertEqual(message[0], 0x51)
        XCTAssertEqual(message[1], 0x78)
        XCTAssertEqual(message[2], 0xA0)
        XCTAssertEqual(message[3], 0x00)
        XCTAssertEqual(message[4], 0x02) // length lo
        XCTAssertEqual(message[5], 0x00) // length hi

        // Data
        XCTAssertEqual(message[6], 0x01)
        XCTAssertEqual(message[7], 0x02)

        // CRC8 of [0x01, 0x02]
        let expectedCRC = CRC8.compute(Data([0x01, 0x02]))
        XCTAssertEqual(message[8], expectedCRC)

        // Footer
        XCTAssertEqual(message[9], 0xFF)
    }
}
