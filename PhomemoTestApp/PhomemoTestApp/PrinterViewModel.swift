import SwiftUI
import PhomemoPrinter
import Combine
import os

private let logger = Logger(subsystem: "com.phomemo.testapp", category: "Printer")

@Observable
@MainActor
class PrinterViewModel {
    var discoveredPrinters: [DiscoveredPrinter] = []
    var connectionState: PrinterConnectionState = .disconnected
    var isScanning = false
    var statusMessage = "Not connected"
    var logs: [String] = []
    var connectedPrinterName: String?
    var isPrinting = false

    private let scanner = PhomemoScanner()
    private var printer: PhomemoPrinter?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Hook up debug callback to see ALL BLE peripherals
        scanner.onAnyPeripheralDiscovered = { [weak self] name, id, services in
            MainActor.assumeIsolated {
                let shortId = id.uuidString.prefix(8)
                let svcList = services.map(\.uuidString).joined(separator: ", ")
                self?.log("BLE: \(name ?? "<no name>") [\(shortId)...] svcs: [\(svcList)]")
            }
        }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        discoveredPrinters = []
        log("Scanning for printers...")
        statusMessage = "Scanning..."

        Task {
            do {
                let printers = try await scanner.scan(timeout: 6.0)
                discoveredPrinters = printers
                if printers.isEmpty {
                    log("No Phomemo printers found (see BLE entries above)")
                    statusMessage = "No printers found"
                } else {
                    log("Found \(printers.count) printer(s)")
                    statusMessage = "Found \(printers.count) printer(s)"
                }
            } catch {
                log("Scan error: \(error.localizedDescription)")
                statusMessage = "Scan error: \(error.localizedDescription)"
            }
            isScanning = false
        }
    }

    func connect(to discovered: DiscoveredPrinter) {
        guard connectionState == .disconnected else { return }
        connectionState = .connecting
        statusMessage = "Connecting to \(discovered.name)..."
        log("Connecting to \(discovered.name) (\(discovered.model.rawValue))...")

        Task {
            do {
                let p = try await PhomemoPrinter.connect(to: discovered, using: scanner)
                printer = p
                connectedPrinterName = discovered.name
                connectionState = .ready
                statusMessage = "Connected to \(discovered.name)"
                log("Connected and ready!")

                p.statusPublisher
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] status in
                        self?.handleStatus(status)
                    }
                    .store(in: &cancellables)

                p.connectionStatePublisher
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] state in
                        self?.connectionState = state
                    }
                    .store(in: &cancellables)
            } catch {
                connectionState = .disconnected
                statusMessage = "Connection failed"
                log("Connection failed: \(error.localizedDescription)")
            }
        }
    }

    func disconnect() {
        printer?.disconnect()
        printer = nil
        connectedPrinterName = nil
        connectionState = .disconnected
        statusMessage = "Disconnected"
        cancellables.removeAll()
        log("Disconnected")
    }

    func printTestText() {
        guard let printer, connectionState == .ready else {
            log("Not ready to print")
            return
        }
        isPrinting = true
        log("Printing test text...")

        Task {
            do {
                try await printer.printText(
                    "This is a test print from the PhomemoPrinter library. If you can read this, everything is working!",
                    title: "Test Print"
                )
                log("Test text printed successfully!")
            } catch {
                log("Print error: \(error.localizedDescription)")
            }
            isPrinting = false
        }
    }

    func printImage(_ image: UIImage) {
        guard let printer, connectionState == .ready else {
            log("Not ready to print")
            return
        }
        isPrinting = true
        log("Printing image...")

        Task {
            do {
                try await printer.print(image: image)
                log("Image printed successfully!")
            } catch {
                log("Print error: \(error.localizedDescription)")
            }
            isPrinting = false
        }
    }

    private func handleStatus(_ status: PrinterStatus) {
        if status.contains(.overheating) {
            log("Printer is overheating!")
            statusMessage = "Overheating - please wait"
        } else if status.contains(.coverOpen) {
            log("Printer cover is open")
            statusMessage = "Cover is open"
        } else if status.contains(.noPaper) {
            log("Printer is out of paper")
            statusMessage = "No paper"
        } else if status.contains(.printComplete) {
            log("Print complete")
        } else if status.contains(.cancelled) {
            log("Print cancelled")
        }
    }

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        print("[Phomemo] \(message)")
        logger.info("\(message)")
        logs.append(entry)
        if logs.count > 100 {
            logs.removeFirst()
        }
    }
}
