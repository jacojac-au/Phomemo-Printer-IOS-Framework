import Foundation
import CoreBluetooth
import Combine
import UIKit

/// Main facade for connecting to and printing on Phomemo printers.
///
/// Usage:
/// ```swift
/// let scanner = PhomemoScanner()
/// let printers = try await scanner.scan(timeout: 5.0)
/// let printer = try await PhomemoPrinter.connect(to: printers[0], using: scanner)
/// try await printer.print(image: myUIImage)
/// printer.disconnect()
/// ```
public final class PhomemoPrinter: @unchecked Sendable {
    /// The discovered printer this instance is connected to.
    public let discoveredPrinter: DiscoveredPrinter

    /// The printer profile for model-specific behavior.
    private let profile: PrinterProfile

    /// BLE connection manager.
    private let connection: BLEPeripheralConnection

    /// BLE central manager (retained for disconnect).
    private let centralManager: BLECentralManager

    /// Current connection state.
    private let connectionStateSubject = CurrentValueSubject<PrinterConnectionState, Never>(.disconnected)

    /// Publisher for connection state changes.
    public var connectionStatePublisher: AnyPublisher<PrinterConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    /// Current connection state.
    public var connectionState: PrinterConnectionState {
        connectionStateSubject.value
    }

    /// Publisher for printer status updates.
    public var statusPublisher: AnyPublisher<PrinterStatus, Never> {
        connection.statusPublisher
    }

    private var cancellables = Set<AnyCancellable>()

    private init(
        discoveredPrinter: DiscoveredPrinter,
        profile: PrinterProfile,
        connection: BLEPeripheralConnection,
        centralManager: BLECentralManager
    ) {
        self.discoveredPrinter = discoveredPrinter
        self.profile = profile
        self.connection = connection
        self.centralManager = centralManager
    }

    /// Connect to a discovered printer and return a ready-to-use PhomemoPrinter.
    ///
    /// - Parameters:
    ///   - printer: A printer discovered via `PhomemoScanner.scan()`.
    ///   - scanner: The scanner that discovered the printer.
    /// - Returns: A connected and initialized `PhomemoPrinter`.
    public static func connect(
        to printer: DiscoveredPrinter,
        using scanner: PhomemoScanner
    ) async throws -> PhomemoPrinter {
        let profile = T02Profile.profile(for: printer.model)
        let centralManager = scanner.bleManager

        // Connect to the peripheral
        let peripheral = try await centralManager.connect(identifier: printer.id)

        // Create the connection handler
        let connection = BLEPeripheralConnection(peripheral: peripheral, profile: profile)

        let instance = PhomemoPrinter(
            discoveredPrinter: printer,
            profile: profile,
            connection: connection,
            centralManager: centralManager
        )

        instance.connectionStateSubject.send(.connecting)

        // Discover services and characteristics
        try await connection.discoverServices()

        // Send initialization commands
        try await connection.sendInitCommands()

        // Brief delay for printer to process init commands
        try await Task.sleep(nanoseconds: 500_000_000)

        instance.connectionStateSubject.send(.ready)

        return instance
    }

    /// Print a UIImage.
    ///
    /// - Parameters:
    ///   - image: The image to print.
    ///   - options: Print options (dithering, threshold, feed lines).
    public func print(image: UIImage, options: PrintOptions = .default) async throws {
        guard connectionState == .ready else {
            throw PhomemoError.notConnected
        }

        connectionStateSubject.send(.printing)

        defer {
            connectionStateSubject.send(.ready)
        }

        // Process image into bitmap
        guard let result = ImageProcessor.process(
            image: image,
            printWidth: profile.printWidthDots,
            options: options
        ) else {
            throw PhomemoError.imageConversionFailed
        }

        // Encode to printer wire format
        let printData = CommandEncoder.encode(
            bitmap: result.bitmap,
            widthBytes: result.widthBytes,
            height: result.height,
            profile: profile
        )

        // Send to printer
        try await connection.writeData(printData)
    }

    /// Print a CGImage.
    public func print(cgImage: CGImage, options: PrintOptions = .default) async throws {
        let uiImage = UIImage(cgImage: cgImage)
        try await print(image: uiImage, options: options)
    }

    /// Print text, optionally with a title.
    ///
    /// Renders the text into an image and prints it.
    ///
    /// - Parameters:
    ///   - text: The body text to print.
    ///   - title: Optional bold title above the text.
    ///   - options: Print options.
    public func printText(
        _ text: String,
        title: String? = nil,
        options: PrintOptions = .default
    ) async throws {
        guard let image = ImageProcessor.renderText(
            text,
            title: title,
            printWidth: profile.printWidthDots
        ) else {
            throw PhomemoError.imageConversionFailed
        }

        // Skip rotation for text images since they're already portrait-oriented
        guard connectionState == .ready else {
            throw PhomemoError.notConnected
        }

        connectionStateSubject.send(.printing)
        defer { connectionStateSubject.send(.ready) }

        // Process without rotation (text is already properly sized)
        guard var pixels = ImageUtilities.toGrayscalePixels(image.cgImage!) else {
            throw PhomemoError.imageConversionFailed
        }

        let width = image.cgImage!.width
        let height = image.cgImage!.height

        if options.dithered {
            DitheredConverter.convert(pixels: &pixels, width: width, height: height)
        } else {
            MonochromeConverter.convert(pixels: &pixels, threshold: options.threshold)
        }

        let bitmap = ImageUtilities.packToBitmap(pixels: pixels, width: width, height: height)
        let widthBytes = width / 8

        let printData = CommandEncoder.encode(
            bitmap: bitmap,
            widthBytes: widthBytes,
            height: height,
            profile: profile
        )

        try await connection.writeData(printData)
    }

    /// Disconnect from the printer.
    public func disconnect() {
        connectionStateSubject.send(.disconnecting)
        centralManager.disconnect(connection.peripheral)
        connectionStateSubject.send(.disconnected)
    }
}
