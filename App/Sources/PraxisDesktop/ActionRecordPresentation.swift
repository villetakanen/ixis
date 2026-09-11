import Foundation
import PraxisCore

/// User-facing wording for one record. Describes evidence at its actual
/// level: a posted shortcut is not a Space transition.
public struct ActionRecordPresentation: Hashable, Sendable {
    public let record: ActionRecord

    public init(_ record: ActionRecord) {
        self.record = record
    }

    public var idText: String { record.id.description }
    public var directionText: String { record.intent.displayName }

    /// "Blocked", "Failed", or "Shortcut posted".
    public var outcomeText: String { record.outcome.summary }

    /// Why the request did not post, or what "posted" means. Never empty.
    public var reasonText: String {
        switch record.outcome {
        case .blocked(let reason):
            switch reason {
            case .executionDisabled: "Execution is off."
            case .shortcutsUnconfirmed: "Shortcut mappings are not confirmed for this session."
            case .eventPostingAccessUnavailable: "Event-posting access was unavailable at the time of the request."
            case .actionInProgress: "Another action was still in progress."
            }
        case .failed(.eventConstructionFailed(let phase, let detail)):
            "Could not construct the \(phase == .keyDown ? "key-down" : "key-up") event: \(detail)"
        case .posted:
            "One key-down/key-up pair was handed to macOS. Praxis does not observe whether a Space transition followed."
        }
    }

    /// Recovery action for blocked/failed outcomes; `nil` when posted.
    public var recoveryText: String? {
        switch record.outcome {
        case .blocked(let reason): reason.recoveryAction
        case .failed(let reason): reason.recoveryAction
        case .posted: nil
        }
    }

    /// Praxis processing time, intent to result, formatted in milliseconds.
    public var elapsedText: String {
        let millis = Double(record.elapsed.components.seconds) * 1000
            + Double(record.elapsed.components.attoseconds) / 1e15
        return String(format: "%.2f ms", millis)
    }

    public var timestampText: String {
        record.timestamp.formatted(date: .omitted, time: .standard)
    }

    /// Single-line summary used by the latest-result panel.
    public var headline: String {
        "\(directionText): \(outcomeText)"
    }
}
