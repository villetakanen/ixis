import CoreGraphics
import Foundation
import PraxisCore
import Testing
@testable import PraxisDesktop

// Scenario IDs refer to specs/space-navigation/spec.md. These tests cover the
// app-state portions of SN-001 and SN-008 and show that the probe forwards
// every request to the controller (SN-002 to SN-004 reasons surface unchanged).

@MainActor
@Suite("SN-001 probe launch and relaunch state")
struct ProbeLaunchTests {
    @Test("a fresh probe is disabled and unconfirmed, shows proposed defaults, and has no records")
    func launchState() {
        let h = ProbeHarness()
        #expect(h.probe.isExecutionEnabled == false)
        #expect(h.probe.areShortcutsConfirmed == false)
        #expect(h.probe.mappings == .proposedDefaults)
        #expect(h.probe.latestRecord == nil)
        #expect(h.probe.records.isEmpty)
        #expect(h.probe.draft(for: .previousSpace).keyCodeText == "0x7B")
        #expect(h.probe.draft(for: .nextSpace).keyCodeText == "0x7C")
        #expect(h.probe.draft(for: .nextSpace).modifiers == .control)
        #expect(h.probe.hasInvalidDraft == false)
    }

    @Test("launch preflights access once without requesting, and reports the result")
    func launchAccessSnapshot() {
        let granted = ProbeHarness(accessGranted: true)
        #expect(granted.probe.accessStatus.isGranted)
        #expect(granted.access.preflightCount == 1)
        #expect(granted.access.requestCount == 0)

        let denied = ProbeHarness(accessGranted: false)
        guard case .denied = denied.probe.accessStatus else {
            Issue.record("expected denied status, got \(denied.probe.accessStatus)"); return
        }
        #expect(denied.access.requestCount == 0)

        let unchecked = ProbeHarness(checkAccessOnLaunch: false)
        #expect(unchecked.probe.accessStatus == .unchecked)
        #expect(unchecked.access.preflightCount == 0)
    }

    @Test("relaunch keeps persisted mappings but resets enablement and confirmation")
    func relaunchResets() {
        let store = MemoryMappingStore()
        let first = ProbeHarness(store: store)
        first.probe.setKeyCodeText("0x0E", for: .nextSpace)
        first.probe.setModifier(.command, enabled: true, for: .nextSpace)
        first.makeEligible()
        #expect(first.probe.request(.nextSpace).outcome == .posted)
        #expect(first.probe.isExecutionEnabled && first.probe.areShortcutsConfirmed)

        let relaunched = ProbeHarness(store: store)
        #expect(relaunched.probe.mappings.nextSpace == KeyboardShortcut(keyCode: 0x0E, modifiers: [.control, .command]))
        #expect(relaunched.probe.mappings.previousSpace == ShortcutMappings.proposedDefaults.previousSpace)
        #expect(relaunched.probe.draft(for: .nextSpace).keyCodeText == "0x0E")
        #expect(relaunched.probe.isExecutionEnabled == false)
        #expect(relaunched.probe.areShortcutsConfirmed == false)
        #expect(relaunched.probe.records.isEmpty, "history is per session")
        #expect(relaunched.probe.request(.nextSpace).outcome == .blocked(.executionDisabled))
        #expect(relaunched.recorder.posted.isEmpty)
    }

    /// Dictionary-backed `KeyedDataStore`, so the test touches no preference file.
    final class DictionaryStore: KeyedDataStore {
        var values: [String: Any] = [:]
        func data(forKey key: String) -> Data? { values[key] as? Data }
        func set(_ value: Any?, forKey key: String) { values[key] = value }
    }

    @Test("an unreadable or absent store yields the proposed defaults")
    func storeFallback() {
        let backing = DictionaryStore()
        let store = UserDefaultsMappingStore(defaults: backing)
        #expect(store.loadMappings() == nil)

        backing.set(Data("not json".utf8), forKey: UserDefaultsMappingStore.key)
        #expect(store.loadMappings() == nil)

        store.saveMappings(unusualMappings)
        #expect(store.loadMappings() == unusualMappings)
        #expect(backing.values.keys.sorted() == [UserDefaultsMappingStore.key], "only the mappings key is written")
    }
}

@MainActor
@Suite("SN-002 mapping edits invalidate confirmation")
struct ProbeMappingTests {
    @Test("changing a key code or a modifier withdraws confirmation and persists; identical edits do not")
    func editsInvalidate() {
        let h = ProbeHarness()
        h.makeEligible()
        #expect(h.probe.areShortcutsConfirmed)
        let savesBefore = h.store.saveCount

        h.probe.setKeyCodeText("0x7C", for: .nextSpace)   // same value, different route
        #expect(h.probe.areShortcutsConfirmed, "re-entering the same key code keeps confirmation")
        h.probe.setKeyCodeText("124", for: .nextSpace)    // decimal for 0x7C
        #expect(h.probe.areShortcutsConfirmed, "decimal spelling of the same key code keeps confirmation")
        #expect(h.store.saveCount == savesBefore)

        h.probe.setKeyCodeText("0x7D", for: .nextSpace)
        #expect(h.probe.areShortcutsConfirmed == false)
        #expect(h.probe.mappings.nextSpace.keyCode == 0x7D)
        #expect(h.store.stored?.nextSpace.keyCode == 0x7D)
        #expect(h.probe.request(.nextSpace).outcome == .blocked(.shortcutsUnconfirmed))
        #expect(h.recorder.posted.isEmpty)

        h.probe.confirmShortcuts()
        h.probe.setModifier(.shift, enabled: true, for: .previousSpace)
        #expect(h.probe.areShortcutsConfirmed == false, "a modifier-only change on the other direction is a change")
        #expect(h.probe.mappings.previousSpace.modifiers == [.control, .shift])

        h.probe.confirmShortcuts()
        h.probe.setModifier(.shift, enabled: true, for: .previousSpace)
        #expect(h.probe.areShortcutsConfirmed, "setting an already-set modifier is not a change")
    }

    @Test("an invalid key code keeps the last valid mapping, shows an error, and refuses confirmation")
    func invalidDraft() {
        let h = ProbeHarness()
        h.makeEligible()
        for text in ["", "0x", "zz", "0x10000", "65536", "-1", "7B"] {
            h.probe.setKeyCodeText(text, for: .previousSpace)
            #expect(h.probe.mappingError(for: .previousSpace) != nil, "\(text.debugDescription) should be invalid")
            #expect(h.probe.hasInvalidDraft)
            #expect(h.probe.mappings == .proposedDefaults, "mapping in force is unchanged for \(text.debugDescription)")
        }
        #expect(h.probe.areShortcutsConfirmed, "an unapplied draft is not a mapping change")

        // The request still goes to the controller, which sees the last valid,
        // confirmed mapping: it posts with 0x7B.
        #expect(h.probe.request(.previousSpace).outcome == .posted)
        #expect(h.postedKeyCodes == [0x7B, 0x7B])

        // Modifier toggles are not accepted while the key code is invalid, so
        // the checkboxes never disagree with the mapping in force.
        h.probe.setModifier(.command, enabled: true, for: .previousSpace)
        #expect(h.probe.draft(for: .previousSpace).modifiers == .control)
        #expect(h.probe.mappings.previousSpace.modifiers == .control)
        #expect(h.probe.areShortcutsConfirmed)

        h.probe.setKeyCodeText("0x7A", for: .previousSpace)
        #expect(h.probe.mappingError(for: .previousSpace) == nil)
        #expect(h.probe.areShortcutsConfirmed == false)
        h.probe.setKeyCodeText("", for: .previousSpace)
        h.probe.confirmShortcuts()
        #expect(h.probe.areShortcutsConfirmed == false, "cannot confirm while the shown text is not a mapping")
    }

    @Test("reset restores the proposed defaults and, when they differ, withdraws confirmation")
    func resetToDefaults() {
        let h = ProbeHarness()
        h.probe.setKeyCodeText("0x0D", for: .previousSpace)
        h.probe.setModifier(.control, enabled: false, for: .nextSpace)
        h.probe.confirmShortcuts()
        h.probe.resetMappingsToProposedDefaults()
        #expect(h.probe.mappings == .proposedDefaults)
        #expect(h.probe.areShortcutsConfirmed == false)
        #expect(h.probe.draft(for: .previousSpace).keyCodeText == "0x7B")
        #expect(h.probe.draft(for: .nextSpace).modifiers == .control)
    }

    @Test("key code text round-trips through the field format", arguments: [UInt16(0), 0x0D, 0x7B, 0xFF, 0xFFFF])
    func keyCodeRoundTrip(keyCode: UInt16) {
        let text = KeyCodeField.text(for: keyCode)
        #expect(text.hasPrefix("0x"))
        #expect(KeyCodeField.parse(text) == keyCode)
        #expect(KeyCodeField.parse(String(keyCode)) == keyCode)
        #expect(KeyCodeField.parse(" \(text.lowercased()) ") == keyCode)
    }
}

@MainActor
@Suite("Requests always reach the controller")
struct ProbeRequestTests {
    @Test("each blocking condition surfaces as the controller's reason with zero posts and no replay")
    func blockedReasonsSurface() {
        let h = ProbeHarness(accessGranted: false)
        #expect(h.probe.request(.nextSpace).outcome == .blocked(.executionDisabled))
        h.probe.setExecutionEnabled(true)
        #expect(h.probe.request(.nextSpace).outcome == .blocked(.shortcutsUnconfirmed))
        h.probe.confirmShortcuts()
        #expect(h.probe.request(.nextSpace).outcome == .blocked(.eventPostingAccessUnavailable))
        h.access.granted = true
        #expect(h.recorder.posted.isEmpty, "resolving conditions replays nothing")
        #expect(h.access.requestCount == 0, "navigation requests never request access")

        let fresh = h.probe.request(.previousSpace)
        #expect(fresh.outcome == .posted)
        #expect(h.recorder.posted.map(\.event.type) == [.keyDown, .keyUp])
        #expect(h.postedKeyCodes == [0x7B, 0x7B])
        #expect(h.probe.records.count == 4)
        #expect(h.probe.records.first == fresh, "records are newest first")
        #expect(h.probe.latestRecord == fresh)
    }

    @Test("a request refreshes the displayed access snapshot by preflight only")
    func requestRefreshesAccessSnapshot() {
        let h = ProbeHarness(accessGranted: true)
        h.makeEligible()
        #expect(h.probe.accessStatus.isGranted)
        h.access.granted = false
        #expect(h.probe.accessStatus.isGranted, "the snapshot is stale until something checks")
        #expect(h.probe.request(.nextSpace).outcome == .blocked(.eventPostingAccessUnavailable))
        #expect(h.probe.accessStatus.isGranted == false)
        #expect(h.access.requestCount == 0)
    }

    @Test("disabling execution never touches mappings or confirmation, and the switch mirrors the controller")
    func executionSwitch() {
        let h = ProbeHarness()
        h.makeEligible()
        h.probe.setExecutionEnabled(false)
        #expect(h.probe.isExecutionEnabled == false)
        #expect(h.probe.areShortcutsConfirmed)
        #expect(h.probe.request(.nextSpace).outcome == .blocked(.executionDisabled))
        h.probe.setExecutionEnabled(true)
        #expect(h.probe.request(.nextSpace).outcome == .posted)
        #expect(h.recorder.posted.count == 2)
    }
}

@MainActor
@Suite("Explicit access setup")
struct ProbeAccessTests {
    @Test("the request action calls the request function once and updates the status; recheck only preflights")
    func requestAndRecheck() {
        let h = ProbeHarness(accessGranted: false)
        h.access.grantOnRequest = true
        let preflightsAfterLaunch = h.access.preflightCount

        h.probe.requestAccess()
        #expect(h.access.requestCount == 1)
        #expect(h.probe.accessRequestCount == 1)
        #expect(h.probe.accessStatus.isGranted)
        #expect(h.access.preflightCount == preflightsAfterLaunch, "requesting does not also preflight")
        #expect(h.recorder.posted.isEmpty, "requesting access posts nothing")
        #expect(h.probe.records.isEmpty, "requesting access is not a navigation request")

        h.access.granted = false
        h.probe.recheckAccess()
        #expect(h.probe.accessStatus.isGranted == false)
        #expect(h.access.preflightCount == preflightsAfterLaunch + 1)
        #expect(h.access.requestCount == 1)
    }

    @Test("access status is independent of enablement and confirmation")
    func accessIndependentOfSetup() {
        let h = ProbeHarness(accessGranted: true)
        #expect(h.probe.accessStatus.isGranted)
        #expect(h.probe.isExecutionEnabled == false && h.probe.areShortcutsConfirmed == false)
        h.makeEligible()
        h.access.granted = false
        h.probe.recheckAccess()
        #expect(h.probe.isExecutionEnabled && h.probe.areShortcutsConfirmed)
    }
}

@MainActor
@Suite("SN-008 diagnostic presentation")
struct ProbePresentationTests {
    @Test("a posted record says “Shortcut posted” and never claims a Space change")
    func postedWording() {
        let h = ProbeHarness()
        h.makeEligible()
        let record = h.probe.request(.nextSpace)
        let p = ActionRecordPresentation(record)
        #expect(p.outcomeText == "Shortcut posted")
        #expect(p.directionText == "Next Space")
        #expect(p.recoveryText == nil)
        #expect(p.reasonText.contains("does not observe whether a Space transition followed"))
        for text in [p.outcomeText, p.reasonText, p.headline] {
            #expect(!text.localizedCaseInsensitiveContains("space changed"))
            #expect(!text.localizedCaseInsensitiveContains("switched"))
        }
        #expect(p.elapsedText.hasSuffix(" ms"))
    }

    @Test("blocked and failed records show direction, outcome, reason, and recovery")
    func blockedAndFailedWording() {
        let h = ProbeHarness(accessGranted: false)
        let disabled = ActionRecordPresentation(h.probe.request(.previousSpace))
        #expect(disabled.outcomeText == "Blocked")
        #expect(disabled.directionText == "Previous Space")
        #expect(disabled.reasonText == "Execution is off.")
        #expect(disabled.recoveryText == BlockReason.executionDisabled.recoveryAction)

        h.probe.setExecutionEnabled(true)
        let unconfirmed = ActionRecordPresentation(h.probe.request(.previousSpace))
        #expect(unconfirmed.reasonText.contains("not confirmed"))
        h.probe.confirmShortcuts()
        let denied = ActionRecordPresentation(h.probe.request(.previousSpace))
        #expect(denied.reasonText.contains("access was unavailable"))
        #expect(denied.recoveryText?.contains("System Settings") == true)

        h.access.granted = true
        h.probe.setKeyCodeText("0x38", for: .previousSpace)   // Shift as the main key fails construction
        h.probe.confirmShortcuts()
        let failed = ActionRecordPresentation(h.probe.request(.previousSpace))
        #expect(failed.outcomeText == "Failed")
        #expect(failed.reasonText.hasPrefix("Could not construct the key-down event:"))
        #expect(failed.reasonText.contains("Choose a non-modifier key"))
        #expect(failed.recoveryText == FailureReason.eventConstructionFailed(phase: .keyDown, detail: "").recoveryAction)
        #expect(h.recorder.posted.isEmpty)
    }

    @Test("elapsed text formats the record's processing duration in milliseconds")
    func elapsedFormatting() {
        func make(_ elapsed: Duration) -> ActionRecordPresentation {
            ActionRecordPresentation(ActionRecord(
                id: RequestID(rawValue: 1), intent: .nextSpace, timestamp: Date(timeIntervalSince1970: 0),
                elapsed: elapsed, outcome: .posted
            ))
        }
        #expect(make(.zero).elapsedText == "0.00 ms")
        #expect(make(.microseconds(1500)).elapsedText == "1.50 ms")
        #expect(make(.milliseconds(1234)).elapsedText == "1234.00 ms")
    }

    @Test("after 51 requests the probe shows the newest 50, newest first")
    func boundedHistory() {
        let h = ProbeHarness()
        h.makeEligible()
        for _ in 1...51 { h.probe.request(.nextSpace) }
        #expect(h.probe.records.count == 50)
        #expect(h.probe.records.first?.id == RequestID(rawValue: 51))
        #expect(h.probe.records.last?.id == RequestID(rawValue: 2))
        #expect(h.probe.latestRecord?.id == RequestID(rawValue: 51))
        #expect(h.recorder.posted.count == 102)
    }

    @Test("shortcut labels show symbols and hexadecimal key codes")
    func shortcutLabels() {
        #expect(KeyboardShortcut(keyCode: 0x7B, modifiers: .control).displayText == "⌃ 0x7B")
        #expect(KeyboardShortcut(keyCode: 0x0D, modifiers: [.command, .shift, .option, .control]).displayText == "⌃⌥⇧⌘ 0x0D")
        #expect(KeyboardShortcut(keyCode: 0x24, modifiers: []).displayText == "0x24 (no modifiers)")
    }
}

/// A mapping that shares nothing with the proposed defaults.
private let unusualMappings = ShortcutMappings(
    previousSpace: KeyboardShortcut(keyCode: 0x0D, modifiers: [.command, .option]),
    nextSpace: KeyboardShortcut(keyCode: 0x0E, modifiers: [.shift, .control])
)
