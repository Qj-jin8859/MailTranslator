// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MailTranslator",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "MailTranslator", targets: ["MailTranslator"]),
        .executable(name: "MailTranslatorSelfTests", targets: ["MailTranslatorSelfTests"])
    ],
    targets: [
        .target(
            name: "MailTranslatorCore",
            path: "Sources/MailTranslatorCore"
        ),
        .executableTarget(
            name: "MailTranslator",
            dependencies: ["MailTranslatorCore"],
            path: "Sources/MailTranslator"
        ),
        .executableTarget(
            name: "MailTranslatorSelfTests",
            dependencies: ["MailTranslatorCore"],
            path: "Tests/SelfTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
