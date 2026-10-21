"""Build the promo film 《长大以后，也要按时睡觉呀》 from still frames, Wanwan's desk art and voice.

    python tools/make_promo.py <assets-dir> <out.mp4> [--landscape] [--preview N]

<assets-dir> holds the GPT stills (char-sheet.png, s01.png ... s10.png) and voice/line-s08.*,
voice/line-s11.* from output/promo2. Everything else (Wanwan's desk frames, her recorded lines,
fonts) comes from this repository. Stills get a slow push-in and cross-fades; Wanwan and her
speech bubble are drawn over the computer screen in the night/morning shots exactly as the app
shows her. Music and sound effects are synthesised here, so the film has no third-party audio.
"""
import json
import math
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FPS = 30
SR = 48000
FONT = '/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc'
FONT_LIGHT = '/usr/share/fonts/opentype/noto/NotoSansCJK-Light.ttc'
FONT_SERIF = '/usr/share/fonts/opentype/noto/NotoSerifCJK-Medium.ttc'
PINK = (253, 244, 248)
VOICE = ROOT / 'assets' / 'voices' / 'girlfriend'
URL = 'github.com/9OwO6/wanwan-shutdown-assistant'

# Timeline (seconds). Each shot: stills, start, duration, push-in, captions, overlays.
# caption: (text, t0, t1, kind) relative to the shot; kind 'narration' (centre, serif) or 'line' (speaker line).
SHOTS = [
    dict(img='s01', d=5.0, zoom=(1.00, 1.08), caps=[('小时候', 0.6, 4.6, 'narration')]),
    dict(img='s02', d=5.0, zoom=(1.04, 1.10), caps=[('妈妈：「别玩了，快睡觉！」', 0.5, 4.6, 'line')]),
    dict(img='s03', d=5.0, zoom=(1.00, 1.07), caps=[('后来', 0.6, 4.6, 'narration')]),
    dict(img='s04', d=5.0, zoom=(1.02, 1.10), caps=[('「别玩了，快睡觉啦」', 0.6, 4.6, 'chat')]),
    dict(img='s05', d=6.0, zoom=(1.00, 1.06), caps=[('再后来', 0.8, 5.6, 'narration')]),
    dict(img=['s06a', 's06b', 's06c'], d=6.0, zoom=(1.03, 1.08), caps=[('没有人催了', 1.0, 5.8, 'narration')], clock=('01:12', '02:47')),
    dict(img=['s07a', 's07b'], d=6.0, zoom=(1.00, 1.05), caps=[('其实不是不想睡', 0.4, 2.9, 'narration'), ('只是少了一个人，告诉你「很晚了」', 3.0, 5.8, 'narration')]),
    dict(img='s08', d=7.0, zoom=(1.00, 1.03), pet=('peek', 'line-s08', '宝宝，很晚了哦～先存一下档嘛，好不好？')),
    dict(img=['s08', 's09'], d=5.0, zoom=(1.03, 1.05), pet=('goodnight', 'shutdown-1@baobao', '时间到～关机咯。晚安宝宝，梦里见。'), split=2.6),
    dict(img='s10', d=5.0, zoom=(1.00, 1.04), pet=('stretch', 'streak-1', '早呀～昨晚超乖的，奖励你一颗小星星！')),
    dict(end=True, d=8.0),
]
PET_SCREEN = {}  # filled from <assets>/layout.json: where the computer screen's empty corner is in s08/s10


def font(path, size):
    return ImageFont.truetype(path, size)


def load_audio(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 's16le', '-ac', '1', '-ar', str(SR), '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32) / 32768


def find_voice(assets, name):
    for base in (assets / 'voice', VOICE):
        for ext in ('.wav', '.mp3'):
            if (base / (name + ext)).is_file():
                return base / (name + ext)
    raise FileNotFoundError(name)


def cover(img, w, h, zoom, cx=0.5, cy=0.5):
    """Scale an image to cover w×h at the given zoom, centred on (cx, cy)."""
    s = max(w / img.width, h / img.height) * zoom
    nw, nh = int(img.width * s + 0.5), int(img.height * s + 0.5)
    im = img.resize((nw, nh), Image.LANCZOS)
    x = int(min(max(cx * nw - w / 2, 0), nw - w))
    y = int(min(max(cy * nh - h / 2, 0), nh - h))
    return im.crop((x, y, x + w, y + h)), (s, x, y)


def text_box(draw, text, fnt):
    l, t, r, b = draw.textbbox((0, 0), text, font=fnt)
    return r - l, b - t, l, t


def draw_caption(frame, text, kind, alpha, W, H):
    layer = Image.new('RGBA', frame.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    a = int(255 * alpha)
    if kind == 'narration':
        f = font(FONT_SERIF, int(W * 0.052))
        tw, th, ox, oy = text_box(d, text, f)
        x, y = (W - tw) / 2 - ox, H * 0.78 - oy
        glow = Image.new('RGBA', frame.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).text((x, y), text, font=f, fill=(0, 0, 0, int(a * 0.9)))
        layer.alpha_composite(glow.filter(ImageFilter.GaussianBlur(W * 0.008)))
        d.text((x, y), text, font=f, fill=(255, 250, 244, a))
    elif kind == 'line':
        f = font(FONT, int(W * 0.044))
        tw, th, ox, oy = text_box(d, text, f)
        x, y = (W - tw) / 2 - ox, H * 0.80 - oy
        pad = W * 0.03
        d.rounded_rectangle((x + ox - pad, y + oy - pad * 0.7, x + ox + tw + pad, y + oy + th + pad * 0.7), radius=pad, fill=(20, 16, 22, int(a * 0.55)))
        d.text((x, y), text, font=f, fill=(255, 248, 240, a))
    elif kind == 'chat':
        f = font(FONT, int(W * 0.046))
        tw, th, ox, oy = text_box(d, text, f)
        pad = W * 0.035
        bx, by = W * 0.5 - (tw + 2 * pad) / 2, H * 0.40
        d.rounded_rectangle((bx, by, bx + tw + 2 * pad, by + th + 2 * pad), radius=pad * 1.1, fill=(255, 255, 255, int(a * 0.95)))
        d.text((bx + pad - ox, by + pad - oy), text, font=f, fill=(60, 52, 58, a))
    frame.alpha_composite(layer)


def draw_clock(frame, text, alpha, W, H):
    layer = Image.new('RGBA', frame.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(FONT_LIGHT, int(W * 0.06))
    tw, th, ox, oy = text_box(d, text, f)
    x, y = W - tw - W * 0.08 - ox, H * 0.08 - oy
    d.text((x, y), text, font=f, fill=(210, 230, 255, int(220 * alpha)))
    frame.alpha_composite(layer)


class Pet:
    """Wanwan at her desk, composed the way app/DesktopPet.ps1 shows her."""

    def __init__(self):
        desk = json.loads((ROOT / 'assets/desk/desk.json').read_text(encoding='utf-8'))
        load = lambda p: Image.open(ROOT / 'assets/desk' / p).convert('RGBA')
        self.back, self.front, self.cup = load(desk['layers']['back']), load(desk['layers']['front']), load(desk['layers']['cup'])
        self.behaviors = desk['behaviors']
        self.frames = {b: [load(f'character/{b}/{i}.png') for i in range(4)] for b in self.behaviors}

    def frame(self, behavior, t):
        spec = self.behaviors[behavior]
        seq, step = spec['frames'], spec['step'] / 1000
        index = seq[min(int(t / step), len(seq) - 1)] if t < len(seq) * step else seq[-1]
        im = self.back.copy()
        im.alpha_composite(self.frames[behavior][index])
        im.alpha_composite(self.front)
        if not spec.get('hide_cup'):
            im.alpha_composite(self.cup)
        return im


def bubble(text, width, scale):
    f = font(FONT, int(40 * scale))
    probe = ImageDraw.Draw(Image.new('RGBA', (1, 1)))
    lines, line = [], ''
    for ch in text:
        if probe.textlength(line + ch, font=f) > width - 64 * scale:
            lines.append(line)
            line = ch
        else:
            line += ch
    lines.append(line)
    lh = int(60 * scale)
    h = int(72 * scale + lh * len(lines))
    im = Image.new('RGBA', (int(width), h + int(26 * scale)), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    shadow = Image.new('RGBA', im.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((6, 10, width - 6, h), radius=int(36 * scale), fill=(128, 80, 101, 60))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(10 * scale)))
    d.rounded_rectangle((2, 2, width - 3, h - 4), radius=int(36 * scale), fill=(255, 247, 250, 255), outline=(231, 200, 215, 255), width=max(1, int(2 * scale)))
    tx = width * 0.72
    d.polygon([(tx - 16 * scale, h - 5), (tx + 16 * scale, h - 5), (tx, h + 18 * scale)], fill=(255, 247, 250, 255))
    for i, ln in enumerate(lines):
        d.text((32 * scale, 30 * scale + i * lh), ln, font=f, fill=(87, 66, 79, 255))
    return im


def shot_frame(shot, t, stills, W, H, pet, layout):
    imgs = shot['img'] if isinstance(shot['img'], list) else [shot['img']]
    d = shot['d']
    if shot.get('split'):
        idx = 0 if t < shot['split'] else 1
        local, span = (t, shot['split']) if idx == 0 else (t - shot['split'], d - shot['split'])
    else:
        span = d / len(imgs)
        idx = min(int(t / span), len(imgs) - 1)
        local = t - idx * span
    z0, z1 = shot['zoom']
    p = t / d
    zoom = z0 + (z1 - z0) * (0.5 - 0.5 * math.cos(math.pi * p))
    name = imgs[idx]
    frame, (s, ox, oy) = cover(stills[name], W, H, zoom)
    frame = frame.convert('RGBA')
    if 'pet' in shot and name in layout and not (shot.get('split') and idx == 1):
        behavior, _, line = shot['pet']
        box = layout[name]  # x, y, size in the still's pixels: the empty bottom-right corner of the screen
        size = box[2] * s
        px, py = box[0] * s - ox, box[1] * s - oy
        appear = min(1, max(0, (t - 0.3) / 0.5))
        pim = pet.frame(behavior, max(0, t - 0.3)).resize((int(size), int(size)), Image.LANCZOS)
        glow = Image.new('RGBA', frame.size, (0, 0, 0, 0))
        glow.paste(pim, (int(px), int(py)), pim)
        glow.putalpha(glow.getchannel('A').point(lambda v: int(v * appear)))
        frame.alpha_composite(glow)
        if t > 0.9 and t < d - 0.3:
            bw = W * 0.74
            b = bubble(line, bw, W / 1080)
            ba = min(1, (t - 0.9) / 0.35, (d - 0.3 - t) / 0.3)
            bx = int(min(px + size * 0.5 - bw * 0.72, W - bw - W * 0.03))
            by = int(py - b.height + size * 0.06)
            b.putalpha(b.getchannel('A').point(lambda v: int(v * ba)))
            frame.alpha_composite(b, (max(int(W * 0.03), bx), max(int(H * 0.05), by)))
    for text, a, b2, kind in shot.get('caps', []):
        if a <= t <= b2:
            alpha = min(1, (t - a) / 0.4, (b2 - t) / 0.4)
            draw_caption(frame, text, kind, alpha, W, H)
    if 'clock' in shot:
        c0, c1 = shot['clock']
        m0 = int(c0[:2]) * 60 + int(c0[3:])
        m1 = int(c1[:2]) * 60 + int(c1[3:])
        m = int(m0 + (m1 - m0) * min(1, t / (d * 0.85)))
        draw_clock(frame, f'{m // 60:02d}:{m % 60:02d}', 1, W, H)
    # fade from / to black at shot edges
    edge = min(t / 0.45, (d - t) / 0.45, 1)
    if shot.get('split') and abs(t - shot['split']) < 0.5:
        edge = min(edge, abs(t - shot['split']) / 0.5 * 0.85 + 0.15)
    if edge < 1:
        black = Image.new('RGBA', frame.size, (0, 0, 0, int(255 * (1 - edge))))
        frame.alpha_composite(black)
    return frame


def end_frame(t, d, W, H, pet):
    frame = Image.new('RGBA', (W, H), PINK + (255,))
    dr = ImageDraw.Draw(frame)
    size = int(min(W, H) * (0.62 if H > W else 0.52))
    pim = pet.frame('peek', t % 2.5).resize((size, size), Image.LANCZOS)
    cx = W // 2 if H > W else int(W * 0.30)
    py = int(H * 0.40 - size / 2) if H > W else int(H * 0.5 - size / 2)
    frame.alpha_composite(pim, (cx - size // 2, py))
    def put(text, fnt, y, color, a, x=None):
        tw, th, ox, oy = text_box(dr, text, fnt)
        xx = (W - tw) / 2 - ox if x is None else x - ox
        layer = Image.new('RGBA', frame.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).text((xx, y - oy), text, font=fnt, fill=color + (int(255 * a),))
        frame.alpha_composite(layer)
    fa = lambda t0: max(0, min(1, (t - t0) / 0.6))
    portrait = H > W
    x = None if portrait else int(W * 0.56)
    y0 = int(H * 0.68) if portrait else int(H * 0.30)
    put('别再漫无目的地熬夜了。', font(FONT_SERIF, int(W * (0.055 if portrait else 0.032))), y0, (120, 70, 95), fa(0.3), x)
    put('长大了以后，也要按时睡觉呀～', font(FONT_SERIF, int(W * (0.055 if portrait else 0.032))), y0 + int(W * (0.085 if portrait else 0.05)), (120, 70, 95), fa(1.6), x)
    put('晚晚 · 关机助理', font(FONT, int(W * (0.075 if portrait else 0.045))), y0 + int(W * (0.21 if portrait else 0.13)), (87, 66, 79), fa(3.6), x)
    put('免费开源 · Windows 下载即用', font(FONT_LIGHT, int(W * (0.038 if portrait else 0.022))), y0 + int(W * (0.31 if portrait else 0.19)), (163, 113, 137), fa(4.2), x)
    put(URL, font(FONT_LIGHT, int(W * (0.033 if portrait else 0.02))), y0 + int(W * (0.37 if portrait else 0.225)), (163, 113, 137), fa(4.6), x)
    if t < 0.6:
        frame.alpha_composite(Image.new('RGBA', frame.size, (0, 0, 0, int(255 * (1 - t / 0.6)))))
    return frame


# ---------- audio ----------

def piano_note(freq, dur, vel=0.18):
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = np.exp(-t * 2.2) * (1 - np.exp(-t * 400))
    tone = sum(a * np.sin(2 * np.pi * freq * k * t) for k, a in ((1, 1), (2, 0.42), (3, 0.18), (4, 0.08)))
    return (tone * env * vel).astype(np.float32)


def music(total, gaps):
    """A slow, soft piano progression; silent inside `gaps` (start, end)."""
    out = np.zeros(int(total * SR) + SR, np.float32)
    hz = lambda m: 440 * 2 ** ((m - 69) / 12)
    chords = [(57, 64, 69, 72), (53, 60, 65, 69), (48, 55, 64, 67), (55, 62, 67, 71)]  # Am F C G
    beat = 0.75
    i = 0
    tt = 0.0
    while tt < total:
        chord = chords[(i // 4) % 4]
        note = chord[[0, 2, 1, 3][i % 4]]
        if i % 4 == 0:
            for m in chord[:2]:
                seg = piano_note(hz(m - 12), 3.0, 0.08)
                s = int(tt * SR)
                out[s:s + len(seg)] += seg[:len(out) - s]
        seg = piano_note(hz(note + 12), 2.2, 0.10)
        s = int(tt * SR)
        out[s:s + len(seg)] += seg[:len(out) - s]
        tt += beat
        i += 1
    env = np.ones_like(out)
    for a, b in gaps:
        sa, sb = int(a * SR), int(b * SR)
        ramp = int(1.2 * SR)
        env[sa:sb] = 0
        env[max(0, sa - ramp):sa] = np.minimum(env[max(0, sa - ramp):sa], np.linspace(1, 0, sa - max(0, sa - ramp)))
        env[sb:sb + ramp] = np.minimum(env[sb:sb + ramp], np.linspace(0, 1, len(env[sb:sb + ramp])))
    # simple room: a few decaying echoes
    wet = out.copy()
    for delay, gain in ((0.11, 0.35), (0.23, 0.22), (0.41, 0.12)):
        k = int(delay * SR)
        wet[k:] += out[:-k] * gain
    return wet * env


def tick(n=1):
    seg = np.zeros(int(0.06 * SR), np.float32)
    t = np.arange(len(seg)) / SR
    seg += np.sin(2 * np.pi * 2400 * t) * np.exp(-t * 120) * 0.08
    return seg


def ding():
    t = np.arange(int(0.6 * SR)) / SR
    return ((np.sin(2 * np.pi * 1318 * t) + 0.5 * np.sin(2 * np.pi * 1976 * t)) * np.exp(-t * 7) * 0.12).astype(np.float32)


def keys(dur):
    rng = np.random.default_rng(3)
    out = np.zeros(int(dur * SR), np.float32)
    tt = 0.1
    while tt < dur - 0.1:
        n = int(0.025 * SR)
        click = rng.normal(0, 1, n).astype(np.float32) * np.exp(-np.arange(n) / SR * 260) * 0.05
        s = int(tt * SR)
        out[s:s + n] += click[:len(out) - s]
        tt += rng.uniform(0.09, 0.32)
    return out


def hum(dur, level=0.012):
    rng = np.random.default_rng(5)
    noise = rng.normal(0, 1, int(dur * SR)).astype(np.float32)
    k = 400
    noise = np.convolve(noise, np.ones(k) / k, mode='same') * 8
    return noise * level


def power_down():
    t = np.arange(int(0.9 * SR)) / SR
    f = 220 * np.exp(-t * 2.5)
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4) * 0.10).astype(np.float32)


def birds(dur):
    rng = np.random.default_rng(9)
    out = np.zeros(int(dur * SR), np.float32)
    for start in rng.uniform(0.2, dur - 0.6, 6):
        n = int(0.18 * SR)
        t = np.arange(n) / SR
        f = 3200 + 900 * np.sin(2 * np.pi * 14 * t)
        chirp = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / t[-1]) * 0.03
        s = int(start * SR)
        out[s:s + n] += chirp[:len(out) - s]
    return out


def build_audio(assets, starts, total, path):
    mix = np.zeros(int(total * SR) + SR, np.float32)
    def put(seg, at, gain=1.0):
        s = int(at * SR)
        e = min(len(mix), s + len(seg))
        mix[s:e] += seg[:e - s] * gain
    # music: quiet from the lonely room (shot 5) until Wanwan speaks (shot 8)
    mix += music(total, [(starts[4] + 0.2, starts[7] + 0.4)])[:len(mix)] * 0.9
    for k in range(0, 5):
        put(tick(), starts[0] + 0.5 + k * 0.95)
    put(ding(), starts[3] + 0.6)
    put(hum(starts[7] - starts[4] + 1), starts[4])
    put(keys(5.5), starts[4] + 0.3)
    put(keys(5.0), starts[5] + 0.5, 0.8)
    put(power_down(), starts[8] + SHOTS[8]['split'] - 0.2)
    put(birds(4.5), starts[9] + 0.2)
    voice_at = {7: 1.0, 8: 0.9, 9: 0.9}
    for idx, at in voice_at.items():
        put(load_audio(find_voice(assets, SHOTS[idx]['pet'][1])), starts[idx] + at, 1.2)
    put(load_audio(find_voice(assets, 'line-s11')), starts[10] + 0.6, 1.2)
    peak = np.max(np.abs(mix)) or 1
    mix = np.clip(mix / max(peak, 1.0) * 0.95, -1, 1)
    fade = int(1.5 * SR)
    mix[int(total * SR) - fade:int(total * SR)] *= np.linspace(1, 0, fade)
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((mix[:int(total * SR)] * 32767).astype(np.int16).tobytes())


def main(assets, out, landscape=False, preview=None):
    assets = Path(assets)
    W, H = (1920, 1080) if landscape else (1080, 1920)
    layout = json.loads((assets / 'layout.json').read_text(encoding='utf-8')) if (assets / 'layout.json').is_file() else {}
    names = {n for s in SHOTS if 'img' in s for n in (s['img'] if isinstance(s['img'], list) else [s['img']])}
    stills = {n: Image.open(assets / f'{n}.png').convert('RGB') for n in names}
    if landscape:
        # vertical stills on a landscape canvas: the still centred over a blurred, darkened copy of itself
        for n, im in stills.items():
            bg, _ = cover(im, W, H, 1.0)
            bg = bg.filter(ImageFilter.GaussianBlur(40)).point(lambda v: int(v * 0.55))
            fg = im.resize((int(im.width * H / im.height), H), Image.LANCZOS)
            bg.paste(fg, ((W - fg.width) // 2, 0))
            scale = H / im.height
            if n in layout:
                x, y, size = layout[n]
                layout[n] = [x * scale + (W - fg.width) / 2, y * scale, size * scale]
            stills[n] = bg
    pet = Pet()
    starts, t = [], 0.0
    for s in SHOTS:
        starts.append(t)
        t += s['d']
    total = t
    wav = Path(out).with_suffix('.wav')
    if preview is None:
        build_audio(assets, starts, total, wav)
    frames = int(total * FPS)
    pick = range(frames)
    if preview is not None:
        k = int(preview * FPS)
        tt = k / FPS
        i = max(j for j, s in enumerate(starts) if s <= tt)
        s = SHOTS[i]
        im = end_frame(tt - starts[i], s['d'], W, H, pet) if s.get('end') else shot_frame(s, tt - starts[i], stills, W, H, pet, layout)
        im.convert('RGB').save(out)
        return
    enc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                            '-i', str(wav), '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p',
                            '-c:a', 'aac', '-b:a', '160k', '-shortest', '-movflags', '+faststart', str(out)], stdin=subprocess.PIPE)
    for k in pick:
        tt = k / FPS
        i = max(j for j, s in enumerate(starts) if s <= tt)
        s = SHOTS[i]
        im = end_frame(tt - starts[i], s['d'], W, H, pet) if s.get('end') else shot_frame(s, tt - starts[i], stills, W, H, pet, layout)
        enc.stdin.write(im.convert('RGB').tobytes())
    enc.stdin.close()
    enc.wait()
    wav.unlink()
    print(f'{out}: {total:.1f}s, {W}x{H}')


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(usage=__doc__)
    ap.add_argument('assets')
    ap.add_argument('out')
    ap.add_argument('--landscape', action='store_true')
    ap.add_argument('--preview', type=float, help='write one frame at this second as a PNG instead of the film')
    a = ap.parse_args()
    main(a.assets, a.out, landscape=a.landscape, preview=a.preview)
