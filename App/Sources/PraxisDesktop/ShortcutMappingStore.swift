import Foundation
import PraxisCore

/// Persists the shortcut mappings between launches. Confirmation and
/// enablement are never stored; they reset on every launch by contract.
@MainActor
public protocol ShortcutMappingStore {
    func loadMappings() -> ShortcutMappings?
    func saveMappings(_ mappings: ShortcutMappings)
}

/// The two `UserDefaults` operations the store needs. Lets tests run the
/// store against a dictionary; `UserDefaults(suiteName:)` leaves preference
/// files behind even after `removePersistentDomain`, so tests avoid it.
public protocol KeyedDataStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: KeyedDataStore {}

/// `UserDefaults`-backed store. Unreadable or undecodable data is treated as
/// absent so a corrupt value falls back to the proposed defaults.
@MainActor
public final class UserDefaultsMappingStore: ShortcutMappingStore {
    public static let key = "praxis.spaceNavigation.shortcutMappings"

    private let defaults: any KeyedDataStore

    public init(defaults: any KeyedDataStore = UserDefaults.standard) {
        self.defaults = defaults
    }

    public func loadMappings() -> ShortcutMappings? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(ShortcutMappings.self, from: data)
    }

    public func saveMappings(_ mappings: ShortcutMappings) {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

/// In-memory store for tests and for running without persistence.
@MainActor
public final class MemoryMappingStore: ShortcutMappingStore {
    public private(set) var stored: ShortcutMappings?
    public private(set) var saveCount = 0

    public init(stored: ShortcutMappings? = nil) {
        self.stored = stored
    }

    public func loadMappings() -> ShortcutMappings? { stored }

    public func saveMappings(_ mappings: ShortcutMappings) {
        stored = mappings
        saveCount += 1
    }
}
