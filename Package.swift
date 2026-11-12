// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IsolatedDesktop",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "IsolatedDesktop", targets: ["IsolatedDesktop"])],
    targets: [
        .executableTarget(name: "IsolatedDesktop"),
        .testTarget(name: "IsolatedDesktopTests", dependencies: ["IsolatedDesktop"])
    ]
)
