import CoreGraphics
import PraxisCore
import Testing
@testable import PraxisDesktop

/// Records what would have been posted. Nothing here calls `CGEvent.post`.
@MainActor
final class RecordingPoster {
    private(set) var posted: [(event: CGEvent, tap: CGEventTapLocation)] = []

    func makeBoundary(
        sourceState: CGEventSourceStateID = CGKeyEventBoundary.defaultSourceState,
        tapLocation: CGEventTapLocation = CGKeyEventBoundary.defaultTapLocation
    ) -> CGKeyEventBoundary {
        CGKeyEventBoundary(sourceState: sourceState, tapLocation: tapLocation) { [self] event, tap in
            posted.append((event, tap))
        }
    }
}

extension CGEvent {
    var keyCode: UInt16 { UInt16(getIntegerValueField(.keyboardEventKeycode)) }
}

@MainActor
@Suite("CGKeyEventBoundary construction")
struct ConstructionTests {
    @Test("key-down and key-up carry the requested type, key code, and exactly the configured modifiers",
          arguments: [
            KeyboardShortcut(keyCode: 0x7B, modifiers: .control),
            KeyboardShortcut(keyCode: 0x7C, modifiers: .control),
            KeyboardShortcut(keyCode: 0x0D, modifiers: [.command, .option]),
            KeyboardShortcut(keyCode: 0x31, modifiers: [.shift, .control, .option, .command]),
            KeyboardShortcut(keyCode: 0x24, modifiers: []),
          ])
    func constructsRealEvents(shortcut: KeyboardShortcut) throws {
        let boundary = RecordingPoster().makeBoundary()
        let down = try boundary.makeEvent(KeyEventSpec(phase: .keyDown, shortcut: shortcut))
        let up = try boundary.makeEvent(KeyEventSpec(phase: .keyUp, shortcut: shortcut))

        #expect(down.type == .keyDown)
        #expect(up.type == .keyUp)
        #expect(down.keyCode == shortcut.keyCode)
        #expect(up.keyCode == shortcut.keyCode)

        let expected = CGEventFlags(shortcut.modifiers)
        for event in [down, up] {
            #expect(event.flags.intersection(.praxisModifierMask) == expected,
                    "modifier bits must be exactly the configured ones")
        }
        #expect(boundary.postedCount == 0, "construction never posts")
    }

    @Test("each Praxis modifier maps to its own CoreGraphics flag and nothing else")
    func modifierMapping() {
        #expect(CGEventFlags(.control) == .maskControl)
        #expect(CGEventFlags(.option) == .maskAlternate)
        #expect(CGEventFlags(.shift) == .maskShift)
        #expect(CGEventFlags(.command) == .maskCommand)
        #expect(CGEventFlags([]) == [])
        #expect(CGEventFlags([.control, .command]) == [.maskControl, .maskCommand])
    }

    @Test("an event source is available for the chosen state")
    func eventSourceExists() {
        let boundary = RecordingPoster().makeBoundary()
        #expect(boundary.hasEventSource)
    }

    @Test("constructed events are independent objects, so the pair is prepared before any post")
    func pairIsTwoEvents() throws {
        let boundary = RecordingPoster().makeBoundary()
        let shortcut = ShortcutMappings.proposedDefaults.nextSpace
        let down = try boundary.makeEvent(KeyEventSpec(phase: .keyDown, shortcut: shortcut))
        let up = try boundary.makeEvent(KeyEventSpec(phase: .keyUp, shortcut: shortcut))
        #expect(down !== up)
        #expect(down.type != up.type)
    }
}

@MainActor
@Suite("CGKeyEventBoundary posting boundary")
struct PostingTests {
    @Test("post hands the exact event to the poster with the configured tap location, in call order")
    func postsInOrderToConfiguredTap() throws {
        let recorder = RecordingPoster()
        let boundary = recorder.makeBoundary(tapLocation: .cgSessionEventTap)
        let shortcut = ShortcutMappings.proposedDefaults.previousSpace
        let down = try boundary.makeEvent(KeyEventSpec(phase: .keyDown, shortcut: shortcut))
        let up = try boundary.makeEvent(KeyEventSpec(phase: .keyUp, shortcut: shortcut))

        boundary.post(down)
        boundary.post(up)

        #expect(recorder.posted.count == 2)
        #expect(recorder.posted[0].event === down)
        #expect(recorder.posted[1].event === up)
        #expect(recorder.posted.allSatisfy { $0.tap == .cgSessionEventTap })
        #expect(boundary.postedCount == 2)
    }

    @Test("the default tap location and source state are the documented decisions")
    func documentedDefaults() {
        let boundary = RecordingPoster().makeBoundary()
        #expect(boundary.tapLocation == .cghidEventTap)
        #expect(CGKeyEventBoundary.defaultSourceState == .combinedSessionState)
    }
}

@MainActor
@Suite("Controller with the production event boundary")
struct IntegrationTests {
    @MainActor
    final class ScriptedAccess: EventPostingAccess {
        var granted = true
        func hasEventPostingAccess() -> Bool { granted }
    }

    @Test("an eligible request posts one real key-down/key-up pair with the mapped key and modifiers",
          arguments: DesktopIntent.allCases)
    func endToEndWithoutLivePosting(intent: DesktopIntent) {
        let recorder = RecordingPoster()
        let mappings = ShortcutMappings(
            previousSpace: KeyboardShortcut(keyCode: 0x7B, modifiers: .control),
            nextSpace: KeyboardShortcut(keyCode: 0x0E, modifiers: [.command, .shift])
        )
        let controller = SpaceNavigationController(
            events: recorder.makeBoundary(),
            access: ScriptedAccess(),
            time: SystemTimeSource(),
            mappings: mappings
        )
        controller.setExecutionEnabled(true)
        controller.confirmShortcuts()

        let record = controller.perform(intent)

        #expect(record.outcome == .posted)
        #expect(recorder.posted.map(\.event.type) == [.keyDown, .keyUp])
        #expect(recorder.posted.map(\.event.keyCode) == [mappings[intent].keyCode, mappings[intent].keyCode])
        for entry in recorder.posted {
            #expect(entry.event.flags.intersection(.praxisModifierMask) == CGEventFlags(mappings[intent].modifiers))
            #expect(entry.tap == .cghidEventTap)
        }
        #expect(record.elapsed >= .zero)
    }

    @Test("a blocked request reaches neither construction nor the poster")
    func blockedPostsNothing() {
        let recorder = RecordingPoster()
        let access = ScriptedAccess()
        access.granted = false
        let boundary = recorder.makeBoundary()
        let controller = SpaceNavigationController(events: boundary, access: access, time: SystemTimeSource())
        controller.setExecutionEnabled(true)
        controller.confirmShortcuts()

        #expect(controller.perform(.nextSpace).outcome == .blocked(.eventPostingAccessUnavailable))
        #expect(recorder.posted.isEmpty)
        #expect(boundary.postedCount == 0)
    }
}
