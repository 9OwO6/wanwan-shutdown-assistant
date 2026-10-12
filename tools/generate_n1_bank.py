"""Generate the approved N1 voice from one fixed reference, with resumable records."""
import argparse,gc,hashlib,json,os,subprocess,time
from pathlib import Path
import numpy as np
import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

ROOT=Path(__file__).resolve().parents[1]
REFERENCE=ROOT/'assets/voices/reference/N1-reference.wav'
REF_TEXT='已经有点晚啦。先保存一下，好不好？我陪你慢慢收尾，晚安。'
REV='fd4b254389122332181a7c3db7f27e918eec64e3'
parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='*');parser.add_argument('--batch',type=int,default=4);parser.add_argument('--force',action='store_true');parser.add_argument('--catalog',default='assets/companion-lines.json');parser.add_argument('--manifest',default='assets/voices/N1/manifest.json');parser.add_argument('--raw-dir',default='output/voice-lab/n1-bank');parser.add_argument('--model',default=os.environ.get('WANWAN_TTS_MODEL','Qwen/Qwen3-TTS-12Hz-1.7B-Base'));parser.add_argument('--reference',type=Path);args=parser.parse_args()
MODEL=args.model
if args.reference:REFERENCE=args.reference
catalog=json.loads((ROOT/args.catalog).read_text(encoding='utf-8-sig'))
rows=catalog['lines']
if args.only:rows=[r for r in rows if r['id'] in args.only or r['cue'] in args.only]
OUT=ROOT/args.raw_dir;OUT.mkdir(parents=True,exist_ok=True)
manifest=ROOT/args.manifest;manifest.parent.mkdir(parents=True,exist_ok=True)
for row in rows:(ROOT/row['file']).parent.mkdir(parents=True,exist_ok=True)
records=json.loads(manifest.read_text(encoding='utf-8')) if manifest.exists() else []
pending=[r for r in rows if args.force or not any(m['id']==r['id'] and m['text']==r['text'] and (ROOT/r['file']).exists() for m in records)]

def measure(path):
    s=subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af','loudnorm=I=-18:TP=-2:LRA=9:print_format=json','-f','null','-'],capture_output=True,text=True,check=True).stderr
    return json.loads(s[s.rfind('{'):s.rfind('}')+1])

def publish(raw,target):
    levels=measure(raw);gain=min(-18-float(levels['input_i']),-2-float(levels['input_tp']))
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-af',f'volume={gain:.4f}dB','-ar','24000','-ac','1','-c:a','pcm_s16le',str(target)],check=True)
    subprocess.run(['ffmpeg','-v','error','-i',str(target),'-f','null','-'],check=True)
    signal,sr=sf.read(target);duration=len(signal)/sr
    assert sr==24000 and 1.5<duration<20 and np.max(np.abs(signal))<.90,f'Invalid audio {target}: {duration}'
    level=measure(target)
    return dict(duration=duration,sample_rate=sr,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),integrated_lufs=float(level['input_i']),true_peak_db=float(level['input_tp']),gain_db=gain)

if pending:
    free,_=torch.cuda.mem_get_info();print(f'Pending {len(pending)} clips; GPU free {free/1024**3:.2f} GiB',flush=True)
    if free<4.3*1024**3:raise RuntimeError('Not enough free GPU memory; leave other applications untouched and resume later')
    # Compute the reference on CPU, then keep only the autoregressive talker on GPU.
    # The fixed-reference encoder and audio codec stay on CPU to leave other apps room.
    torch.set_num_threads(6)
    model=Qwen3TTSModel.from_pretrained(str(MODEL),device_map='cpu',dtype=torch.bfloat16,attn_implementation='sdpa',local_files_only=True)
    model.model.speech_tokenizer.model.float()
    with torch.inference_mode():prompt=model.create_voice_clone_prompt(ref_audio=str(REFERENCE),ref_text=REF_TEXT,x_vector_only_mode=False)
    torch.save(prompt,OUT/'reference-prompt.pt')
    model.model.talker.to('cuda:0');model.device=torch.device('cuda:0')
    print(f'Model loaded; allocated {torch.cuda.memory_allocated()/1024**3:.2f} GiB',flush=True)
    for offset in range(0,len(pending),args.batch):
        group=pending[offset:offset+args.batch];started=time.monotonic();seed=20261010+sum(ord(c) for r in group for c in r['id']);torch.manual_seed(seed)
        print('Generating '+', '.join(r['id'] for r in group),flush=True)
        with torch.inference_mode():
            wavs,sr=model.generate_voice_clone(text=[r['text'] for r in group],language='Chinese',voice_clone_prompt=prompt,non_streaming_mode=True,temperature=.65,top_p=.9,subtalker_temperature=.65,max_new_tokens=220)
        assert len(wavs)==len(group)
        for row,wav in zip(group,wavs):
            raw=OUT/(row['id']+'-raw.wav');sf.write(raw,wav,sr,subtype='PCM_16')
            metrics=publish(raw,ROOT/row['file'])
            record=dict(**row,**metrics,preset='N1',reference_sha256=hashlib.sha256(REFERENCE.read_bytes()).hexdigest(),reference_text=REF_TEXT,model_revision=REV,seed=seed)
            records=[r for r in records if r['id']!=row['id']]+[record]
            temporary=manifest.with_suffix('.tmp');temporary.write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8');temporary.replace(manifest)
        print(f'Completed {len(group)} in {time.monotonic()-started:.1f}s; bank {len(records)}/{len(catalog["lines"])}',flush=True)
    del model;gc.collect();torch.cuda.empty_cache()
print('Requested clips complete; no audio played and no shutdown settings changed',flush=True)
