"""Separate ASR spelling/particle differences from unresolved pronunciation flags."""
import argparse,hashlib,json
from pathlib import Path
from pypinyin import lazy_pinyin,Style
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--catalog',default='assets/companion-lines.json');parser.add_argument('--transcripts',default='output/voice-lab/n1-transcripts.json');parser.add_argument('--output',default='output/voice-lab/n1-transcript-review.json');args=parser.parse_args()
rows=json.loads((ROOT/args.catalog).read_text(encoding='utf-8'))['lines']
records=json.loads((ROOT/args.transcripts).read_text(encoding='utf-8'))
assert len(records)==len(rows) and len({r['id'] for r in records})==len(rows)
def pronunciations(text):
    # Colloquial sentence particles are commonly transcribed differently by ASR.
    text=text.translate(str.maketrans({'啦':'了','呀':'啊','嘛':'吗','地':'得'}))
    return lazy_pinyin(text,style=Style.TONE3,neutral_tone_with_five=True)
reviews=[]
for row in rows:
    record=next(r for r in records if r['id']==row['id'])
    assert record['text']==row['text']
    assert record['sha256']==hashlib.sha256((ROOT/row['file']).read_bytes()).hexdigest()
    unresolved=[c for c in record['changes'] if pronunciations(c['expected'])!=pronunciations(c['heard'])]
    reviews.append({'id':row['id'],'status':'unresolved' if unresolved else ('spelling_or_particle_difference' if record['changes'] else 'exact_normalized_transcript'),'changes':record['changes'],'unresolved':unresolved})
report={'count':len(reviews),'unresolved_count':sum(r['status']=='unresolved' for r in reviews),'review_method':'Compare actual ASR text, flag nonhomophone discrepancies, allow documented sentence-particle differences. This is not a human listening approval.','clips':reviews}
(ROOT/args.output).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'ASR checked {len(reviews)} clips; unresolved pronunciation flags: {report["unresolved_count"]}')
if report['unresolved_count']:print(json.dumps([r for r in reviews if r['status']=='unresolved'],ensure_ascii=False,indent=2));raise SystemExit(1)
