#!/usr/bin/env python3
"""Create stable IDs, descriptions and atlas slots. Never invokes an image API in CI."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
entries={}
def add(key,name,row,col,count=1,anchor='center',size=64):
 entries[key]={'description':name,'row':row,'column':col,'frames':count,'anchor':anchor,'cell_size':size,'fps':9 if count>1 else 0,'source':'subway_atlas_v1.png','candidate_sources':['atlas_a.png','atlas_b.png'],'files':[f'res://assets/art/runtime/{key}_{i}.png' for i in range(count)]}
for d,(r,c,name) in enumerate([(0,0,'回收员向左步行'),(0,4,'回收员向右步行'),(1,0,'回收员面向镜头步行'),(1,4,'回收员背向镜头步行')]):add(f'player/{d}',name,r,c,4,'feet')
for i,(r,c,name) in enumerate([(2,0,'变异鼠爬行'),(2,4,'灰袍强盗行走瞄准'),(3,0,'孢子炮台脉动'),(3,4,'装甲爬行者冲锋'),(4,0,'站区守卫机器人待机攻击')]):add(f'enemies/{i}',name,r,c,4,'feet',96 if i==4 else 64)
names=[['回收净水','密封饮用水','矿化水','应急水箱'],['旧式电池','标准电芯','高密电池','固态电池组'],['压缩饼干','菌菇罐头','水培蔬菜','应急口粮'],['凝胶绷带','肾上腺针','抗辐射片','复合急救剂'],['回声脉冲器','散射电容','折光屏障','磁轨透镜'],['蜂巢装甲','轻量背架','稳流线圈','汲能触须']]
slots=[(4,4),(5,0),(5,4),(6,0),(6,4),(7,0)]
for category,(r,c) in enumerate(slots):
 for i,name in enumerate(names[category]):add(f'items/{category}_{i}',name,r,c+i)
for key,name,r,c in [('bullet','友方薄荷色子弹',7,4),('enemy_bullet','敌方锈色子弹',7,5),('furniture/0','等距储物箱',7,6),('chest','回收宝箱',7,7),('station','地铁车头',8,0),('icon','回收员头盔徽记',8,1),('floor','金属地板',8,2),('scrap','回收合金',8,3),('furniture/1','工作台',8,4),('furniture/2','休息舱',8,5),('furniture/3','水培箱',8,6),('credits','电卡',8,7)]:add(key,name,r,c)
manifest={'schema_version':1,'style_prompt':'res://assets/art/prompts/style.txt','grid':[8,9],'source_size':[1182,1330],'entries':entries}
(root/'assets/art/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
# A small generated GDScript table avoids export filters and runtime file parsing.
(root/'scripts/art_manifest.gd').write_text('extends RefCounted\n# Generated from assets/art/manifest.json. Stable IDs are the art replacement contract.\nconst ENTRIES = '+json.dumps(entries,ensure_ascii=False,indent="\t")+'\n')
print(len(entries),'logical assets;',sum(e['frames'] for e in entries.values()),'runtime frames')
