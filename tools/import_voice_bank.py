"""Import a generated split voice bank (address + body clips) into assets/voices/<voice>/.

    python tools/import_voice_bank.py V3 path/to/output/voice-bank/V3

The source folder is what the generation run produced: ``manifest.json`` plus
``lines/``, ``clock/`` and ``address/`` WAV files. Every clip must match the text in
``assets/voice-script.json`` exactly; anything missing or different stops the import.
WAV masters are copied into the repository, MP3 runtime copies are encoded next to
them (needs ffmpeg with libmp3lame), and ``bank.json`` lists what the app plays.
"""
import hashlib
import json
import shutil
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BITRATE = '64k'
FOLDER = {'line': 'lines', 'hour': 'clock', 'tail': 'clock', 'address': 'address'}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected_clips():
    script = json.loads((ROOT / 'assets/voice-script.json').read_text(encoding='utf-8'))
    clips = [('line', row['id'], row['body']) for row in script['lines']]
    clips += [('hour', row['id'], row['body']) for row in script['clock']['hours']]
    clips += [('tail', row['id'], row['body']) for row in script['clock']['tails']]
    clips += [('address', row['id'], row['text']) for row in script['addresses']]
    return script, clips


def main(voice, source):
    source = Path(source).resolve()
    records = json.loads((source / 'manifest.json').read_text(encoding='utf-8-sig'))
    by_key = {(r['kind'], r['id']): r for r in records}
    script, expected = expected_clips()
    out = ROOT / 'assets' / 'voices' / voice
    clips, references, problems = [], set(), []
    for kind, clip_id, text in expected:
        record = by_key.get((kind, clip_id))
        if record is None:
            problems.append(f'missing {kind}:{clip_id}')
            continue
        if record['text'] != text:
            problems.append(f'text differs for {kind}:{clip_id}: {record["text"]!r} != {text!r}')
            continue
        src = source / record['file']
        if sha256(src) != record['sha256']:
            problems.append(f'hash differs for {record["file"]}')
            continue
        with wave.open(str(src)) as w:
            assert (w.getnchannels(), w.getsampwidth(), w.getframerate()) == (1, 2, 24000), src
            duration = round(w.getnframes() / w.getframerate(), 3)
        references.add(record['reference_sha256'])
        rel = f'assets/voices/{voice}/{FOLDER[kind]}/{clip_id}'
        master = ROOT / (rel + '.wav')
        master.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, master)
        mp3 = ROOT / (rel + '.mp3')
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(master),
                        '-ac', '1', '-codec:a', 'libmp3lame', '-b:a', BITRATE,
                        '-map_metadata', '-1', '-id3v2_version', '0', '-write_xing', '1', str(mp3)], check=True)
        clips.append({'kind': kind, 'id': clip_id, 'text': text, 'file': rel + '.mp3', 'duration': duration,
                      'master_file': rel + '.wav', 'sha256': record['sha256'], 'runtime_sha256': sha256(mp3),
                      'seed': record.get('seed'), 'asr_text': record.get('asr_text'), 'asr_status': record.get('asr_status')})
    if problems:
        sys.exit('Import stopped:\n  ' + '\n  '.join(problems))
    assert len(references) == 1, f'All clips must share one reference voice, found {len(references)}'
    first = records[0]
    bank = {'voice': voice, 'pause_ms': script['pause_ms'], 'reference_sha256': references.pop(),
            'model': Path(first['model']).name, 'revision': first.get('revision'),
            'generation_parameters': first.get('generation_parameters'), 'clips': clips}
    (out / 'bank.json').write_text(json.dumps(bank, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    total = sum(c['duration'] for c in clips)
    flagged = [c['kind'] + ':' + c['id'] for c in clips if c['asr_status'] not in ('ok', 'minor_asr_variation')]
    print(f'{voice}: imported {len(clips)} clips ({total / 60:.1f} min) into assets/voices/{voice}/; '
          f'ASR needs review: {", ".join(flagged) if flagged else "none"}')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
