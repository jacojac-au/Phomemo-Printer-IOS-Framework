import XCTest
@testable import PhomemoPrinter

final class CommandEncoderTests: XCTestCase {
    func testRasterCommand() {
        // T02: 48 bytes wide, 10 lines high
        let cmd = CommandEncoder.rasterCommand(widthBytes: 48, height: 10)
        XCTAssertEqual(cmd, [
            0x1D, 0x76, 0x30, 0x00,
            0x30, 0x00, // 48 = 0x30
            0x0A, 0x00  // 10 = 0x0A
        ])
    }

    func testRasterCommandLargeHeight() {
        // M04S: 154 bytes wide, 500 lines (needs 2-byte LE encoding)
        let cmd = CommandEncoder.rasterCommand(widthBytes: 154, height: 500)
        XCTAssertEqual(cmd, [
            0x1D, 0x76, 0x30, 0x00,
            0x9A, 0x00, // 154 = 0x009A
            0xF4, 0x01  // 500 = 0x01F4
        ])
    }

    func testByteEscaping() {
        let input = Data([0x00, 0x0A, 0xFF, 0x0A, 0x55])
        let escaped = CommandEncoder.escapedBitmapData(input)
        XCTAssertEqual(escaped, Data([0x00, 0x14, 0xFF, 0x14, 0x55]))
    }

    func testByteEscapingNoChange() {
        let input = Data([0x00, 0x0B, 0xFF, 0x09, 0x55])
        let escaped = CommandEncoder.escapedBitmapData(input)
        XCTAssertEqual(escaped, input)
    }

    func testFeedCommand() {
        let cmd = CommandEncoder.feedCommand(lines: 3)
        XCTAssertEqual(cmd, Data([0x1B, 0x64, 0x03]))
    }

    func testFeedCommandDefault() {
        let cmd = CommandEncoder.feedCommand()
        XCTAssertEqual(cmd, Data([0x1B, 0x64, 0x02]))
    }

    func testEncodeWithT02Profile() {
        let profile = T02Profile()
        // Create a tiny 8x2 bitmap (1 byte wide, 2 rows)
        let bitmap = Data([0b10101010, 0b01010101])

        let result = CommandEncoder.encode(
            bitmap: bitmap,
            widthBytes: 1,
            height: 2,
            profile: profile
        )

        // Should contain header + raster command + escaped bitmap + footer
        XCTAssertTrue(result.starts(with: profile.imageHeader))
        XCTAssertTrue(result.count > profile.imageHeader.count + profile.imageFooter.count)

        // Check footer is at the end
        let footerData = Data(profile.imageFooter)
        let resultSuffix = result.suffix(footerData.count)
        XCTAssertEqual(Data(resultSuffix), footerData)
    }

    func testEncodeWithM04SProfile() {
        let profile = M04SProfile()
        let bitmap = Data(repeating: 0xAA, count: 154 * 2) // 2 rows

        let result = CommandEncoder.encode(
            bitmap: bitmap,
            widthBytes: 154,
            height: 2,
            profile: profile
        )

        // Should contain header + raster + bitmap (no escaping) + footer
        XCTAssertTrue(result.starts(with: profile.imageHeader))

        let footerData = Data(profile.imageFooter)
        let resultSuffix = result.suffix(footerData.count)
        XCTAssertEqual(Data(resultSuffix), footerData)
    }
}

private extension Data {
    func starts(with bytes: [UInt8]) -> Bool {
        guard count >= bytes.count else { return false }
        return [UInt8](prefix(bytes.count)) == bytes
    }
}
