"""Dependency-free release audit: catalogs, provenance, PCM and runtime files."""
import hashlib
import json
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8-sig'))

def checked_path(path):
    target = (ROOT / path).resolve()
    assert target.is_relative_to(ROOT), f'Path escapes repository: {path}'
    assert target.is_file(), f'Missing runtime file: {path}'
    return target

checked = 0
for catalog, manifest, count in [
    ('assets/companion-lines.json', 'assets/voices/N1/manifest.json', 92),
    ('assets/clock-lines.json', 'assets/voices/N1-clock/manifest.json', 96),
    ('assets/guard-lines.json', 'assets/voices/N1-guard/manifest.json', 3),
]:
    rows, records = read(catalog)['lines'], read(manifest)
    assert len(rows) == len(records) == count
    assert len({row['id'] for row in rows}) == count
    for row in rows:
        record = next(r for r in records if r['id'] == row['id'])
        assert record['text'] == row['text'] and record['file'] == row['file']
        path = checked_path(row['file'])
        assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], row['id']
        assert record['reference_sha256'] == '3c79b81a7d1c114325e14e73f7c9d58936424f5ec3aa612737f14831f179baec'
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
for item in sprites:
    data = checked_path(f"assets/interactions/{item['id']}.png").read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    # Runtime crops floor(width/2) x floor(height/2); generated sheets may have an odd edge pixel.
    assert width // 2 >= 64 and height // 2 >= 64 and depth == 8 and color == 6
for preset in ('A', 'B', 'C', 'D'):
    checked_path(f'assets/voices/auditions/{preset}.wav')
    for line in read('assets/voice-lines.json'):
        checked_path(f"assets/voices/{preset}/{line['id']}.wav")
for path in ('assets/wanwan.png', 'assets/icons/wanwan.ico', 'assets/wanwan-frames.png', 'Start-Wanwan.ps1', 'app/Main.ps1', 'app/Power.ps1'):
    checked_path(path)
print(f'PASS: {checked} N1 runtime clips, exact catalog/transcript/hash/PCM matching, 24-hour routing, 10 transparent sprite sheets, legacy playback and required runtime files.')
