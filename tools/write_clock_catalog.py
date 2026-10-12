"""Whole-sentence clock fragments, using the approved N1 voice without a live model."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def chinese(n):
    digits = '零一二三四五六七八九'
    if n < 10: return digits[n]
    return (digits[n // 10] if n >= 20 else '') + '十' + (digits[n % 10] if n % 10 else '')
rows = []
for hour in range(24):
    period = '凌晨' if hour < 6 else '早上' if hour < 12 else '中午' if hour == 12 else '下午' if hour < 18 else '晚上'
    clock = '十二' if hour in (0, 12) else chinese(hour % 12)
    text = f'宝贝，已经{period}{clock}点啦。'
    rows.append(dict(id=f'hour-{hour:02d}', cue='clock', action='peek', text=text, file=f'assets/voices/N1-clock/parts/hour-{hour:02d}.wav', hour=hour))
suffixes = {
    'early': ('water', '快到睡觉时间喽。先喝口水，把进度存好，我陪你准备休息。'),
    'soon': ('stretch', '离约好的休息时间不到十分钟啦。先保存文件，我们准备说晚安，好不好？'),
    'bed': ('nod', '到约好的睡觉时间啦。先保存文件，再关掉手上的程序，我们该休息啦。'),
    'final': ('yawn', '进入关机前的最后两分钟啦。先把重要的文件保存好，准备关机休息，好不好？')
}
for cue, (action, text) in suffixes.items():
    rows.append(dict(id=f'tail-{cue}', cue=cue, action=action, text=text, file=f'assets/voices/N1-clock/parts/tail-{cue}.wav'))
path = ROOT / 'assets/clock-parts.json'
path.write_text(json.dumps(dict(version=1, preset='N1', label='清甜温柔报时', precision='当前小时；气泡显示提醒发生时的 HH:mm', lines=rows), ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Authored {len(rows)} clock fragments for 24 hours and four phases')
