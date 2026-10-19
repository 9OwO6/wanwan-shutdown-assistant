"""Split every spoken line into an optional address fragment plus a body that reads on its own.

The voice packs from v0.4.0 record the address (宝宝，/宝贝，/…) once per voice and the
bodies without it; the app plays the chosen address, a short pause, then the body. This
keeps every address option affordable: a new address costs one clip per voice, not a
re-recording of every line.

Derived deterministically from the existing N1 catalogs (companion, guard, watch and
clock parts), so the text the user already approved stays the same apart from the
address moving to the front.

    python tools/write_voice_script.py   # writes assets/voice-script.json
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDRESSES = [
    {'id': 'baobao', 'label': '宝宝', 'text': '宝宝，'},
    {'id': 'baobei', 'label': '宝贝', 'text': '宝贝，'},
    {'id': 'qinaide', 'label': '亲爱的', 'text': '亲爱的，'},
    {'id': 'xiaokeai', 'label': '我的小可爱', 'text': '我的小可爱，'},
    {'id': 'xiaobendan', 'label': '小笨蛋', 'text': '小笨蛋，'},
]
BY_LABEL = {a['label']: a['id'] for a in ADDRESSES}
NAME = '(我的小可爱|亲爱的|宝贝|宝宝)'
# Lines where simply removing the address would leave an awkward sentence.
OVERRIDES = {
    'saved-01': '好，今晚的约定记住啦。到时间我会轻轻提醒你，你也要记得来休息哦。',
}


def split(line_id, text):
    """Return (n1_address_id or None, body)."""
    found = re.findall(NAME, text)
    if not found:
        return None, text
    assert len(found) == 1, (line_id, text)
    body = OVERRIDES.get(line_id)
    if body is None:
        body = re.sub('^' + NAME + '，', '', text)
        body = re.sub('，' + NAME + '([。！？])', r'\2', body)
        body = re.sub('([。！？])' + NAME + '，', r'\1', body)
        body = re.sub('，' + NAME + '，', '，', body)
    assert not re.search(NAME, body), (line_id, body)
    return BY_LABEL[found[0]], body


def read(name):
    return json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8'))['lines']


lines = []
for group, name in [('companion', 'companion-lines.json'), ('guard', 'guard-lines.json'), ('watch', 'watch-lines.json')]:
    for row in read(name):
        address, body = split(row['id'], row['text'])
        lines.append({'id': row['id'], 'group': group, 'cue': row['cue'], 'action': row['action'],
                      'addressed': address is not None, 'n1_address': address, 'body': body,
                      'n1_text': row['text']})

parts = read('clock-parts.json')
hours, tails = [], []
for row in parts:
    if row['id'].startswith('hour-'):
        address, body = split(row['id'], row['text'])
        assert address == 'baobei', row
        hours.append({'id': row['id'], 'hour': row['hour'], 'body': body})
    else:
        tails.append({'id': row['id'], 'cue': row['cue'], 'action': row['action'], 'body': row['text']})
assert len(hours) == 24 and len(tails) == 4

script = {
    'version': 1,
    'pause_ms': 100,
    'default_address': 'rotate',
    'notes': '称呼与正文分开录制；正文不含称呼也要通顺。addressed=true 的句子在选了称呼时会先播称呼。'
             'n1_address 记录原 N1 录音里用的称呼，用于“轮流叫”。',
    'addresses': ADDRESSES,
    'lines': lines,
    'clock': {'address': 'baobei', 'hours': hours, 'tails': tails},
}
out = ROOT / 'assets' / 'voice-script.json'
out.write_text(json.dumps(script, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
addressed = sum(l['addressed'] for l in lines)
print(f'{out.relative_to(ROOT)}: {len(lines)} lines ({addressed} with an address slot), '
      f'{len(hours)} clock hours, {len(tails)} clock tails, {len(ADDRESSES)} addresses; '
      f'{len(lines) + len(hours) + len(tails) + len(ADDRESSES)} clips per voice')
