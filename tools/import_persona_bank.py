"""Import the recorded persona voice banks into assets/voices/<persona>/.

    python tools/import_persona_bank.py path/to/output/voice-bank/v2

The source folder holds ``manifest.json`` and the WAV files the generation run produced
for ``output/voice-bank/v2/clips.json`` (written by tools/write_persona_script.py). Every
clip must match the approved text exactly; anything missing or different stops the import.
WAV masters are copied into the repository, 64 kbps MP3 runtime copies are encoded next to
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
sys.path.insert(0, str(ROOT / 'tools'))


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected():
    """(persona, line id, address, spoken text) for every clip of the approved script."""
    script = json.loads((ROOT / 'assets/persona-script.json').read_text(encoding='utf-8'))
    from write_persona_script import expand  # same expansion rules the recording used
    personas = {p['id']: p for p in script['personas']}
    rows = []
    for line in script['lines']:
        for address, text in expand(personas[line['persona']], line['text']):
            rows.append((line['persona'], line['id'], address, text))
    return script, personas, rows


def main(source):
    source = Path(source).resolve()
    records = json.loads((source / 'manifest.json').read_text(encoding='utf-8-sig'))
    by_key = {(r['line'], r['address']): r for r in records}
    script, personas, rows = expected()
    banks, problems, references = {}, [], {}
    for persona, line_id, address, text in rows:
        record = by_key.get((line_id, address))
        if record is None:
            problems.append(f'missing {line_id} ({address})')
            continue
        if record['text'] != text:
            problems.append(f'text differs for {line_id} ({address}): {record["text"]!r} != {text!r}')
            continue
        src = source / record['file']
        if not src.is_file() or sha256(src) != record['sha256']:
            problems.append(f'file missing or hash differs: {record["file"]}')
            continue
        with wave.open(str(src)) as w:
            assert (w.getnchannels(), w.getsampwidth(), w.getframerate()) == (1, 2, 24000), src
            duration = round(w.getnframes() / w.getframerate(), 3)
        voice = personas[persona]['voice']
        references.setdefault(voice, set()).add(record.get('reference_sha256'))
        key = line_id + ('' if address == 'none' else '@' + address)
        name = line_id.split('/', 1)[1] + ('' if address == 'none' else '@' + address)
        rel = f'assets/voices/{persona}/{name}'
        master = ROOT / (rel + '.wav')
        master.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, master)
        mp3 = ROOT / (rel + '.mp3')
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(master),
                        '-ac', '1', '-codec:a', 'libmp3lame', '-b:a', '64k',
                        '-map_metadata', '-1', '-id3v2_version', '0', '-write_xing', '1', str(mp3)], check=True)
        banks.setdefault(persona, []).append({
            'key': key, 'line': line_id, 'address': address, 'text': text, 'file': rel + '.mp3',
            'duration': duration, 'master_file': rel + '.wav', 'sha256': record['sha256'],
            'runtime_sha256': sha256(mp3), 'seed': record.get('seed'),
            'asr_text': record.get('asr_text'), 'asr_status': record.get('asr_status')})
    if problems:
        sys.exit('Import stopped:\n  ' + '\n  '.join(problems))
    for voice, refs in references.items():
        assert len(refs) == 1, f'{voice}: all clips must share one reference voice, found {refs}'
    for persona, clips in banks.items():
        p = personas[persona]
        first = next(r for r in records if r['voice'] == p['voice'])
        bank = {'persona': persona, 'voice': p['voice'], 'reference_sha256': references[p['voice']].pop(),
                'model': Path(str(first.get('model', ''))).name, 'revision': first.get('revision'), 'clips': clips}
        (ROOT / 'assets/voices' / persona / 'bank.json').write_text(json.dumps(bank, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
        flagged = [c['key'] for c in clips if c['asr_status'] not in ('verified', 'accepted_variant', 'short_sound')]
        total = sum(c['duration'] for c in clips)
        print(f'{persona} ({p["voice"]}): {len(clips)} clips, {total / 60:.1f} min; ASR to review: {", ".join(flagged) or "none"}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
