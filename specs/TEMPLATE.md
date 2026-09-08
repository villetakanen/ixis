---
title: <Capability>
status: draft
implementation: not-started
verification: not-run
---

# <Capability>

Use `draft`, `active`, or `deprecated` for status. Active means the contract governs work; implementation and verification are separate. Replace these instructions and placeholders when copying. Omit sections that add no information.

## Blueprint

### Context

State the user problem, the slice covered, and the relevant vision/plan links.

### Architecture

Describe inputs, outputs, ownership, dependency direction, and data/interface contracts. Link existing source paths; label proposed paths as proposed. Keep implementation detail only where it constrains compatibility or verification.

### Constraints

State capability-specific invariants and scope boundaries. Distinguish established behavior from hypotheses awaiting an experiment.

## Contract

### Definition of done

- [ ] Observable outcome linked to scenario IDs and its evidence method.

### Regression guardrails

List durable invariants that remain true across subsequent changes.

### Scenarios

#### <PREFIX>-001: <Observable behavior>

Evidence: automated | interactive macOS | human experience evaluation (select applicable methods).

```gherkin
Given <explicit preconditions>
When <one meaningful trigger>
Then <observable outcome>
And <relevant invariant>
```

Keep scenario IDs stable. Name the test oracle; distinguish a simulated boundary result from an actual platform effect.

## Evidence

Link actual results with source commit, environment, procedure, and outcome. Mark unexecuted scenarios as not run. Required evidence that is unavailable remains an unmet gate.

## Open questions

For each unknown, name the experiment or decision needed and which work it blocks. Do not silently promote a hypothesis into a guarantee.
