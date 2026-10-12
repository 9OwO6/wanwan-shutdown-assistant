"""Read-only asset inspection; rendering and animation acceptance live in WPF tests."""
import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[1]
catalog=json.loads((root/'assets'/'interactions.json').read_text(encoding='utf-8-sig'))
report=[];hashes=set()
for item in catalog:
    path=root/'assets'/'interactions'/(item['id']+'.png')
    with Image.open(path) as image:
        assert image.mode=='RGBA',f'{path} must have alpha'
        pixels=np.asarray(image)
    h,w=pixels.shape[:2];fh,fw=h//2,w//2
    alpha=pixels[:,:,3];transparent=float(np.mean(alpha==0))
    assert transparent>.1,f'{path} lacks a transparent background'
    cells=[]
    for frame in range(4):
        y,x=divmod(frame,2);cell=pixels[y*fh:(y+1)*fh,x*fw:(x+1)*fw]
        checksum=hashlib.sha256(cell.tobytes()).hexdigest()
        assert checksum not in hashes,'Duplicate pose across interaction assets'
        hashes.add(checksum);cells.append(checksum)
    report.append(dict(id=item['id'],size=[w,h],cell_size=[fw,fh],transparent_ratio=transparent,frame_hashes=cells))
assert len(report)==10 and len(hashes)==40
(root/'output'/'interaction-review'/'asset-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('Validated ten transparent spritesheets, forty unique poses; originals unchanged')
