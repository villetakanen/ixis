---
title: Space navigation
status: active
implementation: not-started
verification: not-run
---

# Space navigation

## Blueprint

### Context

Ixis must establish that a semantic navigation intent can produce a useful macOS action before adding camera recognition. This first slice uses Previous Space and Next Space buttons in a debug window to exercise the same intent boundary a future gesture recognizer will use.

Scope: app shell, explicit action enablement, shortcut setup, event-posting permission, and observable action attempts. Camera, gestures, speech, window selection, and Return submission belong to later slices. See [vision](../../VISION.md) and [scaffold plan](../../plans/initial-scaffold.md).

### Architecture

Proposed ownership; source paths will be recorded when the scaffold exists:

- Pure Swift package: `DesktopIntent.previousSpace` and `.nextSpace`, plus value types for action outcomes. No AppKit or CoreGraphics dependency.
- Native app: a menu bar entry opens a debug window. The window supplies explicit navigation buttons and action status.
- Desktop adapter: consumes an intent and the verified shortcut mapping, checks eligibility, constructs and posts keyboard events using public CoreGraphics APIs.
- App state: owns the enable flag, session shortcut confirmation, permission snapshot, and recent action results. UI state is main-actor isolated; actions are serialized with no deferred navigation queue.

The shortcut mapping contains a key code and modifier set for each direction. Display the proposed Control–Left/Right defaults, but require the user to confirm they match enabled Mission Control shortcuts before execution. Provide a minimal way to enter a different mapping when defaults do not match. No automatic reading of undocumented system shortcut stores or changes to system settings.

Confirmation lasts for the app session. Reset it when an Ixis mapping changes. Explain that changes made in System Settings require rechecking the mapping; Ixis does not claim to monitor those settings. Action execution starts disabled on every launch.

### Action result

Each request produces a record containing a request identifier, direction, timestamp, elapsed intent-to-result duration, and one of:

- `blocked(reason)`: disabled, shortcuts unconfirmed, event-posting access unavailable, or action already in progress. Nothing is posted.
- `failed(reason)`: required events could not be constructed. Nothing is posted; prepare the complete pair before posting either event.
- `posted`: one navigation key-down/key-up pair was handed to the posting API with the configured modifiers. This is not an acknowledgement from Mission Control.

Show the latest result and a bounded history of 50 records with the oldest discarded first. Surface the reason and a relevant recovery action for blocked/failed outcomes. Use “Shortcut posted” for the posted state; never “Space changed.” Timing measures Ixis processing only, not the macOS transition.

### Constraints

- The enable switch and shortcut confirmation are independent from permission state. Turning control off prevents subsequent requests from posting; no request is saved for later replay.
- Check event-posting access immediately before constructing/posting each action; cached UI permission state is not sufficient authorization. Permission can still change after preflight, so posting is never treated as confirmation of effect.
- Request permission through an explicit setup action, not repeatedly from navigation attempts. Explain how to retry/check access after changing system settings.
- Use a matched navigation key-down/key-up pair carrying the configured modifiers. Do not synthesize additional standalone modifier-down events or retries. Complete a started pair even if enablement changes between its events.
- Requests arriving while an action is in progress are blocked, not queued. Distinct eligible button activations each request one pair; OS transition timing is evaluated by the experiment, with no invented cooldown threshold yet.
- No private Space identifiers, WindowServer APIs, pointer movement, or screen capture. The initial slice requests no camera or microphone permission.

## Contract

### Definition of done

- [ ] Menu bar app opens the debug window, launches with actions disabled, and reports setup status (SN-001).
- [ ] Eligibility failures produce visible reasons and zero posts; recovery requires a fresh request (SN-002–004).
- [ ] Direction routing, paired events, failure atomicity, and request serialization are verified automatically (SN-005–007).
- [ ] Debug results distinguish attempted input from observed effects and expose bounded history (SN-008).
- [ ] Real navigation and permission behavior are recorded on the candidate app (SN-009–011). Unsupported configurations and failed effects are explicit.

### Regression guardrails

Unconfirmed or disabled control produces no keyboard input. No deferred action executes after enablement or a permission grant. Each eligible request posts at most one matched pair. UI and logs describe evidence at its actual level: intent, blocked/failed attempt, or posted shortcut.

### Scenarios

#### SN-001: Launch and inspect

Evidence: automated app-state checks and interactive macOS.

Given a newly launched app, when the user opens Debug from the menu bar, then Previous/Next controls, the disabled execution state, shortcut confirmation state, and permission status are visible. Relaunch resets enablement and confirmation, even after a previous enabled session.

#### SN-002: Disabled or unconfirmed

Evidence: automated; exercise each precondition independently.

Given either disabled execution or unconfirmed shortcuts, when a navigation request reaches the controller, then it produces the corresponding blocked reason and posts zero events. Enabling/confirming afterward does not replay the request. Changing either configured shortcut invalidates confirmation.

#### SN-003: Permission unavailable or revoked

Evidence: automated permission boundary; interactive revocation in SN-010.

Given enabled execution and confirmed shortcuts, when the current access check returns unavailable despite any earlier grant, then the request is blocked visibly and posts zero events. It does not automatically prompt or retry.

#### SN-004: Recover without replay

Evidence: automated.

Given a blocked request, when its blocking condition is resolved, then zero events are posted until a fresh navigation request arrives. That new request is checked against all current eligibility conditions.

#### SN-005: Route direction and construct events

Evidence: automated with a recording event boundary.

Given an eligible request for either direction, when it executes, then exactly one key-down followed by one key-up uses that direction's configured key code and modifier set. The result is posted. Repeat with non-default mappings to demonstrate that direction does not hard-code the default keys.

#### SN-006: Construction failure

Evidence: automated with failures injected at each event-construction step.

Given an eligible request, when either event cannot be created, then the result is failed with a visible reason and zero events are posted.

#### SN-007: No deferred or interrupted pair

Evidence: automated with a controllable event boundary.

Given a pair in progress, when another request arrives, then the second request is blocked and never replayed. When execution is disabled after the first key-down, then its matching key-up is still posted, and subsequent requests post nothing.

#### SN-008: Honest and bounded diagnostics

Evidence: automated app-state checks and interactive label inspection.

Given any result, when the debug view updates, then it shows its direction, outcome, and applicable reason. A posted result says “Shortcut posted” without claiming a Space transition. After 51 requests only the newest 50 records remain. Recorded elapsed duration describes intent-to-result processing, not display response.

#### SN-009: Ordinary Space navigation

Evidence: interactive macOS; a mocked posting boundary cannot satisfy this scenario.

Given at least three ordinary Spaces, the middle Space active, verified shortcuts, granted access, and enabled execution, when the tester triggers Previous or Next from the debug window, then the observed desktop moves to the adjacent Space in the requested direction. Return to the middle and test each direction separately. Record any focus/debug-window visibility issue as a finding rather than assuming the next request remains reachable.

#### SN-010: Real permission recovery

Evidence: interactive macOS.

Given a working candidate, when event-posting access is revoked and a new request is made, then the app blocks it visibly when preflight reports the denial. After access is restored, no input is replayed; a fresh request can post. Record whether the tested macOS version requires restarting the app, and verify restart returns to disabled/unconfirmed state.

#### SN-011: Limits of the configured shortcut

Evidence: interactive macOS characterization.

Given a first/last Space, a full-screen Space, or multiple displays, when each direction is requested in turn, then record the observed effect and relevant Mission Control settings. Ixis reports only the posting result, including when the OS makes no transition. Test a deliberately mismatched/disabled system shortcut as well: a posted record must not become a claim of successful navigation. Restore the tester's settings after the experiment.

## Evidence

All scenarios are not run; there is no implementation. Independent spec review evaluates clarity and verifiability only.

For the first hardware run, create `docs/experiments/space-navigation.md` with source SHA, app identity/build, launch path, toolchain, macOS/hardware, display/Space layout, shortcuts, scenario outcomes, and repeat counts. Use 10 deliberate attempts per direction from a valid middle Space for SN-009; record wrong, missed, and duplicate transitions. Passing this probe requires all 20 attempts to produce exactly one transition in the requested direction. This is a baseline protocol, not a statistical reliability claim.

SN-009 and SN-010 must pass on the initial supported development configuration before adding camera-driven actions. SN-011 is required characterization; unavailable hardware is marked not run, with that configuration excluded from validated support. A human records whether the button probe is adequate to continue, separately from eventual gesture usability acceptance.

## Open questions

- Minimum macOS version, stable bundle identity, and signing setup: resolve during app scaffolding before hardware permission evidence is gathered.
- Posting location/event-source behavior and any OS-specific limitations: resolve through SN-009–011 using public APIs; revise this spec with findings if the mechanism fails.
- Space-transition pacing and future gesture cooldown: measure during the probe and later gesture work. This slice does not guarantee that rapid sequential posts each produce a transition.

## API investigation entry points

- [Apple's documented Space shortcuts](https://support.apple.com/en-lamr/guide/mac-help/mh14112/mac)
- [CGEvent posting](https://developer.apple.com/documentation/coregraphics/cgevent/post(tap:))
- [Event-posting access preflight](https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess())

Verify SDK availability and current documentation during implementation; these references do not establish a successful integration.
