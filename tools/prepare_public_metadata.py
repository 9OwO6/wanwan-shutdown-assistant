"""Remove local machine paths while retaining generated-asset provenance."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'assets/interaction-sources.json'
rows=json.loads(path.read_text(encoding='utf-8-sig'))
for row in rows:
    source=row.get('source','')
    if ':/' in source.replace('\\','/'):
        row['source']='image_gen artifact: '+source.replace('\\','/').rsplit('/',1)[-1]
path.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
path=ROOT/'assets/icons/source.json'
record=json.loads(path.read_text(encoding='utf-8-sig'))
record['source_file']='image_gen artifact: '+record['source_file'].replace('\\','/').rsplit('/',1)[-1]
path.write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
records=json.loads((ROOT/'output/voice-lab/round-1/manifest.json').read_text(encoding='utf-8-sig'))
voice=next(record for record in records if record['id']=='N1')
voice['model']='Qwen3-TTS VoiceDesign'
voice['reference_sha256']='3c79b81a7d1c114325e14e73f7c9d58936424f5ec3aa612737f14831f179baec'
(ROOT/'assets/voices/reference/provenance.json').write_text(json.dumps(voice,ensure_ascii=False,indent=2),encoding='utf-8')
print('Public media provenance prepared without local user-directory paths.')
