import SwiftUI
import PhotosUI
import PhomemoPrinter

struct ContentView: View {
    @State private var viewModel = PrinterViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    var body: some View {
        NavigationStack {
            List {
                // Status Section
                Section {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                        Text(viewModel.statusMessage)
                            .font(.subheadline)
                    }
                    if let name = viewModel.connectedPrinterName {
                        HStack {
                            Label(name, systemImage: "printer.fill")
                            Spacer()
                            Button("Disconnect") {
                                viewModel.disconnect()
                            }
                            .foregroundStyle(.red)
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text("Status")
                }

                // Scan Section
                Section {
                    Button {
                        viewModel.scan()
                    } label: {
                        HStack {
                            Label("Scan for Printers", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            if viewModel.isScanning {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isScanning || viewModel.connectionState != .disconnected)

                    ForEach(viewModel.discoveredPrinters) { printer in
                        Button {
                            viewModel.connect(to: printer)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(printer.name)
                                        .font(.body)
                                    Text("\(printer.model.rawValue) - \(printer.rssi) dBm")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(viewModel.connectionState != .disconnected)
                    }
                } header: {
                    Text("Printers")
                }

                // Print Section
                if viewModel.connectionState == .ready {
                    Section {
                        Button {
                            viewModel.printTestText()
                        } label: {
                            HStack {
                                Label("Print Test Text", systemImage: "text.justify.left")
                                Spacer()
                                if viewModel.isPrinting {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(viewModel.isPrinting)

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Pick & Print Image", systemImage: "photo")
                        }
                        .disabled(viewModel.isPrinting)

                        if let selectedImage {
                            HStack {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Spacer()

                                Button("Print") {
                                    viewModel.printImage(selectedImage)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.isPrinting)
                            }
                        }
                    } header: {
                        Text("Print")
                    }
                }

                // Logs Section
                Section {
                    if viewModel.logs.isEmpty {
                        Text("Tap 'Scan for Printers' to start")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(viewModel.logs.indices.reversed(), id: \.self) { index in
                            Text(viewModel.logs[index])
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                } header: {
                    HStack {
                        Text("Log (\(viewModel.logs.count))")
                        Spacer()
                        if !viewModel.logs.isEmpty {
                            Button("Clear") {
                                viewModel.logs.removeAll()
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("Phomemo Test")
            .onChange(of: selectedPhoto) { _, newValue in
                loadImage(from: newValue)
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.connectionState {
        case .disconnected: return .red
        case .connecting: return .orange
        case .connected, .ready: return .green
        case .printing: return .blue
        case .disconnecting: return .orange
        }
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
            }
        }
    }
}

#Preview {
    ContentView()
}
