# PhomemoPrinter

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS 15+](https://img.shields.io/badge/iOS-15+-blue.svg)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Swift Package for printing images and text on Phomemo thermal printers via Bluetooth Low Energy (BLE).

## Supported Printers

| Model | Print Width | DPI  | BLE Write Strategy |
|-------|------------|------|--------------------|
| T02   | 384 dots (48 mm) | ~200 | Bulk |
| M04S  | 1232 dots (110 mm) | ~300 | Chunked |

## Installation

Add the package to your Xcode project via **File > Add Package Dependencies**, using:

```
https://github.com/jacojac-au/Phomemo-Printer-IOS-Framework.git
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jacojac-au/Phomemo-Printer-IOS-Framework.git", from: "1.0.0"),
]
```

Then import it:

```swift
import PhomemoPrinter
```

## Quick Start

```swift
import PhomemoPrinter

// 1. Scan for nearby printers
let scanner = PhomemoScanner()
let printers = try await scanner.scan(timeout: 5.0)

// 2. Connect to a printer
let printer = try await PhomemoPrinter.connect(to: printers[0], using: scanner)

// 3. Print an image
try await printer.print(image: myUIImage)

// 4. Disconnect when done
printer.disconnect()
```

## API Reference

### PhomemoScanner

Scans for nearby Phomemo printers via BLE.

```swift
let scanner = PhomemoScanner()

// Scan for all supported models
let printers = try await scanner.scan(timeout: 5.0)

// Scan for a specific model
let t02Printers = try await scanner.scan(timeout: 5.0, model: .t02)
```

**Properties:**
- `discoveredPrinters: [DiscoveredPrinter]` — `@Published` list updated during scanning.

### PhomemoPrinter

Main interface for connecting and printing.

```swift
// Connect
let printer = try await PhomemoPrinter.connect(to: discoveredPrinter, using: scanner)

// Print a UIImage
try await printer.print(image: myImage)

// Print a CGImage
try await printer.print(cgImage: myCGImage)

// Print text (rendered as an image)
try await printer.printText("Hello, World!", title: "Greeting")

// Disconnect
printer.disconnect()
```

**Properties:**
- `connectionState: PrinterConnectionState` — Current connection state.
- `connectionStatePublisher: AnyPublisher<PrinterConnectionState, Never>` — Observe connection changes.
- `statusPublisher: AnyPublisher<PrinterStatus, Never>` — Observe printer status (paper, heat, etc.).
- `discoveredPrinter: DiscoveredPrinter` — The printer this instance is connected to.

### PrintOptions

Configure print behavior per job.

```swift
// Default: dithering enabled, 128 threshold, 2 feed lines
let options = PrintOptions()

// Custom: simple threshold, no dithering
let options = PrintOptions(dithered: false, threshold: 150, feedLines: 3)

try await printer.print(image: myImage, options: options)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `dithered` | `Bool` | `true` | Use Floyd-Steinberg dithering vs simple threshold |
| `threshold` | `UInt8` | `128` | Monochrome cutoff (only used when `dithered` is false) |
| `feedLines` | `UInt8` | `2` | Blank lines to feed after printing |

### PrinterStatus

An `OptionSet` of conditions reported by the printer via BLE notifications.

```swift
let cancellable = printer.statusPublisher.sink { status in
    if status.contains(.noPaper) {
        print("Out of paper!")
    }
    if status.contains(.overheating) {
        print("Printer is overheating, wait before printing.")
    }
    if status.isReady {
        print("Printer is ready.")
    }
}
```

**Constants:** `.normal`, `.overheating`, `.coverOpen`, `.noPaper`, `.printComplete`, `.cancelled`

### Error Handling

All errors are thrown as `PhomemoError`, which conforms to `LocalizedError`.

```swift
do {
    try await printer.print(image: myImage)
} catch let error as PhomemoError {
    switch error {
    case .noPaper:
        // Prompt user to load paper
    case .printerOverheating:
        // Wait and retry
    case .bluetoothPoweredOff:
        // Ask user to enable Bluetooth
    default:
        print(error.localizedDescription)
    }
}
```

**Cases:** `bluetoothUnavailable`, `bluetoothUnauthorized`, `bluetoothPoweredOff`, `scanTimeout`, `connectionTimeout`, `connectionFailed`, `notConnected`, `serviceNotFound`, `characteristicNotFound`, `writeNotSupported`, `printerOverheating`, `coverOpen`, `noPaper`, `printCancelled`, `imageConversionFailed`, `alreadyConnected`, `disconnected`

### Text Printing

Text is rendered to an image and printed. The library generates a clean layout with optional title and body text.

```swift
try await printer.printText("Meeting at 3pm\nBring the reports", title: "Reminder")
```

## Architecture

The library uses a **profile-based architecture** to support multiple printer models:

```
PhomemoPrinter (facade)
  -> PrinterProfile (protocol)
       -> T02Profile
       -> M04SProfile
  -> BLECentralManager (async/await BLE scanning)
  -> BLEPeripheralConnection (service/characteristic discovery, writes)
  -> ImageProcessor (normalize -> rotate -> resize -> dither/threshold -> 1-bit pack)
  -> CommandEncoder (1-bit bitmap -> printer wire format)
  -> MessageFormatter (command framing with CRC-8)
```

### Adding a New Printer Model

1. Create a new file in `Sources/PhomemoPrinter/PrinterProfile/` (e.g., `MyPrinterProfile.swift`).
2. Implement the `PrinterProfile` protocol:
   - Define `printWidthDots`, `printWidthBytes`, `dpi`, `linesPerChunk`
   - Specify `writeStrategy` (`.bulk` or `.chunked(...)`)
   - Set `requiresByteEscaping` if the printer needs `0x0A -> 0x14` escaping
   - Implement `encodeRasterData(_:)` to wrap bitmap lines in printer commands
3. Add a case to `PrinterModel` and wire it up in the model detection logic.

## Info.plist Requirement

Your app must include a Bluetooth usage description in its `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to Phomemo printers.</string>
```

Or via Xcode: add "Privacy - Bluetooth Always Usage Description" to your target's Info tab.

## Test App

The `PhomemoTestApp/` directory contains a SwiftUI test app that demonstrates scanning, connecting, and printing. Open `PhomemoTestApp/PhomemoTestApp.xcodeproj` in Xcode, set your development team, and run on a physical device (BLE requires a real device).

## Credits

This library was built with insights from the reverse-engineering work of:

- [jeffrafter/phomemo](https://github.com/jeffrafter/phomemo) — M02S protocol documentation
- [matheusdanoite/Phomemo-T02-for-Apple](https://github.com/matheusdanoite/Phomemo-T02-for-Apple) — T02 macOS implementation

## License

MIT. See [LICENSE](LICENSE) for details.
