"""Join whole sentences with a natural pause, avoiding an online/runtime TTS model."""
import hashlib, json, subprocess, wave
from pathlib import Path
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
rows = json.loads((ROOT / 'assets/clock-parts.json').read_text(encoding='utf-8'))['lines']
records = json.loads((ROOT / 'assets/voices/N1-clock/parts-manifest.json').read_text(encoding='utf-8'))
assert len(rows) == len(records) == 28
parts = {}
def load(row):
    record = next(r for r in records if r['id'] == row['id'])
    path = ROOT / row['file']
    assert record['text'] == row['text'] and hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256']
    with wave.open(str(path)) as w:
        assert (w.getnchannels(), w.getsampwidth(), w.getframerate()) == (1, 2, 24000)
        data = np.frombuffer(w.readframes(w.getnframes()), dtype='<i2').copy()
    # Keep every spoken sample; remove only leading/trailing quiet blocks, with a 100 ms safety margin.
    blocks = len(data) // 480
    energy = np.sqrt(np.mean(data[:blocks*480].astype(float).reshape(blocks,480)**2, axis=1))
    active = np.where(energy > 100)[0]
    assert len(active)
    first = max(0, int(active[0]*480) - 2400)
    last = min(len(data), int((active[-1]+1)*480) + 2400)
    trimmed = data[first:last].copy()
    # Fade only the outermost 5 ms within the retained quiet margin to avoid seam clicks.
    n = min(120, len(trimmed)//2)
    trimmed[:n] = (trimmed[:n] * np.linspace(0,1,n)).astype('<i2')
    trimmed[-n:] = (trimmed[-n:] * np.linspace(1,0,n)).astype('<i2')
    return trimmed, record
for row in rows: parts[row['id']] = load(row)
out = ROOT / 'assets/voices/N1-clock'
lines, manifest = [], []
for hour in range(24):
    head = next(r for r in rows if r['id'] == f'hour-{hour:02d}')
    for cue in ['early', 'soon', 'bed', 'final']:
        tail = next(r for r in rows if r['id'] == f'tail-{cue}')
        line = dict(id=f'clock-{hour:02d}-{cue}', cue=cue, hour=hour, action=tail['action'], text=head['text']+tail['text'], file=f'assets/voices/N1-clock/{hour:02d}-{cue}.wav')
        a, ra = parts[head['id']]; b, rb = parts[tail['id']]
        assert ra['reference_sha256'] == rb['reference_sha256']
        audio = np.concatenate([a, np.zeros(2400,dtype='<i2'), b])
        path = ROOT / line['file']
        with wave.open(str(path), 'wb') as w:
            w.setparams((1,2,24000,0,'NONE','not compressed')); w.writeframes(audio.tobytes())
        subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','null','-'],check=True)
        lines.append(line)
        manifest.append(dict(**line, duration=len(audio)/24000, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), reference_sha256=ra['reference_sha256'], source_ids=[head['id'],tail['id']], source_sha256=[ra['sha256'],rb['sha256']], pause_ms=100))
(ROOT / 'assets/clock-lines.json').write_text(json.dumps(dict(version=1,preset='N1',precision='语音报当前小时，气泡显示提醒时的 HH:mm',lines=lines),ensure_ascii=False,indent=2),encoding='utf-8')
(out / 'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('Composed and decoded 96 hour/phase reminders; 100 ms pause between whole sentences')
