import CoreGraphics
import PraxisCore

/// Thrown when CoreGraphics cannot create the requested keyboard event.
public struct KeyEventConstructionError: Error, CustomStringConvertible, Sendable {
    public enum Reason: Sendable {
        case allocationFailed
        case unexpectedEventType(UInt32)
    }

    public let spec: KeyEventSpec
    public let reason: Reason
    public var description: String {
        let key = "keyCode 0x\(String(spec.shortcut.keyCode, radix: 16))"
        switch reason {
        case .allocationFailed:
            return "CGEvent(keyboardEventSource:virtualKey:keyDown:) returned nil for \(spec.phase) \(key)"
        case .unexpectedEventType(let type):
            return "Cannot use \(key) as the shortcut's main key: CoreGraphics produced event type \(type) instead of \(spec.phase). Choose a non-modifier key."
        }
    }
}

/// Production `KeyEventBoundary` built on public CoreGraphics APIs.
///
/// Construction creates a real `CGEvent` for one phase of the pair and sets
/// exactly the configured modifier flags. Posting hands the event to `poster`,
/// which defaults to `CGEvent.post(tap:)`. Tests inject a recording poster, so
/// they exercise real construction while never posting live input.
///
/// Decisions pending hardware evidence (SN-009 to SN-011), see ARCHITECTURE.md:
/// event source state `.combinedSessionState`, tap location `.cghidEventTap`.
@MainActor
public final class CGKeyEventBoundary: KeyEventBoundary {
    public typealias Event = CGEvent
    public typealias Poster = @MainActor (CGEvent, CGEventTapLocation) -> Void

    public static let defaultTapLocation: CGEventTapLocation = .cghidEventTap
    public static let defaultSourceState: CGEventSourceStateID = .combinedSessionState

    /// The only place in Praxis that posts a keyboard event.
    public static let livePoster: Poster = { event, tap in event.post(tap: tap) }

    public let tapLocation: CGEventTapLocation
    private let source: CGEventSource?
    private let poster: Poster
    private(set) public var postedCount = 0

    /// - Parameters:
    ///   - sourceState: state for the `CGEventSource`; `nil` source is used if
    ///     CoreGraphics cannot create one, which CGEvent accepts.
    ///   - tapLocation: where events are posted.
    ///   - poster: receives constructed events; defaults to live posting.
    public init(
        sourceState: CGEventSourceStateID = CGKeyEventBoundary.defaultSourceState,
        tapLocation: CGEventTapLocation = CGKeyEventBoundary.defaultTapLocation,
        poster: @escaping Poster = CGKeyEventBoundary.livePoster
    ) {
        self.source = CGEventSource(stateID: sourceState)
        self.tapLocation = tapLocation
        self.poster = poster
    }

    public var hasEventSource: Bool { source != nil }

    public func makeEvent(_ spec: KeyEventSpec) throws -> CGEvent {
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: spec.shortcut.keyCode,
            keyDown: spec.phase == .keyDown
        ) else {
            throw KeyEventConstructionError(spec: spec, reason: .allocationFailed)
        }
        let expectedType: CGEventType = spec.phase == .keyDown ? .keyDown : .keyUp
        guard event.type == expectedType else {
            throw KeyEventConstructionError(spec: spec, reason: .unexpectedEventType(event.type.rawValue))
        }
        // Replace, do not merge: the pair carries only the configured modifiers
        // and no standalone modifier events are ever posted.
        event.flags = CGEventFlags(spec.shortcut.modifiers)
        return event
    }

    public func post(_ event: CGEvent) {
        postedCount += 1
        poster(event, tapLocation)
    }
}

extension CGEventFlags {
    /// Maps Praxis modifiers onto CoreGraphics flag bits.
    public init(_ modifiers: KeyModifiers) {
        var flags: CGEventFlags = []
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        self = flags
    }

    /// The four modifier bits Praxis can set.
    public static let praxisModifierMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
}
