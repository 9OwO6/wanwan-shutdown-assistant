"""Transcribe actual N1 WAVs locally, flagging discrepancies for review, not masking them."""
import argparse,hashlib,json,re,time
from difflib import SequenceMatcher
from pathlib import Path
import torch
from transformers import AutoProcessor,AutoModelForMultimodalLM

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--cpu',action='store_true');parser.add_argument('--only',nargs='*');parser.add_argument('--catalog',default='assets/companion-lines.json');parser.add_argument('--manifest',default='assets/voices/N1/manifest.json');parser.add_argument('--output',default='output/voice-lab/n1-transcripts.json');args=parser.parse_args()
rows=json.loads((ROOT/args.catalog).read_text(encoding='utf-8'))['lines']
bank=json.loads((ROOT/args.manifest).read_text(encoding='utf-8'))
rows=[r for r in rows if (ROOT/r['file']).exists() and any(m['id']==r['id'] and m['text']==r['text'] for m in bank)]
if args.only:rows=[r for r in rows if r['id'] in args.only]
OUT=ROOT/args.output
records=json.loads(OUT.read_text(encoding='utf-8')) if OUT.exists() else []
for record in records:
    record['transcript']=re.sub(r'<\|[^>]+\|>','',record['transcript'])
rows=[r for r in rows if not any(m['id']==r['id'] and m.get('sha256')==hashlib.sha256((ROOT/r['file']).read_bytes()).hexdigest() for m in records)]
if not rows:print('No new or changed audio to transcribe');raise SystemExit(0)
torch.set_num_threads(6)
model=AutoModelForMultimodalLM.from_pretrained('E:/LocalAI/models/Qwen3-ASR-0.6B-hf',dtype=torch.float32 if args.cpu else torch.bfloat16,device_map='cpu' if args.cpu else 'cuda:0',attn_implementation='sdpa',local_files_only=True)
processor=AutoProcessor.from_pretrained('E:/LocalAI/models/Qwen3-ASR-0.6B-hf',local_files_only=True)
def normalize(s):
    s=s.replace('三十五秒','35秒').replace('十分钟','10分钟').replace('两分钟','2分钟').replace('二分钟','2分钟')
    return re.sub(r'[^\u4e00-\u9fff0-9a-z]','',s.lower()).replace('的','得').replace('喔','哦')
for offset in range(0,len(rows),6):
    group=rows[offset:offset+6];start=time.monotonic()
    inputs=processor.apply_transcription_request(audio=[str(ROOT/r['file']) for r in group],language='Chinese').to(model.device,dtype=model.dtype)
    with torch.inference_mode():out=model.generate(**inputs,max_new_tokens=160,do_sample=False)
    result=processor.batch_decode(out[:,inputs['input_ids'].shape[1]:],return_format='transcription_only',skip_special_tokens=True)
    for row,transcript in zip(group,result):
        transcript=re.sub(r'<\|[^>]+\|>','',transcript)
        a,b=normalize(row['text']),normalize(transcript)
        ratio=SequenceMatcher(None,a,b).ratio()
        changes=[{'expected':a[i:j],'heard':b[k:l]} for op,i,j,k,l in SequenceMatcher(None,a,b).get_opcodes() if op!='equal']
        records=[m for m in records if m['id']!=row['id']]
        records.append({'id':row['id'],'sha256':hashlib.sha256((ROOT/row['file']).read_bytes()).hexdigest(),'text':row['text'],'transcript':transcript,'similarity':ratio,'changes':changes,'review_required':bool(changes)})
    OUT.write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'Transcribed {len(records)}/{len(bank)} in {time.monotonic()-start:.1f}s',flush=True)
for record in records:
    a,b=normalize(record['text']),normalize(record['transcript'])
    record['similarity']=SequenceMatcher(None,a,b).ratio()
    record['changes']=[{'expected':a[i:j],'heard':b[k:l]} for op,i,j,k,l in SequenceMatcher(None,a,b).get_opcodes() if op!='equal']
    record['review_required']=bool(record['changes'])
OUT.write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
print('Transcript differences to review: '+', '.join(r['id'] for r in records if r['review_required']),flush=True)
