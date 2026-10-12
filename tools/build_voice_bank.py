"""Prepare all four local voice packs, keeping human choice pending."""
import json
import shutil
import subprocess
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "assets" / "voices"
LINES = json.loads((ROOT / "assets" / "voice-lines.json").read_text(encoding="utf-8"))
records = []
for preset, reference, speed in [("A", "cute_dog_reference.wav", .94),
                                  ("D", "female_03.wav", .96)]:
    directory = BANK / preset
    directory.mkdir(parents=True, exist_ok=True)
    for line in LINES:
        target = directory / f'{line["id"]}.wav'
        if not target.exists():
            payload = dict(text_input=line["text"], language="zh-cn",
                           character_voice_gen=reference, narrator_enabled="false",
                           text_not_inside="character", speed=str(speed), temperature="0.65",
                           output_file_name=f'wanwan_{preset}_{line["id"]}',
                           output_file_timestamp="true", autoplay="false")
            req = urllib.request.Request("http://127.0.0.1:7851/api/tts-generate",
                                         data=urllib.parse.urlencode(payload).encode("utf-8"))
            with urllib.request.urlopen(req, timeout=300) as response:
                result = json.load(response)
            if result.get("status") != "generate-success":
                raise RuntimeError(result)
            shutil.copyfile(result["output_file_path"], target)
        print(f'{preset}/{line["id"]} ready', flush=True)
for preset, semitones in [("B", 1), ("C", 2)]:
    directory = BANK / preset
    directory.mkdir(parents=True, exist_ok=True)
    ratio = 2 ** (semitones / 12)
    for line in LINES:
        target = directory / f'{line["id"]}.wav'
        if not target.exists():
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(BANK / "A" / target.name),
                            "-af", f"asetrate=24000*{ratio},aresample=24000,atempo={1 / ratio}",
                            str(target)], check=True)
for preset in "ABCD":
    for line in LINES:
        target = BANK / preset / f'{line["id"]}.wav'
        subprocess.run(["ffmpeg", "-v", "error", "-i", str(target), "-f", "null", "-"], check=True)
        probe = json.loads(subprocess.check_output([
            "ffprobe", "-v", "error", "-show_entries", "format=duration:stream=sample_rate,channels",
            "-of", "json", str(target)], encoding="utf-8"))
        duration = float(probe["format"]["duration"])
        if not .6 < duration < 30:
            raise RuntimeError(f"Unexpected duration: {target} {duration}")
        records.append(dict(preset=preset, id=line["id"], text=line["text"],
                            duration=duration, file=f'{preset}/{target.name}',
                            reference="female_03.wav" if preset == "D" else "cute_dog_reference.wav",
                            semitones={"A": 0, "B": 1, "C": 2, "D": 0}[preset]))
(BANK / "manifest.json").write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Verified {len(records)} voice clips; no voice automatically selected", flush=True)
