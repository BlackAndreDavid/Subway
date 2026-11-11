#!/usr/bin/env python3
"""Read-only acceptance checks for source data, assets and evidence paths."""
from pathlib import Path
import json,re,math,argparse
from generate_room_layouts import compile_layouts
ROOT=Path(__file__).resolve().parents[1]
def acceptance_complete(checklist,summary,checkpoint=False):
 pending=re.findall(r'^\s*- \[ \] (.+)$',checklist,re.M)
 completed=re.findall(r'^\s*- \[x\] (.+)$',checklist,re.M)
 assert summary['acceptance_items']==len(pending)+len(completed),'Acceptance item count is stale'
 assert summary['open_acceptance_items']==len(pending),'Open acceptance count is stale'
 assert summary.get('pending_acceptance',[])==pending,'Pending acceptance registry is stale'
 if pending:
  assert checkpoint,'Active acceptance checklist has open tasks'
  assert summary.get('status')=='development_checkpoint','Pending tasks require a declared development checkpoint'
  assert summary.get('pending_acceptance')==pending,'Pending acceptance tasks must be explicitly registered'
 return not pending

def audit(checkpoint=False):
 assert (ROOT/"scripts/room_layout_data.gd").read_text()==compile_layouts(),"Obstacle layout resource is stale"
 economy=json.loads((ROOT/'assets/balance/economy.json').read_text())
 regions=json.loads((ROOT/'assets/balance/regions.json').read_text())
 metro=json.loads((ROOT/'assets/maps/shanghai_metro.json').read_text())
 manifest=json.loads((ROOT/'assets/art/manifest.json').read_text())
 tags=regions['station_tags'];assert {s['name'] for s in metro['stations']}==set(tags)
 areas=set()
 for station in metro['stations']:
  tag=tags[station['name']];source=tag['economy_source'];record=economy['records'][source];areas.add(source)
  assert source!='city_reference',station['name']+' still uses a placeholder economic source'
  assert record.get('url','').startswith('https://') and record['year']==2025
  assert record['verification'] in ['official','official_report_secondary_transcription']
  available=[(math.sqrt(record[axis]/denom),weight) for axis,weight,denom in [('industrial',regions['zones'][tag['zone']]['industry_weight'],13878.95),('retail',1-regions['zones'][tag['zone']]['industry_weight'],2827.99)] if record.get(axis) is not None]
  assert available and sum(w for _,w in available)>0
  expected=min(1,max(0,sum(v*w for v,w in available)/sum(w for _,w in available)*tag['local_factor']))
  assert abs(station['economy_index']-expected)<.000001
  assert station['local_area']==tag['local_area'] and tag['reference_note']
  assert station['economy_source']==source
 assert len(areas)==15 and len(metro['stations'])==110
 assert tags['西岑']['zone']=='research' and tags['花桥']['economy_source']=='kunshan'
 assert tags['奉贤新城']['zone']=='commercial'
 for file in (ROOT/'scripts').glob('*.gd'):
  assert '.svg' not in file.read_text(),f'Obsolete vector resource dependency: {file}'
 files=[]
 for entry in manifest['entries'].values():
  assert entry['description'] and len(entry['candidate_sources'])>=2
  for candidate in entry['candidate_sources']:assert (ROOT/'assets/art/candidates'/candidate).is_file()
  for path in entry['files']:
   relative=path.removeprefix('res://');assert relative.endswith('.png') and (ROOT/relative).is_file();files.append(relative)
 assert len(files)==109 and len(set(files))==109
 assert (ROOT/'assets/art/prompts/style.txt').is_file() and (ROOT/'assets/art/prompts/color_lock.txt').is_file()
 for path in ['docs/art_simplification_comparison.png','docs/base.png','docs/combat.png','docs/map.png','docs/regional_materials.png','docs/task-checklist.md']:
  assert (ROOT/path).is_file(),path
 summary=json.loads((ROOT/'docs/validation/audit-summary.json').read_text())
 complete=acceptance_complete((ROOT/'docs/task-checklist.md').read_text(),summary,checkpoint)
 print(f'PROJECT AUDIT: {len(metro["stations"])} stations / {len(areas)} economic areas; {len(files)} raster frames; source-data and asset evidence verified.')
 if not complete:print('CHECKPOINT: registered full-game acceptance remains pending; source integrity is validated separately.')
 return complete
if __name__=='__main__':
 parser=argparse.ArgumentParser()
 parser.add_argument('--checkpoint',action='store_true',help='Allow only explicitly registered development-checkpoint tasks to remain pending')
 parser.add_argument('--github-output',type=Path)
 args=parser.parse_args()
 complete=audit(args.checkpoint)
 if args.github_output:
  with args.github_output.open('a') as output:output.write('complete='+str(complete).lower()+'\n')
