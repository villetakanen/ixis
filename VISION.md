# Praxis

> Intent into action.

## What we are building

Praxis lets you conduct agents with your hands and voice. It is an experimental macOS interaction layer for working with multiple AI agents.

The core idea is not "gesture control for macOS" and explicitly not air-mouse emulation.

Instead:

> Hands control attention and space.  
> Voice expresses intent.  
> A gesture commits the intent.

The primary use case is a user working with several agent interfaces simultaneously — for example ChatGPT, Codex, Claude, terminal-based agents, browser-based agents, etc.

Rather than moving a mouse between them:

1. Gesture toward / navigate to an agent window.
2. Praxis focuses that window.
3. Speak naturally.
4. macOS speech-to-text enters the instruction into the focused application.
5. Perform a commit gesture.
6. Praxis sends Enter / Return.
7. Gesture to another agent/window and continue.

The Minority Report inspiration is deliberate, but the goal is a genuinely useful interaction model rather than visual theatrics.

The user is not manipulating a pointer.

The user is conducting a spatial collection of agents.


# Product hypothesis

AI-heavy work changes the desktop interaction problem.

A user may have several semi-autonomous agents working simultaneously. Mouse-and-keyboard interaction requires repeatedly:

- locate window
- move pointer
- click
- find input
- type
- submit
- switch context

Praxis explores whether this can instead become:

    LOOK / GESTURE → SPEAK → COMMIT

The important abstraction is therefore semantic interaction with windows and workspaces, not continuous pointer control.


# Platform

Target:

- macOS
- Apple Silicon
- Swift 6
- Native macOS application
- Prefer Apple frameworks
- Avoid third-party dependencies for the initial prototype

Likely frameworks:

- SwiftUI / AppKit
- AVFoundation
- Vision
- Accessibility / AXUIElement
- CoreGraphics / CGEvent
- Speech, Dictation, or other appropriate native macOS speech facilities

Investigate the correct current Apple APIs rather than assuming specific APIs from this brief.


# Architecture

Keep the architecture deliberately small.

Conceptually:

    Camera
       │
       ▼
    Hand Tracking
       │
       ▼
    Gesture Recognition
       │
       ▼
    Semantic Intent
       │
       ▼
    Desktop Controller
       │
       ├── Window focus
       ├── Window manipulation
       ├── Space navigation
       └── Commit / Return

Speech is a parallel input:

    Microphone / macOS Dictation
       │
       ▼
    Text
       │
       ▼
    Currently focused agent

The two input channels should remain conceptually separate.

Gestures answer:

    WHERE?
    WHEN?

Speech answers:

    WHAT?


# Important architectural principle

Do not couple raw gestures directly to macOS actions.

Use semantic intents.

For example:

    HandTracker
        ↓
    GestureRecognizer
        ↓
    .select(direction)
    .nextWorkspace
    .previousWorkspace
    .maximize
    .restore
    .commit
        ↓
    DesktopController

This lets us completely change the gesture vocabulary later without rewriting macOS integration.


# Suggested project structure

    Praxis/
    ├── App/
    │   ├── PraxisApp.swift
    │   └── AppState.swift
    │
    ├── Camera/
    │   └── CameraCapture.swift
    │
    ├── Vision/
    │   ├── HandTracker.swift
    │   ├── HandPose.swift
    │   └── HandLandmark.swift
    │
    ├── Gestures/
    │   ├── GestureRecognizer.swift
    │   ├── GestureState.swift
    │   ├── GestureIntent.swift
    │   └── MotionFilter.swift
    │
    ├── Desktop/
    │   ├── DesktopController.swift
    │   ├── WindowController.swift
    │   ├── SpaceController.swift
    │   └── KeyboardController.swift
    │
    ├── Speech/
    │   └── SpeechController.swift
    │
    ├── Permissions/
    │   └── PermissionManager.swift
    │
    └── UI/
        ├── MenuBarView.swift
        └── DebugView.swift


# Interaction model

Do NOT begin by implementing a large gesture vocabulary.

The first prototype exists to discover the vocabulary.

Start with a handful of primitives.

Candidate primitives:

    directional swipe
    pinch
    open palm
    grab / fist
    spread
    hold

These are hypotheses, not requirements.


## Candidate mappings

For example:

    swipe left/right
        → switch macOS Space

    directional selection gesture
        → focus adjacent / indicated window

    spread
        → maximize focused window

    pinch / grab + movement
        → potentially manipulate focused window

    short deliberate commit gesture
        → Return

The exact commit gesture should be easy, fast and extremely difficult to trigger accidentally.


# Speech

Speech should NOT initially be an AI feature of Praxis.

Do not build:

    speech → LLM → intent classification

Praxis should preferably use native macOS speech/dictation capabilities to enter text into the currently selected application.

The target application owns the conversation.

For example:

    Praxis focuses Claude
            ↓
    user dictates
            ↓
    text appears in Claude
            ↓
    commit gesture
            ↓
    Praxis sends Return

Then:

    gesture → Codex
            ↓
    user speaks
            ↓
    text appears in Codex
            ↓
    gesture → commit

Praxis is therefore a ROUTER of human attention, not another agent sitting between the human and their agents.


# Window selection

This is one of the important experiments.

We need to determine what "gesture toward that window" should actually mean.

Possible approaches include:

1. Relative navigation

       gesture left
           → focus window logically/spatially left

2. Spatial mapping

       hand position corresponds approximately to regions of the display

3. Application/window carousel

       repeated gesture cycles through available agent windows

4. Workspace/Space-oriented navigation

       gestures primarily navigate macOS Spaces rather than individual windows

Do not prematurely choose a complicated spatial algorithm.

Prototype the simplest reliable mechanism first.


# Spaces

Switching macOS Spaces is a first-class interaction.

Prefer supported public macOS mechanisms.

If there is no appropriate public API, investigate generating the equivalent configured keyboard shortcut through CGEvent rather than relying on private WindowServer APIs.

Avoid private APIs in the initial implementation.


# Gesture recognition

Do not classify every camera frame independently into commands.

Gesture recognition must be temporal.

Conceptually:

    observations
        ↓
    hand state
        ↓
    trajectory
        ↓
    gesture state machine
        ↓
    semantic intent

Example:

    hand enters
    ↓
    open palm
    ↓
    rapid horizontal trajectory
    ↓
    release / deceleration
    ↓
    SWIPE_RIGHT

Use hysteresis, minimum durations, velocity thresholds and cooldowns to avoid accidental activation.


# Hand tracking

Use Apple's Vision hand-pose capabilities unless investigation demonstrates a concrete reason not to.

Normalize coordinates so gesture recognition is independent of:

- camera resolution
- display resolution
- distance from camera where reasonably possible

The gesture layer should operate on normalized hand observations rather than Vision-specific objects.


# Safety against accidental input

This matters enormously.

A prototype that occasionally fires unintended commands will feel unusable regardless of recognition accuracy.

Design for:

- activation/deactivation state
- gesture confidence
- hysteresis
- cooldown after actions
- deliberate commit gesture
- hand-lost handling
- cancellation

Consider an activation pose or other mechanism, but don't overdesign it before testing.


# Debug UI

Although the final product should disappear into the background, the prototype needs an excellent debug view.

Provide an optional window showing:

- camera preview
- detected hand landmarks/skeleton
- recognized hand state
- current gesture state
- current semantic intent
- confidence
- current focused window/application
- recent intent history

Example:

    HAND      detected
    STATE     openPalm
    MOTION    right, 1.34 normalized units/sec
    GESTURE   swipeRight
    INTENT    nextSpace
    TARGET    Codex
    COOLDOWN  180ms

This will be essential for tuning the interaction.


# Menu bar application

Praxis should normally run as a menu bar utility.

Menu should provide roughly:

    Praxis
    ─────────────
    ● Gesture Control
    ● Dictation
    ─────────────
    Open Debug View
    Calibrate
    ─────────────
    Permissions…
    Quit

Exact UI is not important yet.


# Permissions

Handle macOS permissions properly.

Likely permissions include:

- Camera
- Microphone / speech recognition if required
- Accessibility

The application should detect missing permissions and clearly explain what is needed.

Do not silently fail.


# Performance

This interaction must feel immediate.

Prioritize latency over visual polish.

Camera processing does not necessarily need to run at the camera's maximum frame rate.

Target approximately 20–30 useful hand observations per second initially.

Avoid blocking the main thread.

Window/keyboard actions should happen effectively immediately after gesture recognition.


# Explicit non-goals for v0

Do NOT implement:

- air mouse
- cursor positioning
- gesture-controlled pointer
- custom LLM
- agent orchestration backend
- agent APIs
- screen understanding
- OCR
- application-specific Claude/ChatGPT/Codex integrations
- elaborate settings
- custom gesture training
- cloud services
- cross-platform support

If we find ourselves building these, reconsider the architecture.


# First milestone

Build the smallest vertical slice proving:

    camera
       ↓
    hand tracking
       ↓
    swipe recognition
       ↓
    semantic intent
       ↓
    macOS action

Specifically:

    SWIPE LEFT  → previous Space
    SWIPE RIGHT → next Space

The debug view should display the camera, landmarks and detected gesture.

Nothing else is required for this milestone.


# Second milestone

Add focused-window operations.

Prove:

    gesture
       ↓
    select/focus window

and:

    gesture
       ↓
    maximize/restore focused window

Use AXUIElement / Accessibility where appropriate.


# Third milestone

Add speech + commit.

Prove the complete interaction:

    select agent window
        ↓
    dictate text
        ↓
    commit gesture
        ↓
    Return
        ↓
    select another agent
        ↓
    dictate
        ↓
    commit

At this point we can evaluate whether Praxis actually changes the experience of working with multiple agents.


# Engineering approach

Treat this as an interaction experiment, not a production application.

Keep components separable and observable.

Prefer:

    simple
    native
    measurable
    replaceable

over:

    abstract
    generalized
    configurable
    clever

Especially avoid building a generic gesture framework before we know which gestures actually work.


# Success criterion

The prototype succeeds if this interaction feels natural:

> I have ChatGPT, Claude and Codex working.
>
> Without touching mouse or keyboard, I gesture between their workspaces,
> speak an instruction to whichever one I bring into focus, and make a
> small physical gesture to send it.

The desired subjective experience is not:

> "I can control my Mac with gestures."

It is:

> "I am conducting several agents with my hands and voice."

That distinction should guide every implementation decision.
