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

## v0.3: a product review pass with a second AI collaborator

After v0.2 the application worked, but neither release had been downloaded. A product review with Claude started from that metric instead of from the feature list, and found the friction was mostly *before* first use:

| Finding | Evidence | Change |
|---|---|---|
| The download was 103 MB for a bedtime timer | 86 MB of uncompressed 24 kHz PCM; 23 MB of RGBA sprite sheets | MP3 runtime clips with hash-tracked WAV masters; palette + alpha quantization of art in the release only → ~25 MB |
| The biggest objection to auto-shutdown is losing work | Shutdown was the only action | Sleep action; a real-clock resume check grants a fresh two-minute save window instead of sleeping again immediately |
| A fixed bedtime fails on Friday night | Listed as future work in v0.2 | `Get-NightBedtime` assigns each bedtime to its evening; Fri/Sat may use a later time; 10 new boundary tests |
| Autostart depended on `wscript.exe` | VBScript is being deprecated in Windows | Shortcuts launch hidden PowerShell directly; existing shortcuts migrate on start |
| The landing page was English-first for a Chinese-only UI | No Chinese quick start, no SmartScreen/uninstall guidance | Chinese-first README with FAQ; English section kept for reviewers |
| Releases were hand-built ZIPs | — | `build_release.py` + tag-triggered workflow that audits the staged package before publishing |

Two details show why AI output still needs review. The existing N1 guard recording literally says “正常关机” (normal shutdown), so the sleep path announces with an existing goodnight line rather than mislabeling the action. And a resume detector based on the *scheduled* clock would have broken the deterministic tests, which inject time jumps; it uses the real clock instead.

## Portfolio talking points

- Built a native desktop product using PowerShell/WPF and a narrowly scoped C# interop layer.
- Integrated AI-generated visuals and a synthetic voice as offline, versioned runtime assets.
- Designed deterministic scheduling and isolated test modes around consequential OS behavior.
- Diagnosed user-path failures that were not caught by a successful UI render alone.
- Used runtime captures, native media opening and data integrity checks as evidence.

These are implementation and validation claims. There are no invented user-growth numbers, performance benchmarks, commercial adoption figures or production uptime claims.

## Deliberate tradeoffs

Prepared audio is predictable and works offline, but supports a finite dialogue library and hour-level speech rather than arbitrary live conversation. Sprite animation is lightweight but has no lip synchronization or skeletal rig. PowerShell makes the prototype easy to run on Windows, while an eventual packaged application could improve installation, signing and accessibility.
