import Testing
@testable import PraxisCore

// Scenario IDs refer to specs/space-navigation/spec.md.

@MainActor
@Suite("SN-001 launch state")
struct LaunchStateTests {
    @Test("a new controller is disabled, unconfirmed, idle, and has no history")
    func freshState() {
        let h = Harness()
        #expect(h.controller.isExecutionEnabled == false)
        #expect(h.controller.areShortcutsConfirmed == false)
        #expect(h.controller.isActionInProgress == false)
        #expect(h.controller.history.isEmpty)
        #expect(h.controller.latestRecord == nil)
        #expect(h.controller.mappings == .proposedDefaults)
    }

    @Test("relaunch resets enablement and confirmation even after an enabled session")
    func relaunchResets() {
        let first = Harness()
        first.makeEligible()
        first.controller.perform(.nextSpace)
        #expect(first.controller.latestRecord?.outcome == .posted)

        // A relaunch is a new controller; nothing about enablement or
        // confirmation is carried over, only the mappings the app chooses to pass.
        let relaunched = Harness(mappings: first.controller.mappings)
        #expect(relaunched.controller.isExecutionEnabled == false)
        #expect(relaunched.controller.areShortcutsConfirmed == false)
        #expect(relaunched.controller.perform(.nextSpace).outcome == .blocked(.executionDisabled))
        #expect(relaunched.events.posted.isEmpty)
    }
}

@MainActor
@Suite("SN-002 disabled or unconfirmed")
struct DisabledOrUnconfirmedTests {
    @Test("disabled execution blocks with its own reason and posts nothing, even when confirmed")
    func disabledBlocks() {
        let h = Harness()
        h.controller.confirmShortcuts()
        let record = h.controller.perform(.previousSpace)
        #expect(record.outcome == .blocked(.executionDisabled))
        #expect(record.intent == .previousSpace)
        #expect(h.events.constructed.isEmpty)
        #expect(h.events.posted.isEmpty)
        #expect(h.access.checkCount == 0)
    }

    @Test("unconfirmed shortcuts block with their own reason and post nothing, even when enabled")
    func unconfirmedBlocks() {
        let h = Harness()
        h.controller.setExecutionEnabled(true)
        let record = h.controller.perform(.nextSpace)
        #expect(record.outcome == .blocked(.shortcutsUnconfirmed))
        #expect(h.events.constructed.isEmpty)
        #expect(h.events.posted.isEmpty)
        #expect(h.access.checkCount == 0)
    }

    @Test("enabling or confirming afterwards does not replay the blocked request")
    func noReplayAfterEnabling() {
        let h = Harness()
        h.controller.perform(.nextSpace)
        h.controller.perform(.previousSpace)
        h.makeEligible()
        #expect(h.events.posted.isEmpty)
        #expect(h.controller.history.count == 2)
        #expect(h.controller.history.oldestFirst.allSatisfy { !$0.outcome.isPosted })
    }

    @Test("changing either shortcut invalidates confirmation; identical mappings do not")
    func mappingChangeInvalidatesConfirmation() {
        let h = Harness()
        h.makeEligible()
        h.controller.updateMappings(.proposedDefaults)
        #expect(h.controller.areShortcutsConfirmed, "unchanged mappings keep confirmation")

        var changedNext = ShortcutMappings.proposedDefaults
        changedNext.nextSpace = unusualMappings.nextSpace
        h.controller.updateMappings(changedNext)
        #expect(h.controller.areShortcutsConfirmed == false)
        #expect(h.controller.mappings == changedNext)
        #expect(h.controller.perform(.previousSpace).outcome == .blocked(.shortcutsUnconfirmed))

        h.controller.confirmShortcuts()
        var modifierOnly = changedNext
        modifierOnly.nextSpace.modifiers = [.option]
        h.controller.updateMappings(modifierOnly)
        #expect(h.controller.areShortcutsConfirmed == false, "a modifier-only change is a change")

        h.controller.confirmShortcuts()
        var changedPrevious = modifierOnly
        changedPrevious.previousSpace = unusualMappings.previousSpace
        h.controller.updateMappings(changedPrevious)
        #expect(h.controller.areShortcutsConfirmed == false)
        #expect(h.controller.perform(.nextSpace).outcome == .blocked(.shortcutsUnconfirmed))
        #expect(h.events.posted.isEmpty)
    }
}

@MainActor
@Suite("SN-003 access unavailable or revoked")
struct AccessTests {
    @Test("unavailable access blocks visibly and constructs nothing")
    func unavailableBlocks() {
        let h = Harness(accessGranted: false)
        h.makeEligible()
        let record = h.controller.perform(.nextSpace)
        #expect(record.outcome == .blocked(.eventPostingAccessUnavailable))
        #expect(h.access.checkCount == 1)
        #expect(h.events.constructed.isEmpty)
        #expect(h.events.posted.isEmpty)
    }

    @Test("access is checked fresh for every eligible request; an earlier grant does not carry over")
    func revocationAfterEarlierGrant() {
        let h = Harness()
        h.makeEligible()
        #expect(h.controller.perform(.nextSpace).outcome == .posted)
        h.access.granted = false
        let blocked = h.controller.perform(.nextSpace)
        #expect(blocked.outcome == .blocked(.eventPostingAccessUnavailable))
        #expect(h.access.checkCount == 2)
        #expect(h.events.posted.count == 2, "only the first request's pair was posted")
    }

    @Test("a blocked request does not retry on its own; a later revoked check is not re-polled")
    func noAutomaticRetry() {
        let h = Harness(accessGranted: false)
        h.makeEligible()
        h.controller.perform(.previousSpace)
        h.access.granted = true
        #expect(h.access.checkCount == 1)
        #expect(h.events.posted.isEmpty)
    }
}

@MainActor
@Suite("SN-004 recover without replay")
struct RecoveryTests {
    @Test("resolving each blocking condition posts nothing until a fresh request")
    func resolveThenFreshRequest() {
        let h = Harness(accessGranted: false)

        h.controller.perform(.nextSpace)                       // blocked: disabled
        h.controller.setExecutionEnabled(true)
        #expect(h.events.posted.isEmpty)

        h.controller.perform(.nextSpace)                       // blocked: unconfirmed
        h.controller.confirmShortcuts()
        #expect(h.events.posted.isEmpty)

        h.controller.perform(.nextSpace)                       // blocked: access
        h.access.granted = true
        #expect(h.events.posted.isEmpty)

        let fresh = h.controller.perform(.nextSpace)
        #expect(fresh.outcome == .posted)
        #expect(h.events.posted.count == 2)
        #expect(h.controller.history.count == 4)
    }

    @Test("a fresh request is checked against all current conditions, not the one that was resolved")
    func freshRequestRechecksEverything() {
        let h = Harness(accessGranted: false)
        h.controller.perform(.previousSpace)                   // blocked: disabled
        h.controller.setExecutionEnabled(true)
        let next = h.controller.perform(.previousSpace)
        #expect(next.outcome == .blocked(.shortcutsUnconfirmed))
        h.controller.confirmShortcuts()
        let third = h.controller.perform(.previousSpace)
        #expect(third.outcome == .blocked(.eventPostingAccessUnavailable))
        #expect(h.events.posted.isEmpty)
    }
}

@MainActor
@Suite("SN-005 route direction and construct events")
struct RoutingTests {
    @Test("each direction posts exactly one key-down then key-up with its configured shortcut",
          arguments: [ShortcutMappings.proposedDefaults, unusualMappings])
    func routesPerMapping(mappings: ShortcutMappings) {
        for intent in DesktopIntent.allCases {
            let h = Harness(mappings: mappings)
            h.makeEligible()
            let record = h.controller.perform(intent)
            #expect(record.outcome == .posted)
            #expect(record.intent == intent)
            let expected = mappings[intent]
            #expect(h.events.posted == [
                KeyEventSpec(phase: .keyDown, shortcut: expected),
                KeyEventSpec(phase: .keyUp, shortcut: expected),
            ])
            #expect(h.events.constructed == h.events.posted)
        }
    }

    @Test("direction is not hard-coded: swapping the mapping swaps the posted key")
    func swappedMappingFollowsConfiguration() {
        let swapped = ShortcutMappings(
            previousSpace: ShortcutMappings.proposedDefaults.nextSpace,
            nextSpace: ShortcutMappings.proposedDefaults.previousSpace
        )
        let h = Harness(mappings: swapped)
        h.makeEligible()
        h.controller.perform(.previousSpace)
        #expect(h.events.posted.map(\.shortcut.keyCode) == [0x7C, 0x7C])
        #expect(h.controller.isActionInProgress == false)
    }
}

@MainActor
@Suite("SN-006 construction failure")
struct ConstructionFailureTests {
    @Test("failure at either construction step yields failed with that step and posts nothing",
          arguments: KeyEventPhase.allCases)
    func failsAtomically(phase: KeyEventPhase) {
        let h = Harness()
        h.makeEligible()
        h.events.failingPhases = [phase]
        let record = h.controller.perform(.nextSpace)
        guard case .failed(.eventConstructionFailed(let failedPhase, let detail)) = record.outcome else {
            Issue.record("expected failed outcome, got \(record.outcome)")
            return
        }
        #expect(failedPhase == phase)
        #expect(detail.contains("injected"))
        #expect(h.events.posted.isEmpty, "nothing is posted when any event of the pair is missing")
        #expect(h.controller.isActionInProgress == false)
        // Key-down failure stops before key-up construction; key-up failure
        // means key-down was built but never posted.
        #expect(h.events.constructed.count == (phase == .keyDown ? 1 : 2))
    }

    @Test("a later request after a failure is handled fresh")
    func recoversAfterFailure() {
        let h = Harness()
        h.makeEligible()
        h.events.failingPhases = [.keyUp]
        h.controller.perform(.nextSpace)
        h.events.failingPhases = []
        #expect(h.controller.perform(.nextSpace).outcome == .posted)
        #expect(h.events.posted.count == 2)
    }
}

@MainActor
@Suite("SN-007 no deferred or interrupted pair")
struct SerializationTests {
    // The controller is synchronous on the main actor, so the only way a
    // request can arrive mid-pair is re-entrantly from inside the boundary's
    // `post`. The recording boundary's `onPost` hook is that entry point.

    @Test("a request arriving between key-down and key-up is blocked and never replayed")
    func overlappingRequestIsBlocked() {
        let h = Harness()
        h.makeEligible()
        var inner: ActionRecord?
        h.events.onPost = { spec in
            guard spec.phase == .keyDown, inner == nil else { return }
            #expect(h.controller.isActionInProgress)
            inner = h.controller.perform(.previousSpace)
        }
        let outer = h.controller.perform(.nextSpace)

        #expect(outer.outcome == .posted)
        #expect(inner?.outcome == .blocked(.actionInProgress))
        #expect(inner?.intent == .previousSpace)
        #expect(h.events.posted.map(\.phase) == [.keyDown, .keyUp])
        #expect(h.events.posted.allSatisfy { $0.shortcut == ShortcutMappings.proposedDefaults.nextSpace })
        #expect(h.controller.isActionInProgress == false)

        // Nothing deferred: the next fresh request posts exactly one more pair.
        h.events.onPost = nil
        h.controller.perform(.nextSpace)
        #expect(h.events.posted.count == 4)
        // History is ordered by completion: the blocked inner request (#2)
        // finished before the outer pair (#1) did.
        #expect(h.controller.history.oldestFirst.map(\.id.rawValue) == [2, 1, 3])
    }

    @Test("disabling execution after key-down still posts the matching key-up; later requests post nothing")
    func disableMidPairCompletesPair() {
        let h = Harness()
        h.makeEligible()
        h.events.onPost = { spec in
            if spec.phase == .keyDown { h.controller.setExecutionEnabled(false) }
        }
        let record = h.controller.perform(.nextSpace)
        #expect(record.outcome == .posted)
        #expect(h.events.posted.map(\.phase) == [.keyDown, .keyUp])

        let after = h.controller.perform(.nextSpace)
        #expect(after.outcome == .blocked(.executionDisabled))
        #expect(h.events.posted.count == 2)
    }

    @Test("revoking access after key-down still completes the pair")
    func revokeMidPairCompletesPair() {
        let h = Harness()
        h.makeEligible()
        h.events.onPost = { spec in
            if spec.phase == .keyDown { h.access.granted = false }
        }
        #expect(h.controller.perform(.previousSpace).outcome == .posted)
        #expect(h.events.posted.map(\.phase) == [.keyDown, .keyUp])
        #expect(h.controller.perform(.previousSpace).outcome == .blocked(.eventPostingAccessUnavailable))
        #expect(h.events.posted.count == 2)
    }
}

@MainActor
@Suite("SN-008 honest and bounded diagnostics")
struct DiagnosticsTests {
    @Test("every record carries direction, outcome, and processing duration from the injected clock")
    func recordContents() {
        let h = Harness()
        h.makeEligible()
        h.events.onPost = { spec in
            if spec.phase == .keyDown { h.time.advance(by: .milliseconds(7)) }
        }
        let start = h.time.current.date
        let record = h.controller.perform(.previousSpace)
        #expect(record.id == RequestID(rawValue: 1))
        #expect(record.intent == .previousSpace)
        #expect(record.timestamp == start)
        #expect(record.elapsed == .milliseconds(7))
        #expect(record.outcome == .posted)
        #expect(h.controller.latestRecord == record)
    }

    @Test("blocked records report zero elapsed when the clock does not move, and expose a recovery action")
    func blockedRecordTiming() {
        let h = Harness()
        let record = h.controller.perform(.nextSpace)
        #expect(record.elapsed == .zero)
        guard case .blocked(let reason) = record.outcome else {
            Issue.record("expected blocked"); return
        }
        #expect(!reason.recoveryAction.isEmpty)
    }

    @Test("request identifiers increase across all outcomes")
    func identifiersIncrease() {
        let h = Harness()
        let a = h.controller.perform(.nextSpace)
        h.makeEligible()
        let b = h.controller.perform(.nextSpace)
        h.events.failingPhases = [.keyDown]
        let c = h.controller.perform(.nextSpace)
        #expect([a.id, b.id, c.id].map(\.rawValue) == [1, 2, 3])
        #expect(a.outcome == .blocked(.executionDisabled))
        #expect(b.outcome == .posted)
        guard case .failed(.eventConstructionFailed(phase: .keyDown, _)) = c.outcome else {
            Issue.record("expected key-down construction failure, got \(c.outcome)"); return
        }
    }

    @Test("after 51 requests only the newest 50 records remain")
    func historyIsBounded() {
        let h = Harness()
        h.makeEligible()
        for _ in 1...51 { h.controller.perform(.nextSpace) }
        #expect(h.controller.history.count == 50)
        #expect(h.controller.history.oldestFirst.first?.id == RequestID(rawValue: 2))
        #expect(h.controller.latestRecord?.id == RequestID(rawValue: 51))
        #expect(h.events.posted.count == 102)
    }
}
