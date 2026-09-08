# Architecture

Status: established for Milestone 0 (the button-driven Space-navigation probe). Later milestones extend this document rather than replacing it. Product intent lives in [VISION.md](VISION.md); behavior contracts live in `specs/`.

## Layout

| Path | Owns | Depends on |
| --- | --- | --- |
| `Packages/PraxisCore/` | Semantic layer: `DesktopIntent` (the boundary type) and `BoundedHistory` (groundwork for the task-2 result history; no consumer yet). Pure Swift; no AppKit, SwiftUI, or CoreGraphics. | Swift standard library, Foundation in tests only |
| `App/` | Native app: menu bar item, debug window, and (from task 2 on) app state and the desktop adapter that turns intents into attempted macOS actions. | `PraxisCore`, SwiftUI, AppKit today; CoreGraphics from task 3 |
| `App/Resources/Info.plist` | Bundle identity and version metadata. | |
| `scripts/` | The only supported build, test, and launch entry points. | Toolchain below |
| `build/<configuration>/Praxis.app` | Assembled, ad-hoc signed app bundle (ignored by Git). | `scripts/build-app` |

Dependency direction is one way: the app imports the core; the core never imports the app or any Apple UI/graphics framework. Recognized input (a button today, a gesture later), semantic intent (`DesktopIntent`), and attempted macOS action (adapter, task 2+) stay separate types.

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
- Swift Testing ships with the Command Line Tools at `<developer dir>/Library/Developer/Frameworks/Testing.framework` plus `<developer dir>/Library/Developer/usr/lib/lib_TestingInterop.dylib`, but SwiftPM 6.3.3 does not add those paths. `scripts/test-core` adds them explicitly when the developer directory has no `Platforms/` folder (the marker of full Xcode). XCTest is not available with the Command Line Tools; tests use Swift Testing only.
- Requirements enforced by `scripts/lib/toolchain.sh`: Swift 6.2 or newer and macOS SDK 26 or newer. The manifests declare `swift-tools-version: 6.2` because `.macOS(.v26)` is annotated `@available(_PackageDescription 6.2)` in the installed PackageDescription swiftinterface. Missing prerequisites fail with a named cause.
- `PRAXIS_DEVELOPER_DIR` selects a developer directory for one command without changing the machine-wide `xcode-select` selection. Verified on 2026-09-08: `scripts/check` passes with the default Command Line Tools and with `PRAXIS_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; the Xcode path exercises the branch of `scripts/test-core` that lets SwiftPM find Swift Testing itself.
- An Xcode project can be added later if a feature needs it (asset catalogs, entitlements UI, Instruments templates). Until then the SwiftPM path is the reference build.

## Minimum macOS version

Decision: macOS 26.0 (`LSMinimumSystemVersion` and the SwiftPM platform value).

Rationale: the only development and test configuration runs macOS 26.6; the project is an interaction experiment with no distribution goal yet; targeting the installed OS avoids availability shims for SwiftUI scene modifiers (`defaultLaunchBehavior`, `restorationBehavior`) and keeps Swift 6 strict concurrency free of legacy workarounds. Lower the floor only when a concrete configuration needs it and can be tested.

## Bundle identity

Decision: `CFBundleIdentifier` is `com.villetakanen.praxis`. `scripts/build-app` fails if `Info.plist` drifts from this value.

Rationale: reverse-DNS on the author's personal domain, independent of the repository name (`ixis` today, `Praxis` as product name) so a repository rename does not change the identity macOS uses for privacy permissions. Assumption: the author controls `villetakanen.com`; if not, change this once before any permission evidence is gathered, because permission grants are keyed to identity.

Other bundle facts: `CFBundleName`/`CFBundleDisplayName` `Praxis`; `LSUIElement` true (menu bar app, no Dock icon); `NSPrincipalClass` `NSApplication`; no entitlements and no App Sandbox. Assumption to verify in task 3: posting keyboard events to other applications requires an unsandboxed app plus the event-posting privacy grant.

## Signing

Decision: ad-hoc signing (`codesign --sign -`) in `scripts/build-app`. No Developer ID or Apple Development certificate exists on this machine, and none is invented or requested.

Expected consequence to verify during permission work (tasks 3 and 5): macOS ties privacy grants (Accessibility, Input Monitoring, event posting) to the app's code signature. An ad-hoc signature has no team identity, so a rebuilt binary may be treated as a new client and require granting again. Record the observed behavior in the experiment report. If re-granting after every rebuild makes experiments impractical, obtaining an Apple Development certificate is the next step; that is a human decision.

## Version metadata

`CFBundleShortVersionString` `0.1.0` and `CFBundleVersion` `1`. Apple requires these to be period-separated integers, so the proposed `0.1.0-alpha.1` product version from [plans/project-workflow.md](plans/project-workflow.md) cannot be placed in the bundle; the prerelease label lives in release notes and tags only. No release exists; these values describe the development build.

## Build, test, and launch

| Command | Does | Fails when |
| --- | --- | --- |
| `scripts/check` | Runs `scripts/test-core`, then `scripts/build-app`. | Any test fails, the build fails, or a toolchain prerequisite is missing. |
| `scripts/test-core` | `swift test` on `Packages/PraxisCore` with Swift Testing. | Tests fail or Swift Testing cannot be located. |
| `scripts/build-app` | `swift build` on `App/`, assembles and ad-hoc signs `build/debug/Praxis.app`, prints identity, version, and signature. `PRAXIS_CONFIGURATION=release` for a release build. | Build fails, `Info.plist` identity drifts, or signing/verification fails. |
| `scripts/run-app` | Builds, quits a running Praxis, launches the bundle with `open`. | As `build-app`. |

`scripts/check` proves compilation, unit behavior, and bundle assembly. It does not prove that the menu bar item appears, that the debug window opens, that permissions work, or that any Space changes. Those are interactive macOS evidence and are recorded separately.

## Verified API availability

Checked against the installed macOS 26.5 SDK on 2026-09-08:

| API | Availability | Source |
| --- | --- | --- |
| `SwiftUI.MenuBarExtra` | macOS 13.0+ | SwiftUI swiftinterface |
| `SwiftUI.OpenWindowAction` | macOS 13.0+ | SwiftUI swiftinterface |
| `Scene.defaultLaunchBehavior`, `Scene.restorationBehavior` | macOS 15.0+ | SwiftUI swiftinterface |
| `NSApplication.activate()` | macOS 14.0+ | `AppKit/NSApplication.h` line 231 |
| `CGPreflightPostEventAccess`, `CGRequestPostEventAccess` | macOS 10.15+ | `CoreGraphics/CGEvent.h` lines 405 and 408 |
| `CGEventPost` | macOS 10.4+ | `CoreGraphics/CGEvent.h` line 353 |

Presence in the SDK is not evidence that posting a shortcut changes a Space; that is what SN-009 through SN-011 measure.

## Not decided

- Whether an Xcode project is ever needed.
- Signing identity for repeatable permission grants (see Signing).
- Distribution audience and packaging; nothing here is a release.
