import Foundation

/// What the controller asks the event boundary to build: one phase of a
/// shortcut pair with the configured key code and modifiers.
public struct KeyEventSpec: Hashable, Sendable {
    public let phase: KeyEventPhase
    public let shortcut: KeyboardShortcut

    public init(phase: KeyEventPhase, shortcut: KeyboardShortcut) {
        self.phase = phase
        self.shortcut = shortcut
    }
}

/// Constructs and posts keyboard events. The production adapter (app target)
/// wraps CoreGraphics; tests use a recording double.
///
/// Both methods run synchronously on the main actor. `post` cannot fail: the
/// controller constructs the whole pair first, and "posted" means only that
/// the events were handed to this boundary.
@MainActor
public protocol KeyEventBoundary {
    associatedtype Event

    /// Builds the event for `spec`. Throw when the platform cannot create it.
    func makeEvent(_ spec: KeyEventSpec) throws -> Event

    /// Hands a previously constructed event to the platform.
    func post(_ event: Event)
}

/// Reports whether the process may post keyboard events right now. The
/// controller calls this immediately before each action; it never caches the
/// answer and never requests access itself.
@MainActor
public protocol EventPostingAccess {
    func hasEventPostingAccess() -> Bool
}

/// A moment in time: wall clock for display, monotonic duration for elapsed
/// measurement.
public struct TimeStamp: Hashable, Sendable {
    public let date: Date
    public let monotonic: Duration

    public init(date: Date, monotonic: Duration) {
        self.date = date
        self.monotonic = monotonic
    }
}

/// Supplies timestamps to the controller so tests can control elapsed time.
@MainActor
public protocol TimeSource {
    func now() -> TimeStamp
}

/// Production time source: `Date()` plus `ContinuousClock` since creation.
public struct SystemTimeSource: TimeSource {
    private let reference = ContinuousClock.now

    public init() {}

    public func now() -> TimeStamp {
        TimeStamp(date: Date(), monotonic: reference.duration(to: .now))
    }
}
