"""Read-only asset inspection; rendering and animation acceptance live in WPF tests."""
import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from audit_sprite_frames import components
root=Path(__file__).resolve().parents[1]
catalog=json.loads((root/'assets'/'interactions.json').read_text(encoding='utf-8-sig'))
report=[];hashes=set()
layout=json.loads((root/'assets/character-frame-layout.json').read_text(encoding='utf-8'))
assert layout['canvas']==[640,640] and len(layout['frames'])==40
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
        record=next(r for r in layout['frames'] if r['action']==item['id'] and r['index']==frame)
        assert hashlib.sha256(path.read_bytes()).hexdigest()==record['source_sha256'],'Source atlas changed without review'
        image_path=root/record['file']
        with Image.open(image_path) as clean:
            assert clean.mode=='RGBA' and clean.size==(640,640)
            cell=np.asarray(clean)
        # No significant disconnected sleeve may remain, on either side.
        groups=components(cell[:,:,3]>=24)
        assert not any(g['area']>=100 for g in groups[1:]),f'Neighboring sleeve remains: {item["id"]}/{frame}'
        assert not np.any(cell[0,:,3]) and not np.any(cell[-1,:,3]) and not np.any(cell[:,0,3]) and not np.any(cell[:,-1,3]),'Transparent canvas gutter missing'
        x,y,w,h=record['source_rect'];ox,oy=record['offset']
        original=pixels[y:y+h,x:x+w];rendered=cell[oy:oy+h,ox:ox+w]
        excluded=np.zeros((h,w),bool)
        for sx,sy,sw,sh in record['excluded_spans']:excluded[sy:sy+sh,sx:sx+sw]=True
        assert not np.any(excluded[:,64:-64]),'Central face/hands must never be clipped'
        assert not np.any(rendered[:,:,3][excluded]),'Excluded fragment is still visible'
        if item['id']=='peek' and frame==3:
            assert not np.any(rendered[:,:40,3]),'Connected neighboring-sleeve stub remains at the reviewed left seam'
        opaque=(original[:,:,3]==255)&~excluded
        assert np.array_equal(original[:,:,:3][opaque],rendered[:,:,:3][opaque]),'Original opaque character pixels changed'
        checksum=hashlib.sha256(cell.tobytes()).hexdigest()
        assert checksum not in hashes,'Duplicate pose across interaction assets'
        hashes.add(checksum);cells.append(checksum)
    report.append(dict(id=item['id'],size=[w,h],cell_size=[fw,fh],transparent_ratio=transparent,frame_hashes=cells))
assert len(report)==10 and len(hashes)==40
out=root/'output'/'interaction-review';out.mkdir(parents=True,exist_ok=True)
(out/'asset-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for offset in (0,5):
    contact=Image.new('RGB',(1000,1350),'#302a36');draw=ImageDraw.Draw(contact)
    for row,item in enumerate(catalog[offset:offset+5]):
        for frame in range(4):
            image=Image.open(root/f'assets/frames/{item["id"]}/{frame}.png').convert('RGBA');image.thumbnail((235,235))
            contact.paste(image,(frame*250+(250-image.width)//2,row*270+25),image)
            draw.text((frame*250+8,row*270+4),f'{item["id"]} / {frame}',fill='white')
    contact.save(out/f'clean-contact-{offset//5+1}.jpg',quality=92)
print('Validated forty 640x640 transparent frames: no significant neighboring components, protected original opaque pixels, intact gutters and forty unique poses. Source atlases unchanged.')
