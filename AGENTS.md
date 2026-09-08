# Working on Praxis

Praxis routes human attention between agents through hands and voice. Read [VISION.md](VISION.md) for product intent and non-goals. Preserve the distinction between a recognized gesture, a semantic intent, and an attempted macOS action.

## Context

- Read the relevant `specs/<capability>/spec.md` before implementation. [Spec template](specs/TEMPLATE.md).
- [Scaffold plan](plans/initial-scaffold.md) gives the implementation sequence. [ARCHITECTURE.md](ARCHITECTURE.md) records the established layout, toolchain, bundle identity, and signing decisions.
- [Project workflow](plans/project-workflow.md) defines spec, development, test, and agent handoffs. Its version/release policy remains proposed until distribution work begins.
- Use GitHub issues for bounded implementation work; specs own lasting behavior, issues own the change.

## Judgment

Keep the experiment small, native, observable, and replaceable. Discover unknown platform behavior through bounded experiments. Record findings and update changed contracts alongside implementation; do not weaken a contract merely to make a failing implementation pass.

Separate automated results from observed macOS effects and human interaction acceptance. Report missing evidence explicitly. Posting an event does not prove that the intended desktop effect occurred.

For a new behavioral spec or nontrivial implementation, delegate an independent critic review with fresh context containing the relevant artifacts. The critic reports cited findings and does not edit files. Resolve findings before claiming readiness. Routine prose edits do not require this review.

Follow existing user authorization for Git and publication actions. A critic verdict does not grant publication permission or substitute for human acceptance. Version/release roles follow the boundaries in the workflow document.

## Verification

- `scripts/check`: runs the PraxisCore tests and builds `build/debug/Praxis.app`. Fails with a named cause when Swift 6.2+ or the macOS 26 SDK is missing.
- `scripts/test-core`: PraxisCore tests only (Swift Testing). Pass `--filter <name>` to narrow.
- `scripts/build-app`: builds and ad-hoc signs the app bundle, printing its path, identifier, and version.
- `scripts/run-app`: builds and launches the bundle. Observing the menu bar item and debug window is interactive macOS evidence, not part of `scripts/check`.
- Documentation changes: check links and `git diff --check`.

The Command Line Tools are sufficient; Xcode 26.6 is also installed and usable per command via `PRAXIS_DEVELOPER_DIR`, and `xcodebuild` is not used. `scripts/test-app` and `scripts/acceptance` do not exist yet; never report a proposed command as executed. A passing `scripts/check` says nothing about permissions or desktop effects.
