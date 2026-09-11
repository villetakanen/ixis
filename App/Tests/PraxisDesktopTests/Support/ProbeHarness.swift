import CoreGraphics
import Foundation
import PraxisCore
@testable import PraxisDesktop

/// Access double that also implements the explicit request action.
@MainActor
final class ScriptedSetupAccess: EventPostingSetup {
    var granted: Bool
    var grantOnRequest = false
    private(set) var preflightCount = 0
    private(set) var requestCount = 0

    init(granted: Bool) { self.granted = granted }

    func hasEventPostingAccess() -> Bool {
        preflightCount += 1
        return granted
    }

    func requestEventPostingAccess() -> Bool {
        requestCount += 1
        if grantOnRequest { granted = true }
        return granted
    }
}

/// A probe over the production `CGKeyEventBoundary` with a recording poster:
/// real event construction, no live posting, scripted access, in-memory store.
@MainActor
struct ProbeHarness {
    let recorder = RecordingPoster()
    let access: ScriptedSetupAccess
    let store: MemoryMappingStore
    let probe: SpaceNavigationProbe<CGKeyEventBoundary>

    init(accessGranted: Bool = true, store: MemoryMappingStore = MemoryMappingStore(), checkAccessOnLaunch: Bool = true) {
        access = ScriptedSetupAccess(granted: accessGranted)
        self.store = store
        probe = SpaceNavigationProbe(
            events: recorder.makeBoundary(),
            access: access,
            store: store,
            checkAccessOnLaunch: checkAccessOnLaunch
        )
    }

    /// Enables execution and confirms shortcuts so requests are eligible.
    func makeEligible() {
        probe.setExecutionEnabled(true)
        probe.confirmShortcuts()
    }

    var postedKeyCodes: [UInt16] { recorder.posted.map(\.event.keyCode) }
}
