# Atlas bleed audit and video-ready character frames

![Three representative before/after frame repairs](screenshots/frame-repair-comparison.png)

## Finding

The generated 2×2 atlases are not exact, isolated rectangular cells. Some sleeves cross the nominal halfway boundary. The old renderer split each atlas equally and inset every cell by eight pixels; that still exposed a neighboring sleeve in seven of the forty poses.

Affected zero-based slots: `peek/3`, `stretch/0`, `nod/3`, `heart/3`, `cheer/3`, `wave/3`, and `goodnight/3`. Six contain a separate edge component. In `peek/3`, the neighboring sleeve joins the lower atlas seam, requiring an explicit reviewed left boundary rather than a largest-component-only rule.

## Fix

Runtime now loads forty independent **640×640 RGBA PNGs** from [`assets/frames/`](../assets/frames/), with consistent per-action placement and a transparent gutter. The original atlases remain as production source inputs; use the independent frames for video or animation instead of splitting those atlases again.

`assets/character-frame-layout.json` records the exact source rectangle, source SHA-256, transparent-canvas offset and excluded edge spans. The six disconnected sleeves receive narrow silhouette-based exclusions; the connected `peek/3` strip has a reviewed 40-pixel left boundary. `heart/3` uses shaped exclusions because a rectangular deletion would also cut valid sleeve pixels.

The exporter uses native WPF clipping at **1:1 source scale**. It does not regenerate faces, repaint hands, enlarge every crop margin, or resample the character. All opaque RGB pixels outside the reviewed edge exclusions are checked against the source atlas. The central face/hand region is protected from clipping.

## Reproduce and validate

Pillow and NumPy are required only for the inspection/layout tools. The WPF exporter runs in Windows PowerShell.

```powershell
python tools/audit_sprite_frames.py
python tools/prepare_character_frame_layout.py
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File tools/export_character_frames.ps1
python tools/validate_interactions.py
```

Validation checks all forty exports for dimensions, alpha gutters, distinct poses, remaining significant disconnected components, cleared exclusion regions, source hashes and unchanged opaque source pixels. CI runs this audit as well. Runtime WPF tests exercise all ten interactions, forty poses and the countdown surfaces.

Read-only contact sheets and per-frame reports are written to `output/`. The source atlas files are retained unchanged for reproducibility. Images are prepared from existing art through deterministic crop geometry; no generative image edit was used for this repair.
