# Initial scaffold

Status: implementation plan; Milestone 0 scaffold in progress (see [ARCHITECTURE.md](../ARCHITECTURE.md))

The product intent lives in [VISION.md](../VISION.md). This plan narrows the first implementation to its Space-switching milestone. Milestone 0 is the button-driven probe of the Space-navigation action path ([spec](../specs/space-navigation/spec.md)); the camera-to-swipe slice remains the first gesture milestone and reuses the same intent and adapter boundary.

## Structure

- One native macOS app target: menu bar, debug window, permissions, camera/Vision adapter, and desktop actions.
- One local Swift package: normalized hand observations, temporal swipe recognition, and semantic intents; independently testable without camera or desktop access.
- Add speech and focused-window operations only when their milestones begin. No placeholder frameworks or controllers.

## Build sequence

0. Milestone 0, button probe: app shell and buttons that dispatch previous/next Space intents through configured keyboard shortcuts. Verify permissions and actual desktop behavior before introducing recognition. The enablement, shortcut confirmation, and permission guards built here belong to the adapter and remain the only path to a posted event.
1. First gesture milestone: camera capture and Vision hand landmarks. Keep processing bounded, discard stale frames, and keep UI work on the main actor.
2. Temporal swipe recognition with debug intent history. Test cancellation, lost tracking, cooldown, and ordinary non-command movement.
3. Gesture-driven execution: recognized swipes emit the same intents as the buttons and connect to the existing adapter, whose enablement guards already exist; no second execution path. Measure misses, accidental actions, and capture-to-action latency in real use.

## Boundaries and evidence

- Raw camera/Vision objects stay outside the gesture package.
- Specify coordinate orientation and mirroring once; use timestamps rather than frame counts.
- Posting a keyboard event is an action attempt, not proof that a Space changed.
- Validate the user's Space shortcuts; do not silently assume defaults or use private APIs.
- Keep a stable app identity and predictable launch path for permission testing.
- Use deterministic gesture traces for automated tests and real macOS sessions for integration evidence.
- Focusing a window does not prove that its text input is focused. Investigate this before the speech milestone.

## Toolchain

Swift 6.3.3 and the macOS 26.5 SDK are available through the Command Line Tools, and Xcode 26.6 is installed alongside them. The app and core package build and test with Swift Package Manager alone on either toolchain, and `scripts/build-app` assembles the bundle. Decisions and their rationale are in [ARCHITECTURE.md](../ARCHITECTURE.md); an Xcode project is not required for Milestone 0.

## API starting points

- [Vision hand-pose request](https://developer.apple.com/documentation/vision/detecthumanhandposerequest)
- [CGEvent posting](https://developer.apple.com/documentation/coregraphics/cgevent/post(tap:))
- [Event-posting permission preflight](https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess())
- [Apple's Space navigation instructions](https://support.apple.com/en-lamr/guide/mac-help/mh14112/mac)

These are investigation entry points, not evidence that the integration already works.
