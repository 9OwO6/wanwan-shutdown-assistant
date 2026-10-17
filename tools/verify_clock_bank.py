"""Verify the entire on-disk hourly voice pack, including source provenance."""
import hashlib, json, subprocess, wave
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
rows=json.loads((ROOT/'assets/clock-lines.json').read_text(encoding='utf-8'))['lines']
records=json.loads((ROOT/'assets/voices/N1-clock/manifest.json').read_text(encoding='utf-8'))
parts=json.loads((ROOT/'assets/voices/N1-clock/parts-manifest.json').read_text(encoding='utf-8'))
reference=hashlib.sha256((ROOT/'assets/voices/reference/N1-reference.wav').read_bytes()).hexdigest()
assert len(rows)==len(records)==96
assert {(r['hour'],r['cue']) for r in rows}=={(h,c) for h in range(24) for c in ['early','soon','bed','final']}
checked=[]
for row in rows:
    record=next(r for r in records if r['id']==row['id'])
    assert record['text']==row['text'] and record.get('runtime_file',record['file'])==row['file']
    assert record['reference_sha256']==reference
    source=[next(p for p in parts if p['id']==name) for name in record['source_ids']]
    assert row['text']==''.join(p['text'] for p in source)
    assert all(p['reference_sha256']==reference for p in source)
    for p, expected in zip(source,record['source_sha256']):
        assert hashlib.sha256((ROOT/p['file']).read_bytes()).hexdigest()==expected==p['sha256']
    path=ROOT/record['file'];digest=hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest==record['sha256']
    subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','null','-'],check=True)
    with wave.open(str(path)) as w:
        assert (w.getnchannels(),w.getsampwidth(),w.getframerate())==(1,2,24000)
        audio=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2')/32768
    assert 3<len(audio)/24000<20 and abs(len(audio)/24000-record['duration'])<.001
    assert np.max(np.abs(audio))<.90
    checked.append(dict(id=row['id'],sha256=digest,duration=record['duration'],text=row['text']))
report=dict(count=96,hours=24,phases=4,reference_sha256=reference,full_decode=True,clips=checked)
(ROOT/'output/voice-lab/clock-bank-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('Clock bank passed: 96 matching texts, 24 hours, four phases, source hashes, full decode and no clipping')
