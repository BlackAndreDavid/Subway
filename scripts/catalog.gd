extends RefCounted
const RegionalData=preload("res://scripts/regional_data.gd")
const Art=preload("res://scripts/art_library.gd")

const CLASSES = [
	{"name":"坦克", "hp":160.0, "capacity":30, "grid_cols":6,"grid_rows":5,"armor":0.40, "range":260.0, "speed":190.0},
	{"name":"射手", "hp":110.0, "capacity":24, "grid_cols":6,"grid_rows":4,"armor":0.10, "range":620.0, "speed":235.0},
	{"name":"刺客", "hp":80.0, "capacity":18, "grid_cols":6,"grid_rows":3,"armor":0.25, "range":410.0, "speed":290.0}]
const SHAPES={
	"furn_0":["##","##"],"furn_1":["###","###"],"furn_2":["##","##","##"],"furn_3":["##","##"],
	"0_0":["#","#"],"0_1":["#","#"],"0_2":["#","#"],"0_3":["##","##"],
	"1_0":["#"],"1_1":["#","#"],"1_2":["##","##"],"1_3":["###","###"],
	"2_0":["##"],"2_1":["#"],"2_2":["##","#."],"2_3":["##","##"],
	"3_0":["#","#"],"3_1":["#","#"],"3_2":["#"],"3_3":["##","##"],
	"4_0":["##","##"],"4_1":["##","##"],"4_2":["###","###"],"4_3":["###","###"],
	"5_0":["##","##"],"5_1":["##","##","##"],"5_2":["##","##"],"5_3":["#..","###"],
	"scrap":["##"],"mat_wafer":["##","##"],"mat_alloy":["##"],"mat_culture":["#","#"],
	"mat_watch":["#"],"mat_bearing":["##","##"],"mat_valve":["#.","##"],"mat_seeds":["##"],"mat_archive":["##","##"]}
static var cell_cache: Dictionary={}
static var bounds_cache: Dictionary={}
static func cells(id: String,rotation: int=0) -> Array:
	var cache_key=id+":"+str(posmod(rotation,4))
	if cell_cache.has(cache_key):return cell_cache[cache_key]
	var result: Array=[]
	var shape: Array=SHAPES[id]
	for y in range(shape.size()):
		for x in range(shape[y].length()):
			if shape[y][x]=="#":result.append(Vector2i(x,y))
	var bounds=Vector2i(shape[0].length(),shape.size())
	for turn in range(posmod(rotation,4)):
		for index in range(result.size()):result[index]=Vector2i(bounds.y-1-result[index].y,result[index].x)
		bounds=Vector2i(bounds.y,bounds.x)
	cell_cache[cache_key]=result
	return result
static func bounds(id: String,rotation: int=0) -> Vector2i:
	var cache_key=id+":"+str(posmod(rotation,4))
	if bounds_cache.has(cache_key):return bounds_cache[cache_key]
	var extent=Vector2i.ZERO
	for cell in cells(id,rotation):extent=extent.max(cell+Vector2i.ONE)
	bounds_cache[cache_key]=extent
	return extent
static func weapon_cooldown(id: String) -> float:
	return {"4_0":10.0,"4_1":7.0,"4_2":15.0,"4_3":6.0}.get(id,0.0)
const CATEGORY_NAMES = ["水", "电", "食物", "药物", "武器", "强化模块"]
const FURNITURE_NAMES=["储物箱","工作台","休息舱","水培箱"]
const FURNITURE_RECIPES=[{"scrap":2},{"scrap":3,"1_0":1},{"scrap":4,"3_0":1},{"scrap":3,"0_0":1,"1_0":1}]
const NAMES = [
	["回收净水", "密封饮用水", "矿化水", "应急水箱"],
	["旧式电池", "标准电芯", "高密电池", "固态电池组"],
	["压缩饼干", "菌菇罐头", "水培蔬菜", "应急口粮"],
	["凝胶绷带", "肾上腺针", "抗辐射片", "复合急救剂"],
	["回声脉冲器", "散射电容", "折光屏障", "磁轨透镜"],
	["蜂巢装甲", "轻量背架", "稳流线圈", "汲能触须"]]
const DESCRIPTIONS = [
	["补充基地水储量 +3", "补充基地水储量 +5", "补充基地水储量 +7", "补充基地水储量 +10"],
	["转换为账户电量 +6", "转换为账户电量 +10", "转换为账户电量 +15", "转换为账户电量 +22"],
	["补充基地食物 +3", "补充基地食物 +5", "补充基地食物 +7", "补充基地食物 +10"],
	["恢复 35 生命；3 次", "12 秒移速与射速提升；2 次", "恢复20生命并获得8秒护盾；2次", "恢复 70 生命；2 次"],
	["范围冲击并推开敌人；冷却 10 秒", "朝瞄准方向发射扇形弹幕；冷却 7 秒", "获得 4 秒无敌护盾；冷却 15 秒", "强力穿透弹；冷却 6 秒"],
	["护甲增加 15%，上限 70%", "背包容量增加 6 格", "射速提升 25%", "清理普通房间额外回收 2 电量"]]
const STATIONS = preload("res://scripts/metro_data.gd").STATIONS

static func item(id: String) -> Dictionary:
	if id.begins_with("furn_"):
		var type=int(id.trim_prefix("furn_"))
		return {"id":id,"name":FURNITURE_NAMES[type],"category":7,"price":[30,55,75,65][type],"desc":"材料合成的家具；在基地布置模式中放置。","icon":Art.path("furniture/%d" % type),"uses":0}
	if RegionalData.MATERIALS.has(id):
		var data: Dictionary=RegionalData.MATERIALS[id]
		return {"id":id,"name":data.name,"category":6,"price":data.price,"desc":data.desc,"icon":Art.path("materials/"+id.trim_prefix("mat_")),"uses":0}
	if id == "scrap":
		return {"id":id, "name":"回收合金", "category":6, "price":9, "desc":"可交易的加工材料", "icon":Art.path("scrap"), "uses":0}
	var parts = id.split("_")
	var c = int(parts[0])
	var i = int(parts[1])
	return {"id":id, "name":NAMES[c][i], "category":c, "price":[6,8,7,18,38,30][c] + i * [3,4,3,6,14,12][c], "desc":DESCRIPTIONS[c][i], "icon":Art.path("items/%d_%d" % [c,i]), "uses":[3,2,2,2][i] if c==3 else 0}

static func all_ids() -> Array:
	var ids: Array = []
	for c in range(6):
		for i in range(4): ids.append("%d_%d" % [c,i])
	return ids

static func valid_ids() -> Array:
	return all_ids()+["scrap","furn_0","furn_1","furn_2","furn_3"]+RegionalData.MATERIALS.keys()
