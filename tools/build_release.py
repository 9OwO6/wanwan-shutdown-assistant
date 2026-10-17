"""Build the slim portable Windows ZIP from the runtime files only.

    python tools/build_release.py v0.3.0

Produces dist/Wanwan-<version>-windows.zip containing a single ``Wanwan``
folder. WAV masters, generation references, unused concept art, tests and
media-production tools stay in the repository and are not shipped. The staged
folder is audited with verify_release_assets.py before zipping.
"""
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = sys.argv[1] if len(sys.argv) > 1 else 'dev'
DIST = ROOT / 'dist'
STAGE = DIST / 'stage' / 'Wanwan'

TOP_LEVEL = ['VERSION', 'Start-Wanwan.ps1', '启动晚晚.vbs', '启动晚晚.cmd', 'LICENSE', 'NOTICE.md', 'README.md']
RUNTIME_GLOBS = [
    'app/*.ps1',
    'assets/*.json',
    'assets/wanwan.png',
    'assets/icons/*',
    'assets/frames/*/*.png',
    'assets/voices/**/*.mp3',
    'assets/voices/manifest.json',
    'assets/voices/N1/manifest.json',
    'assets/voices/N1-clock/manifest.json',
    'assets/voices/N1-guard/manifest.json',
    'assets/voices/N1-watch/manifest.json',
]
EXCLUDE_PARTS = {'reference', 'parts'}
EXCLUDE_NAMES = {'voice-lab-candidates.json'}

if STAGE.parent.exists():
    shutil.rmtree(STAGE.parent)
files = [ROOT / name for name in TOP_LEVEL]
for pattern in RUNTIME_GLOBS:
    files.extend(sorted(ROOT.glob(pattern)))
copied = 0
for src in files:
    rel = src.relative_to(ROOT)
    if EXCLUDE_PARTS & set(rel.parts) or rel.name in EXCLUDE_NAMES or not src.is_file():
        continue
    dst = STAGE / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    copied += 1

# Character art is the other large payload. A 256-colour palette with alpha
# (libimagequant) is visually indistinguishable at display size and ~3x smaller.
try:
    import imagequant
    from PIL import Image
    for png in [*STAGE.glob('assets/frames/*/*.png'), STAGE / 'assets/wanwan.png']:
        quantized = imagequant.quantize_pil_image(Image.open(png).convert('RGBA'), dithering_level=1.0,
                                                  max_colors=256, min_quality=70, max_quality=95)
        quantized.save(png, optimize=True)
except ImportError:
    print('imagequant/Pillow not installed: shipping lossless character art')

subprocess.run([sys.executable, str(ROOT / 'tools' / 'verify_release_assets.py'), str(STAGE)], check=True)

DIST.mkdir(exist_ok=True)
archive = DIST / f'Wanwan-{VERSION}-windows.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for path in sorted(STAGE.rglob('*')):
        if path.is_file():
            zf.write(path, path.relative_to(STAGE.parent))
print(f'{archive.relative_to(ROOT)}: {copied} files, {archive.stat().st_size / 1_000_000:.1f} MB')
