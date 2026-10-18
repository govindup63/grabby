// swift-tools-version: 6.0
import PackageDescription

import Foundation

// With only the Command Line Tools installed (no Xcode), the toolchain does not pass Swift
// Testing's macro plugin path or runtime search paths, so the test target supplies them.
// On a machine with Xcode these paths do not exist and nothing is added.
let cltRoot = "/Library/Developer/CommandLineTools"
let testingPlugins = "\(cltRoot)/usr/lib/swift/host/plugins/testing"
let testingFrameworks = "\(cltRoot)/Library/Developer/Frameworks"
let testingLibs = "\(cltRoot)/Library/Developer/usr/lib"
// Only when the Command Line Tools are the active toolchain: Xcode's own toolchain ships its
// own Swift Testing and cannot load the CLT plugin. GRABBY_CLT_TESTING=0/1 overrides the guess.
let usesCommandLineToolsOnly: Bool = {
    if let override = ProcessInfo.processInfo.environment["GRABBY_CLT_TESTING"] { return override == "1" }
    let developerDir = ProcessInfo.processInfo.environment["DEVELOPER_DIR"] ?? ""
    if developerDir.contains("Xcode") { return false }
    let xcodeInstalled = (try? FileManager.default.contentsOfDirectory(atPath: "/Applications"))?
        .contains { $0.hasPrefix("Xcode") && $0.hasSuffix(".app") } ?? false
    return !xcodeInstalled && FileManager.default.fileExists(atPath: testingPlugins)
}()
let testSwiftSettings: [SwiftSetting] = usesCommandLineToolsOnly ? [.unsafeFlags(["-plugin-path", testingPlugins])] : []
let testLinkerSettings: [LinkerSetting] = usesCommandLineToolsOnly ? [.unsafeFlags([
    "-Xlinker", "-rpath", "-Xlinker", testingFrameworks,
    "-Xlinker", "-rpath", "-Xlinker", testingLibs,
])] : []

let package = Package(
    name: "Grabby",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "GrabbyApp", targets: ["GrabbyApp"]),
        .executable(name: "grabby-probe", targets: ["GrabbyProbe"]),
    ],
    targets: [
        .target(name: "GrabbyCore"),
        .target(name: "GrabbyPrivate"),
        .target(
            name: "GrabbyEngines",
            dependencies: ["GrabbyCore", "GrabbyPrivate"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
            ]
        ),
        .executableTarget(
            name: "GrabbyApp",
            dependencies: ["GrabbyCore", "GrabbyPrivate", "GrabbyEngines"],
            exclude: ["Resources"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .executableTarget(
            name: "GrabbyProbe",
            dependencies: ["GrabbyCore", "GrabbyPrivate", "GrabbyEngines"]
        ),
        .testTarget(
            name: "GrabbyCoreTests",
            dependencies: ["GrabbyCore"],
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        ),
    ]
)
