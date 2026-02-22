import Foundation

/// Errors thrown by the PhomemoPrinter library.
public enum PhomemoError: LocalizedError {
    case bluetoothUnavailable
    case bluetoothUnauthorized
    case bluetoothPoweredOff
    case scanTimeout
    case connectionTimeout
    case connectionFailed(underlying: Error?)
    case notConnected
    case serviceNotFound
    case characteristicNotFound
    case writeNotSupported
    case printerOverheating
    case coverOpen
    case noPaper
    case printCancelled
    case imageConversionFailed
    case alreadyConnected
    case disconnected

    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is not available on this device."
        case .bluetoothUnauthorized:
            return "Bluetooth permission has not been granted."
        case .bluetoothPoweredOff:
            return "Bluetooth is powered off."
        case .scanTimeout:
            return "No printers found within the scan timeout."
        case .connectionTimeout:
            return "Connection to the printer timed out."
        case .connectionFailed(let error):
            return "Connection failed: \(error?.localizedDescription ?? "Unknown error")"
        case .notConnected:
            return "Not connected to a printer."
        case .serviceNotFound:
            return "Required BLE service not found on the printer."
        case .characteristicNotFound:
            return "Required BLE characteristic not found."
        case .writeNotSupported:
            return "Write characteristic does not support writing."
        case .printerOverheating:
            return "Printer is overheating. Please wait for it to cool down."
        case .coverOpen:
            return "Printer cover is open."
        case .noPaper:
            return "Printer is out of paper."
        case .printCancelled:
            return "Print job was cancelled."
        case .imageConversionFailed:
            return "Failed to convert image for printing."
        case .alreadyConnected:
            return "Already connected to a printer."
        case .disconnected:
            return "Printer disconnected unexpectedly."
        }
    }
}
