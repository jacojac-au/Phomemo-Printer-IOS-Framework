import Foundation

/// Encodes processed bitmap data into printer wire-format commands.
enum CommandEncoder {
    /// Encode a 1-bit packed bitmap into printer raster commands for the given profile.
    ///
    /// - Parameters:
    ///   - bitmap: 1-bit packed bitmap data (MSB first, black=1).
    ///   - widthBytes: Bytes per row (e.g. 48 for T02, 154 for M04S).
    ///   - height: Total height in dots/rows.
    ///   - profile: The printer profile defining encoding behavior.
    /// - Returns: Complete print data including header, raster commands, and footer.
    static func encode(
        bitmap: Data,
        widthBytes: Int,
        height: Int,
        profile: PrinterProfile
    ) -> Data {
        var data = Data()
        data.append(contentsOf: profile.imageHeader)

        let maxChunkHeight = profile.maxLinesPerChunk
        var remaining = height
        var rowOffset = 0

        while remaining > 0 {
            let chunkHeight = min(maxChunkHeight, remaining)

            // Raster command: GS v 0
            data.append(contentsOf: rasterCommand(
                widthBytes: widthBytes,
                height: chunkHeight
            ))

            // Bitmap rows for this chunk
            let startByte = rowOffset * widthBytes
            let endByte = min(startByte + chunkHeight * widthBytes, bitmap.count)
            let chunkData = bitmap.subdata(in: startByte..<endByte)

            if profile.requiresByteEscaping {
                data.append(escapedBitmapData(chunkData))
            } else {
                data.append(chunkData)
            }

            remaining -= chunkHeight
            rowOffset += chunkHeight
        }

        data.append(contentsOf: profile.imageFooter)
        return data
    }

    /// Generate a GS v 0 raster command header.
    /// Format: `1D 76 30 00 xL xH yL yH`
    static func rasterCommand(widthBytes: Int, height: Int) -> [UInt8] {
        [
            0x1D, 0x76, 0x30, 0x00,
            UInt8(widthBytes & 0xFF),
            UInt8((widthBytes >> 8) & 0xFF),
            UInt8(height & 0xFF),
            UInt8((height >> 8) & 0xFF)
        ]
    }

    /// Escape bytes that could be misinterpreted by the printer.
    /// Specifically, 0x0A (LF) is replaced with 0x14 on T02.
    static func escapedBitmapData(_ data: Data) -> Data {
        var result = Data(capacity: data.count)
        for byte in data {
            if byte == 0x0A {
                result.append(0x14)
            } else {
                result.append(byte)
            }
        }
        return result
    }

    /// Generate a paper feed command.
    /// Format: `ESC d n` = `1B 64 n`
    static func feedCommand(lines: UInt8 = 2) -> Data {
        Data([0x1B, 0x64, lines])
    }
}
