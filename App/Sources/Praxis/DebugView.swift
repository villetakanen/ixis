import PraxisCore
import PraxisDesktop
import SwiftUI

/// The button-driven Space-navigation probe. Everything shown here is either
/// app state or a controller record; the view adds no eligibility logic, so a
/// request made in any state reaches the controller and gets its reason back.
struct DebugView: View {
    static let windowID = "praxis.debug"

    @Bindable var probe: ProductionProbe
    private let bundle = Bundle.main

    var body: some View {
        Form {
            navigationSection
            executionSection
            mappingSection
            accessSection
            latestResultSection
            historySection
            buildSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 600)
    }

    // MARK: Sections

    private var navigationSection: some View {
        Section("Space navigation") {
            HStack {
                ForEach(DesktopIntent.allCases, id: \.rawValue) { intent in
                    Button(intent.displayName) { probe.request(intent) }
                        .accessibilityIdentifier("praxis.request.\(intent.rawValue)")
                }
                Spacer()
                Text(readinessText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("Each press is one request. The controller decides whether it posts; a blocked or failed request shows its reason below. Buttons stay active in every state on purpose.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var executionSection: some View {
        Section("Execution") {
            Toggle("Execute navigation shortcuts", isOn: Binding(
                get: { probe.isExecutionEnabled },
                set: { probe.setExecutionEnabled($0) }
            ))
            Text("Off on every launch. Turning it off does not save requests for later; nothing is replayed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var mappingSection: some View {
        Section {
            ForEach(DesktopIntent.allCases, id: \.rawValue) { intent in
                MappingEditor(probe: probe, intent: intent)
            }
            HStack {
                Button("Reset to Control–Left / Control–Right") {
                    probe.resetMappingsToProposedDefaults()
                }
                Spacer()
                Button(probe.areShortcutsConfirmed ? "Reconfirm mappings" : "Confirm mappings match System Settings") {
                    probe.confirmShortcuts()
                }
                .disabled(probe.hasInvalidDraft)
                .accessibilityIdentifier("praxis.confirm")
            }
            Text(confirmationText)
                .font(.footnote)
                .foregroundStyle(probe.areShortcutsConfirmed ? Color.secondary : Color.orange)
        } header: {
            Text("Shortcut mappings")
        } footer: {
            Text("Compare with System Settings › Keyboard › Keyboard Shortcuts › Mission Control (“Move left a space” / “Move right a space”). Praxis does not read those settings. If you change them there, recheck the mappings here and confirm again; confirmation lasts for this app session and is withdrawn whenever a mapping changes.")
        }
    }

    private var accessSection: some View {
        Section("Event-posting access") {
            LabeledContent("Status", value: accessStatusText)
            HStack {
                Button("Request access…") { probe.requestAccess() }
                    .accessibilityIdentifier("praxis.requestAccess")
                Button("Recheck") { probe.recheckAccess() }
                    .accessibilityIdentifier("praxis.recheckAccess")
            }
            Text("“Request access…” asks macOS once and may open System Settings › Privacy & Security. Navigation requests never prompt. The status here is a snapshot; the controller checks access again immediately before each action. After changing System Settings, press Recheck.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var latestResultSection: some View {
        Section("Latest result") {
            if let record = probe.latestRecord {
                RecordRow(presentation: ActionRecordPresentation(record), expanded: true)
            } else {
                Text("No requests yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var historySection: some View {
        Section {
            if probe.records.isEmpty {
                Text("Empty.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(probe.records, id: \.id) { record in
                    RecordRow(presentation: ActionRecordPresentation(record), expanded: false)
                }
            }
        } header: {
            Text("Recent requests (\(probe.records.count) of newest \(ProductionProbe.historyCapacity))")
        } footer: {
            Text("Duration is Praxis processing from request to result. It excludes any macOS transition, which Praxis cannot observe. “Shortcut posted” means the key pair was handed to macOS, not that the Space changed.")
        }
    }

    private var buildSection: some View {
        Section("Build") {
            LabeledContent("Bundle identifier", value: bundle.bundleIdentifier ?? "none (not running from an app bundle)")
            LabeledContent("Version", value: versionDescription)
            LabeledContent("Executable", value: bundle.executablePath ?? "unknown")
        }
    }

    // MARK: Text

    /// Display-only summary of the setup state. It does not gate anything.
    private var readinessText: String {
        var missing: [String] = []
        if !probe.isExecutionEnabled { missing.append("execution off") }
        if !probe.areShortcutsConfirmed { missing.append("mappings unconfirmed") }
        if !probe.accessStatus.isGranted { missing.append("access not granted") }
        return missing.isEmpty ? "Setup complete; requests may post." : "Setup incomplete: " + missing.joined(separator: ", ")
    }

    private var confirmationText: String {
        if probe.hasInvalidDraft {
            return probe.areShortcutsConfirmed
                ? "Confirmed for the mapping shown on the right; the key code text is invalid and has not been applied."
                : "Fix the invalid key code before confirming."
        }
        return probe.areShortcutsConfirmed
            ? "You confirmed these mappings match the enabled Mission Control shortcuts."
            : "Not confirmed for this session. Requests are blocked until you confirm."
    }

    private var accessStatusText: String {
        switch probe.accessStatus {
        case .unchecked:
            "Not checked yet."
        case .granted(let at):
            "Granted (checked \(at.formatted(date: .omitted, time: .standard)))"
        case .denied(let at):
            "Not granted (checked \(at.formatted(date: .omitted, time: .standard)))"
        }
    }

    private var versionDescription: String {
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return "\(short) (\(build))"
    }
}

/// Key code text field plus four modifier toggles for one direction.
private struct MappingEditor: View {
    @Bindable var probe: ProductionProbe
    let intent: DesktopIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(intent.displayName)
                    .frame(width: 120, alignment: .leading)
                TextField("Key code", text: Binding(
                    get: { probe.draft(for: intent).keyCodeText },
                    set: { probe.setKeyCodeText($0, for: intent) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .accessibilityIdentifier("praxis.keyCode.\(intent.rawValue)")
                ForEach(KeyModifiers.displayOrder, id: \.1) { modifier, name, symbol in
                    Toggle("\(symbol) \(name)", isOn: Binding(
                        get: { probe.draft(for: intent).modifiers.contains(modifier) },
                        set: { probe.setModifier(modifier, enabled: $0, for: intent) }
                    ))
                    .toggleStyle(.checkbox)
                    .disabled(probe.mappingError(for: intent) != nil)
                }
                Spacer()
                Text(probe.mappings[intent].displayText)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let error = probe.mappingError(for: intent) {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct RecordRow: View {
    let presentation: ActionRecordPresentation
    let expanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(presentation.idText)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                Text(presentation.directionText)
                Text(presentation.outcomeText)
                    .fontWeight(.semibold)
                    .foregroundStyle(outcomeColor)
                Spacer()
                Text(presentation.elapsedText)
                    .font(.callout.monospaced())
                Text(presentation.timestampText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if expanded || !presentation.record.outcome.isPosted {
                Text(presentation.reasonText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let recovery = presentation.recoveryText {
                    Text(recovery)
                        .font(.footnote)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var outcomeColor: Color {
        switch presentation.record.outcome {
        case .posted: .primary
        case .blocked: .orange
        case .failed: .red
        }
    }
}
