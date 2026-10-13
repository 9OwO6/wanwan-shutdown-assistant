# Verification and evidence boundaries

## Automated checks

GitHub Actions runs schedule boundary tests on Windows and a standard-library Python audit of required runtime assets, catalog counts, transcript/manifest matching, waveform hashes and PCM format. It also syntax-parses PowerShell source.

Interactive WPF tests require a Windows desktop session; they are not advertised as headless CI coverage.

| Test mode | What it exercises |
|---|---|
| `SmokeTest` | Actual WPF construction and render |
| `InteractionTest` | Demo countdown, deferral, cancellation and demo completion |
| `DialogueTest` | 23 scenes, four variations each, matching caption/voice and 92 muted native audio opens |
| `PetTest` | Companion presentation, focus, work-area bounds, animation, four real scheduled phases and 96 muted native audio opens |
| `GuardTest` | Overdue save window, announcement ordering, retry, cancellation, three muted native audio opens and safe privilege acquisition |
| `PetControlsTest` | Routed down/up events with controlled move coordinates, position persistence, hide/menu controls, activation persistence and an overdue reminder with the pet hidden |
| `LifecycleTest` | Explicit application lifetime, background ticks while hidden and restore |
| `CountdownTest` | Acknowledge-to-compact, live ticking, hide/restore/expand, deadline preservation, hidden demo completion, final announcement restoration and simulated shutdown |
| `ShowcaseTest` | Six real UI captures and a 32-frame runtime animation sequence using a synthetic schedule |

All consequential requests in test modes are simulated. `GuardTest` enables the shutdown privilege only in its own test process, but never calls `ExitWindowsEx`. The source deliberately separates that from proof of an actual completed system shutdown.

## Reproduce screenshots

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -ShowcaseTest
python tools\build_showcase.py
```

The capture uses a synthetic 23:30 bedtime, prepared N1 voice routed at zero volume, and disabled real shutdown. `build_showcase.py` requires Pillow; it composes the overview from those captures and assembles the captured animation frames.

## Manual acceptance

1. Launch with automatic shutdown disabled and try the 35-second demo.
2. Drag the avatar, release it and confirm the main window did not accidentally open.
3. Hide the avatar; restore it through the tray and confirm the saved position.
4. Hide the main window; launch again and confirm the same instance is restored.
5. With work saved, enable a real schedule. Check the visible guard state and the save countdown.
6. Verify final speech, any unsaved-work prompts and the actual shutdown outcome on the intended Windows installation.

The last step is intentionally not automated against a developer or CI machine. No claim of universal application-save behavior, signed installation or broad Windows certification is made.
