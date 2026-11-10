extends RefCounted

const CLASSES = [
	{"name":"坦克", "hp":160.0, "capacity":20, "armor":0.40, "range":260.0, "speed":190.0},
	{"name":"射手", "hp":110.0, "capacity":15, "armor":0.10, "range":620.0, "speed":235.0},
	{"name":"刺客", "hp":80.0, "capacity":11, "armor":0.25, "range":410.0, "speed":290.0}]
const CATEGORY_NAMES = ["水", "电", "食物", "药物", "武器", "强化模块"]
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
	["恢复 35 生命；3 次", "12 秒移速与射速提升；2 次", "延长本层防护时间 90 秒；2 次", "恢复 70 生命；2 次"],
	["范围冲击并推开敌人；冷却 10 秒", "朝瞄准方向发射扇形弹幕；冷却 7 秒", "获得 4 秒无敌护盾；冷却 15 秒", "强力穿透弹；冷却 6 秒"],
	["护甲增加 15%，上限 70%", "背包容量增加 6 格", "射速提升 25%", "清理普通房间额外回收 2 电量"]]
const STATIONS = [
	{"name":"邮电新村", "pos":Vector2(280,280), "traffic":80, "radiation":1, "yield":"水 / 旧电芯", "factor":1.0},
	{"name":"四平路", "pos":Vector2(430,210), "traffic":110, "radiation":2, "yield":"食物 / 药物", "factor":1.12},
	{"name":"世纪大道", "pos":Vector2(630,370), "traffic":160, "radiation":3, "yield":"模块 / 电子材料", "factor":1.3},
	{"name":"人民广场", "pos":Vector2(340,440), "traffic":200, "radiation":2, "yield":"药物 / 武器", "factor":1.18},
	{"name":"虹桥枢纽", "pos":Vector2(130,520), "traffic":65, "radiation":4, "yield":"稀有模块 / 合金", "factor":1.5},
	{"name":"临港避难所", "pos":Vector2(800,540), "traffic":40, "radiation":5, "yield":"电池组 / 武器", "factor":1.65}]

static func item(id: String) -> Dictionary:
	if id == "scrap":
		return {"id":id, "name":"回收合金", "category":6, "price":9, "desc":"可交易的加工材料", "icon":"res://assets/items/5_1.svg", "uses":0}
	var parts = id.split("_")
	var c = int(parts[0])
	var i = int(parts[1])
	return {"id":id, "name":NAMES[c][i], "category":c, "price":[6,8,7,18,38,30][c] + i * [3,4,3,6,14,12][c], "desc":DESCRIPTIONS[c][i], "icon":"res://assets/items/%d_%d.svg" % [c,i], "uses":[3,2,2,2][i] if c==3 else 0}

static func all_ids() -> Array:
	var ids: Array = []
	for c in range(6):
		for i in range(4): ids.append("%d_%d" % [c,i])
	return ids
