"""Encode the WAV voice masters into compact MP3 runtime clips.

The WAV files stay in the repository as the production masters that the
generation and verification tools work with. The application only plays the
MP3 copies, which keeps the portable download small (~70 MB of PCM becomes
~10 MB). Run this again after regenerating or replacing any voice line:

    python tools/encode_runtime_audio.py

It needs ffmpeg with libmp3lame on PATH. Catalog ``file`` fields are pointed at
the MP3 copies; manifests keep describing the WAV master (``file``/``sha256``)
and gain ``runtime_file``/``runtime_sha256`` for the MP3 that ships.
"""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BITRATE = '64k'

BANKS = [
    ('assets/companion-lines.json', 'assets/voices/N1/manifest.json'),
    ('assets/clock-lines.json', 'assets/voices/N1-clock/manifest.json'),
    ('assets/guard-lines.json', 'assets/voices/N1-guard/manifest.json'),
    ('assets/watch-lines.json', 'assets/voices/N1-watch/manifest.json'),
]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def to_mp3_path(rel):
    return rel[:-4] + '.mp3' if rel.endswith('.wav') else rel


def encode(src_rel):
    src = ROOT / src_rel
    dst = ROOT / to_mp3_path(src_rel)
    if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
        subprocess.run(
            ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(src),
             '-ac', '1', '-codec:a', 'libmp3lame', '-b:a', BITRATE,
             '-map_metadata', '-1', '-id3v2_version', '0', '-write_xing', '1', str(dst)],
            check=True)
    return dst


def read(rel):
    return json.loads((ROOT / rel).read_text(encoding='utf-8-sig'))


def write(rel, data, compact_lines=False):
    path = ROOT / rel
    if compact_lines:
        # guard-lines.json is hand-maintained in a one-line-per-entry layout.
        body = ',\n'.join(' ' + json.dumps(line, ensure_ascii=False, separators=(',', ':')) for line in data['lines'])
        head = {k: v for k, v in data.items() if k != 'lines'}
        prefix = json.dumps(head, ensure_ascii=False, separators=(',', ':'))[:-1]
        path.write_text(prefix + ',"lines":[\n' + body + '\n]}\n', encoding='utf-8')
    else:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


encoded = 0
for catalog_rel, manifest_rel in BANKS:
    catalog, manifest = read(catalog_rel), read(manifest_rel)
    by_id = {record['id']: record for record in manifest}
    for row in catalog['lines']:
        record = by_id[row['id']]
        master_rel = record['file']
        assert master_rel.endswith('.wav'), master_rel
        mp3 = encode(master_rel)
        row['file'] = to_mp3_path(master_rel)
        record['runtime_file'] = row['file']
        record['runtime_sha256'] = sha256(mp3)
        encoded += 1
    write(catalog_rel, catalog, compact_lines=catalog_rel.endswith(('guard-lines.json', 'watch-lines.json')))
    write(manifest_rel, manifest)

# Legacy 11-line presets A-D and their audition previews.
legacy_rel = 'assets/voices/manifest.json'
legacy = read(legacy_rel)
for record in legacy:
    master_rel = 'assets/voices/' + record['file']
    mp3 = encode(master_rel)
    record['runtime_file'] = to_mp3_path(record['file'])
    record['runtime_sha256'] = sha256(mp3)
    encoded += 1
write(legacy_rel, legacy)
for preset in 'ABCD':
    encode(f'assets/voices/auditions/{preset}.wav')
    encoded += 1

print(f'Encoded {encoded} runtime clips as {BITRATE} MP3.')
