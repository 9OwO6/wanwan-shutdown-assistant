"""Generate local XTTS auditions without changing AllTalk configuration."""
import json
import shutil
import subprocess
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "voice-auditions"
OUT.mkdir(parents=True, exist_ok=True)
TEXT = "已经有点晚啦。先保存一下，好不好？我陪你慢慢收尾，晚安。"
CANDIDATES = [
    ("A", "cute_dog_reference.wav", 0, 0.94, "原声"),
    ("B", "cute_dog_reference.wav", 1, 0.94, "轻微升调"),
    ("C", "cute_dog_reference.wav", 2, 0.94, "明亮升调"),
    ("D", "female_03.wav", 0, 0.96, "另一女声"),
]
manifest = []
for code, voice, pitch, speed, label in CANDIDATES:
    target = OUT / f"{code}.wav"
    if not target.exists() and code in ("B", "C"):
        # XTTS 不支持 pitch 参数：从同一原声做明确标注的轻微升调。
        ratio = 2 ** (pitch / 12)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(OUT / "A.wav"),
                        "-af", f"asetrate=24000*{ratio},aresample=24000,atempo={1 / ratio}",
                        str(target)], check=True)
    elif not target.exists():
        params = dict(text_input=TEXT, character_voice_gen=voice,
                      language="zh-cn", narrator_enabled="false",
                      text_not_inside="character", output_file_name=f"wanwan_audition_{code}",
                      output_file_timestamp="true", autoplay="false",
                      speed=str(speed), temperature="0.65")
        req = urllib.request.Request("http://127.0.0.1:7851/api/tts-generate",
                                     data=urllib.parse.urlencode(params).encode("utf-8"))
        with urllib.request.urlopen(req, timeout=240) as response:
            result = json.load(response)
        if result.get("status") != "generate-success":
            raise RuntimeError(result)
        shutil.copyfile(result["output_file_path"], target)
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration:stream=sample_rate,channels",
        "-of", "json", str(target)], encoding="utf-8"))
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(target), "-f", "null", "-"], check=True)
    seconds = float(probe["format"]["duration"])
    if not 2 < seconds < 30:
        raise RuntimeError(f"Unexpected duration: {target} {seconds}")
    manifest.append(dict(id=code, label=label, reference=voice, pitch=pitch,
                         speed=speed, text=TEXT, file=target.name, duration=seconds))
    print(f"{code}: generated and decoded ({seconds:.1f}s)", flush=True)
(OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
