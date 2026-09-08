# Initial scaffold

Status: proposed implementation plan

The product intent lives in [VISION.md](../VISION.md). This plan narrows the first implementation to its Space-switching milestone.

## Structure

- One native macOS app target: menu bar, debug window, permissions, camera/Vision adapter, and desktop actions.
- One local Swift package: normalized hand observations, temporal swipe recognition, and semantic intents; independently testable without camera or desktop access.
- Add speech and focused-window operations only when their milestones begin. No placeholder frameworks or controllers.

## Build sequence

1. App shell and buttons that dispatch previous/next Space intents through configured keyboard shortcuts. Verify permissions and actual desktop behavior before introducing recognition.
2. Camera capture and Vision hand landmarks. Keep processing bounded, discard stale frames, and keep UI work on the main actor.
3. Temporal swipe recognition with debug intent history. Test cancellation, lost tracking, cooldown, and ordinary non-command movement.
4. Explicitly enabled desktop execution. Measure misses, accidental actions, and capture-to-action latency in real use.

## Boundaries and evidence

- Raw camera/Vision objects stay outside the gesture package.
- Specify coordinate orientation and mirroring once; use timestamps rather than frame counts.
- Posting a keyboard event is an action attempt, not proof that a Space changed.
- Validate the user's Space shortcuts; do not silently assume defaults or use private APIs.
- Keep a stable app identity and predictable launch path for permission testing.
- Use deterministic gesture traces for automated tests and real macOS sessions for integration evidence.
- Focusing a window does not prove that its text input is focused. Investigate this before the speech milestone.

## Toolchain prerequisite

At initial inspection, Swift 6.3.3 is available and `xcode-select` points to Command Line Tools. No Xcode app matched `/Applications/Xcode*.app`. Establish the full Xcode toolchain before building the native app target; the pure Swift package can be developed separately.

## API starting points

- [Vision hand-pose request](https://developer.apple.com/documentation/vision/detecthumanhandposerequest)
- [CGEvent posting](https://developer.apple.com/documentation/coregraphics/cgevent/post(tap:))
- [Event-posting permission preflight](https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess())
- [Apple's Space navigation instructions](https://support.apple.com/en-lamr/guide/mac-help/mh14112/mac)

These are investigation entry points, not evidence that the integration already works.
