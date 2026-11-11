extends RefCounted
const C=preload("res://scripts/catalog.gd")
const Data=preload("res://scripts/regional_data.gd")
static func profile(station: int,radiation_override: int=-1) -> Dictionary:
	var info: Dictionary=C.STATIONS[station]
	var radiation=clampi(radiation_override if radiation_override>0 else int(info.radiation),1,5)
	var economy=clampf(float(info.economy_index),0,1)
	return {"radiation":radiation,"economy":economy,"zone":info.zone,"richness":1.0+0.65*(radiation-1)+0.30*economy,"drop_chance":0.60+0.06*(radiation-1)+0.04*economy,"bonus_chance":0.10*(radiation-1)+0.12*economy,"rare_chance":0.04+0.035*(radiation-1)+0.025*economy,"protection_seconds":360-20*radiation}
static func exclusive_ids(station: int) -> Array:
	return Data.ZONES[C.STATIONS[station].zone].exclusive.duplicate()
static func allowed_ids(station: int) -> Array:
	return C.all_ids()+["scrap"]+exclusive_ids(station)
static func choose_item(station: int,rng: RandomNumberGenerator,radiation_override: int=-1) -> String:
	var data=profile(station,radiation_override)
	var exclusive=exclusive_ids(station)
	if not exclusive.is_empty() and rng.randf()<data.rare_chance:
		return exclusive[rng.randi_range(0,exclusive.size()-1)]
	if rng.randf()<0.12:return "scrap"
	var weights: Array=Data.ZONES[data.zone].weights
	var total=0.0
	for weight in weights:total+=float(weight)
	var roll=rng.randf()*total
	var category=0
	for i in range(weights.size()):
		roll-=float(weights[i])
		if roll<=0:
			category=i
			break
	var grade=rng.randi_range(2,3) if rng.randf()<data.rare_chance else rng.randi_range(0,1)
	return "%d_%d" % [category,grade]
static func roll_room(station: int,floor_number: int,rng: RandomNumberGenerator,boss: bool=false,radiation_override: int=-1) -> Array:
	var data=profile(station,radiation_override)
	var loot: Array=[]
	if boss:
		loot=["5_%d" % rng.randi_range(0,3),"chest"]
		if rng.randf()<data.bonus_chance:loot.append(choose_item(station,rng,radiation_override))
		return loot
	if rng.randf()>=data.drop_chance:return []
	var count=1+(1 if rng.randf()<data.bonus_chance else 0)
	for _i in range(count):
		var roll=rng.randf()
		if roll<0.13:loot.append("power")
		elif roll<0.26:loot.append("crystal")
		elif roll<0.37:loot.append("chest")
		else:loot.append(choose_item(station,rng,radiation_override))
	return loot
static func chest_budget(station: int,floor_number: int,radiation_override: int=-1) -> int:
	return floori((22+18*floor_number)*float(profile(station,radiation_override).richness))
static func open_chest(station: int,floor_number: int,rng: RandomNumberGenerator,radiation_override: int=-1) -> Array:
	var remaining=chest_budget(station,floor_number,radiation_override)
	var drops: Array=[]
	for _i in range(8):
		var affordable: Array=[]
		for id in allowed_ids(station):
			if C.item(id).price<=remaining:affordable.append(id)
		if affordable.is_empty():break
		var id=choose_item(station,rng,radiation_override)
		if not affordable.has(id):id=affordable[rng.randi_range(0,affordable.size()-1)]
		drops.append(id)
		remaining-=int(C.item(id).price)
	return drops
static func pickup_value(station: int,kind: String) -> int:
	return maxi(1,roundi((8 if kind in ["credits","crystal"] else 5)*float(profile(station).richness)))
