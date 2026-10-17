# Wanwan: video-ready character frames

Forty independent **640×640 RGBA PNGs**. Each action folder contains `0.png` through `3.png`; use their alpha channel when compositing onto your video background. Placement is consistent within each action, so avoid independently auto-trimming every image if you want a stable animation anchor.

| Folder | Gesture |
|---|---|
| `peek` | Checking in / leaning toward you |
| `pat` | Reaching out for a gentle pat |
| `water` | Offering a cup |
| `stretch` | Stretching |
| `nod` | Acknowledging / thumbs up |
| `heart` | Forming a heart |
| `cheer` | Encouragement |
| `wave` | Waving |
| `yawn` | Getting sleepy |
| `goodnight` | Saying goodnight |

These are reviewed native-scale exports from the original character atlases, with seven neighboring-sleeve artifacts removed. They are the same images used by the app. See `docs/FRAME_REPAIR.md` and `assets/character-frame-layout.json` in the repository for the audit and exact crop geometry.

**Media terms:** provided for running and evaluating the Wanwan personal portfolio project. The code's MIT license does not grant unrestricted commercial reuse of the character artwork. Contact the repository owner for separate reuse permission. See the repository's `NOTICE.md`.
