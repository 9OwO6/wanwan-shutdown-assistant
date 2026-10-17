"""Describe native atlas clipping; never regenerate or paint character pixels."""
import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image
from audit_sprite_frames import components

ROOT=Path(__file__).resolve().parents[1]
catalog=json.loads((ROOT/'assets/interactions.json').read_text(encoding='utf-8-sig'))
frames=[]
for item in catalog:
    source=f"assets/interactions/{item['id']}.png"
    path=ROOT/source
    rgba=np.asarray(Image.open(path).convert('RGBA'));height,width=rgba.shape[:2];w,h=width//2,height//2
    for index in range(4):
        x,y=(index%2)*w+8,(index//2)*h+8
        cell=rgba[y:y+h-16,x:x+w-16];alpha=cell[:,:,3];groups=components(alpha>=24)
        primary=np.zeros(alpha.shape,bool)
        for yy,x0,x1 in groups[0]['runs']:primary[yy,x0:x1]=True
        excluded=np.zeros(alpha.shape,bool);artifacts=[]
        for component in groups[1:]:
            if component['area']<100:continue
            # Remove the neighboring component with a two-pixel antialias margin,
            # while protecting every opaque pixel of the actual central character.
            for yy,x0,x1 in component['runs']:
                excluded[max(0,yy-2):yy+3,max(0,x0-2):x1+2]=True
            artifacts.append({'area':component['area'],'bbox':component['bbox']})
        excluded &= ~primary
        if item['id']=='peek' and index==3:
            # The neighboring sleeve joins the main component along the bottom seam.
            # Its narrow left strip needs an explicit, reviewed atlas boundary.
            excluded[:,:40]=True
            artifacts.append({'reason':'neighboring sleeve connected at bottom atlas seam','bbox':[0,0,40,alpha.shape[0]]})
        spans=[]
        for yy,row in enumerate(excluded):
            edges=np.diff(np.pad(row.astype(np.int8),(1,1)))
            for x0,x1 in zip(np.flatnonzero(edges==1),np.flatnonzero(edges==-1)):
                spans.append([int(x0),yy,int(x1-x0),1])
        # The repair is limited to atlas edges; no central face/hand pixels are clipped.
        assert not np.any(excluded[:,64:-64])
        frames.append(dict(action=item['id'],index=index,source=source,source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),source_rect=[x,y,w-16,h-16],offset=[(640-(w-16))//2,632-(h-16)],excluded_spans=spans,artifacts=artifacts,file=f"assets/frames/{item['id']}/{index}.png"))
layout=dict(version=1,canvas=[640,640],method='native WPF atlas crop and reviewed edge clipping; no generative redraw',frames=frames)
(ROOT/'assets/character-frame-layout.json').write_text(json.dumps(layout,ensure_ascii=False,indent=2),encoding='utf-8')
print(f"Prepared 40 frame rectangles; repaired {sum(bool(f['artifacts']) for f in frames)} contaminated atlas slots. Original art unchanged.")
