import XCTest
@testable import PhomemoPrinter

final class CRC8Tests: XCTestCase {
    func testEmptyData() {
        let result = CRC8.compute(Data())
        XCTAssertEqual(result, 0x00)
    }

    func testSingleByte() {
        // CRC-8/SMBUS of [0x01] = 0x07
        let result = CRC8.compute(Data([0x01]))
        XCTAssertEqual(result, 0x07)
    }

    func testMultipleBytes() {
        // Known CRC-8/SMBUS value: "123456789" → 0xF4
        let input = Data("123456789".utf8)
        let result = CRC8.compute(input)
        XCTAssertEqual(result, 0xF4)
    }

    func testAllZeros() {
        let result = CRC8.compute(Data([0x00, 0x00, 0x00]))
        XCTAssertEqual(result, 0x00)
    }

    func testAllOnes() {
        let result = CRC8.compute(Data([0xFF]))
        // CRC-8/SMBUS of [0xFF] = 0xF3
        let expected: UInt8 = 0xF3
        XCTAssertEqual(result, expected)
    }

    func testByteArrayInput() {
        let result = CRC8.compute([0x01, 0x02, 0x03])
        let expected = CRC8.compute(Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(result, expected)
    }

    func testConsistency() {
        let data = Data([0x1F, 0x11, 0x02, 0x04])
        let result1 = CRC8.compute(data)
        let result2 = CRC8.compute(data)
        XCTAssertEqual(result1, result2)
    }
}
