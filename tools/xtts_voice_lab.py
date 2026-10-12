"""Re-synthesize C-family auditions from a cleaned reference, without changing AllTalk."""
import json,os,time,subprocess,wave
from pathlib import Path
os.environ['CUDA_VISIBLE_DEVICES']='-1'
import numpy as np
import torch
import soundfile as sf
from TTS.tts.models.xtts import Xtts
from TTS.tts.configs.xtts_config import XttsConfig

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output'/'voice-lab'/'round-1';OUT.mkdir(parents=True,exist_ok=True)
TEXT='已经有点晚啦。先保存一下，好不好？我陪你慢慢收尾，晚安。'
REF=ROOT/'output'/'voice-cleanup'/'reference-clean'/'reference-original.wav'
records=[]
for code,name in [('C1','cute_dog_zh_v1'),('C2','xttsv2_2.0.3')]:
    target=OUT/(code+'.wav')
    if target.exists():continue
    started=time.monotonic();directory=Path('E:/LocalAI/alltalk_tts/models/xtts')/name
    config=XttsConfig();config.load_json(str(directory/'config.json'))
    model=Xtts.init_from_config(config);model.load_checkpoint(config,checkpoint_dir=str(directory),eval=True,use_deepspeed=False);model.cpu()
    latent,embedding=model.get_conditioning_latents(audio_path=[str(REF)],gpt_cond_len=6,gpt_cond_chunk_len=6,max_ref_length=8,sound_norm_refs=True)
    torch.manual_seed(20261010)
    print(f'{code}: generating with {name} and a cleaned C reference',flush=True)
    with torch.inference_mode():
        result=model.inference(TEXT,'zh-cn',latent,embedding,temperature=.55,top_p=.85,top_k=50,repetition_penalty=10.0,speed=.96,enable_text_splitting=True)
    raw=OUT/(code+'-raw.wav');sf.write(str(raw),result['wav'],24000,subtype='PCM_16')
    shifted=OUT/(code+'-shift.wav');ratio=2**(2/12)
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-af',f'asetrate=24000*{ratio},aresample=48000,atempo={1/ratio},apad=pad_dur=0.1',str(shifted)],check=True)
    clean=OUT/'clean';clean.mkdir(exist_ok=True)
    subprocess.run([str(ROOT/'tools'/'vendor'/'deep-filter-0.5.6-x86_64-pc-windows-msvc.exe'),'-D','-a','24','-o',str(clean),str(shifted)],check=True)
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(clean/shifted.name),'-af','loudnorm=I=-18:TP=-2:LRA=9','-ar','24000','-ac','1','-c:a','pcm_s16le',str(target)],check=True)
    subprocess.run(['ffmpeg','-v','error','-i',str(target),'-f','null','-'],check=True)
    with wave.open(str(target)) as wav:duration=wav.getnframes()/wav.getframerate()
    assert 3<duration<25
    records.append(dict(id=code,text=TEXT,model=name,reference=str(REF),pitch=2,temperature=.55,duration=duration,generation_seconds=time.monotonic()-started))
    (OUT/'c-family-manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'{code} ready: {duration:.1f}s, processing took {time.monotonic()-started:.1f}s',flush=True)
    del model
print('C-family auditions complete; original model and application settings unchanged',flush=True)
