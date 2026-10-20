"""Import the desk-scene layers (seated Wanwan at her desk) into assets/desk/.

    python tools/import_desk_art.py path/to/output/desk-art/layers

Copies the background, the desk front layers (lamp on/off, with/without the mug) and
every complete behavior (four 640x640 RGBA frames), then writes assets/desk/desk.json,
which app/Visuals.ps1 loads for the compact desk pet. Behaviors with missing frames are
skipped and reported, so a partial sample can still be tried in the app.
"""
import json
import shutil
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'desk'
BEHAVIORS = {
    'write': {'name': '写字', 'frames': [0, 1, 2, 3, 2, 1], 'step': 420},
    'drink': {'name': '喝水', 'frames': [0, 1, 2, 2, 3, 0], 'step': 480, 'hide_cup': True},
    'yawn': {'name': '打哈欠', 'frames': [0, 1, 2, 3, 2, 0], 'step': 460},
    'sleep': {'name': '趴着睡', 'frames': [0, 1, 2, 3, 2, 1], 'step': 700},
    'watch': {'name': '陪你看视频', 'frames': [0, 1, 0, 2, 3, 2], 'step': 520},
    'play': {'name': '陪你玩游戏', 'frames': [0, 1, 2, 1, 2, 3], 'step': 380},
    'stretch': {'name': '伸懒腰', 'frames': [0, 1, 2, 2, 3, 0], 'step': 460},
    'peek': {'name': '抬头看你', 'frames': [0, 1, 2, 3, 2, 1], 'step': 420},
    'poked': {'name': '被戳了', 'frames': [0, 1, 2, 3], 'step': 360},
    'goodnight': {'name': '说晚安', 'frames': [0, 1, 2, 1, 2, 3], 'step': 460},
}
# Layer order (Codex render recipe): back + desk back -> character -> desk front occlusion -> mug.
# The two back plates are flattened here; lamp on/off variants for the back and the front.
# Two layouts are supported:
# - minimal (preferred, user's choice): transparent back -> desk back strip -> desk surface + notebook
#   -> character -> desk edge -> mug; a faint warm glow behind her while she naps.
# - room: back + desk back (lamp on/off) -> character -> desk front occlusion (lamp on/off) -> mug.
LAYOUTS = {
    'minimal': {'detect': 'desk-surface.png',
                'backs': {'back': ('back.png', 'desk-back.png', 'desk-surface.png'),
                          'back_lamp_off': ('back.png', 'glow.png', 'desk-back.png', 'desk-surface.png')},
                'fronts': {'front': 'desk-edge.png', 'cup': 'cup.png'}},
    'room': {'detect': 'desk-front-occlusion-no-cup.png',
             'backs': {'back': ('back.png', 'desk-back.png'), 'back_lamp_off': ('back.png', 'desk-back-lamp-off.png')},
             'fronts': {'front': 'desk-front-occlusion-no-cup.png', 'front_lamp_off': 'desk-front-occlusion-lamp-off-no-cup.png', 'cup': 'cup.png'}},
}


def png_size(path):
    data = path.read_bytes()[:26]
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    return width, height, color


def main(source):
    source = Path(source).resolve()
    OUT.mkdir(parents=True, exist_ok=True)
    from PIL import Image
    layers = {}
    layout = next(name for name, spec in LAYOUTS.items() if (source / spec['detect']).is_file())
    for old in OUT.glob('*.png'):
        old.unlink()
    for key, parts in LAYOUTS[layout]['backs'].items():
        if all((source / part).is_file() for part in parts):
            image = Image.open(source / parts[0]).convert('RGBA')
            for part in parts[1:]:
                image.alpha_composite(Image.open(source / part).convert('RGBA'))
            assert image.size == (640, 640)
            image.save(OUT / f'{key}.png', optimize=True)
            layers[key] = f'{key}.png'
    for key, name in LAYOUTS[layout]['fronts'].items():
        src = source / name
        if src.is_file():
            assert png_size(src)[:2] == (640, 640), src
            shutil.copyfile(src, OUT / name)
            layers[key] = name
    assert 'back' in layers and 'front' in layers, 'back + desk-back and the front occlusion layer are required'
    behaviors, skipped = {}, []
    for behavior, spec in BEHAVIORS.items():
        frames = [source / 'character' / behavior / f'{i}.png' for i in range(4)]
        if not all(f.is_file() for f in frames):
            skipped.append(behavior)
            continue
        target = OUT / 'character' / behavior
        target.mkdir(parents=True, exist_ok=True)
        for i, frame in enumerate(frames):
            width, height, color = png_size(frame)
            assert (width, height) == (640, 640) and color == 6, f'{frame}: need 640x640 RGBA'
            shutil.copyfile(frame, target / f'{i}.png')
        behaviors[behavior] = spec
    assert behaviors, 'no complete behavior to import'
    (OUT / 'desk.json').write_text(json.dumps({'layers': layers, 'behaviors': behaviors}, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    print(f'Imported {layout} layout: layers {sorted(layers)} and behaviors {sorted(behaviors)}' + (f'; skipped incomplete {skipped}' if skipped else ''))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
