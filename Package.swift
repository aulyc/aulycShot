// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "aulycShot",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "aulycShot", targets: ["aulycShot"]),
        .executable(name: "AulycShotShareExtension", targets: ["AulycShotShareExtension"])
    ],
    targets: [
        .target(
            name: "SystemSettingsKit",
            path: "ThirdParty/PermissionFlow/Sources/SystemSettingsKit"
        ),
        .target(
            name: "PermissionFlow",
            dependencies: ["SystemSettingsKit"],
            path: "ThirdParty/PermissionFlow/Sources/PermissionFlow",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "aulycShot",
            dependencies: [
                "PermissionFlow"
            ],
            path: "aulycShot",
            exclude: ["App/Info.plist"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Vision"),
                .linkedFramework("CoreImage"),
                .linkedFramework("ImageIO"),
                .linkedFramework("UniformTypeIdentifiers"),
                .linkedFramework("Carbon"),
                .linkedFramework("VideoToolbox"),
                .linkedLibrary("z"),
            ]
        ),
        .executableTarget(
            name: "AulycShotShareExtension",
            path: "aulycShot-share-extension",
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]
        ),
        .testTarget(
            name: "aulycShotTests",
            dependencies: ["aulycShot"],
            path: "Tests/aulycShotTests"
        ),
        .testTarget(
            name: "PermissionFlowTests",
            dependencies: ["PermissionFlow"],
            path: "Tests/PermissionFlowTests"
        )
    ]
)
