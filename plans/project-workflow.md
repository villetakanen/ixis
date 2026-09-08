# Project workflow proposal

Status: initial spec, development, and test workflow adopted. Version/release policy remains proposed. Agent configurations and CI gates are not installed.
Date: 2026-09-08

## Operating model

Keep the product experimental and the evidence dependable. Use ASDLC's spec-anchored approach: permanent feature contracts, bounded work items, independent review, and explicit acceptance evidence. Gesture choices and tuning values remain hypotheses until observed in use.

The scaffold sequence is in [initial-scaffold.md](initial-scaffold.md); product intent is in [VISION.md](../VISION.md).

## Artifacts

| Artifact | Owns |
| --- | --- |
| `VISION.md` | Product intent, taste, non-goals |
| `AGENTS.md` | Short navigation and persistent project judgment |
| `ARCHITECTURE.md` | Established system boundaries and toolchain decisions |
| `specs/<capability>/spec.md` | Lasting behavior and verification contract |
| GitHub issue | Bounded change, linked spec clauses, completion evidence |
| `plans/` | Proposed sequencing and investigations |
| `docs/experiments/` | Hardware protocols, measured results, unresolved hypotheses |
| `docs/adrs/` | Consequential decisions and rationale, when needed |
| PR/check artifacts | Diff, test evidence, critic verdict tied to a commit |

Use GitHub issues as the work-item source of truth once implementation starts. Avoid maintaining a duplicate task backlog in Markdown. Start with one implementation stream; add concurrent builders only when file ownership and dependencies are separable.

## Spec-flow

1. Identify a user-visible capability and the uncertainty it resolves.
2. For an unknown platform mechanism, write a bounded experiment with a question, procedure, evidence, and stop condition. A spike concludes with findings, not an implied production contract.
3. Write a small spec with Blueprint (context, boundaries, data/interface contracts) and Contract (observable outcomes, invariants, scenarios).
4. Label each scenario with its evidence method: automated, interactive macOS, or human experience evaluation. Assign stable scenario IDs.
5. Have a fresh critic check ambiguity, contradictory requirements, and whether each claim can actually be verified. Resolve product choices with the human; resolve routine implementation details within the accepted scope.
6. Implement against the spec. Commit discovered behavior changes with the corresponding spec changes. A bug fix restoring existing behavior need not rewrite the contract.

Spec lifecycle: `draft` → `active` → `deprecated`. Draft can guide a bounded spike; active means the contract governs implementation, not that implementation is complete. Record implementation and evidence status separately.

Start with `specs/space-navigation/spec.md` for button → intent → action attempt. Add `specs/hand-observation/spec.md` and `specs/swipe-recognition/spec.md` as those slices begin. Specify debug observability within these contracts until it needs independent evolution. Do not pre-author the speech/window milestones.

Every behavioral acceptance criterion needs an observable result. Example: denied event-posting permission produces a visible blocked result and no attempted keyboard event. A successfully posted event must not be labeled a confirmed Space transition.

## Dev-flow

`issue + relevant spec → short branch → builder → deterministic checks → critic → acceptance → merge`

The builder receives the bounded change, relevant specs, repository instructions, and starting commit. It implements the smallest slice, updates the spec where discoveries change the contract, and makes coherent working commits. Use Conventional Commits for readable history; version decisions also inspect actual behavior.

PR handoff: problem/result, linked issue and scenario IDs, changed contracts, checks and their outcomes, hardware evidence or explicit gaps, and the reviewed commit SHA. Do not use the conversation transcript as the handoff.

The critic reports findings; the builder fixes them. After edits, rerun affected checks and review the new candidate. Existing session authorization governs merge/publish actions; absent that authorization, prepare a concrete result before requesting approval. Human acceptance of an interaction experiment is separate from permission to merge code.

A contract ambiguity returns to spec-flow. Missing Xcode, permissions, camera, or signing capability produces a named unmet gate. None is silently treated as a pass.

## Test-flow

| Layer | What it establishes | Initial cases |
| --- | --- | --- |
| Deterministic core | Temporal recognition and semantic behavior | left/right traces, jitter, slow drift, short motions, cancellation, lost hand, reacquisition, cooldown, timestamp gaps |
| Adapter/integration | Boundary handling | coordinate orientation/mirroring, permission denial, capture interruption, bounded frame processing, key-down/key-up construction |
| Interactive macOS | Actual OS effects on the candidate app | configured shortcuts, revoked permissions, first/last Space, full-screen Spaces, multiple displays |
| Human experiment | Whether the interaction is useful | intentional attempts, ordinary movement without commands, fatigue, perceived latency |

Write behavioral core tests before implementing recognition. Use timestamped normalized traces and a controllable clock; avoid wall-clock sleeps. Include negative traces and real observation traces when available. Synthetic traces alone do not establish recognition accuracy.

Camera images need not be stored for replay; normalized observations can support tuning. Keep local recordings out of the public repository unless explicitly selected for publication.

Each experiment records commit, app build, hardware, macOS, camera setup, configured shortcuts, procedure, number of attempts, misses, duplicate/wrong-direction actions, idle exposure duration, accidental actions, and latency distribution. Separate capture-to-intent, intent-to-post, and observed desktop response latency. Report denominators and measurement methods.

The brief's 20–30 observations/second is an initial target. Establish baseline latency and false-activation data before choosing acceptance thresholds; do not fabricate a performance promise. Human acceptance should explicitly say whether the slice is suitable to continue experimenting with.

Command surface (`scripts/check`, `scripts/test-core`, `scripts/build-app`, and `scripts/run-app` exist; the rest remain proposed):

- `scripts/check`: available deterministic checks, including pure Swift tests and native app build; fail clearly if a required toolchain is missing.
- `scripts/test-core`: fast, repeatable gesture-package tests.
- `scripts/test-app`: app/adapter tests that do not require live desktop control.
- `scripts/acceptance`: guide or collect an interactive hardware run; never report success without observed outcomes.

Exact invocations are documented in [ARCHITECTURE.md](../ARCHITECTURE.md). CI runs headless checks; permission dialogs, camera quality, and actual Space transitions remain explicit interactive evidence. Require the appropriate evidence for the changed capability rather than rerunning unrelated journeys.

## Agent contracts

Roles are bounded invocations with artifact handoffs, not persistent autonomous coworkers. Start with one critic and simple version/release procedures; automate repetitive mechanics through scripts once demonstrated.

| Role | Input | Output | Authority |
| --- | --- | --- | --- |
| Spec author | Vision, experiment results, requested change | Spec draft and verifiable scenarios | Propose contracts; surface product decisions |
| Builder | Work item, active spec, starting tree | Implementation, tests, spec updates, evidence | Edit the scoped implementation |
| Critic | Base/head SHA, diff, relevant specs/instructions, check evidence | Structured verdict and cited findings | Read and verify; report without fixing or merging |
| Version agent | Changes since last release, compatibility policy, current version | Version proposal, rationale, changelog and version-file patch | Prepare version metadata; cannot tag or publish |
| Release agent | Selected commit/version, gate evidence, release scope | Built artifact, checksums, manifest, release notes/draft | Prepare release; publish only within user-authorized scope |

### Critic

Use a fresh context independent of the builder's narrative. Inspect the diff and surrounding code against the relevant contract. Cover negative paths, Swift concurrency ownership, stale observations, repeated actions, permission failures, and evidence gaps.

Output fields: reviewed base/head SHA; scenario coverage; verdict (`pass`, `changes-required`, `inconclusive`); findings with severity, file/line, violated clause, practical consequence, and suggested correction; checks actually executed; unavailable evidence.

Opinions without a violated contract or concrete defect are advisory. Inconclusive hardware claims remain unverified. A pass covers the stated review scope and never substitutes for missing required acceptance. Trivial prose edits do not need a critic invocation.

### Version agent

Proposed initial line: `0.1.0-alpha.1` for the first distributable experimental slice, followed by alpha iterations. This is a proposed policy, not an assigned current version. No release is created merely because the repository exists.

Maintain one canonical product version and a separately increasing app build number. During app scaffolding, verify how prerelease labels map to Apple's bundle-version constraints; do not put an arbitrary SemVer prerelease string into bundle metadata.

Under 0.x, propose a minor increment for a new milestone or incompatible established contract and a patch increment for compatible fixes. Record incompatible changes explicitly; do not infer compatibility solely from commit prefixes. Implementation-only commits need no version bump on their own.

The version agent prepares metadata before the final release candidate is tested. Its output is reviewable code/data, not a release side effect. Mechanical consistency belongs in a script, while the agent explains the change classification.

### Release agent

Build from a clean, selected commit after version changes are included. Bind evidence to that commit and the produced artifact checksum. A release manifest records version/build, source SHA, toolchain, supported platform, test/critic/hardware evidence, artifact checksum, and signing/notarization status.

Separate a local development build from an externally distributed prerelease. Validate signing, packaging, notarization, and installation requirements through current Apple documentation before implementing external distribution. Signing credentials stay outside repository artifacts and agent reports.

Prepare notes, artifact, and a draft release first. When publication is authorized, tag the selected commit and publish those exact artifacts; never silently rebuild a different binary. Verify the published tag/assets. On retry, inspect existing state and refuse conflicting tags or artifacts. Repairs to published binaries receive a new version rather than replacing history.

The release agent cannot waive missing tests, infer human experience acceptance, or edit application behavior to make a release pass. A failed gate returns the work to the owning flow.

## Adoption sequence

The initial repository instructions, [spec template](../specs/TEMPLATE.md), and [Space-navigation contract](../specs/space-navigation/spec.md) are now recorded. The first implementation work item and executable scaffold are next; no runtime verification has occurred.

1. Agree the workflow boundaries and first experiment; add a minimal `AGENTS.md` and spec template.
2. Write the Space-navigation spec and first bounded work item.
3. Establish app identity/toolchain, create the app and package, and implement actual check commands (Milestone 0 scaffold, in progress).
4. Run one complete builder → critic → hardware evidence loop manually.
5. Encode proven checks in CI and review output in a small structured schema.
6. Add version metadata and release automation when the first useful artifact is ready to distribute.

Pending choices: minimum macOS version, signing/team identity, initial distribution audience, and measurable recognition acceptance thresholds. These do not block writing the first spec; they must be resolved before their dependent build/release gates.

## ASDLC grounding

Read on 2026-09-08. The pages below ground the approach; the concrete Praxis agent roles, file layout, lifecycle labels, commands, and version policy above are project proposals, not claimed ASDLC requirements.

- [Getting started](https://asdlc.io/getting-started/): durable specs and bounded changes.
- [Living specs](https://asdlc.io/practices/living-specs/): Blueprint/Contract organization and refinement alongside implementation.
- [Feature assembly](https://asdlc.io/practices/feature-assembly/): contract-led implementation and verification.
- [Adversarial review](https://asdlc.io/practices/adversarial-code-review/): independent critic with actionable contract violations.
- [Context gates](https://asdlc.io/patterns/context-gates/): separate automated, probabilistic, and human evidence.
- [AGENTS.md guidance](https://asdlc.io/practices/agents-md-spec/): minimal durable instructions and tool-enforced rules.
- [Workflow as code](https://asdlc.io/practices/workflow-as-code/): automate mechanical orchestration where warranted; the practice is marked experimental.
