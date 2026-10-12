"""Pin the official Base model and verify any locally reused tokenizer weights."""
import hashlib,json,shutil
from pathlib import Path
from huggingface_hub import HfApi,snapshot_download

REPO='Qwen/Qwen3-TTS-12Hz-1.7B-Base'
REV='fd4b254389122332181a7c3db7f27e918eec64e3'
TARGET=Path('E:/LocalAI/models/Wanwan-Qwen3-Base')
SOURCE=Path('E:/LocalAI/models/Wanwan-Qwen3-VoiceDesign')
info=HfApi().model_info(REPO,revision=REV,files_metadata=True)
weight=next(s for s in info.siblings if s.rfilename=='speech_tokenizer/model.safetensors')
existing=SOURCE/weight.rfilename
if existing.exists() and hashlib.sha256(existing.read_bytes()).hexdigest()==weight.lfs.sha256:
    target=TARGET/weight.rfilename;target.parent.mkdir(parents=True,exist_ok=True)
    if not target.exists():shutil.copy2(existing,target)
    ignore=[weight.rfilename]
    print('Tokenizer reuse verified against official SHA256',flush=True)
else:ignore=[]
snapshot_download(REPO,revision=REV,local_dir=str(TARGET),ignore_patterns=ignore,max_workers=3)
for s in info.siblings:
    path=TARGET/s.rfilename
    assert path.is_file() and path.stat().st_size==s.size,s.rfilename
    if s.lfs:assert hashlib.sha256(path.read_bytes()).hexdigest()==s.lfs.sha256,s.rfilename
(TARGET/'wanwan-source.json').write_text(json.dumps({'repo':REPO,'revision':REV,'verified_lfs':True},indent=2),encoding='utf-8')
print('Base model downloaded and verified',flush=True)
