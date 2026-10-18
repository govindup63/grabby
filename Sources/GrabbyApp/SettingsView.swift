import GrabbyCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: model.status == "Grabby is working" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.status == "Grabby is working" ? .green : .orange)
                    Text(model.status)
                    Spacer()
                    if model.status != "Grabby is working" {
                        Button("Open Accessibility Settings") { Permissions.openAccessibilityPane() }
                    }
                }
            }

            Section("Action button") {
                HStack {
                    Text(model.actionButtonLabel).font(.headline)
                    Spacer()
                    if model.learnState == .listening {
                        Button("Cancel") { model.cancelLearning() }
                    } else {
                        Button("Change...") { model.startLearning() }
                    }
                }
                switch model.learnState {
                case .idle:
                    Text("Hold this button and move the mouse to switch desktops.")
                        .font(.caption).foregroundStyle(.secondary)
                case .listening:
                    Label("Press the mouse button you want to use. Left and right are not allowed.", systemImage: "cursorarrow.click")
                        .foregroundStyle(.blue)
                case .message(let text):
                    Text(text).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Drag") {
                Picker("Switching style", selection: $model.settings.switchingStyle) {
                    Text("Smooth (follows the pointer)").tag(SwitchingStyle.smooth)
                    Text("Keyboard shortcut (one desktop per step)").tag(SwitchingStyle.keyboard)
                }
                Picker("Natural direction", selection: naturalDirectionBinding) {
                    Text("Follow system").tag(0)
                    Text("On").tag(1)
                    Text("Off").tag(2)
                }
                LabeledContent("Drag left or right", value: "Switch desktop")
                LabeledContent("Drag up", value: "Mission Control")
                Picker("Drag down", selection: $model.settings.dragDownAction) {
                    Text("App Expose").tag(DragDownAction.appExpose)
                    Text("Show Desktop").tag(DragDownAction.showDesktop)
                    Text("Nothing").tag(DragDownAction.none)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Throw")
                        Spacer()
                        Text(throwLabel).foregroundStyle(.secondary).font(.caption)
                    }
                    Slider(value: $model.settings.throwStrength, in: 0...1, step: 0.05) {
                        Text("Throw")
                    } minimumValueLabel: {
                        Image(systemName: "hand.point.up.left").foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Image(systemName: "hand.wave").foregroundStyle(.secondary)
                    }
                    Text("At zero the desktop only follows the mouse and stays where you let go. Further right, a quick flick carries it to the next desktop.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Tap") {
                Picker("Tap without moving", selection: $model.settings.tapAction) {
                    Text("Mission Control").tag(TapAction.missionControl)
                    Text("App Expose").tag(TapAction.appExpose)
                    Text("Show Desktop").tag(TapAction.showDesktop)
                    Text("Nothing").tag(TapAction.none)
                    Text("Pass the click through").tag(TapAction.passThrough)
                }
            }

            Section("General") {
                Toggle("Keep pointer in place while dragging", isOn: $model.settings.pinPointer)
                Toggle("Launch at login", isOn: $model.settings.launchAtLogin)
                if let error = model.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            if !model.conflicts.isEmpty {
                Section("Conflicts") {
                    ForEach(model.conflicts, id: \.tool) { conflict in
                        Label(conflict.advice, systemImage: "exclamationmark.triangle")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var throwLabel: String {
        let v = model.settings.throwStrength
        if v == 0 { return "Follows the mouse" }
        if v < 0.4 { return "Gentle" }
        if v < 0.75 { return "Medium" }
        return "Flick to switch"
    }

    private var naturalDirectionBinding: Binding<Int> {
        Binding(
            get: {
                switch model.settings.naturalDirection {
                case nil: return 0
                case true?: return 1
                case false?: return 2
                }
            },
            set: { model.settings.naturalDirection = $0 == 0 ? nil : ($0 == 1) }
        )
    }
}
