import Foundation

/// The connection state of a Phomemo printer.
public enum PrinterConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case ready
    case printing
    case disconnecting
}
