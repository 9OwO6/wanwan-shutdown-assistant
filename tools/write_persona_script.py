"""The approved bedtime script (v2, 2026-10-19) for the two personas, as data.

    python tools/write_persona_script.py

Writes assets/persona-script.json (what the app reads) and output/voice-bank/v2/clips.json
(what the voice generation run records). Lines containing {称呼} are recorded as whole
sentences once per address of that persona, plus once without an address; nothing is
spliced at runtime except the hour + reminder of the hourly clock.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
A = '{称呼}'

PERSONAS = [
    {'id': 'girlfriend', 'name': '女友', 'voice': 'N1', 'voice_name': '清甜温柔',
     'description': '爱撒娇、黏人，你熬夜她会哼一声、小小生气，但不说教。',
     'addresses': [{'id': 'baobao', 'label': '宝宝'}, {'id': 'qinaide', 'label': '亲爱的'}],
     'default_address': 'baobao'},
    {'id': 'sister', 'name': '姐姐', 'voice': 'V3', 'voice_name': '知性温柔',
     'description': '成熟温柔、会照顾人；催你睡觉时温柔但不让步，偶尔轻轻调侃你。',
     'addresses': [{'id': 'xiaobendan', 'label': '小笨蛋'}],
     'default_address': 'none'},
]

# cue -> (action, girlfriend text(s), sister text(s)). Several texts = variants the app rotates.
LINES = [
    # 睡前提醒（early/soon/bed/final 也用作整点报时的后半句）
    ('early', 'water', ['还有半小时就该睡啦，还在忙的任务不多了吧～', A + '，半小时后我就要帮你关机了哦，注意别开新任务啦。'],
                       ['还有半小时就到休息时间了呢。应该准备着手收尾工作了。', '还有半小时了。注意别再开新的工作了。']),
    ('soon', 'stretch', ['只剩十分钟啦～快存一下档嘛，好不好？', A + '，十分钟倒计时开始咯，要乖乖收尾哦～'],
                        ['只剩十分钟了呢。先把重要的东西存好，好吗？', '十分钟后就该休息了。剩下的，明天再做也来得及。']),
    ('bed', 'nod', ['到点啦' + A + '～该睡觉觉了，不许再拖了哦。'], ['时间到了哦。今天已经很努力了，去休息吧。']),
    ('dialog', 'goodnight', ['好啦好啦，说好的时间到了嘛，去睡觉好不好～'], ['好了，今天就到这里吧。乖，先去保存。']),
    ('final', 'yawn', ['最后两分钟啦！快保存快保存～'], ['还有两分钟。没保存的，现在保存好哦。']),
    ('due', 'nod', ['已经过点啦！哼，再给你两分钟，然后我就帮你关机咯。'], ['已经过了约好的时间了呢。再给你两分钟，存好就关机。']),
    ('shutdown', 'goodnight', ['时间到～关机咯。晚安' + A + '，梦里见。'], ['时间到了。晚安，做个好梦。']),
    ('sleep', 'goodnight', ['电脑先睡啦，你也快去睡嘛～'], ['电脑先睡了。你也该去休息了，嗯？']),
    # 你的回应
    ('defer', 'nod', ['那……再给你一会儿，就一会儿哦。'], ['好吧，再给你一点时间。不过只有这一次哦。']),
    ('cancel', 'heart', ['好吧，忙完记得早点睡。'], ['有急事就去吧。忙完了，要记得早点睡。']),
    ('ack', 'nod', ['嗯！说好了哦。'], ['嗯，姐姐记住了哦。']),
    ('goodnight', 'goodnight', ['晚安' + A + '，明天见。'], ['晚安，' + A + '。明天见。']),
    # 起夜监督
    ('caught', 'peek', ['诶？怎么又偷偷起来啦！'], ['这么晚了，怎么又起来了？是有什么急事吗？']),
    ('caught-again', 'pat', ['又被我抓到了……快回去躺好。'], ['又起来了呀……听话，回去躺好。']),
    ('watch-final', 'goodnight', ['好啦，别再试啦，乖乖去睡。'], ['好了，别再试了。乖乖去睡觉，好吗？']),
    # 早上见面
    ('streak', 'cheer', ['早呀～昨晚超乖的，奖励你一颗小星星！'], ['早上好。昨晚很听话呢，继续保持哦。']),
    ('reset', 'heart', ['昨晚是不是又熬夜啦……哼，今晚要早点睡哦。'], ['昨晚又熬夜了吧？没关系，今晚早点睡就好。']),
    # 晚晚陪伴（开关打开后）
    ('companion-game', 'yawn', ['打完这把就睡，好不好？'], ['这一局打完就休息吧，好吗？']),
    ('companion-video', 'yawn', ['这集看完就睡嘛。'], ['这集看完就去睡，嗯？']),
    ('companion-work', 'stretch', ['明天再写吧，你都写了好久了。'], ['已经很晚了，剩下的明天再做吧。']),
    ('back', 'wave', ['你回来啦。'], ['回来啦？']),
    # 设置和体验
    ('preview', 'peek', [A + '～听得到吗？是我呀！'], [A + '，听得清吗？以后就由我来提醒你了。']),
    ('saved', 'heart', ['记住啦～到点我会来叫你的！'], ['记下了。到时间我会提醒你的。']),
    ('disabled', 'heart', ['记好啦～不过现在只会提醒你，不会帮你关机哦。'], ['记下了。现在只提醒，不会帮你关机哦。']),
    ('demo', 'goodnight', ['这只是演示啦，不会真的关机的～'], ['这是演示，不会关机的，放心看吧。']),
    ('hello', 'wave', ['嗯？叫我呀？', '在呢在呢～'], ['嗯？怎么了？', '找我有事吗？']),
    # 短音（戳一戳、打哈欠）
    ('poke', 'pat', ['嗯？'], ['嗯？']),
    ('poke-more', 'peek', ['诶——干嘛呀～'], ['怎么了呀。']),
    ('poke-angry', 'heart', ['哼！不理你了！'], ['再闹，姐姐要生气了哦。']),
    ('yawn-sound', 'yawn', ['哈啊～'], ['呼……']),
]

HOUR_WORDS = ['十二', '一', '两', '三', '四', '五', '六', '七', '八', '九', '十', '十一']
HOURS = {
    'girlfriend': lambda h: A + '，到' + HOUR_WORDS[h % 12] + '点啦。',
    'sister': lambda h: '已经' + HOUR_WORDS[h % 12] + '点了呢。',
}


def without_address(text):
    """Remove the address and the punctuation that only existed for it."""
    out = re.sub('^' + re.escape(A) + '[，～]', '', text)   # 句首称呼连同后面的标点
    out = out.replace('，' + A + '。', '。')                  # 句中「，称呼。」
    out = out.replace(A, '')                                  # 其余位置只去掉称呼本身，保留标点
    assert A not in out and out, text
    return out


def expand(persona, text):
    """All recorded variants of one line: (address id or 'none', spoken text)."""
    if A not in text:
        return [('none', text)]
    variants = [(a['id'], text.replace(A, a['label'])) for a in persona['addresses']]
    return variants + [('none', without_address(text))]


def main():
    lines, clips = [], []
    for persona in PERSONAS:
        column = 1 if persona['id'] == 'girlfriend' else 2
        for cue, action, *texts in LINES:
            for index, text in enumerate(texts[column - 1], start=1):
                line_id = f"{persona['id']}/{cue}-{index}"
                lines.append({'id': line_id, 'persona': persona['id'], 'cue': cue, 'action': action, 'text': text})
                for address, spoken in expand(persona, text):
                    clips.append({'voice': persona['voice'], 'line': line_id, 'address': address, 'text': spoken,
                                  'file': f"{persona['voice']}/{cue}-{index}" + ('' if address == 'none' else '@' + address) + '.wav'})
        for hour in range(24):
            text = HOURS[persona['id']](hour)
            line_id = f"{persona['id']}/hour-{hour:02d}"
            lines.append({'id': line_id, 'persona': persona['id'], 'cue': 'hour', 'hour': hour, 'action': 'peek', 'text': text})
            for address, spoken in expand(persona, text):
                clips.append({'voice': persona['voice'], 'line': line_id, 'address': address, 'text': spoken,
                              'file': f"{persona['voice']}/hour-{hour:02d}" + ('' if address == 'none' else '@' + address) + '.wav'})

    script = {'version': 2, 'approved': '2026-10-19',
              'notes': '台词第二版（用户批注后定稿）。{称呼} 的句子每个称呼录一遍整句，再录一遍不带称呼的；自定义名字只显示在文字里。'
                       '整点报时 = 整点句 + 对应提醒句（early/soon/bed/final 的第一种说法），中间停顿 clock_pause_ms。',
              'clock_pause_ms': 300, 'personas': PERSONAS, 'lines': lines}
    (ROOT / 'assets/persona-script.json').write_text(json.dumps(script, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    out = ROOT / 'output/voice-bank/v2'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'clips.json').write_text(json.dumps(clips, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    by_voice = {}
    for clip in clips:
        by_voice[clip['voice']] = by_voice.get(clip['voice'], 0) + 1
    print(f'{len(lines)} lines; clips to record: ' + ', '.join(f'{v} {n}' for v, n in by_voice.items()) + f' (total {len(clips)})')


if __name__ == '__main__':
    main()
