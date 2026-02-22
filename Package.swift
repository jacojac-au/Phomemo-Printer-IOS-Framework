// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhomemoPrinter",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "PhomemoPrinter", targets: ["PhomemoPrinter"]),
    ],
    targets: [
        .target(
            name: "PhomemoPrinter",
            path: "Sources/PhomemoPrinter"
        ),
        .testTarget(
            name: "PhomemoPrinterTests",
            dependencies: ["PhomemoPrinter"],
            path: "Tests/PhomemoPrinterTests"
        ),
    ]
)
