#!/usr/bin/env python3
"""Region-median flat coloring and a deterministic shared median palette.

Run AFTER Godot import_art.gd. Never edits generated atlas sources/candidates.
No model calls, dithering, blur, interpolation, or randomly selected colors.
"""
from __future__ import annotations
from collections import Counter,defaultdict
from functools import lru_cache
from pathlib import Path
from statistics import median
import argparse,hashlib,json,math,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
@lru_cache(maxsize=None)
def lab(rgb):
 vals=[v/255 for v in rgb]
 r,g,b=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals]
 x=(.4124564*r+.3575761*g+.1804375*b)/.95047
 y=.2126729*r+.7151522*g+.0721750*b
 z=(.0193339*r+.1191920*g+.9503041*b)/1.08883
 f=lambda t: t**(1/3) if t>(6/29)**3 else t/(3*(6/29)**2)+4/29
 fx,fy,fz=f(x),f(y),f(z)
 return (116*fy-16,500*(fx-fy),200*(fy-fz))
def distance(a,b):return sum((a[i]-b[i])**2 for i in range(3))
def weighted_median(values):
 """Upper/lower middle average for an even number of original pixels."""
 values=sorted(values)
 total=sum(weight for _,weight in values)
 targets=((total-1)//2,total//2);result=[];seen=0
 for value,weight in values:
  while len(result)<2 and targets[len(result)]<seen+weight:result.append(value)
  seen+=weight
  if len(result)==2:break
 return round((result[0]+result[1])/2)
def channel_median(hist):
 return tuple(weighted_median([(rgb[c],count) for rgb,count in hist.items()]) for c in range(3))
def regions(image,config):
 width,height=image.size
 px=image.load();pixels=[px[x,y] for y in range(height) for x in range(width)]
 foreground=[i for i,p in enumerate(pixels) if p[3]>0]
 parent={i:i for i in foreground};count={i:1 for i in foreground}
 low={i:list(lab(pixels[i][:3])) for i in foreground}
 high={i:v[:] for i,v in low.items()}
 def find(i):
  while parent[i]!=i:
   parent[i]=parent[parent[i]];i=parent[i]
  return i
 edges=[]
 limit=config['neighbor_delta_e']**2
 for i in foreground:
  x=i%width;y=i//width
  for j in ([i+1] if x+1<width else [])+([i+width] if y+1<height else []):
   if j not in parent:continue
   d=distance(lab(pixels[i][:3]),lab(pixels[j][:3]))
   if d<=limit:edges.append((d,i,j))
 for _,i,j in sorted(edges):
  a=find(i);b=find(j)
  if a==b:continue
  lo=[min(low[a][c],low[b][c]) for c in range(3)]
  hi=[max(high[a][c],high[b][c]) for c in range(3)]
  if any(hi[c]-lo[c]>config['component_lab_span'][c] for c in range(3)):continue
  if count[a]<count[b]:a,b=b,a
  parent[b]=a;count[a]+=count[b];low[a]=lo;high[a]=hi
 groups=defaultdict(list)
 for i in foreground:groups[find(i)].append(i)
 result=[]
 for indices in groups.values():
  color=channel_median(Counter(pixels[i][:3] for i in indices))
  result.append((indices,color))
 return pixels,result

def shared_palette(hist,size,iterations):
 colors=sorted(hist);labs={rgb:lab(rgb) for rgb in colors}
 # Seeds protect small but important mint highlights, rust and purple details.
 anchors=[(16,24,33),(52,81,90),(139,201,191),(209,168,100),(223,219,195),(187,121,104),(150,121,156),(117,140,77)]
 centers=[]
 for anchor in anchors:
  if len(centers)>=min(size,len(colors)):break
  seed=min(colors,key=lambda c:(distance(labs[c],lab(anchor)),c))
  if seed not in centers:centers.append(seed)
 nearest={rgb:min(distance(labs[rgb],lab(c)) for c in centers) for rgb in colors}
 while len(centers)<min(size,len(colors)):
  next_color=max(colors,key=lambda rgb:(nearest[rgb]*math.sqrt(hist[rgb]),rgb))
  if next_color in centers:break
  centers.append(next_color);center_lab=lab(next_color)
  for rgb in colors:nearest[rgb]=min(nearest[rgb],distance(labs[rgb],center_lab))
 for _ in range(iterations):
  buckets=[Counter() for _ in centers];center_labs=[lab(c) for c in centers];assignments={}
  for rgb in colors:
   index=min(range(len(centers)),key=lambda i:(distance(labs[rgb],center_labs[i]),i))
   buckets[index][rgb]+=hist[rgb]
   assignments[rgb]=index
  updated=[channel_median(bucket) if bucket else centers[i] for i,bucket in enumerate(buckets)]
  if updated==centers:break
  centers=updated
 palette=sorted(set(centers),key=lambda rgb:(lab(rgb)[0],rgb))
 # Preserve last cluster membership so each emitted group color is its exact weighted median.
 mapping={rgb:palette.index(centers[assignments[rgb]]) for rgb in colors}
 return palette,mapping

def process(root=ROOT):
 config=json.loads((root/'assets/art/simplification.json').read_text())
 manifest=json.loads((root/'assets/art/manifest.json').read_text())
 files=sorted({file.removeprefix('res://') for entry in manifest['entries'].values() for file in entry['files']})
 before_dir=root/'work/art-before-simplification';before_dir.mkdir(parents=True,exist_ok=True)
 histogram=Counter();staged=[]
 for relative in files:
  path=root/relative;image=Image.open(path).convert('RGBA')
  backup=before_dir/path.relative_to(root/'assets/art/runtime');backup.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,backup)
  pixels,groups=regions(image,config)
  for indices,color in groups:histogram[color]+=len(indices)
  staged.append((relative,image.size,pixels,groups))
 palette,mapping=shared_palette(histogram,config['palette_size'],config['iterations'])
 report=[]
 for relative,size,pixels,groups in staged:
  output=Image.new('RGBA',size,(0,0,0,0));result=[(0,0,0,0)]*len(pixels)
  for indices,color in groups:
   flat=(*palette[mapping[color]],255)
   for i in indices:result[i]=flat
  output.putdata(result);output.save(root/relative)
  before_colors=len({pixel[:3] for pixel in pixels if pixel[3]})
  after_colors=len({pixel[:3] for pixel in result if pixel[3]})
  assert all(bool(a[3])==bool(b[3]) for a,b in zip(pixels,result))
  assert all(len({result[i] for i in indices})==1 for indices,_ in groups)
  report.append({'path':relative,'foreground_pixels':sum(bool(p[3]) for p in pixels),'regions':len(groups),'before_colors':before_colors,'after_colors':after_colors,'before_sha256':hashlib.sha256(bytes(v for p in pixels for v in p)).hexdigest(),'after_sha256':hashlib.sha256(bytes(v for p in result for v in p)).hexdigest(),'mask_preserved':True,'regions_flat':True})
 out={'version':1,'algorithm':'connected bounded-Lab regions; per-region RGB median; shared weighted RGB-median palette','config':config,'palette':[{'index':i,'rgb':list(rgb),'hex':'#%02x%02x%02x'%rgb} for i,rgb in enumerate(palette)],'assets':report}
 (root/'assets/art/palette.json').write_text(json.dumps(out['palette'],indent=2)+'\n')
 (root/'assets/art/simplification_report.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
 # Preview is a report; not a new game sprite and never fed back into the art.
 preview=Image.new('RGB',(8*48,4*48),'#10242e')
 for i,rgb in enumerate(palette):
  patch=Image.new('RGB',(44,44),rgb);preview.paste(patch,((i%8)*48+2,(i//8)*48+2))
 preview.save(root/'assets/art/palette.png')
 samples=['player/2_0.png','enemies/4_0.png','items/5_0_0.png','materials/wafer_0.png','items/4_2_0.png','materials/archive_0.png']
 comparison=Image.new('RGBA',(6*192,2*192),(16,36,46,255))
 for i,name in enumerate(samples):
  for row,path in enumerate([before_dir/name,root/'assets/art/runtime'/name]):
   image=Image.open(path).convert('RGBA').resize((192,192),Image.Resampling.NEAREST)
   comparison.alpha_composite(image,(i*192,row*192))
 comparison.convert('RGB').save(root/'docs/art_simplification_comparison.png')
 print('Simplified %d sprites to %d shared median colors; per-sprite colors %d–%d (before %d–%d). All silhouettes preserved.'%(len(report),len(palette),min(r['after_colors'] for r in report),max(r['after_colors'] for r in report),min(r['before_colors'] for r in report),max(r['before_colors'] for r in report)))
 return out

def self_test():
 config={'neighbor_delta_e':11.5,'component_lab_span':[22,18,18]}
 image=Image.new('RGBA',(4,2),(0,0,0,0))
 shades=[(98,120,139,255),(100,121,141,255),(102,122,140,255),(104,123,142,255)]
 for x,color in enumerate(shades):image.putpixel((x,0),color)
 for x in range(4):image.putpixel((x,1),(220,180,70,255))
 _,groups=regions(image,config)
 assert len(groups)==2,'different material boundaries must not merge'
 blue=next(color for indices,color in groups if 0 in indices)
 assert blue==tuple(round(median([c[channel] for c in shades])) for channel in range(3)),'region representative must be the exact component-wise median'
 assert channel_median(Counter({(10,20,30):3,(90,100,110):1}))==(10,20,30),'weighted median must honor pixel count'
 palette,mapping=shared_palette(Counter({(10,20,30):5,(11,21,31):5,(220,180,70):6}),2,8)
 assert len(palette)<=2
 print('Median segmentation and palette algorithm self-tests passed.')
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--self-test',action='store_true');args=parser.parse_args()
 if args.self_test:self_test()
 else:process()
