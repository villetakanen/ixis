import Foundation
import Observation
import PraxisCore

/// Result of the most recent event-posting access check shown in the UI.
/// Display only: the controller re-checks live before every action.
public enum AccessStatus: Hashable, Sendable {
    case unchecked
    case granted(checkedAt: Date)
    case denied(checkedAt: Date)

    public var isGranted: Bool {
        if case .granted = self { return true }
        return false
    }
}

/// Main-actor app state for the button-driven Space-navigation probe.
///
/// Every navigation request goes through `SpaceNavigationController.perform`;
/// this type adds no eligibility guard of its own and never decides on the controller's
/// behalf. It owns what the contract assigns to the app: the mapping editor's
/// text, mapping persistence across launches, the permission snapshot, the
/// explicit access request, and observable mirrors of controller state for
/// SwiftUI. Enablement and confirmation are never persisted.
@MainActor
@Observable
public final class SpaceNavigationProbe<Events: KeyEventBoundary> {
    public static var historyCapacity: Int { SpaceNavigationController<Events>.defaultHistoryCapacity }

    /// One direction's editor fields.
    public struct MappingDraft: Hashable, Sendable {
        public var keyCodeText: String
        public var modifiers: KeyModifiers

        public init(shortcut: KeyboardShortcut) {
            keyCodeText = KeyCodeField.text(for: shortcut.keyCode)
            modifiers = shortcut.modifiers
        }

        /// The shortcut this draft describes, or `nil` if the key code text
        /// is not a valid key code.
        public var shortcut: KeyboardShortcut? {
            KeyCodeField.parse(keyCodeText).map { KeyboardShortcut(keyCode: $0, modifiers: modifiers) }
        }
    }

    @ObservationIgnored private let controller: SpaceNavigationController<Events>
    @ObservationIgnored private let access: any EventPostingSetup
    @ObservationIgnored private let store: any ShortcutMappingStore
    @ObservationIgnored private let time: any TimeSource

    // Mirrors of controller state, refreshed after every controller call.
    public private(set) var isExecutionEnabled = false
    public private(set) var areShortcutsConfirmed = false
    public private(set) var mappings: ShortcutMappings
    public private(set) var latestRecord: ActionRecord?
    /// Newest first, at most `historyCapacity` entries.
    public private(set) var records: [ActionRecord] = []

    public private(set) var accessStatus: AccessStatus = .unchecked
    public private(set) var accessRequestCount = 0

    /// Editor text per direction. Edits apply to the controller immediately
    /// when they parse; otherwise `mappingError(for:)` explains and the last
    /// valid mapping stays in force.
    public private(set) var drafts: [DesktopIntent: MappingDraft]

    /// - Parameters:
    ///   - events: production or recording event boundary.
    ///   - access: production or scripted access, including the request action.
    ///   - store: where mappings persist between launches.
    ///   - time: clock for the controller's records and the access snapshot.
    ///   - checkAccessOnLaunch: preflight once during init. The preflight
    ///     never prompts; it only fills the status shown before the first
    ///     explicit recheck.
    public init(
        events: Events,
        access: any EventPostingSetup,
        store: any ShortcutMappingStore,
        time: any TimeSource = SystemTimeSource(),
        checkAccessOnLaunch: Bool = true
    ) {
        let initialMappings = store.loadMappings() ?? .proposedDefaults
        self.controller = SpaceNavigationController(
            events: events, access: access, time: time, mappings: initialMappings
        )
        self.access = access
        self.store = store
        self.time = time
        self.mappings = initialMappings
        self.drafts = Dictionary(uniqueKeysWithValues: DesktopIntent.allCases.map {
            ($0, MappingDraft(shortcut: initialMappings[$0]))
        })
        if checkAccessOnLaunch { recheckAccess() }
        refresh()
    }

    // MARK: Navigation

    /// A button activation. Always reaches the controller, whatever the UI
    /// state, so the controller's guard produces the visible reason.
    @discardableResult
    public func request(_ intent: DesktopIntent) -> ActionRecord {
        let record = controller.perform(intent)
        // Keep the displayed access status current with what the controller
        // just saw. Preflight only; never a request.
        recheckAccess()
        refresh()
        return record
    }

    // MARK: Execution and confirmation

    public func setExecutionEnabled(_ enabled: Bool) {
        controller.setExecutionEnabled(enabled)
        refresh()
    }

    /// The user asserts the shown mappings match the enabled Mission Control
    /// shortcuts. Ignored while a draft is invalid, because the shown text
    /// would not describe the mapping in force.
    public func confirmShortcuts() {
        guard !hasInvalidDraft else { return }
        controller.confirmShortcuts()
        refresh()
    }

    // MARK: Mapping editor

    public func draft(for intent: DesktopIntent) -> MappingDraft {
        drafts[intent] ?? MappingDraft(shortcut: mappings[intent])
    }

    public func setKeyCodeText(_ text: String, for intent: DesktopIntent) {
        var draft = draft(for: intent)
        draft.keyCodeText = text
        applyDraft(draft, for: intent)
    }

    /// Ignored while the direction's key code text is invalid: the checkboxes
    /// must keep describing the mapping in force until the key code is fixed.
    public func setModifier(_ modifier: KeyModifiers, enabled: Bool, for intent: DesktopIntent) {
        var draft = draft(for: intent)
        guard draft.shortcut != nil else { return }
        if enabled { draft.modifiers.insert(modifier) } else { draft.modifiers.remove(modifier) }
        applyDraft(draft, for: intent)
    }

    /// Restores Apple's documented default shortcuts in the editor.
    public func resetMappingsToProposedDefaults() {
        for intent in DesktopIntent.allCases {
            applyDraft(MappingDraft(shortcut: ShortcutMappings.proposedDefaults[intent]), for: intent)
        }
    }

    /// Why a direction's draft cannot be applied; `nil` when valid.
    public func mappingError(for intent: DesktopIntent) -> String? {
        draft(for: intent).shortcut == nil
            ? "Enter a key code as hexadecimal (0x7B) or decimal (123), 0 to 65535. The previous valid mapping stays in force."
            : nil
    }

    public var hasInvalidDraft: Bool {
        DesktopIntent.allCases.contains { draft(for: $0).shortcut == nil }
    }

    private func applyDraft(_ draft: MappingDraft, for intent: DesktopIntent) {
        drafts[intent] = draft
        guard let shortcut = draft.shortcut else { return }
        var updated = controller.mappings
        updated[intent] = shortcut
        // The controller ignores identical mappings, so keystrokes that do
        // not change the value keep the confirmation.
        controller.updateMappings(updated)
        if updated != mappings { store.saveMappings(updated) }
        refresh()
    }

    // MARK: Access

    /// Explicit setup action: may show the system prompt or open System
    /// Settings. Never triggered by a navigation request.
    public func requestAccess() {
        accessRequestCount += 1
        let granted = access.requestEventPostingAccess()
        accessStatus = granted ? .granted(checkedAt: time.now().date) : .denied(checkedAt: time.now().date)
    }

    /// Non-prompting preflight. Updates the display only; the controller
    /// still checks live before each action.
    public func recheckAccess() {
        let granted = access.hasEventPostingAccess()
        accessStatus = granted ? .granted(checkedAt: time.now().date) : .denied(checkedAt: time.now().date)
    }

    // MARK: Mirrors

    private func refresh() {
        isExecutionEnabled = controller.isExecutionEnabled
        areShortcutsConfirmed = controller.areShortcutsConfirmed
        mappings = controller.mappings
        latestRecord = controller.latestRecord
        records = controller.history.newestFirst
    }
}

/// The probe as the app runs it: real CoreGraphics events posted live, the
/// real privacy preflight/request, and mappings persisted in `UserDefaults`.
public typealias ProductionProbe = SpaceNavigationProbe<CGKeyEventBoundary>

extension SpaceNavigationProbe where Events == CGKeyEventBoundary {
    /// The only place the live poster and the real access functions are wired
    /// together. Nothing here posts; posting happens only on a user request
    /// that passes the controller's guards.
    public static func production(defaults: any KeyedDataStore = UserDefaults.standard) -> ProductionProbe {
        ProductionProbe(
            events: CGKeyEventBoundary(),
            access: CGEventPostingAccess(),
            store: UserDefaultsMappingStore(defaults: defaults)
        )
    }
}
