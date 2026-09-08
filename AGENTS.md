# Working on Praxis

Praxis routes human attention between agents through hands and voice. Read [VISION.md](VISION.md) for product intent and non-goals. Preserve the distinction between a recognized gesture, a semantic intent, and an attempted macOS action.

## Context

- Read the relevant `specs/<capability>/spec.md` before implementation. [Spec template](specs/TEMPLATE.md).
- [Scaffold plan](plans/initial-scaffold.md) gives the implementation sequence.
- [Project workflow](plans/project-workflow.md) defines spec, development, test, and agent handoffs. Its version/release policy remains proposed until distribution work begins.
- Use GitHub issues for bounded implementation work; specs own lasting behavior, issues own the change.

## Judgment

Keep the experiment small, native, observable, and replaceable. Discover unknown platform behavior through bounded experiments. Record findings and update changed contracts alongside implementation; do not weaken a contract merely to make a failing implementation pass.

Separate automated results from observed macOS effects and human interaction acceptance. Report missing evidence explicitly. Posting an event does not prove that the intended desktop effect occurred.

For a new behavioral spec or nontrivial implementation, delegate an independent critic review with fresh context containing the relevant artifacts. The critic reports cited findings and does not edit files. Resolve findings before claiming readiness. Routine prose edits do not require this review.

Follow existing user authorization for Git and publication actions. A critic verdict does not grant publication permission or substitute for human acceptance. Version/release roles follow the boundaries in the workflow document.

## Verification

This repository currently contains planning and specifications only. Build, test, and acceptance scripts are not implemented. Check documentation links and `git diff --check` for documentation changes. Add real commands here when the app/package scaffold exists; never report a proposed command as executed.
