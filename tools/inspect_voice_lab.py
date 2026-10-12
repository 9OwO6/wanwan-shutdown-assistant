"""Check actual audition files, with no claim to judge naturalness or companionship."""
import hashlib,json,subprocess,wave
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'output'/'voice-lab'/'round-1'
records=[];hashes=set()
for code in ['C0','C1','C2','N1','N2','N3']:
    path=OUT/(code+'.wav')
    subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','null','-'],check=True)
    digest=hashlib.sha256(path.read_bytes()).hexdigest();assert digest not in hashes;hashes.add(digest)
    with wave.open(str(path)) as wav:
        assert wav.getframerate()==24000 and wav.getnchannels()==1 and wav.getsampwidth()==2
        samples=np.frombuffer(wav.readframes(wav.getnframes()),np.int16).astype(float)/32768
    assert 3<len(samples)/24000<25
    assert np.max(np.abs(samples))<.99,'Clipped audio'
    levels=subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af','loudnorm=I=-18:TP=-2:LRA=9:print_format=json','-f','null','-'],capture_output=True,text=True,check=True).stderr
    measure=json.loads(levels[levels.rfind('{'):levels.rfind('}')+1])
    assert abs(float(measure['input_i'])+18)<.8,'Unequal comparison loudness'
    block=480;n=len(samples)//block;rms=np.sqrt(np.mean(samples[:n*block].reshape(n,block)**2,axis=1))
    records.append(dict(id=code,sha256=digest,duration=len(samples)/24000,integrated_lufs=float(measure['input_i']),
                        true_peak_db=float(measure['input_tp']),quiet_20ms_p10_db=float(20*np.log10(max(np.percentile(rms,10),1e-9)))))
(OUT/'technical-check.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print(json.dumps(records,indent=2))
print('Six distinct auditions decoded, no clipping, matched loudness; voice approval pending human listening')
