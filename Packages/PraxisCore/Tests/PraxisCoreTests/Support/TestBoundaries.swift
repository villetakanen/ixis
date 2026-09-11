import Foundation
import PraxisCore

struct ConstructionError: Error, CustomStringConvertible {
    let phase: KeyEventPhase
    var description: String { "injected \(phase) construction failure" }
}

/// Recording, controllable event boundary. Records every construction and
/// post, fails construction for chosen phases, and runs `onPost` synchronously
/// from inside `post` so tests can act between key-down and key-up.
@MainActor
final class RecordingKeyEventBoundary: KeyEventBoundary {
    struct Event: Hashable {
        let spec: KeyEventSpec
    }

    var failingPhases: Set<KeyEventPhase> = []
    private(set) var constructed: [KeyEventSpec] = []
    private(set) var posted: [KeyEventSpec] = []
    var onPost: ((KeyEventSpec) -> Void)?

    func makeEvent(_ spec: KeyEventSpec) throws -> Event {
        constructed.append(spec)
        if failingPhases.contains(spec.phase) {
            throw ConstructionError(phase: spec.phase)
        }
        return Event(spec: spec)
    }

    func post(_ event: Event) {
        posted.append(event.spec)
        onPost?(event.spec)
    }
}

/// Scripted access check that counts how often it is consulted.
@MainActor
final class ScriptedAccess: EventPostingAccess {
    var granted: Bool
    private(set) var checkCount = 0

    init(granted: Bool) { self.granted = granted }

    func hasEventPostingAccess() -> Bool {
        checkCount += 1
        return granted
    }
}

/// Manual clock. `advance` moves both the wall clock and the monotonic value.
@MainActor
final class ManualTimeSource: TimeSource {
    private(set) var current: TimeStamp

    init(start: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        current = TimeStamp(date: start, monotonic: .zero)
    }

    func advance(by duration: Duration) {
        let seconds = Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1e18
        current = TimeStamp(
            date: current.date.addingTimeInterval(seconds),
            monotonic: current.monotonic + duration
        )
    }

    func now() -> TimeStamp { current }
}

/// A controller with fresh doubles, wired the way tests need it.
@MainActor
struct Harness {
    let events = RecordingKeyEventBoundary()
    let access: ScriptedAccess
    let time = ManualTimeSource()
    let controller: SpaceNavigationController<RecordingKeyEventBoundary>

    init(
        mappings: ShortcutMappings = .proposedDefaults,
        accessGranted: Bool = true,
        historyCapacity: Int = SpaceNavigationController<RecordingKeyEventBoundary>.defaultHistoryCapacity
    ) {
        access = ScriptedAccess(granted: accessGranted)
        controller = SpaceNavigationController(
            events: events,
            access: access,
            time: time,
            mappings: mappings,
            historyCapacity: historyCapacity
        )
    }

    /// Enables execution and confirms shortcuts so requests are eligible.
    func makeEligible() {
        controller.setExecutionEnabled(true)
        controller.confirmShortcuts()
    }
}

/// A mapping that shares nothing with the proposed defaults.
let unusualMappings = ShortcutMappings(
    previousSpace: KeyboardShortcut(keyCode: 0x0D, modifiers: [.command, .option]),
    nextSpace: KeyboardShortcut(keyCode: 0x0E, modifiers: [.shift, .control])
)
