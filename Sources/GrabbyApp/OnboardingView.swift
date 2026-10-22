import AppKit
import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "cursorarrow.motionlines")
                    .font(.system(size: 36))
                Text("Grabby needs Accessibility access")
                    .font(.title2.bold())
            }
            Text("Grabby watches one mouse button and, while you hold it, turns mouse movement into desktop switching and Mission Control. macOS only lets an app see and send mouse input after you allow it under Accessibility.")
                .fixedSize(horizontal: false, vertical: true)
            Text("1. Click the button below.\n2. Find Grabby in the list and turn it on. If it is not listed, click the + button under the list and choose Grabby from Applications.\n3. Come back here. Grabby starts working as soon as access is granted, no relaunch needed.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Open System Settings") { Permissions.openAccessibilityPane() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}

@MainActor
final class OnboardingWindowController {
    private let window: NSWindow

    init() {
        let hosting = NSHostingController(rootView: OnboardingView())
        window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to Grabby"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window.orderOut(nil)
    }
}
