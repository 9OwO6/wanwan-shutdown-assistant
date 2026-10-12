"""Apply the user-approved C denoising recipe from preserved originals, never cumulatively."""
import json
import shutil
import subprocess
import wave
import hashlib
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
BACKUP=ROOT/'assets'/'voices'/'C-original'
OUT=ROOT/'output'/'voice-cleanup'
ENGINE=ROOT/'tools'/'vendor'/'deep-filter-0.5.6-x86_64-pc-windows-msvc.exe'
if not ENGINE.exists():raise RuntimeError('Download the official DeepFilterNet v0.5.6 Windows release into tools/vendor first.')
BACKUP.mkdir(parents=True,exist_ok=True)
OUT.mkdir(parents=True,exist_ok=True)

def run(*args):subprocess.run([str(a) for a in args],check=True)
def samples(file):
    with wave.open(str(file)) as w:
        assert w.getnchannels()==1 and w.getsampwidth()==2
        return np.frombuffer(w.readframes(w.getnframes()),dtype=np.int16).astype(float)/32768,w.getframerate()
def measure(before,after):
    a,rate=samples(before);b,rate_b=samples(after)
    assert rate_b==rate
    block=int(rate*.02);count=min(len(a),len(b))//block
    ra=np.sqrt(np.mean(a[:count*block].reshape(count,block)**2,axis=1))
    rb=np.sqrt(np.mean(b[:count*block].reshape(count,block)**2,axis=1))
    quiet=ra<=np.percentile(ra,20);speech=ra>=np.percentile(ra,65)
    db=lambda r:20*np.log10(max(float(np.sqrt(np.mean(r*r))),1e-9))
    return dict(duration_before=len(a)/rate,duration_after=len(b)/rate,
                quiet_reduction_db=db(ra[quiet])-db(rb[quiet]),
                speech_level_change_db=db(rb[speech])-db(ra[speech]),
                peak_after_db=20*np.log10(max(float(max(abs(b))),1e-9)))
def clean(original,target):
    signal,rate=samples(original);duration=len(signal)/rate
    stage=OUT/'neural-input';result=OUT/'neural-bank';stage.mkdir(exist_ok=True);result.mkdir(exist_ok=True)
    prepared=stage/original.name
    # Pad before compensated inference so its lookahead never truncates a word ending.
    run('ffmpeg','-v','error','-y','-i',original,'-af','apad=pad_dur=0.1','-ar',48000,'-ac',1,'-c:a','pcm_s16le',prepared)
    run(ENGINE,'-D','-a','30','-o',result,prepared)
    run('ffmpeg','-v','error','-y','-i',result/original.name,'-ar',rate,'-t',duration,'-c:a','pcm_s16le',target)
    run('ffmpeg','-v','error','-i',target,'-f','null','-')
    report=measure(original,target)
    if abs(report['duration_before']-report['duration_after'])>.001:raise RuntimeError('Changed duration')
    if report['speech_level_change_db'] < -4:raise RuntimeError('Too much speech attenuation')
    return report

records=[]
for source in sorted((ROOT/'assets'/'voices'/'C').glob('*.wav')):
    original=BACKUP/source.name
    if not original.exists():shutil.copyfile(source,original)
    target=OUT/source.name
    report=clean(original,target)
    shutil.copyfile(target,source)
    records.append(dict(id=source.stem,**report))
audition_original=OUT/'C-original.wav'
if not audition_original.exists():shutil.copyfile(ROOT/'output'/'voice-auditions'/'C.wav',audition_original)
audition_clean=OUT/'C-clean.wav'
records.append(dict(id='audition',**clean(audition_original,audition_clean)))
shutil.copyfile(audition_clean,ROOT/'output'/'voice-auditions'/'C.wav')
report=dict(engine='DeepFilterNet',version='0.5.6',source='https://github.com/Rikorose/DeepFilterNet/releases/tag/v0.5.6',
            recipe=['--compensate-delay','--atten-lim-db','30'],approved_sample='C-neural-30db.wav',
            binary_sha256=hashlib.sha256(ENGINE.read_bytes()).hexdigest(),records=records)
(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'assets'/'voices'/'C-cleanup.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(clips=len(records),audition=records[-1]),indent=2))
