# Architecture

Status: established for Milestone 0 (the button-driven Space-navigation probe). Later milestones extend this document rather than replacing it. Product intent lives in [VISION.md](VISION.md); behavior contracts live in `specs/`.

## Layout

| Path | Owns | Depends on |
| --- | --- | --- |
| `Packages/PraxisCore/` | Semantic layer and the guarded action controller: `DesktopIntent`, `ShortcutMappings`, `ActionRecord`/`ActionOutcome`, `BoundedHistory`, the boundary protocols, and `SpaceNavigationController`. Pure Swift; no AppKit, SwiftUI, or CoreGraphics. | Swift standard library and Foundation (`Date` only) |
| `App/Sources/PraxisDesktop/` | macOS adapters: `CGKeyEventBoundary` (CoreGraphics event construction and posting) and `CGEventPostingAccess` (preflight and explicit request). App state for the probe: `SpaceNavigationProbe`, `ShortcutMappingStore`, `ActionRecordPresentation`, key code field parsing. Library target so it is testable. | `PraxisCore`, CoreGraphics, Foundation, Observation |
| `App/Sources/Praxis/` | Executable: menu bar item and the debug window (`DebugView`) bound to `ProductionProbe`; the window is presented at launch and reopened from the menu. View code only; no state and no eligibility guard. | `PraxisDesktop`, `PraxisCore`, SwiftUI, AppKit |
| `App/Tests/PraxisDesktopTests/` | Adapter tests (real `CGEvent` construction, posting order at the boundary, access wiring, controller integration) and probe tests (launch/relaunch state, editor-driven mapping invalidation, request forwarding, access setup, presentation wording and bounds). Never post live input or request access. | |
| `App/Resources/Info.plist` | Bundle identity and version metadata. | |
| `scripts/` | The only supported build, test, and launch entry points. | Toolchain below |
| `build/<configuration>/Praxis.app` | Assembled, ad-hoc signed app bundle (ignored by Git). | `scripts/build-app` |

Dependency direction is one way: the app imports the core; the core never imports the app or any Apple UI/graphics framework. Recognized input (a button today, a gesture later), semantic intent (`DesktopIntent`), and attempted macOS action (adapter, task 3) stay separate types.

## Space-navigation controller boundary

Established in task 2. The split between package and app is:

| Concern | Owner |
| --- | --- |
| Enable flag, mappings, session confirmation and its invalidation, in-progress flag, 50-record history, every eligibility guard, pair construction-before-posting | `SpaceNavigationController` in `PraxisCore` |
| Shortcut value types (`KeyboardShortcut`, `KeyModifiers`, `ShortcutMappings.proposedDefaults`) and result types (`ActionRecord`, `ActionOutcome`, `BlockReason`, `FailureReason`) | `PraxisCore` |
| Building and posting real keyboard events (`KeyEventBoundary`), checking event-posting access (`EventPostingAccess`), and time (`TimeSource`) | Protocols in `PraxisCore`; production implementations `CGKeyEventBoundary` and `CGEventPostingAccess` in `PraxisDesktop`. `SystemTimeSource` ships in the core. |
| Display of state and records, persistence of mappings across launches, the explicit permission setup action, mapping editor text and validation | `SpaceNavigationProbe` in `PraxisDesktop` and `DebugView` in the executable (task 4, see below). Neither re-implements an eligibility guard; every request goes through `perform(_:)`. The probe's only rule of its own is refusing the Confirm setup action while a key code field is invalid. |

Concurrency model: `SpaceNavigationController` is `@MainActor` and `perform(_:)` is synchronous with no suspension point. The main actor therefore serializes requests, and there is no queue: a request that cannot run now is recorded as blocked and dropped. The `isActionInProgress` guard covers the one remaining way a request can arrive mid-pair, re-entrancy from inside the event boundary's `post` (for example UI code reacting to a posted event). The pair is committed once both events are constructed; disabling execution or losing access between key-down and key-up does not stop the key-up. History is ordered by completion, so a re-entrant blocked request is recorded before the pair that was in progress.

Constraint on the adapter (task 3): `KeyEventBoundary.post` must stay synchronous. An awaited gap between key-down and key-up would reintroduce a suspension point and invalidate the serialization argument above; any inter-event pacing must be synchronous, or the guard must be redesigned first.

Confirmation invalidation: `updateMappings` resets confirmation only when the new mappings differ from the current ones (key code or modifiers of either shortcut). Reassigning identical mappings, as an editor may do on every keystroke, keeps the confirmation.

Tests reach the mid-pair state through the recording boundary's synchronous `onPost` hook, which issues the overlapping request, flips enablement or access, or advances the manual clock from inside `post`. No timing delays or production queues exist to make this testable.

Scenario to test mapping (`Packages/PraxisCore/Tests/PraxisCoreTests/SpaceNavigationControllerTests.swift`):

| Scenario | Suite |
| --- | --- |
| SN-001 state portion | `LaunchStateTests` |
| SN-002 | `DisabledOrUnconfirmedTests` |
| SN-003 | `AccessTests` |
| SN-004 | `RecoveryTests` |
| SN-005 | `RoutingTests` (parameterized over default and non-default mappings) |
| SN-006 | `ConstructionFailureTests` (parameterized over key-down and key-up failure) |
| SN-007 | `SerializationTests` |
| SN-008 history portion | `DiagnosticsTests`, plus `BoundedHistoryTests` |

Interactive parts of SN-001 and SN-008 and all of SN-009 to SN-011 are not covered by these tests.

## macOS event adapter

Established in task 3 (`App/Sources/PraxisDesktop/`). Public CoreGraphics APIs only.

- **Construction.** `CGKeyEventBoundary.makeEvent` calls `CGEvent(keyboardEventSource:virtualKey:keyDown:)` with the configured key code and sets `event.flags` to exactly the configured modifiers (Control → `maskControl`, Option → `maskAlternate`, Shift → `maskShift`, Command → `maskCommand`). A `nil` result or an event type that differs from the requested key-down/key-up phase throws `KeyEventConstructionError`, which the controller reports as a failed outcome with zero posts. Modifier keys used as the main key generate `flagsChanged` events and are rejected; modifiers on a normal main key remain supported. Regression tests cover Shift and Control main keys, both phases and directions, and recovery through a fresh request after correcting the mapping. No standalone modifier events, no retries.
- **Posting.** `post` hands the event to an injected `Poster`. The default `CGKeyEventBoundary.livePoster` is the only place in Praxis that calls `CGEvent.post(tap:)`. Tests always inject a recording poster, so `scripts/test-app` constructs real events and posts none.
- **Access.** `CGEventPostingAccess.hasEventPostingAccess()` calls `CGPreflightPostEventAccess()` and nothing else; the controller calls it before every action. `requestEventPostingAccess()` calls `CGRequestPostEventAccess()` and exists only for the explicit setup action (task 4 UI). Both are injectable, so tests verify the wiring without touching the privacy database; one test calls the real preflight, which shows no UI, and does not assert its value.

Decisions pending hardware evidence (SN-009 to SN-011). Change them with findings, not by assumption:

| Decision | Value | Why this first | What could prove it wrong |
| --- | --- | --- | --- |
| Event source | `CGEventSource(stateID: .combinedSessionState)` | Apple documents it as the state table reflecting all sources in the login session; the natural choice for a synthesized user shortcut. `nil` is accepted by `CGEvent` as a fallback. | Mission Control ignoring the shortcut, or modifier state bleeding into later real key presses. |
| Posting location | `.cghidEventTap` | Inserts the event at the HID level so system-level shortcut handling sees it before applications. | If the HID tap requires broader access than event posting, `.cgSessionEventTap` is the fallback. |
| Modifiers as flags only | `event.flags` on the pair, no modifier key events | Required by the spec (no standalone modifier events). | Apple's `CGEvent(keyboardEventSource:...)` documentation example produces a character by posting separate Shift key-down/up events. If Mission Control requires physical modifier events, SN-009 fails and the spec constraint must be revisited with that evidence. |
| Non-modifier flag bits cleared | `event.flags` is replaced, not merged, so bits CoreGraphics adds at creation (for arrow keys typically `maskSecondaryFn` and `maskNumericPad`, plus `maskNonCoalesced`) are dropped | Keeps the posted flags exactly the configured set and testable. | If the shortcut matcher expects the auxiliary arrow-key bits, SN-009 fails for this reason rather than the flags-only one; merging the creation-time bits with the configured modifiers is the fallback. |

What the automated adapter tests cannot establish: that `CGEvent.post(tap:)` is accepted by the system, that Mission Control reacts to a flags-only pair, that a Space actually changes, how the preflight behaves after revocation on this macOS version, whether the ad-hoc signature causes re-prompts after rebuilds, or the pacing between consecutive pairs. Those are SN-009 to SN-011.

Apple documentation consulted on 2026-09-09 (developer.apple.com/documentation/coregraphics): `CGEvent.post(tap:)` "posts the specified event immediately before any event taps instantiated for that location" (macOS 10.4+); `CGEvent(keyboardEventSource:virtualKey:keyDown:)` returns `nil` if the event could not be created (macOS 10.4+); `CGPreflightPostEventAccess()` and `CGRequestPostEventAccess()` return `Bool` (macOS 10.15+); `CGEventSourceStateID.combinedSessionState` as described above.

## Debug interface and app state

Established in task 4. `SpaceNavigationProbe<Events>` (`App/Sources/PraxisDesktop/SpaceNavigationProbe.swift`) is a `@MainActor @Observable` class that wraps one `SpaceNavigationController` and exposes mirrors of its state for SwiftUI. `ProductionProbe.production()` is the only place the live `CGKeyEventBoundary`, the real `CGEventPostingAccess`, and the `UserDefaults` mapping store are wired together; `PraxisApp` holds one instance per process, so relaunch starts disabled and unconfirmed by construction.

- **Requests.** `request(_:)` calls `perform(_:)` unconditionally and then refreshes the mirrors and the access snapshot (preflight only). The Previous/Next buttons stay enabled in every state so the controller's reason, not a disabled button, explains a non-posting request.
- **Mapping editor.** Per direction: one key code text field (`0x7B` hexadecimal or decimal, parsed by `KeyCodeField`) and four modifier checkboxes. A parseable edit is applied through `updateMappings` at once and saved to the store; the controller decides whether it is a change, so retyping the same value keeps the confirmation. An unparseable key code shows an error, leaves the last valid mapping in force, ignores modifier toggles for that direction, and blocks the Confirm button until fixed, so the editor never shows modifiers that differ from the mapping in force. No general settings framework.
- **Confirmation and access.** Confirm is the user's assertion for the session; the window explains that System Settings changes require rechecking here. `requestAccess()` calls `CGRequestPostEventAccess()` once per press; `recheckAccess()` preflights. Neither is reachable from a navigation request. The shown access status is a snapshot with its check time; the controller still checks live before each action.
- **Records.** `ActionRecordPresentation` produces the wording: `Shortcut posted`, `Blocked`, or `Failed`; a reason sentence for every outcome; the core's recovery action for blocked/failed; elapsed processing time in milliseconds. The posted reason says Praxis does not observe whether a transition followed. The window shows the latest record and the newest 50, newest first.
- **Persistence.** Only `ShortcutMappings` (JSON in `UserDefaults` key `praxis.spaceNavigation.shortcutMappings`). Undecodable data falls back to the proposed defaults. The store reads and writes through a two-method `KeyedDataStore` protocol that `UserDefaults` conforms to, so tests use a dictionary and leave no preference files behind. Enablement, confirmation, access status, and history are never stored.

Probe tests (`App/Tests/PraxisDesktopTests/SpaceNavigationProbeTests.swift`) run over the production `CGKeyEventBoundary` with a recording poster, a scripted access double, and an in-memory store. They cover SN-001 launch/relaunch state, SN-002 editor-driven invalidation, forwarding of the three externally reachable block reasons (in-progress is reachable only by re-entrancy and stays in the core tests), the explicit access actions, and SN-008 wording and bounds. They do not show that SwiftUI renders the bindings, that the menu bar item appears, or that any label reads as intended on screen; that is interactive observation.

Known limitation for hardware testing: the debug window lives on the Space it was opened in, so after a successful transition the tester must return to that Space (or reopen the window from the menu bar, which activates the app) before the next request. The spec asks for this to be recorded as a finding in SN-009 rather than worked around ahead of evidence.

## Toolchain

Decision: build with Swift Package Manager. The Command Line Tools are sufficient; full Xcode also works and is selected per command. No Xcode project is present or required.

Inspected on 2026-09-08 (development Mac; Xcode was installed later the same day):

| Item | Value |
| --- | --- |
| macOS | 26.6.2 (25G83), Apple Silicon |
| Active developer directory | `/Library/Developer/CommandLineTools` |
| Swift | 6.3.3 (swiftlang-6.3.3.1.3), SwiftPM 6.3.3 |
| macOS SDK | 26.5 (`MacOSX26.5.sdk`) |
| Xcode.app | Xcode 26.6 (17F113) at `/Applications/Xcode.app`, license accepted; not the active developer directory |
| Code-signing identities | none |

Consequences:

- `swift build` and `swift test` work with the Command Line Tools alone. `xcodebuild` is available only through Xcode and nothing depends on it.
- Swift Testing ships with the Command Line Tools at `<developer dir>/Library/Developer/Frameworks/Testing.framework` plus `<developer dir>/Library/Developer/usr/lib/lib_TestingInterop.dylib`, but SwiftPM 6.3.3 does not add those paths. `praxis_swift_test_args` in `scripts/lib/toolchain.sh`, used by both `scripts/test-core` and `scripts/test-app`, adds them explicitly when the developer directory has no `Platforms/` folder (the marker of full Xcode). XCTest is not available with the Command Line Tools; tests use Swift Testing only.
- Requirements enforced by `scripts/lib/toolchain.sh`: Swift 6.2 or newer and macOS SDK 26 or newer. The manifests declare `swift-tools-version: 6.2` because `.macOS(.v26)` is annotated `@available(_PackageDescription 6.2)` in the installed PackageDescription swiftinterface. Missing prerequisites fail with a named cause.
- `PRAXIS_DEVELOPER_DIR` selects a developer directory for one command without changing the machine-wide `xcode-select` selection. Verified on 2026-09-08: `scripts/check` passes with the default Command Line Tools and with `PRAXIS_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; the Xcode path exercises the branch of `praxis_swift_test_args` that lets SwiftPM find Swift Testing itself (re-verified 2026-09-09 with `scripts/test-app` included).
- An Xcode project can be added later if a feature needs it (asset catalogs, entitlements UI, Instruments templates). Until then the SwiftPM path is the reference build.

## Minimum macOS version

Decision: macOS 26.0 (`LSMinimumSystemVersion` and the SwiftPM platform value).

Rationale: the only development and test configuration runs macOS 26.6; the project is an interaction experiment with no distribution goal yet; targeting the installed OS avoids availability shims for SwiftUI scene modifiers (`defaultLaunchBehavior`, `restorationBehavior`) and keeps Swift 6 strict concurrency free of legacy workarounds. Lower the floor only when a concrete configuration needs it and can be tested.

## Bundle identity

Decision: `CFBundleIdentifier` is `com.villetakanen.praxis`. `scripts/build-app` fails if `Info.plist` drifts from this value.

Rationale: reverse-DNS on the author's personal domain, independent of the repository name (`ixis` today, `Praxis` as product name) so a repository rename does not change the identity macOS uses for privacy permissions. Assumption: the author controls `villetakanen.com`; if not, change this once before any permission evidence is gathered, because permission grants are keyed to identity.

Other bundle facts: `CFBundleName`/`CFBundleDisplayName` `Praxis`; `LSUIElement` true (menu bar app, no Dock icon); `NSPrincipalClass` `NSApplication`; no entitlements and no App Sandbox. Assumption to verify in SN-009 and SN-010: posting keyboard events to other applications requires an unsandboxed app plus the event-posting privacy grant.

## Signing

Decision: ad-hoc signing (`codesign --sign -`) in `scripts/build-app`. No Developer ID or Apple Development certificate exists on this machine, and none is invented or requested.

Expected consequence to verify during permission work (tasks 3 and 5): macOS ties privacy grants (Accessibility, Input Monitoring, event posting) to the app's code signature. An ad-hoc signature has no team identity, so a rebuilt binary may be treated as a new client and require granting again. Record the observed behavior in the experiment report. If re-granting after every rebuild makes experiments impractical, obtaining an Apple Development certificate is the next step; that is a human decision.

## Version metadata

`CFBundleShortVersionString` `0.1.0` and `CFBundleVersion` `1`. Apple requires these to be period-separated integers, so the proposed `0.1.0-alpha.1` product version from [plans/project-workflow.md](plans/project-workflow.md) cannot be placed in the bundle; the prerelease label lives in release notes and tags only. No release exists; these values describe the development build.

## Build, test, and launch

| Command | Does | Fails when |
| --- | --- | --- |
| `scripts/check` | Runs `scripts/test-core`, `scripts/test-app`, then `scripts/build-app`. | Any test fails, the build fails, or a toolchain prerequisite is missing. |
| `scripts/test-core` | `swift test` on `Packages/PraxisCore` with Swift Testing. | Tests fail or Swift Testing cannot be located. |
| `scripts/test-app` | `swift test` on `App` (`PraxisDesktopTests`: adapter and probe tests). Constructs real CoreGraphics events, posts none, requests no permission. | Tests fail or Swift Testing cannot be located. |
| `scripts/build-app` | `swift build` on `App/`, assembles and ad-hoc signs `build/debug/Praxis.app`, prints identity, version, and signature. `PRAXIS_CONFIGURATION=release` for a release build. | Build fails, `Info.plist` identity drifts, or signing/verification fails. |
| `scripts/run-app` | Builds, quits a running Praxis, launches the bundle with `open`. The debug window appears and takes focus. | As `build-app`. |

`scripts/check` proves compilation, unit and adapter behavior up to the posting boundary, and bundle assembly. It does not prove that the menu bar item appears, that the debug window opens, that permissions work, that a posted event is accepted by macOS, or that any Space changes. Those are interactive macOS evidence and are recorded separately.

## Verified API availability

Checked against the installed macOS 26.5 SDK on 2026-09-08:

| API | Availability | Source |
| --- | --- | --- |
| `SwiftUI.MenuBarExtra` | macOS 13.0+ | SwiftUI swiftinterface |
| `SwiftUI.OpenWindowAction` | macOS 13.0+ | SwiftUI swiftinterface |
| `Scene.defaultLaunchBehavior`, `Scene.restorationBehavior` | macOS 15.0+ | SwiftUI swiftinterface |
| `NSApplication.activate()` | macOS 14.0+ | `AppKit/NSApplication.h` line 231 |
| `CGPreflightPostEventAccess`, `CGRequestPostEventAccess` | macOS 10.15+ | `CoreGraphics/CGEvent.h` lines 405 and 408 |
| `CGEventPost` (`CGEvent.post(tap:)`) | macOS 10.4+ | `CoreGraphics/CGEvent.h` line 353 |
| `CGEventCreateKeyboardEvent` (`CGEvent(keyboardEventSource:virtualKey:keyDown:)`) | macOS 10.4+ | `CoreGraphics/CGEvent.h` line 79 |
| `CGEventSetFlags`, `CGEventGetIntegerValueField`, `kCGKeyboardEventKeycode` | present | `CoreGraphics/CGEvent.h` lines 182 and 211, `CGEventTypes.h` line 182 |
| `CGEventTapLocation` (`kCGHIDEventTap`, `kCGSessionEventTap`, `kCGAnnotatedSessionEventTap`) | present | `CoreGraphics/CGEventTypes.h` line 402 |

Presence in the SDK is not evidence that posting a shortcut changes a Space; that is what SN-009 through SN-011 measure. Posting is implemented and reachable from the debug window, but automated checks exercise it only through the recording poster.

## Not decided

- Whether an Xcode project is ever needed.
- Signing identity for repeatable permission grants (see Signing).
- Distribution audience and packaging; nothing here is a release.
