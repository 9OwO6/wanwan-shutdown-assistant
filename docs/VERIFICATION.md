# Verification and evidence boundaries

## Automated checks

GitHub Actions runs 26 schedule boundary tests, 16 bedtime-history tests and 16 update tests (version order, asset origin, installer file replacement) (including Fri/Sat weekend bedtimes, after-midnight nights and sleep-watch windows) on Windows and a standard-library Python audit of required runtime assets, catalog counts, transcript/manifest matching, MP3 runtime hashes, WAV master hashes and PCM format. It also syntax-parses PowerShell source and builds/audits the slim portable package.

Interactive WPF tests require a Windows desktop session; they are not advertised as headless CI coverage.

| Test mode | What it exercises |
|---|---|
| `SmokeTest` | Actual WPF construction and render |
| `InteractionTest` | Demo countdown, deferral, cancellation and demo completion |
| `DialogueTest` | 23 scenes, four variations each, matching caption/voice and 92 muted native audio opens |
| `PetTest` | Companion presentation, focus, work-area bounds, animation, four real scheduled phases and 96 muted native audio opens |
| `GuardTest` | Overdue save window, announcement ordering, retry, cancellation, the sleep action (goodnight line instead of the shutdown recording, fresh save window after the request, countdown closed when the night ends), three muted native audio opens and safe privilege acquisition |
| `PetControlsTest` | Routed down/up events with controlled move coordinates, position persistence, hide/menu controls, activation persistence and an overdue reminder with the pet hidden |
| `LifecycleTest` | Explicit application lifetime, background ticks while hidden and restore |
| `CountdownTest` | Acknowledge-to-compact, live ticking, hide/restore/expand, deadline preservation, hidden demo completion, final announcement restoration and simulated shutdown |
| `WatchTest` | Sleep watch after a guarded night (WakeGrace countdown, caught and caught-again lines, final line before the simulated request, caught record kept), window end, unguarded overdue unchanged, morning streak greeting once, update installer arguments resuming an active countdown |
| `ShowcaseTest` | Six real UI captures and a 32-frame runtime animation sequence using a synthetic schedule |

All consequential requests in test modes are simulated. `GuardTest` enables the shutdown privilege only in its own test process, but never calls `ExitWindowsEx` or `SetSuspendState`. The source deliberately separates that from proof of an actual completed system shutdown.

## Reproduce screenshots

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -ShowcaseTest
python tools\build_showcase.py
```

The capture uses a synthetic 23:30 bedtime (01:00 on Fri/Sat), prepared N1 voice routed at zero volume, and disabled real shutdown. `build_showcase.py` requires Pillow; it composes the overview from those captures and assembles the captured animation frames.

## Portable release

```powershell
python tools\build_release.py v0.3.0
```

Stages only runtime files, quantizes character art to a 256-colour palette with alpha when `imagequant` is installed, audits the staged folder with `verify_release_assets.py` (release mode: MP3 hashes, catalogs, sprite sheets, launchers) and writes `dist/Wanwan-<version>-windows.zip`. CI builds it on every push; pushing a `v*` tag publishes it as a release with `docs/releases/<tag>.md` as notes.

## Manual acceptance

1. Launch with automatic shutdown disabled and try the 35-second demo.
2. Drag the avatar, release it and confirm the main window did not accidentally open.
3. Hide the avatar; restore it through the tray and confirm the saved position.
4. Hide the main window; launch again and confirm the same instance is restored.
5. With work saved, enable a real schedule. Check the visible guard state and the save countdown. Repeat with the sleep action and confirm the fresh two-minute window after waking.
6. Verify final speech, any unsaved-work prompts and the actual shutdown outcome on the intended Windows installation.

The last step is intentionally not automated against a developer or CI machine. No claim of universal application-save behavior, signed installation or broad Windows certification is made.
