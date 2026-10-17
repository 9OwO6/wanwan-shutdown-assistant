# AI-assisted engineering: from a bedtime idea to a native Windows product

## The product problem

A basic shutdown timer is easy to ignore. Wanwan explores a more personal interaction: an affectionate fictional companion who gently asks the user to wrap up and rest. The experience needed coherent artwork, a consistent Mandarin voice, animation, visible state and an actual scheduling mechanism.

The scope was deliberately concrete: a local Windows prototype, staged reminders, a controllable desktop avatar and normal shutdown with time to save work.

## Development approach

Codex was used as an engineering collaborator for requirements, PowerShell/WPF implementation, C# interop, debugging, media tooling and tests. Human decisions directed the companion personality, visual quality, preferred N1 voice, dialogue style and whether to enable real automatic shutdown.

This is AI-assisted work, not a claim of manually authoring every line or training a foundation model. The engineering contribution is in turning generated code and media into a coherent, inspectable application—and validating the behavior people actually use.

## Three connected pipelines

### 1. Product behavior

Bedtime settings feed a deterministic schedule function. A WPF Dispatcher timer interprets the phase and selects a reminder, countdown or shutdown announcement. Presentation is separate from the schedule calculation, so clock boundaries can be tested without waiting until midnight.

Cancellation and deferral keys are associated with the relevant bedtime date. An overdue startup receives a two-minute save window instead of immediately requesting shutdown. A pending announcement waits for its reserved audio duration before the request.

### 2. Visual assets

Generated artwork established a consistent adult fictional companion. Ten transparent 2×2 sprite sheets provide forty poses. A reviewed native WPF export pipeline separates them into independent 640×640 transparent PNGs; the application loads those frames and shares the animation state across its surfaces. Frame timing, subtle movement, short transitions and a reduced-motion mode supply the interaction polish without a game engine.

Asset inspection checks transparency and distinct poses; runtime tests check that visible frames actually advance. The README animation is a capture of the application, not a separately animated illustration.

### 3. Voice assets

The selected N1 reference was designed with Qwen3-TTS VoiceDesign, then used with Qwen3-TTS Base to produce consistent companion lines. Runtime catalogs map each line to its actual audio and caption.

The pipeline records reference hashes, text, model revisions, duration and waveform hashes. It uses FFmpeg for PCM conversion, loudness processing and complete decoding. ASR transcript checks identify pronunciation/content differences for review; technical checks do not substitute for human listening.

For clock reminders, 24 whole-sentence hour prefixes are combined with four whole-sentence phase suffixes, separated by a 100 ms pause. This produces 96 prepared reminders while avoiding live synthesis. The main N1 companion bank contains 92 lines across 23 scenes, plus three dedicated guard-status clips.

## Debugging the real user path

| Failure | Cause | Change | Verification |
|---|---|---|---|
| App disappeared after “hide to tray” | `ShowDialog()` returned when hidden; cleanup stopped the timer and disposed the tray | Explicit `Application.Run` lifetime | Hide, observe background ticks and tray, restore, then exit |
| Desktop pet could not be dragged or hidden | Compact avatar had an open action but no drag/hide interaction | Routed pointer handling, movement threshold, saved coordinates, hide controls | Down/move/up routing with controlled pointer coordinates, no accidental opening, persistence and hidden guard tests |
| A visible companion was mistaken for an enabled schedule | Companion visibility and guard state were separate, but presentation did not make that clear | Status on the avatar and a dedicated save-and-enable button | Actual activation button, persisted `Enabled=true`, overdue countdown with hidden avatar |
| Shutdown privilege acquisition could fail | Managed struct layout did not match native `TOKEN_PRIVILEGES` | Explicit DWORD/LUID fields and error-code checking | 16-byte layout and privilege enablement in a test process; no native shutdown |
| A final spoken reminder could be interrupted | Playback was asynchronous, followed immediately by the OS request | Pending announcement state and an audio-duration wait | No simulated request before the announcement interval; cancellation clears pending state |
| Extra sleeves appeared during animation/video export | Generated subjects crossed the atlas halfway lines; a uniform 8-pixel inset still included neighboring arms | Reviewed per-frame clipping and forty independent transparent exports | Seven contaminated slots corrected; opaque-pixel comparison, alpha/gutter checks, connected-component inspection and actual WPF playback |

## Portfolio talking points

- Built a native desktop product using PowerShell/WPF and a narrowly scoped C# interop layer.
- Integrated AI-generated visuals and a synthetic voice as offline, versioned runtime assets.
- Designed deterministic scheduling and isolated test modes around consequential OS behavior.
- Diagnosed user-path failures that were not caught by a successful UI render alone.
- Used runtime captures, native media opening and data integrity checks as evidence.

These are implementation and validation claims. There are no invented user-growth numbers, performance benchmarks, commercial adoption figures or production uptime claims.

## Deliberate tradeoffs

Prepared audio is predictable and works offline, but supports a finite dialogue library and hour-level speech rather than arbitrary live conversation. Sprite animation is lightweight but has no lip synchronization or skeletal rig. PowerShell makes the prototype easy to run on Windows, while an eventual packaged application could improve installation, signing and accessibility.
