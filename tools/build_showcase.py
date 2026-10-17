"""Compose a portfolio cover and GIF from actual isolated WPF captures."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/screenshots'

def font(size, bold=False):
    name = 'segoeuib.ttf' if bold else 'segoeui.ttf'
    for candidate in (Path('C:/Windows/Fonts') / name,
                      Path('/usr/share/fonts/opentype/inter') / ('Inter-SemiBold.otf' if bold else 'Inter-Regular.otf')):
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default(size=size)

cover = Image.new('RGB', (1600, 1120), '#f7eff4')
draw = ImageDraw.Draw(cover)
draw.text((65, 42), 'WANWAN', fill='#493342', font=font(55, True))
draw.text((65, 111), 'A gentler way to end the day.', fill='#8e657d', font=font(27))
draw.text((950, 73), 'Windows native  /  AI-assisted engineering', fill='#8e657d', font=font(22))

def place(name, box, label):
    source = Image.open(OUT / name).convert('RGBA')
    source.thumbnail((box[2], box[3]), Image.Resampling.LANCZOS)
    draw.rounded_rectangle((box[0]-8, box[1]-8, box[0]+source.width+8, box[1]+source.height+8), radius=22, fill='#ffffff')
    cover.paste(source, box[:2], source)
    draw.text((box[0], box[1]+source.height+18), label, fill='#8e657d', font=font(18))

place('main-window.png', (65, 190, 985, 785), 'Real WPF application · Chinese interface')
place('reminder-bubble.png', (1120, 190, 390, 420), 'Time-aware companion reminder')
place('desktop-pet.png', (1135, 700, 142, 180), 'Drag · hide · visible guard state')
draw.text((65, 1030), 'Offline voice assets   •   Animated desktop companion   •   Deterministic bedtime scheduling', fill='#6f5064', font=font(23))
cover.save(OUT / 'showcase.png', optimize=True)

frames = []
for path in sorted((ROOT / 'output/showcase-frames').glob('frame-*.png')):
    source = Image.open(path).convert('RGBA')
    background = Image.new('RGBA', source.size, '#f7eff4')
    background.alpha_composite(source)
    frames.append(background.convert('RGB').quantize(colors=192))
assert len(frames) == 32, 'Run app/Main.ps1 -ShowcaseTest first'
frames[0].save(OUT / 'companion-animation.gif', save_all=True, append_images=frames[1:], duration=100, loop=0, disposal=2, optimize=False)
print('Composed portfolio cover and 32 captured animation frames; source screenshots retained.')
