#!/usr/bin/env python3
"""Deterministic original vector art; no downloaded or model-generated imagery."""
from pathlib import Path
import math,random,wave,struct
ROOT=Path(__file__).resolve().parents[1]/'assets'
def svg(name,body,w=64,h=64):
 p=ROOT/(name+'.svg');p.parent.mkdir(parents=True,exist_ok=True)
 p.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>')
def rect(x,y,w,h,c,rx=0):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{c}"/>'
colors=['#7cc8d0','#f2bd78','#9dc894','#d294b4','#ee8b65','#b5b3e5']
for category,c in enumerate(colors):
 for i in range(4):
  b=rect(3,3,58,58,'#172d36',9)+f'<rect x="4" y="4" width="56" height="56" rx="8" stroke="{c}" fill="none" opacity=".5"/>'
  if category==0: b+=f'<path d="M32 12 Q8 39 23 48 Q44 60 48 39 Q47 29 32 12" fill="{c}"/>'+rect(25,35,5,9,'#d3f8f4',2)
  elif category==1:b+=rect(19,17,28,34,c,4)+rect(26,12,13,5,c)+f'<path d="M35 22 L25 35 H33 L29 46 L42 31 H33Z" fill="#172d36"/>'
  elif category==2:b+=rect(17,18,30,31,c,5)+rect(22,13,20,5,c)+f'<path d="M24 29H40M24 35H40M24 41H34" stroke="#172d36" stroke-width="3"/>'
  elif category==3:b+=rect(18,15,28,35,c,6)+rect(25,22,14,5,'#172d36')+rect(29,18,6,14,'#172d36')
  elif category==4:b+=f'<path d="M12 26H45V21H51V35H37L31 49H22L27 35H12Z" fill="{c}"/>'
  else:b+=rect(18,18,28,28,c,4)+rect(24,24,16,16,'#172d36')+''.join(rect(13+j*10,12,4,7,c)+rect(13+j*10,46,4,7,c) for j in range(4))
  b+=rect(10,53,9+i*8,3,c,1)
  svg(f'items/{category}_{i}',b)
for d in range(4):
 for f in range(4):
  a=math.sin(f*math.pi/2)*3
  b='<ellipse cx="32" cy="55" rx="18" ry="6" fill="#081b26" opacity=".6"/>'
  b+=rect(21,39,8,14+a,'#b9c4bc',2)+rect(36,39,8,14-a,'#b9c4bc',2)
  b+=rect(16,25,33,23,'#d1a864',6)+rect(11,28,8,19,'#758a89',3)+rect(46,28,8,19,'#758a89',3)
  b+=rect(20,9,26,25,'#d6d9bd',9)+rect(23,15,20,11,'#183541',4)
  if d==0:b+=rect(24,16,8,5,'#86dfdb',2)
  if d==1:b+=rect(34,16,8,5,'#86dfdb',2)
  if d==2:b+=rect(25,16,16,5,'#86dfdb',2)
  if d==3:b+=rect(24,12,18,12,'#899c98',3)
  svg(f'player/{d}_{f}',b)
for i,c in enumerate(['#c89b84','#c1b77e','#ba82a1','#81afa2','#e8ab70']):
 b='<ellipse cx="32" cy="54" rx="23" ry="7" fill="#0a1e26" opacity=".7"/>'
 if i==0:b+=f'<path d="M9 41 L17 23 L24 30 L42 30 L51 20 L54 46 L42 51 L17 50Z" fill="{c}"/>'
 elif i==1:b+=rect(14,18,36,34,c,12)+rect(7,35,12,16,c,5)+rect(46,35,12,16,c,5)
 elif i==2:b+=f'<path d="M32 6 L55 49 L10 49Z" fill="{c}"/>'
 elif i==3:b+=rect(9,25,47,23,c,9)+rect(20,16,25,15,c,6)
 else:b+=rect(5,12,54,44,c,12)+rect(1,27,12,27,'#926a5b',4)+rect(51,27,12,27,'#926a5b',4)
 b+=rect(21,31,7,5,'#152a30',1)+rect(36,31,7,5,'#152a30',1)+rect(25,42,15,3,'#152a30',1)
 svg(f'enemies/{i}',b)
svg('bullet','<circle cx="8" cy="8" r="7" fill="#85e5dd" opacity=".3"/><circle cx="8" cy="8" r="4" fill="#cbfff3"/>',16,16)
svg('enemy_bullet','<circle cx="8" cy="8" r="6" fill="#ee896e"/><circle cx="7" cy="6" r="2" fill="#ffe6be"/>',16,16)
svg('icon',rect(0,0,64,64,'#10252f',12)+rect(14,10,36,40,'#8dd7d4',9)+rect(19,16,26,15,'#17333f',4)+rect(21,37,6,6,'#efc17e',3)+rect(38,37,6,6,'#efc17e',3)+'<path d="M21 55L26 49M43 55L38 49" stroke="#8dd7d4" stroke-width="4"/>')
svg('furniture/crate','<path d="M32 4L60 19L32 34L4 19Z" fill="#c6a778"/><path d="M4 19L32 34V61L4 46Z" fill="#786a57"/><path d="M32 34L60 19V46L32 61Z" fill="#9b855f"/>')
svg('floor',rect(0,0,96,48,'#253b43')+'<path d="M0 1H96M1 0V48M0 47H96M95 0V48M48 0V48" stroke="#314b52"/>',96,48)
svg('station',rect(9,8,46,45,'#8bd6d1',12)+rect(16,15,32,21,'#17343e',4)+rect(18,43,7,5,'#edc081',2)+rect(39,43,7,5,'#edc081',2))
svg('chest',rect(9,21,46,30,'#bb925d',4)+rect(9,19,46,11,'#dfb779',4)+rect(28,26,9,13,'#193540',2))
# Small original sound cues, deterministically synthesized.
for name,freq in [('shot',510),('pickup',880),('hit',170),('door',330)]:
 with wave.open(str(ROOT/(name+'.wav')),'wb') as w:
  w.setparams((1,2,22050,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',int(4500*math.sin(2*math.pi*freq*t/22050)*(1-t/2205))) for t in range(2205)))
print('Generated',len(list(ROOT.rglob('*.*'))),'original art/audio assets')
