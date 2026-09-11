/// Modifier keys held while a navigation key is pressed.
///
/// Pure value type; the adapter maps it to platform event flags.
public struct KeyModifiers: OptionSet, Hashable, Sendable, Codable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = KeyModifiers(rawValue: 1 << 0)
    public static let option = KeyModifiers(rawValue: 1 << 1)
    public static let shift = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)
}

/// One keyboard shortcut: a macOS virtual key code plus modifiers.
public struct KeyboardShortcut: Hashable, Sendable, Codable {
    /// macOS virtual key code (the values Carbon names `kVK_*`), for example
    /// 0x7B for Left Arrow and 0x7C for Right Arrow.
    public var keyCode: UInt16
    public var modifiers: KeyModifiers

    public init(keyCode: UInt16, modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// The shortcut configured for each navigation intent.
public struct ShortcutMappings: Hashable, Sendable, Codable {
    public var previousSpace: KeyboardShortcut
    public var nextSpace: KeyboardShortcut

    public init(previousSpace: KeyboardShortcut, nextSpace: KeyboardShortcut) {
        self.previousSpace = previousSpace
        self.nextSpace = nextSpace
    }

    /// Apple's documented default Mission Control shortcuts, Control–Left and
    /// Control–Right. These are a proposal to show the user; they must be
    /// confirmed against the enabled system shortcuts before execution.
    public static let proposedDefaults = ShortcutMappings(
        previousSpace: KeyboardShortcut(keyCode: 0x7B, modifiers: .control),
        nextSpace: KeyboardShortcut(keyCode: 0x7C, modifiers: .control)
    )

    public subscript(intent: DesktopIntent) -> KeyboardShortcut {
        get {
            switch intent {
            case .previousSpace: previousSpace
            case .nextSpace: nextSpace
            }
        }
        set {
            switch intent {
            case .previousSpace: previousSpace = newValue
            case .nextSpace: nextSpace = newValue
            }
        }
    }
}
