# Media provenance and reproduction

## Bundled runtime assets

The featured character is an original fictional adult companion generated through image tools. `assets/interaction-sources.json` retains generation prompts/artifact identifiers; `assets/icons/source.json` records the icon brief and resolutions. Local user-directory paths were removed for publication.

The N1 voice reference was generated with Qwen3-TTS VoiceDesign, using the N1 brief in `assets/voice-lab-candidates.json`. It is a synthetic design reference, not a recording of the developer. Its SHA-256 is `3c79b81a7d1c114325e14e73f7c9d58936424f5ec3aa612737f14831f179baec`. Subsequent N1 clips were generated using the same reference with Qwen3-TTS Base. The reference and a provenance record are included under `assets/voices/reference/`.

| Asset set | Catalog / manifest | Purpose |
|---|---|---|
| 92 N1 companion lines | `companion-lines.json`, `voices/N1/manifest.json` | 23 scenes × four variations |
| 96 N1 clock reminders | `clock-lines.json`, `voices/N1-clock/manifest.json` | 24 hours × four schedule phases |
| 3 N1 guard lines | `guard-lines.json`, `voices/N1-guard/manifest.json` | Overdue, final announcement, guard-off status |
| 28 clock fragments | `clock-parts.json`, `voices/N1-clock/parts-manifest.json` | Whole-sentence prefixes and suffixes used by the composer |
| 40 reviewed 640×640 PNG frames | `frames/`, `character-frame-layout.json` | Runtime playback and video-ready transparent assets |
| 10 original sprite atlases | `interactions.json`, `interaction-sources.json` | Unchanged production inputs; do not re-split equally for video |
| Multi-size icon | `icons/source.json` | Main window, tray and shortcuts |

**Runtime format.** The WAV files are production masters. The application plays 64 kbps mono MP3 copies created by `python tools/encode_runtime_audio.py` (needs FFmpeg); catalogs point at the MP3, manifests keep the master `file`/`sha256` and add `runtime_file`/`runtime_sha256`. Re-run the encoder after regenerating any line. The portable release ships only the MP3 copies and palette-quantized character art.

Legacy A/B/C/D clips and their auditions remain to keep the existing voice selector runnable. N1 is the selected and featured production voice. Legacy raw backups, experimental captures, generation logs and third-party executables are excluded from the public repository.

## Optional development dependencies

See [frame repair and reproduction](FRAME_REPAIR.md) for the corrected native WPF export pipeline. Individual poses are zero-indexed as `assets/frames/{action}/0.png` through `3.png`; all use transparent 640×640 canvases and consistent placement within each action.

Running the app does not require any of these. Generating or deeply analyzing media requires separately installed packages/models: Qwen3-TTS, PyTorch, NumPy, SoundFile, Pillow, FFmpeg, and the selected ASR environment. Model weights are not included.

The main N1 generator accepts a local model directory and an optional reference:

```powershell
python tools/generate_n1_bank.py --model C:/Models/Qwen3-TTS-Base
python tools/generate_n1_bank.py --model C:/Models/Qwen3-TTS-Base --catalog assets/guard-lines.json --manifest assets/voices/N1-guard/manifest.json --raw-dir output/voice-lab/guard-bank
```

Generation is resumable and records text, hashes, durations and model revision. Clock composition uses complete spoken fragments with a 100 ms pause. Validation should include waveform decoding, text checks and listening; a matching hash alone says nothing about whether a voice sounds natural.

Historical voice-lab/AllTalk/XTTS scripts preserve their original environment assumptions and are provided as development history, not turnkey setup instructions. The optional DeepFilterNet binary must be obtained separately; its license notice is retained.

See `NOTICE.md` for code/media licensing boundaries.
