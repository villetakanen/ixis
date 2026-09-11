import PraxisCore

/// Text representation of a key code in the mapping editor: hexadecimal with
/// a `0x` prefix, as Apple's `kVK_*` constants are usually quoted. Decimal
/// input is accepted too.
public enum KeyCodeField {
    /// Renders a key code the way the editor shows it, for example `0x7B`.
    public static func text(for keyCode: UInt16) -> String {
        "0x" + String(keyCode, radix: 16, uppercase: true).leftPadded(to: 2)
    }

    /// Parses the editor text. Returns `nil` for empty, malformed, or
    /// out-of-range input so the caller can keep the last valid mapping.
    public static func parse(_ text: String) -> UInt16? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("0x") {
            let digits = lowered.dropFirst(2)
            guard !digits.isEmpty else { return nil }
            return UInt16(digits, radix: 16)
        }
        return UInt16(trimmed, radix: 10)
    }
}

private extension String {
    func leftPadded(to width: Int, with pad: Character = "0") -> String {
        count >= width ? self : String(repeating: pad, count: width - count) + self
    }
}

extension KeyModifiers {
    /// Modifier order used in labels: Control, Option, Shift, Command.
    public static let displayOrder: [(KeyModifiers, String, String)] = [
        (.control, "Control", "⌃"),
        (.option, "Option", "⌥"),
        (.shift, "Shift", "⇧"),
        (.command, "Command", "⌘"),
    ]

    /// Symbols for the set modifiers, for example `⌃⇧`; empty for none.
    public var symbols: String {
        Self.displayOrder.filter { contains($0.0) }.map(\.2).joined()
    }
}

extension KeyboardShortcut {
    /// Compact label such as `⌃ 0x7B`, or `0x24 (no modifiers)`.
    public var displayText: String {
        let key = KeyCodeField.text(for: keyCode)
        return modifiers.isEmpty ? "\(key) (no modifiers)" : "\(modifiers.symbols) \(key)"
    }
}
