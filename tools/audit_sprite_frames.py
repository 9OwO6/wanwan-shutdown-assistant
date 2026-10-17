"""Inspect the existing half-sheet runtime crops, without modifying source art."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/sprite-audit';OUT.mkdir(parents=True,exist_ok=True)

def components(mask):
    parent=[0];runs=[];previous=[]
    def find(label):
        while parent[label]!=label:
            parent[label]=parent[parent[label]];label=parent[label]
        return label
    for y,row in enumerate(mask):
        edges=np.diff(np.pad(row.astype(np.int8),(1,1)))
        starts=np.flatnonzero(edges==1);ends=np.flatnonzero(edges==-1)
        current=[];cursor=0
        for x0,x1 in zip(starts,ends):
            x0=int(x0);x1=int(x1)
            while cursor<len(previous) and previous[cursor][1]<x0:cursor+=1
            matches=[];j=cursor
            while j<len(previous) and previous[j][0]<=x1:
                matches.append(find(previous[j][2]));j+=1
            if matches:
                label=matches[0]
                for other in matches[1:]:parent[find(other)]=find(label)
            else:
                label=len(parent);parent.append(label)
            current.append((x0,x1,label));runs.append((y,x0,x1,label))
        previous=current
    groups={}
    for y,x0,x1,label in runs:
        key=find(label)
        if key not in groups:groups[key]={'area':0,'bbox':[x0,y,x1,y+1],'runs':[]}
        group=groups[key];group['area']+=x1-x0
        b=group['bbox'];b[0]=min(b[0],x0);b[1]=min(b[1],y);b[2]=max(b[2],x1);b[3]=max(b[3],y+1)
        group['runs'].append((y,x0,x1))
    return sorted(groups.values(),key=lambda g:g['area'],reverse=True)

def main():
    catalog=json.loads((ROOT/'assets/interactions.json').read_text(encoding='utf-8-sig'))
    records=[];pages=[]
    for offset in range(0,len(catalog),5):
        page=Image.new('RGB',(1000,5*270),'#302a36');draw=ImageDraw.Draw(page)
        for row_index,item in enumerate(catalog[offset:offset+5]):
            sheet=Image.open(ROOT/f"assets/interactions/{item['id']}.png").convert('RGBA');w,h=sheet.width//2,sheet.height//2
            for frame in range(4):
                x,y=(frame%2)*w+8,(frame//2)*h+8
                cell=sheet.crop((x,y,x+w-16,y+h-16));cell.save(OUT/f"{item['id']}-{frame}-before.png")
                groups=components(np.asarray(cell)[:,:,3]>=24)
                largest=groups[0];main_mask=np.zeros((cell.height,cell.width),bool)
                for yy,x0,x1 in largest['runs']:main_mask[yy,x0:x1]=True
                fragments=[]
                for group in groups[1:]:
                    if group['area']<20:continue
                    x0,y0,x1,y1=group['bbox']
                    fragments.append({'area':group['area'],'bbox':group['bbox'],'main_pixels_in_rect':int(main_mask[y0:y1,x0:x1].sum())})
                records.append({'action':item['id'],'frame':frame,'crop':[x,y,w-16,h-16],'main':{'area':largest['area'],'bbox':largest['bbox']},'fragments':fragments})
                thumb=cell.copy();thumb.thumbnail((235,235))
                page.paste(thumb,(frame*250+(250-thumb.width)//2,row_index*270+25),thumb)
                draw.text((frame*250+8,row_index*270+4),f"{item['id']} / {frame}",fill='white')
        path=OUT/f'contact-{offset//5+1}.jpg';page.save(path,quality=92);pages.append(str(path))
    (OUT/'audit.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
    for r in records:
        significant=[g for g in r['fragments'] if g['area']>=100]
        if significant:print(r['action'],r['frame'],'main',r['main']['bbox'],'fragments',significant)
    print('Inspected 40 frames; source files unchanged. Contact sheets:',*pages)

if __name__=='__main__':main()
