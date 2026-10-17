"""Make an audit illustration from unchanged atlas crops and reviewed exports."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
layout=json.loads((ROOT/'assets/character-frame-layout.json').read_text(encoding='utf-8'))
canvas=Image.new('RGB',(1100,1200),'#302a36');draw=ImageDraw.Draw(canvas)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',22)
draw.text((30,15),'BEFORE: uniform atlas split',font=font,fill='#f5d9de')
draw.text((575,15),'AFTER: reviewed transparent frame',font=font,fill='#d8ecd9')
for row,(action,index) in enumerate([('peek',3),('heart',3),('stretch',0)]):
    record=next(r for r in layout['frames'] if r['action']==action and r['index']==index)
    sheet=Image.open(ROOT/record['source']).convert('RGBA');x,y,w,h=record['source_rect'];ox,oy=record['offset']
    before=Image.new('RGBA',(640,640));before.alpha_composite(sheet.crop((x,y,x+w,y+h)),(ox,oy))
    after=Image.open(ROOT/record['file']).convert('RGBA')
    for column,image in enumerate([before,after]):
        image.thumbnail((360,360));canvas.paste(image,(90+column*550,65+row*380),image)
    draw.text((30,65+row*380),f'{action}/{index}',font=font,fill='white')
destination=ROOT/'docs/screenshots/frame-repair-comparison.png';canvas.save(destination,optimize=True)
print('Saved before/after audit comparison; no source images changed.')
