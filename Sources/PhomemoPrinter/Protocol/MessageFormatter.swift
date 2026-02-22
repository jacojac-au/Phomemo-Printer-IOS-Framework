import Foundation

/// Formats messages using the Phomemo framing protocol.
///
/// Frame format: `[0x51, 0x78, command, 0x00, lengthLo, lengthHi, ...data..., crc8(data), 0xFF]`
enum MessageFormatter {
    /// Create a framed message with the given command byte and payload data.
    static func formatMessage(command: UInt8, data: Data) -> Data {
        let length = UInt16(data.count)
        var message = Data([
            0x51, 0x78,
            command,
            0x00,
            UInt8(length & 0xFF),
            UInt8((length >> 8) & 0xFF)
        ])
        message.append(data)
        message.append(CRC8.compute(data))
        message.append(0xFF)
        return message
    }

    /// Create a framed message from raw bytes.
    static func formatMessage(command: UInt8, bytes: [UInt8]) -> Data {
        formatMessage(command: command, data: Data(bytes))
    }
}
