# Architecture

```mermaid
flowchart LR
    Settings[Local JSON settings] --> Schedule[Pure schedule calculation]
    Clock[Dispatcher timer] --> Schedule
    Schedule --> Controller[Reminder and countdown controller]
    Controller --> Main[WPF main window]
    Controller --> Pet[Desktop pet and countdown]
    Controller --> Voice[Caption and prepared audio routing]
    Voice --> Player[WPF MediaPlayer / system voice]
    Controller --> Pending[Wait for final announcement]
    Pending --> Power[C# Win32 interop]
    Power --> OS[Normal Windows shutdown request]
    Test[Isolated test mode] --> Fake[Simulated shutdown request]
    Pending --> Fake
    Assets[Versioned catalogs and media] --> Pet
    Assets --> Voice
```

The native and simulated shutdown paths are selected by the test-mode guard. The diagram depicts both available paths, not two simultaneous requests.

## Modules

| Module | Responsibility |
|---|---|
| `Main.ps1` | Window construction, settings, tray, single instance, Dispatcher and shutdown sequence |
| `Schedule.ps1` | Given a clock value and settings, determine bedtime date, deadline and phase |
| `DesktopPet.ps1` | Compact/expanded presentation, dragging, persisted position, hide/open controls and hour reminders |
| `Visuals.ps1` | Shared character surfaces, sprite frames, transitions and reduced motion |
| `Dialogue.ps1` | Scene catalogs, non-repeating line selection and system-voice addressing |
| `Voice.ps1` / `GuardVoice.ps1` | Exact caption/asset routing and audio duration |
| `Icons.ps1` | Window/tray branding and work-area placement |
| `Power.ps1` | Token privilege handling and non-forced shutdown API |

## State and lifetime

The normal app owns an explicit WPF `Application` lifetime. Hiding a window does not terminate its message loop. A named mutex enforces one runtime instance; a named event lets a second launch restore the existing main window. Quitting through the tray ends the application and releases its resources.

Settings and cancellation/deferral markers persist locally. Test modes write into `output/` instead of the user configuration. The showcase uses a synthetic default schedule and muted audio. Neither local logs nor the user's settings are committed to this repository.

## Schedule phases

`Day → Early → Soon → Bed → Final → Due`

Early starts 30 minutes before bedtime, Soon at 10 minutes, Bed at bedtime and Final two minutes before the deadline. Due begins at the deadline. The current nightly window ends four hours after that deadline; later use is associated with a future night rather than forcing a daytime shutdown.

The controller decides whether to show a bubble, a save window or a final announcement. Presentation visibility is independent of an enabled guard: a hidden desktop pet can still receive a scheduled reminder.

## Runtime vs. asset production

Runtime uses bundled artwork and PCM audio. Model weights, GPU libraries and media-generation services are not bundled or loaded by the application. Python generation tools are development utilities; their outputs are validated before runtime playback.
