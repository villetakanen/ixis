import Foundation

/// Identifies one navigation request within a controller's lifetime.
public struct RequestID: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static func < (lhs: RequestID, rhs: RequestID) -> Bool { lhs.rawValue < rhs.rawValue }
    public var description: String { "#\(rawValue)" }
}

/// Why a request was blocked before anything was posted.
public enum BlockReason: Hashable, Sendable {
    case executionDisabled
    case shortcutsUnconfirmed
    case eventPostingAccessUnavailable
    case actionInProgress

    /// What the user can do about it. Wording for the debug view.
    public var recoveryAction: String {
        switch self {
        case .executionDisabled:
            "Turn on execution, then request again."
        case .shortcutsUnconfirmed:
            "Confirm that the mappings match the enabled Mission Control shortcuts, then request again."
        case .eventPostingAccessUnavailable:
            "Grant event-posting access in System Settings, recheck access, then request again."
        case .actionInProgress:
            "Wait for the current action to finish, then request again."
        }
    }
}

/// Which event of the pair the controller was constructing.
public enum KeyEventPhase: Hashable, Sendable, CaseIterable {
    case keyDown
    case keyUp
}

/// Why an eligible request failed. Nothing was posted.
public enum FailureReason: Hashable, Sendable {
    /// The boundary could not construct the event for `phase`.
    case eventConstructionFailed(phase: KeyEventPhase, detail: String)

    public var recoveryAction: String {
        switch self {
        case .eventConstructionFailed:
            "Check the mapping's key code and modifiers, then request again."
        }
    }
}

/// The result of one navigation request.
public enum ActionOutcome: Hashable, Sendable {
    /// Eligibility failed; zero events were posted.
    case blocked(BlockReason)
    /// Construction failed; zero events were posted.
    case failed(FailureReason)
    /// One key-down/key-up pair was handed to the posting boundary. This is
    /// not an acknowledgement that the Space changed.
    case posted

    /// Short label for the debug view. Never claims a Space transition.
    public var summary: String {
        switch self {
        case .blocked: "Blocked"
        case .failed: "Failed"
        case .posted: "Shortcut posted"
        }
    }

    public var isPosted: Bool {
        if case .posted = self { return true }
        return false
    }
}

/// One entry in the bounded result history.
public struct ActionRecord: Hashable, Sendable {
    public let id: RequestID
    public let intent: DesktopIntent
    /// Wall-clock time the request was received.
    public let timestamp: Date
    /// Praxis processing time from request to result. Excludes any macOS
    /// transition.
    public let elapsed: Duration
    public let outcome: ActionOutcome

    public init(id: RequestID, intent: DesktopIntent, timestamp: Date, elapsed: Duration, outcome: ActionOutcome) {
        self.id = id
        self.intent = intent
        self.timestamp = timestamp
        self.elapsed = elapsed
        self.outcome = outcome
    }
}
