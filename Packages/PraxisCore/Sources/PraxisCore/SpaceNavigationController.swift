/// Turns a Space-navigation intent into at most one attempted keyboard
/// shortcut, guarded by the Space-navigation contract.
///
/// Ownership: this type holds the execution enable flag, the shortcut
/// mappings and their session confirmation, the in-progress flag, and the
/// bounded result history. The app wraps it for display and supplies the
/// platform boundaries; the app does not re-implement any guard.
///
/// Concurrency and serialization: the controller is main-actor isolated and
/// `perform(_:)` is synchronous. It never suspends, so under normal use two
/// requests cannot interleave; the main actor serializes them. The
/// `isActionInProgress` guard covers the one way a request can still arrive
/// mid-pair: re-entrancy from inside the event boundary's `post` (or from any
/// code it calls). Blocked requests are recorded and dropped, never queued.
@MainActor
public final class SpaceNavigationController<Events: KeyEventBoundary> {
    public static var defaultHistoryCapacity: Int { 50 }

    private let events: Events
    private let access: any EventPostingAccess
    private let time: any TimeSource
    private var nextRequestID: UInt64 = 1

    /// Execution starts disabled on every launch.
    public private(set) var isExecutionEnabled = false

    /// Shortcut mappings shown to and edited by the user.
    public private(set) var mappings: ShortcutMappings

    /// Whether the user confirmed, this session, that `mappings` match the
    /// enabled Mission Control shortcuts. Starts false; reset when mappings change.
    public private(set) var areShortcutsConfirmed = false

    /// True only while a pair is being constructed and posted.
    public private(set) var isActionInProgress = false

    /// Record history ordered by completion (newest last), bounded to
    /// `defaultHistoryCapacity` by default. Under re-entrancy a blocked inner
    /// request completes, and is recorded, before the outer pair finishes.
    public private(set) var history: BoundedHistory<ActionRecord>

    public var latestRecord: ActionRecord? { history.latest }

    public init(
        events: Events,
        access: any EventPostingAccess,
        time: any TimeSource,
        mappings: ShortcutMappings = .proposedDefaults,
        historyCapacity: Int = SpaceNavigationController.defaultHistoryCapacity
    ) {
        self.events = events
        self.access = access
        self.time = time
        self.mappings = mappings
        self.history = BoundedHistory(capacity: historyCapacity)
    }

    // MARK: Configuration

    public func setExecutionEnabled(_ enabled: Bool) {
        isExecutionEnabled = enabled
    }

    /// Replaces the mappings. A change to either shortcut invalidates the
    /// session confirmation; assigning identical mappings does not.
    public func updateMappings(_ newMappings: ShortcutMappings) {
        guard newMappings != mappings else { return }
        mappings = newMappings
        areShortcutsConfirmed = false
    }

    /// The user asserts that the current mappings match the system shortcuts.
    public func confirmShortcuts() {
        areShortcutsConfirmed = true
    }

    // MARK: Requests

    /// Handles one navigation request and returns its record. Every request
    /// yields exactly one record; eligible requests post exactly one
    /// key-down/key-up pair or nothing.
    @discardableResult
    public func perform(_ intent: DesktopIntent) -> ActionRecord {
        let started = time.now()
        let id = RequestID(rawValue: nextRequestID)
        nextRequestID += 1

        func finish(_ outcome: ActionOutcome) -> ActionRecord {
            let record = ActionRecord(
                id: id,
                intent: intent,
                timestamp: started.date,
                elapsed: time.now().monotonic - started.monotonic,
                outcome: outcome
            )
            history.append(record)
            return record
        }

        if isActionInProgress { return finish(.blocked(.actionInProgress)) }
        if !isExecutionEnabled { return finish(.blocked(.executionDisabled)) }
        if !areShortcutsConfirmed { return finish(.blocked(.shortcutsUnconfirmed)) }
        if !access.hasEventPostingAccess() { return finish(.blocked(.eventPostingAccessUnavailable)) }

        isActionInProgress = true
        defer { isActionInProgress = false }

        let shortcut = mappings[intent]
        let keyDown: Events.Event
        let keyUp: Events.Event
        do {
            keyDown = try events.makeEvent(KeyEventSpec(phase: .keyDown, shortcut: shortcut))
        } catch {
            return finish(.failed(.eventConstructionFailed(phase: .keyDown, detail: "\(error)")))
        }
        do {
            keyUp = try events.makeEvent(KeyEventSpec(phase: .keyUp, shortcut: shortcut))
        } catch {
            return finish(.failed(.eventConstructionFailed(phase: .keyUp, detail: "\(error)")))
        }

        // Both events exist; the pair is now committed and completes even if
        // enablement or access changes while posting.
        events.post(keyDown)
        events.post(keyUp)
        return finish(.posted)
    }
}
