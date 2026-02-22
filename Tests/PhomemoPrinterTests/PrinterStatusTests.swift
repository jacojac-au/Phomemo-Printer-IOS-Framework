import XCTest
@testable import PhomemoPrinter

final class PrinterStatusTests: XCTestCase {
    func testOverheating() {
        let status = PrinterStatus.from(notificationData: [0x00, 3, 0xA9])
        XCTAssertEqual(status, .overheating)
    }

    func testTemperatureNormal() {
        let status = PrinterStatus.from(notificationData: [0x00, 3, 0xA8])
        XCTAssertEqual(status, .normal)
    }

    func testCoverOpen() {
        let status = PrinterStatus.from(notificationData: [0x00, 5, 0x99])
        XCTAssertEqual(status, .coverOpen)
    }

    func testCoverClosed() {
        let status = PrinterStatus.from(notificationData: [0x00, 5, 0x98])
        XCTAssertEqual(status, .normal)
    }

    func testNoPaper() {
        let status = PrinterStatus.from(notificationData: [0x00, 6, 0x88])
        XCTAssertEqual(status, .noPaper)
    }

    func testPaperPresent() {
        let status = PrinterStatus.from(notificationData: [0x00, 6, 0x89])
        XCTAssertEqual(status, .normal)
    }

    func testPrintComplete() {
        let status = PrinterStatus.from(notificationData: [0x00, 15, 0x0C])
        XCTAssertEqual(status, .printComplete)
    }

    func testCancelled() {
        let status = PrinterStatus.from(notificationData: [0x00, 11, 0xB8])
        XCTAssertEqual(status, .cancelled)
    }

    func testTooShortData() {
        let status = PrinterStatus.from(notificationData: [0x00, 3])
        XCTAssertNil(status)
    }

    func testUnknownStatus() {
        let status = PrinterStatus.from(notificationData: [0x00, 99, 0x00])
        XCTAssertNil(status)
    }

    func testIsReady() {
        XCTAssertTrue(PrinterStatus.normal.isReady)
        XCTAssertTrue(PrinterStatus.printComplete.isReady)
        XCTAssertFalse(PrinterStatus.overheating.isReady)
        XCTAssertFalse(PrinterStatus.coverOpen.isReady)
        XCTAssertFalse(PrinterStatus.noPaper.isReady)
    }
}
