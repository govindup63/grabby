// swift-tools-version: 6.0
import PackageDescription

// Swift Testing ships with the Command Line Tools but the toolchain does not pass its
// macro plugin path or runtime search paths, so the test target supplies them.
let cltRoot = "/Library/Developer/CommandLineTools"
let testingPlugins = "\(cltRoot)/usr/lib/swift/host/plugins/testing"
let testingFrameworks = "\(cltRoot)/Library/Developer/Frameworks"
let testingLibs = "\(cltRoot)/Library/Developer/usr/lib"

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
            swiftSettings: [.unsafeFlags(["-plugin-path", testingPlugins])],
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "-rpath", "-Xlinker", testingFrameworks,
                "-Xlinker", "-rpath", "-Xlinker", testingLibs,
            ])]
        ),
    ]
)
