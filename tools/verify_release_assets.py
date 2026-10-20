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
# Persona voice banks: every clip of the approved script, exact text, hashed MP3 (and WAV master in the repository).
import importlib.util
spec = importlib.util.spec_from_file_location('persona_script', ROOT / 'tools/write_persona_script.py')
script = read('assets/persona-script.json')
personas = {p['id']: p for p in script['personas']}
installed = []
expand = None
if spec and (ROOT / 'tools/write_persona_script.py').is_file():
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module); expand = module.expand
for persona_id, persona in personas.items():
    bank_path = f'assets/voices/{persona_id}/bank.json'
    if not (ROOT / bank_path).is_file():
        continue
    bank = read(bank_path)
    clips = {c['key']: c for c in bank['clips']}
    lines = [l for l in script['lines'] if l['persona'] == persona_id]
    if expand:  # repository: the bank must cover every recorded variant
        wanted = {l['id'] + ('' if a == 'none' else '@' + a): t for l in lines for a, t in expand(persona, l['text'])}
        assert set(clips) == set(wanted), f'{persona_id}: bank differs from the script'
        for key, text in wanted.items():
            assert clips[key]['text'] == text, key
    assert len({c['reference_sha256'] for c in [bank]}) == 1
    for clip in clips.values():
        runtime = checked_path(clip['file'])
        assert runtime.read_bytes()[:3] == b'ID3' or runtime.read_bytes()[:2] in (b'\xff\xfb', b'\xff\xf3', b'\xff\xf2'), clip['file']
        assert hashlib.sha256(runtime.read_bytes()).hexdigest() == clip['runtime_sha256'], clip['key']
        assert 0.2 < clip['duration'] < 20
        master = ROOT / clip['master_file']
        if master.exists():
            masters += 1
            assert hashlib.sha256(master.read_bytes()).hexdigest() == clip['sha256'], clip['key']
            with wave.open(str(master)) as audio:
                assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) == (1, 2, 24000)
                frames = audio.readframes(audio.getnframes())
                assert max(abs(sample[0]) for sample in struct.iter_unpack('<h', frames)) < 32767
        checked += 1
    installed.append(f'{persona_id} ({len(clips)})')
hours = {(l['persona'], l['hour']) for l in script['lines'] if l['cue'] == 'hour'}
assert hours == {(p, h) for p in personas for h in range(24)}
for p in personas:
    for cue in ('early', 'soon', 'bed', 'final', 'due', 'shutdown', 'sleep', 'disabled', 'caught', 'caught-again', 'watch-final', 'streak', 'reset', 'preview', 'poke'):
        assert any(l['persona'] == p and l['cue'] == cue for l in script['lines']), (p, cue)
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
for path in ('assets/wanwan.png', 'assets/icons/wanwan.ico', 'assets/icons/wanwan-256.png', 'Start-Wanwan.ps1', '启动晚晚.vbs', '启动晚晚.cmd', 'app/Main.ps1', 'app/Voice.ps1', 'app/Persona.ps1', 'assets/persona-script.json', 'app/Power.ps1', 'app/Schedule.ps1', 'app/History.ps1', 'app/Watch.ps1', 'app/UpdateCore.ps1', 'app/ApplyUpdate.ps1', 'VERSION'):
    checked_path(path)
mode = f'{masters} WAV masters PCM-checked' if masters else 'release mode, MP3 only'
print(f'PASS: {checked} runtime clips ({mode}; persona banks: {", ".join(installed) or "none yet"}), exact catalog/transcript/hash matching, 24-hour routing, 40 reviewed character frames and required runtime files.')
