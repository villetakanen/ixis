/// A semantic request for a desktop action.
///
/// Intents sit between a recognized input (a button today, a gesture later)
/// and an attempted macOS action. They carry no key codes, modifiers, or
/// platform objects; an adapter maps them to actual actions.
public enum DesktopIntent: String, CaseIterable, Codable, Hashable, Sendable {
    case previousSpace
    case nextSpace

    /// User-facing label for debug UI and records.
    public var displayName: String {
        switch self {
        case .previousSpace: "Previous Space"
        case .nextSpace: "Next Space"
        }
    }
}
