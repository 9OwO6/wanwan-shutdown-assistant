"""Audition original adult companion voices locally; never replace application clips."""
import argparse,gc,json,os,subprocess,time,wave,shutil
from pathlib import Path
import numpy as np
import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

ROOT=Path(__file__).resolve().parents[1]
MODEL=Path('E:/LocalAI/models/Wanwan-Qwen3-VoiceDesign')
REVISION='5ecdb67327fd37bb2e042aab12ff7391903235d3'
TEXT='已经有点晚啦。先保存一下，好不好？我陪你慢慢收尾，晚安。'
parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='*');parser.add_argument('--out',default='round-1');args=parser.parse_args()
OUT=ROOT/'output'/'voice-lab'/args.out;OUT.mkdir(parents=True,exist_ok=True)
specs=json.loads((ROOT/'assets'/'voice-lab-candidates.json').read_text(encoding='utf-8-sig'))
if args.only:specs=[s for s in specs if s['id'] in args.only]
def publish(raw,target):
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-af','loudnorm=I=-18:TP=-2:LRA=9','-ar','24000','-ac','1','-c:a','pcm_s16le',str(target)],check=True)
    subprocess.run(['ffmpeg','-v','error','-i',str(target),'-f','null','-'],check=True)
    with wave.open(str(target)) as w:
        rate=w.getframerate();signal=np.frombuffer(w.readframes(w.getnframes()),dtype=np.int16).astype(float)/32768
    duration=len(signal)/rate
    assert 3<duration<20,f'Unexpected audition length: {duration}'
    return dict(duration=duration,sample_rate=rate,peak_db=float(20*np.log10(max(np.max(np.abs(signal)),1e-9))))

baseline=ROOT/'output'/'voice-cleanup'/'C-clean.wav'
publish(baseline,OUT/'C0.wav')
pending=[s for s in specs if not (OUT/(s['id']+'.wav')).exists()]
records=json.loads((OUT/'manifest.json').read_text(encoding='utf-8')) if (OUT/'manifest.json').exists() else []
if pending:
    free,total=torch.cuda.mem_get_info() if torch.cuda.is_available() else (0,0)
    print(f'GPU free before load: {free/1024**3:.2f} GiB',flush=True)
    # Reserve activation headroom without unloading any other application.
    options=dict(dtype=torch.bfloat16,attn_implementation='sdpa',local_files_only=True)
    if free>4.7*1024**3:options['device_map']='cuda:0'
    else:options.update(device_map='cpu',dtype=torch.float32)
    model=Qwen3TTSModel.from_pretrained(str(MODEL),**options)
    print('VoiceDesign model loaded',flush=True)
    for spec in pending:
        started=time.monotonic();torch.manual_seed(spec['seed'])
        print(f'Generating {spec["id"]}: {spec["label"]}',flush=True)
        with torch.inference_mode():
            wavs,sr=model.generate_voice_design(text=TEXT,language='Chinese',instruct=spec['instruct'],
                                               non_streaming_mode=True,temperature=.75,top_p=.9,
                                               subtalker_temperature=.75,max_new_tokens=300)
        raw=OUT/(spec['id']+'-raw.wav');sf.write(str(raw),wavs[0],sr,subtype='PCM_16')
        metrics=publish(raw,OUT/(spec['id']+'.wav'))
        record=dict(**spec,**metrics,text=TEXT,model=str(MODEL),revision=REVISION,generation_seconds=time.monotonic()-started)
        records=[r for r in records if r['id']!=spec['id']]+[record]
        (OUT/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
        print(f'{spec["id"]} ready: {metrics["duration"]:.2f}s, generated in {record["generation_seconds"]:.1f}s',flush=True)
    del model;gc.collect();torch.cuda.empty_cache()
print('Auditions complete; application voice and reminder settings unchanged',flush=True)
