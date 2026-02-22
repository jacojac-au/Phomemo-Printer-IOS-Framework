import XCTest
import CoreBluetooth
@testable import PhomemoPrinter

final class T02ProfileTests: XCTestCase {
    let profile = T02Profile()

    func testPrintWidth() {
        XCTAssertEqual(profile.printWidthDots, 384)
        XCTAssertEqual(profile.printWidthBytes, 48)
    }

    func testModel() {
        XCTAssertEqual(profile.model, .t02)
    }

    func testServiceUUIDs() {
        XCTAssertEqual(profile.scanServiceUUID, CBUUID(string: "AF30"))
        XCTAssertEqual(profile.serviceUUID, CBUUID(string: "FF00"))
        XCTAssertEqual(profile.writeCharacteristicUUID, CBUUID(string: "FF02"))
    }

    func testWriteStrategy() {
        if case .bulk = profile.writeStrategy {
            // Expected
        } else {
            XCTFail("T02 should use bulk write strategy")
        }
    }

    func testByteEscaping() {
        XCTAssertTrue(profile.requiresByteEscaping)
    }

    func testMaxLinesPerChunk() {
        XCTAssertEqual(profile.maxLinesPerChunk, 256)
    }

    func testImageHeaderStartsWithEscInit() {
        XCTAssertEqual(profile.imageHeader[0], 0x1B)
        XCTAssertEqual(profile.imageHeader[1], 0x40)
    }

    func testM04SProfile() {
        let m04s = M04SProfile()
        XCTAssertEqual(m04s.printWidthDots, 1232)
        XCTAssertEqual(m04s.printWidthBytes, 154)
        XCTAssertEqual(m04s.model, .m04s)
        XCTAssertFalse(m04s.requiresByteEscaping)

        if case .chunked(let chunkSize, let burstCount, let delayMs) = m04s.writeStrategy {
            XCTAssertEqual(chunkSize, 205)
            XCTAssertEqual(burstCount, 3)
            XCTAssertEqual(delayMs, 50)
        } else {
            XCTFail("M04S should use chunked write strategy")
        }
    }

    func testProfileFactory() {
        let t02 = T02Profile.profile(for: .t02)
        XCTAssertEqual(t02.model, .t02)

        let m04s = T02Profile.profile(for: .m04s)
        XCTAssertEqual(m04s.model, .m04s)
    }

    func testDiscoveredPrinterModelDetection() {
        XCTAssertEqual(DiscoveredPrinter.detectModel(from: "T02"), .t02)
        XCTAssertEqual(DiscoveredPrinter.detectModel(from: "Phomemo T02"), .t02)
        XCTAssertEqual(DiscoveredPrinter.detectModel(from: "M04S"), .m04s)
        XCTAssertEqual(DiscoveredPrinter.detectModel(from: "Phomemo M04AS"), .m04s)
        XCTAssertNil(DiscoveredPrinter.detectModel(from: "RandomDevice"))
        XCTAssertNil(DiscoveredPrinter.detectModel(from: nil))
    }
}
