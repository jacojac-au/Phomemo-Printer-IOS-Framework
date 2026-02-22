import Foundation

/// CRC-8/SMBUS calculator used for Phomemo message framing.
/// Polynomial: 0x07, initial value: 0x00.
enum CRC8 {
    /// Compute CRC-8 over the given data.
    static func compute(_ data: Data) -> UInt8 {
        var crc: UInt8 = 0
        for byte in data {
            crc ^= byte
            for _ in 0..<8 {
                if (crc & 0x80) != 0 {
                    crc = (crc << 1) ^ 0x07
                } else {
                    crc <<= 1
                }
            }
        }
        return crc
    }

    /// Compute CRC-8 over a byte array.
    static func compute(_ bytes: [UInt8]) -> UInt8 {
        compute(Data(bytes))
    }
}
