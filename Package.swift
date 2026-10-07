// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SpanishMenuBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SpanishMenuBar", targets: ["SpanishMenuBar"]),
    ],
    targets: [
        .target(
            name: "SpanishMenuBarCore",
            resources: [.copy("Resources/es-en.xml")]
        ),
        .executableTarget(
            name: "SpanishMenuBar",
            dependencies: ["SpanishMenuBarCore"]
        ),
    ]
)
