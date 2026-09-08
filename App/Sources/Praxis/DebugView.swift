import PraxisCore
import SwiftUI

/// Debug window shell. Task 1 shows build identity and the core intent
/// boundary only; navigation controls, enablement, shortcut confirmation, and
/// permission status arrive with the controller and app state (tasks 2–4).
struct DebugView: View {
    static let windowID = "praxis.debug"

    private let bundle = Bundle.main

    var body: some View {
        Form {
            Section("Build") {
                LabeledContent("Bundle identifier", value: bundle.bundleIdentifier ?? "none (not running from an app bundle)")
                LabeledContent("Version", value: versionDescription)
                LabeledContent("Executable", value: bundle.executablePath ?? "unknown")
            }

            Section("Space navigation") {
                ForEach(DesktopIntent.allCases, id: \.rawValue) { intent in
                    LabeledContent(intent.displayName, value: "not implemented")
                }
                Text("Execution is not implemented. Enablement, shortcut confirmation, permission status, and results appear once the action controller exists.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 300)
    }

    private var versionDescription: String {
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return "\(short) (\(build))"
    }
}
