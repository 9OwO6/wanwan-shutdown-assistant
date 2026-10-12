"""Verify every delivered clip against its text, provenance and decoded PCM."""
import hashlib,json,subprocess,wave
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
catalog=json.loads((ROOT/'assets/companion-lines.json').read_text(encoding='utf-8'))
records=json.loads((ROOT/'assets/voices/N1/manifest.json').read_text(encoding='utf-8'))
assert len(catalog['lines'])==len(records)==92
assert len({r['text'] for r in catalog['lines']})==92
reference=hashlib.sha256((ROOT/'assets/voices/reference/N1-reference.wav').read_bytes()).hexdigest()
hashes=set();checked=[]
for row in catalog['lines']:
    record=next(r for r in records if r['id']==row['id'])
    assert record['text']==row['text'] and record['file']==row['file']
    assert record['reference_sha256']==reference
    path=ROOT/row['file'];digest=hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest==record['sha256'] and digest not in hashes;hashes.add(digest)
    subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','null','-'],check=True)
    with wave.open(str(path)) as w:
        assert w.getframerate()==24000 and w.getnchannels()==1 and w.getsampwidth()==2
        signal=np.frombuffer(w.readframes(w.getnframes()),dtype=np.int16).astype(float)/32768
    duration=len(signal)/24000
    assert 1.5<duration<20 and abs(duration-record['duration'])<.01
    assert np.max(np.abs(signal))<.90
    assert record['true_peak_db']<=-1.95
    block=480;n=len(signal)//block;rms=np.sqrt(np.mean(signal[:n*block].reshape(n,block)**2,axis=1))
    checked.append(dict(id=row['id'],duration=duration,sha256=digest,integrated_lufs=record['integrated_lufs'],true_peak_db=record['true_peak_db'],quiet_p10_db=float(20*np.log10(max(np.percentile(rms,10),1e-9)))))
report={'count':len(checked),'cues':len({r['cue'] for r in catalog['lines']}),'reference_sha256':reference,'complete_decode':True,'clip_checks':checked,'note':'Signal checks and reference reuse do not replace human listening for voice quality.'}
(ROOT/'output/voice-lab/n1-bank-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Checked {len(checked)} distinct clips, matching text and reference, PCM format, full decode and no clipping')
