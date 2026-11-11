extends RefCounted
const C=preload("res://scripts/catalog.gd")
const Loot=preload("res://scripts/loot_rules.gd")
const Data=preload("res://scripts/regional_data.gd")
static func run(check: Callable) -> void:
	var representatives: Dictionary={}
	for index in range(C.STATIONS.size()):
		var info: Dictionary=C.STATIONS[index]
		representatives[info.zone]=index
		check.call(info.economy_index>=0 and info.economy_index<=1,"bounded economic reference index")
		check.call(info.has("economy_source") and info.has("economy_scope"),"traceable reference metadata")
		check.call(info.economy_source!="city_reference","no station uses an economic placeholder")
		check.call(info.has("local_area") and not info.local_area.is_empty(),"station-level exploration area label")
		check.call(info.economy_year==2025,"reference year propagated to UI")
		var previous: Dictionary={}
		for radiation in range(1,6):
			var current=Loot.profile(index,radiation)
			if not previous.is_empty():
				for key in ["richness","drop_chance","bonus_chance","rare_chance"]:check.call(current[key]>previous[key],"radiation raises "+key)
				check.call(current.protection_seconds<previous.protection_seconds,"radiation reduces protection time")
				check.call(Loot.chest_budget(index,1,radiation)>Loot.chest_budget(index,1,radiation-1),"radiation raises chest budget")
			previous=current
	# Radiation dominates economic variation globally, not only within one station.
	for a in C.STATIONS:
		for b in C.STATIONS:
			if a.radiation>b.radiation:check.call(a.richness>b.richness,"globally monotone risk/reward bands")
	for id in Data.MATERIALS:
		check.call(C.valid_ids().has(id),"exclusive materials recognized by save validator")
		check.call(ResourceLoader.exists(C.item(id).icon),"exclusive material art wired")
	var rng=RandomNumberGenerator.new()
	rng.seed=99171
	var exclusive_seen: Dictionary={}
	for zone in representatives:
		var station=int(representatives[zone])
		var allowed=Loot.allowed_ids(station)
		for other_zone in Data.ZONES:
			for id in Data.ZONES[other_zone].exclusive:check.call(allowed.has(id)==(other_zone==zone),"exclusive whitelist: "+id+" / "+zone)
		for _sample in range(800):
			var drops=Loot.roll_room(station,2,rng)
			drops.append(Loot.choose_item(station,rng))
			for id in drops:
				if id in ["power","credits","crystal","chest"]:continue
				check.call(allowed.has(id),"normal drop respects regional pool")
				if Data.MATERIALS.has(id):
					exclusive_seen[id]=true
					check.call(Data.MATERIALS[id].zone==zone,"no foreign exclusive production")
		for floor_number in range(1,4):
			for _sample in range(80):
				var total=0
				for id in Loot.open_chest(station,floor_number,rng):
					check.call(allowed.has(id),"chest respects regional whitelist")
					total+=int(C.item(id).price)
				check.call(total<=Loot.chest_budget(station,floor_number),"chest conserves value budget")
	check.call(exclusive_seen.size()==Data.MATERIALS.size(),"every exclusive material can actually drop")
	var totals: Array=[]
	for radiation in [1,5]:
		rng.seed=41371
		var sum=0.0
		for _sample in range(4000):
			for id in Loot.roll_room(0,1,rng,false,radiation):
				if id=="chest":sum+=Loot.chest_budget(0,1,radiation)*0.8
				elif id in ["power","credits","crystal"]:sum+=(8 if id in ["credits","crystal"] else 5)*float(Loot.profile(0,radiation).richness)
				else:sum+=float(C.item(id).price)
		totals.append(sum/4000)
	check.call(totals[1]>totals[0]*1.5,"sampled high radiation expected return rises")
	print("Regional loot sampled mean value: radiation1 %.2f / radiation5 %.2f" % [totals[0],totals[1]])
