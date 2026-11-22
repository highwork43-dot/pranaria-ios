// swift-tools-version:5.9
import PackageDescription

// Ядро приложения — кроссплатформенное (Foundation-only), чтобы его можно было
// тестировать на Linux без Xcode. iOS-слой собирается отдельно через
// XcodeGen (project.yml) и компилирует оба каталога в один target.
let package = Package(
    name: "Pranaria",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "PranariaCore", targets: ["PranariaCore"])
    ],
    targets: [
        .target(
            name: "PranariaCore",
            path: "Sources/PranariaCore"
        ),
        .testTarget(
            name: "PranariaCoreTests",
            dependencies: ["PranariaCore"],
            path: "Tests/PranariaCoreTests"
        )
    ]
)
