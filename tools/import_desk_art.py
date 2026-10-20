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
    'drink': {'name': '喝水', 'frames': [0, 1, 2, 2, 3, 0], 'step': 480, 'front': 'front_no_cup'},
    'yawn': {'name': '打哈欠', 'frames': [0, 1, 2, 3, 2, 0], 'step': 460},
    'sleep': {'name': '趴着睡', 'frames': [0, 1, 2, 3, 2, 1], 'step': 700},
}
LAYERS = {'back': 'back.png', 'front': 'desk-front.png', 'front_lamp_off': 'desk-front-lamp-off.png',
          'front_no_cup': 'desk-front-no-cup.png', 'front_lamp_off_no_cup': 'desk-front-lamp-off-no-cup.png'}


def png_size(path):
    data = path.read_bytes()[:26]
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    return width, height, color


def main(source):
    source = Path(source).resolve()
    OUT.mkdir(parents=True, exist_ok=True)
    layers = {}
    for key, name in LAYERS.items():
        src = source / name
        if src.is_file():
            assert png_size(src)[:2] == (640, 640), src
            shutil.copyfile(src, OUT / name)
            layers[key] = name
    assert 'front' in layers, 'desk-front.png is required'
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
    print(f'Imported layers {sorted(layers)} and behaviors {sorted(behaviors)}' + (f'; skipped incomplete {skipped}' if skipped else ''))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
