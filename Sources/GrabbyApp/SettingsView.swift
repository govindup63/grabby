import GrabbyCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    private var working: Bool { model.status == "Grabby is working" }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: working ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(working ? .green : .orange)
                    Text(model.status)
                    Spacer()
                    if !working {
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
                    Text("Hold this button and move the mouse: left or right slides between desktops, up opens Mission Control, down brings you back to your app.")
                        .font(.caption).foregroundStyle(.secondary)
                case .listening:
                    Label("Press the mouse button you want to use. Left and right are not allowed.", systemImage: "cursorarrow.click")
                        .foregroundStyle(.blue)
                case .message(let text):
                    Text(text).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Sliding") {
                Picker("Direction", selection: naturalDirectionBinding) {
                    Text("Follow system scrolling").tag(0)
                    Text("Natural").tag(1)
                    Text("Reversed").tag(2)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Throw")
                        Spacer()
                        Text(throwLabel).foregroundStyle(.secondary).font(.caption)
                    }
                    Slider(value: $model.settings.throwStrength, in: 0...1, step: 0.05) {
                        EmptyView()
                    } minimumValueLabel: {
                        Image(systemName: "hand.point.up.left").foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Image(systemName: "hand.wave").foregroundStyle(.secondary)
                    }
                    Text("At zero, where you let go decides: past halfway it completes, otherwise it slides back. Further right, the speed of your hand at release counts too, so a flick can finish the move.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Tap and clicks") {
                Picker("Tap without moving", selection: $model.settings.tapAction) {
                    Text("Nothing").tag(TapAction.none)
                    Text("Mission Control").tag(TapAction.missionControl)
                    Text("App Expose").tag(TapAction.appExpose)
                    Text("Show Desktop").tag(TapAction.showDesktop)
                    Text("Pass the click through").tag(TapAction.passThrough)
                }
                LabeledContent("Hold + left click", value: "Area screenshot")
                LabeledContent("Hold + right click", value: "Screenshot and recording panel")
            }

            Section("General") {
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
        if v == 0 { return "Where you let go decides" }
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
