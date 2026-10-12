"""Package the generated artwork as Windows multi-resolution icon resources."""
import json
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / 'assets/icons'
source = Image.open(folder / 'wanwan-icon.png').convert('RGBA')
assert source.getextrema()[3][0] == 0, 'Icon needs actual transparent corners'
sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
source.save(folder / 'wanwan.ico', sizes=[(n, n) for n in sizes])
for size in [16, 32, 64, 256]:
    source.resize((size, size), Image.Resampling.LANCZOS).save(folder / f'wanwan-{size}.png')
prompt = 'Use case: stylized-concept. Asset type: one polished Windows app icon, square image. Use the supplied image ONLY as the identity reference for Wanwan, an original adult Chinese female companion: warm brown shoulder-length hair with soft bangs, gentle brown eyes, cream knit cardigan. Create a close-up head-and-shoulders illustrated portrait with soft, refined 3D illustration / hand-painted icon rendering, friendly gentle smile, face LARGE and centered for excellent readability at 32px. Simplify hair into clean flowing shapes and facial detail into broad readable forms. Put the portrait inside a solid muted warm rose rounded-square icon tile with rounded corners and a small pale cream crescent moon in the upper right, kept separate from the face. Very premium calm bedtime companion feeling, crisp clean edges, restrained palette, no text, no tiny ornamental detail. No enclosing outer frame or padding: the rounded square fills about 94 percent of square canvas, actual transparent pixels outside tile rounded corners. Deliver ONLY this one square icon, no multiple variants, no montage, no mockup. Preserve recognizable adult character likeness but stylize rather than photorealism.'
data = dict(tool='built-in image_gen', reference='assets/wanwan.png', output='assets/icons/wanwan-icon.png', icon_sizes=sizes, prompt=prompt, prompt_summary='晚晚近景头像、暖玫瑰色圆角、小月亮、透明外缘、适合小尺寸 Windows 图标', source_file='image_gen artifact: exec-a0f30916-1f15-4d1c-a4cd-6958c74045de.png')
(folder / 'source.json').write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
print('Packaged transparent Wanwan icon in nine Windows sizes')
