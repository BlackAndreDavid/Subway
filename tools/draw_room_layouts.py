#!/usr/bin/env python3
"""Render a review sheet of the authored collision layouts (not runtime art)."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[1]
data=json.loads((root/'assets/rooms/layouts.json').read_text())
image=Image.new('RGB',(1120,380),'#10242e');draw=ImageDraw.Draw(image)
font=ImageFont.truetype(str(root/'assets/fonts/subway_cjk.otf'),15)
small=ImageFont.truetype(str(root/'assets/fonts/subway_cjk.otf'),12)
draw.text((20,12),'障碍布局库 · 10种 · 所有门口与可走区域保持连通',font=font,fill='#d6ddd9')
for index,layout in enumerate(data['layouts']):
 x0=20+(index%5)*220;y0=55+(index//5)*158
 draw.text((x0,y0),f'{index+1:02d}  {layout["name"]}',font=font,fill='#d1a864')
 for y,row in enumerate(layout['rows']):
  for x,char in enumerate(row):
   x1=x0+x*12;y1=y0+29+y*12
   draw.rectangle((x1,y1,x1+10,y1+10),fill='#587279' if char=='#' else '#1d3740')
 for x,y in [(7,0),(7,8),(0,4),(14,4)]:
  x1=x0+x*12;y1=y0+29+y*12
  draw.rectangle((x1,y1,x1+10,y1+10),outline='#8bc9bf',width=2)
draw.text((20,365),'绿色边框：预留门口    灰色：实体障碍    深色：可走区域',font=small,fill='#a3c4c2')
image.save(root/'assets/rooms/layouts_preview.png')
