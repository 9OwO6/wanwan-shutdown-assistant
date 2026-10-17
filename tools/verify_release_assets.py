"""Dependency-free release audit: catalogs, provenance, PCM and runtime files.

Runs against the repository (WAV masters present: also checks PCM format,
duration and master hashes) or against an extracted portable release
(``python tools/verify_release_assets.py path/to/Wanwan``), which ships only the
MP3 runtime clips.
"""
import hashlib
import json
import struct
import sys
import wave
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]

def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8-sig'))

def checked_path(path):
    target = (ROOT / path).resolve()
    assert target.is_relative_to(ROOT), f'Path escapes repository: {path}'
    assert target.is_file(), f'Missing runtime file: {path}'
    return target

checked = 0
masters = 0
for catalog, manifest, count in [
    ('assets/companion-lines.json', 'assets/voices/N1/manifest.json', 92),
    ('assets/clock-lines.json', 'assets/voices/N1-clock/manifest.json', 96),
    ('assets/guard-lines.json', 'assets/voices/N1-guard/manifest.json', 3),
    ('assets/watch-lines.json', 'assets/voices/N1-watch/manifest.json', 5),
]:
    rows, records = read(catalog)['lines'], read(manifest)
    assert len(rows) == len(records) == count
    assert len({row['id'] for row in rows}) == count
    for row in rows:
        record = next(r for r in records if r['id'] == row['id'])
        assert record['text'] == row['text'] and record['runtime_file'] == row['file']
        runtime = checked_path(row['file'])
        assert runtime.read_bytes()[:2] in (b'\xff\xfb', b'\xff\xf3', b'\xff\xf2'), f'Not an MP3 frame: {row["file"]}'
        assert hashlib.sha256(runtime.read_bytes()).hexdigest() == record['runtime_sha256'], row['id']
        assert record['reference_sha256'] == '3c79b81a7d1c114325e14e73f7c9d58936424f5ec3aa612737f14831f179baec'
        assert 1 < record['duration'] < 20
        path = ROOT / record['file']
        if not path.exists():  # portable release: WAV masters are not shipped
            checked += 1
            continue
        masters += 1
        assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], row['id']
        with wave.open(str(path)) as audio:
            assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) == (1, 2, 24000)
            frames = audio.readframes(audio.getnframes())
            duration = audio.getnframes() / audio.getframerate()
            assert 1 < duration < 20 and abs(duration - record['duration']) < 0.01
            assert len(frames) == audio.getnframes() * 2
            assert max(abs(sample[0]) for sample in struct.iter_unpack('<h', frames)) < 32767
        checked += 1

clock = read('assets/clock-lines.json')['lines']
assert {(r['hour'], r['cue']) for r in clock} == {(h, c) for h in range(24) for c in ('early', 'soon', 'bed', 'final')}
sprites = read('assets/interactions.json')
assert len(sprites) == 10
# Source atlases are production inputs kept in the repository only; the app plays the reviewed frames.
release_mode = not (ROOT / 'assets/interactions').exists()
for item in sprites if not release_mode else []:
    data = checked_path(f"assets/interactions/{item['id']}.png").read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    assert width // 2 >= 64 and height // 2 >= 64 and depth == 8 and color == 6
layout = read('assets/character-frame-layout.json')
assert layout['canvas'] == [640, 640] and len(layout['frames']) == 40
for frame in layout['frames']:
    data = checked_path(frame['file']).read_bytes()
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    # RGBA in the repository; 256-colour palette + alpha (type 3) in the portable release.
    assert data[:8] == b'\x89PNG\r\n\x1a\n' and (width, height, depth) == (640, 640, 8) and color in ((3, 6) if release_mode else (6,))
    if not release_mode:
        assert hashlib.sha256(checked_path(frame['source']).read_bytes()).hexdigest() == frame['source_sha256']
legacy = read('assets/voices/manifest.json')
for preset in ('A', 'B', 'C', 'D'):
    checked_path(f'assets/voices/auditions/{preset}.mp3')
    for line in read('assets/voice-lines.json'):
        record = next(r for r in legacy if r['preset'] == preset and r['id'] == line['id'])
        clip = checked_path(f"assets/voices/{preset}/{line['id']}.mp3")
        assert hashlib.sha256(clip.read_bytes()).hexdigest() == record['runtime_sha256']
for path in ('assets/wanwan.png', 'assets/icons/wanwan.ico', 'assets/icons/wanwan-256.png', 'Start-Wanwan.ps1', '启动晚晚.vbs', '启动晚晚.cmd', 'app/Main.ps1', 'app/Power.ps1', 'app/Schedule.ps1', 'app/History.ps1', 'app/Watch.ps1', 'app/UpdateCore.ps1', 'app/ApplyUpdate.ps1', 'assets/watch-lines.json', 'VERSION'):
    checked_path(path)
mode = f'{masters} WAV masters PCM-checked' if masters else 'release mode, MP3 only'
print(f'PASS: {checked} N1 runtime clips ({mode}), exact catalog/transcript/hash matching, 24-hour routing, 40 reviewed character frames, legacy playback and required runtime files.')
