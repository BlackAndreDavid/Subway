extends Node
const Metro=preload("res://scripts/metro.gd")
const Catalog = preload("res://scripts/catalog.gd")
const FloorGenerator = preload("res://scripts/floor_generator.gd")
const Inventory=preload("res://scripts/inventory.gd")
const SAVE_VERSION = 2
const STASH_COLUMNS=12
var slot = -1
var state: Dictionary = {}
var run: Dictionary = {}
var settings = {"volume":0.5,"fullscreen":false}
var last_error = ""
var base_arrival=false
var base_position=Vector2(5,3)

func _ready() -> void:
	var saved = read_json("user://settings.json")
	if not saved.is_empty(): settings.merge(saved,true)
	apply_settings()

func new_game(index: int, base_name: String) -> bool:
	slot=index
	state={"version":SAVE_VERSION,"name":base_name.strip_edges() if not base_name.strip_edges().is_empty() else "上海堡垒", "day":1,"station":0,"water":24,"food":24,"power":240,"stash":["3_0","3_1","3_2","3_3","4_0","4_1","4_2","4_3","5_0","5_1","5_2","5_3"],"furniture":[],"news":0,"market_stock":{},"customer":0}
	run={}
	state.stash.append_array(["scrap","scrap","scrap","scrap","scrap","scrap","scrap","scrap","scrap","scrap","scrap","scrap","1_0","1_0","0_0","0_0"])
	base_arrival=false
	base_position=Vector2(5,3)
	return save_game()

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var f = FileAccess.open(path,FileAccess.READ)
	if f==null: return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}

func slot_info(index: int) -> Dictionary:
	return read_json("user://slot_%d.json" % index)

func load_game(index: int) -> bool:
	var data = slot_info(index)
	if not validate_save(data):
		last_error="存档损坏或版本不兼容；未覆盖原文件。"
		return false
	slot=index
	state=data
	ensure_stash()
	state.stash_rows=int(state.stash_rows)
	for placement in state.stash_layout:
		for field in ["x","y","rot"]:placement[field]=int(placement[field])
	state.version=SAVE_VERSION
	run={}
	base_arrival=false
	base_position=Vector2(5,3)
	return true

func validate_save(data: Dictionary) -> bool:
	for key in ["version","name","day","station","water","food","power","stash","furniture","news","market_stock","customer"]:
		if not data.has(key): return false
	if not (data.version is int or data.version is float) or not int(data.version) in [1,SAVE_VERSION] or float(int(data.version))!=float(data.version) or not data.name is String: return false
	for key in ["day","station","water","food","power","news","customer"]:
		if not (data[key] is int or data[key] is float): return false
	if data.day<1 or data.station<0 or data.station>=Catalog.STATIONS.size(): return false
	if data.water<0 or data.food<0 or data.power<0: return false
	if not data.stash is Array or not data.furniture is Array or not data.market_stock is Dictionary: return false
	var valid = Catalog.valid_ids()
	for id in data.stash:
		if not id is String or not valid.has(id): return false
	if int(data.version)==SAVE_VERSION:
		if not data.has_all(["stash_layout","stash_rows"]) or not data.stash_layout is Array or data.stash_layout.size()!=data.stash.size():return false
		if not (data.stash_rows is int or data.stash_rows is float) or int(data.stash_rows)!=data.stash_rows or data.stash_rows<1:return false
		var entries=stash_entries_for(data)
		if entries.size()!=data.stash.size() or not Inventory.valid(entries,Vector2i(STASH_COLUMNS,int(data.stash_rows))):return false
	for furniture in data.furniture:
		if not furniture is Dictionary or not furniture.has_all(["x","y","type"]): return false
		for key in ["x","y","type"]:
			if not (furniture[key] is int or furniture[key] is float): return false
		if furniture.x<0 or furniture.x>=10 or furniture.y<0 or furniture.y>=6 or furniture.type<0 or furniture.type>3: return false
	for id in data.market_stock:
		if not valid.has(id):return false
		if not (data.market_stock[id] is int or data.market_stock[id] is float):return false
		if data.market_stock[id]<0 or data.market_stock[id]>4:return false
	return true

func write_json(path: String,data: Dictionary) -> bool:
	var temp = path+".tmp"
	var file = FileAccess.open(temp,FileAccess.WRITE)
	if file==null:
		last_error="无法写入存档，请检查磁盘权限。"
		return false
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	file.close()
	var err = DirAccess.rename_absolute(temp,path)
	if err!=OK:
		last_error="无法替换存档文件：%s" % error_string(err)
	return err==OK

func save_game() -> bool:
	if slot<0 or not run.is_empty(): return false
	ensure_stash()
	state.version=SAVE_VERSION
	return write_json("user://slot_%d.json" % slot,state)

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,settings.volume)))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_MAXIMIZED)

func save_settings() -> void:
	write_json("user://settings.json",settings)
	apply_settings()

func next_day() -> String:
	if state.water<2 or state.food<2 or state.power<5: return "资源不足：每天需要 2 水、2 食物、5 电量。"
	state.water-=2
	state.food-=2
	state.power-=5
	state.day+=1
	state.news=(int(state.day)*7)%4
	state.market_stock={}
	state.customer=0
	if not save_game(): return last_error
	return "进入第 %d 天。基地已保存。" % state.day

func travel(index: int) -> String:
	if index<0 or index>=Catalog.STATIONS.size():return "无效站点。"
	var cost = travel_cost(index)
	if index==state.station: return "已经位于该站点。"
	if state.power<cost: return "账户电量不足。"
	state.power-=cost
	state.station=index
	save_game()
	return "抵达%s，消耗 %d 电量。" % [Catalog.STATIONS[index].name,cost]

func travel_cost(index: int) -> int:
	var path=Metro.route(int(state.station),index)
	return 0 if path.size()<=1 else 4+2*(path.size()-1)

func price(id: String,buy: bool) -> int:
	var item = Catalog.item(id)
	var factor = Catalog.STATIONS[int(state.station)].factor
	if int(state.news)==int(item.category)%4: factor*=1.25
	return maxi(1,roundi(item.price*factor*(1.0 if buy else 0.62)))

func trade(id: String,buy: bool) -> String:
	var value=price(id,buy)
	if buy:
		if state.market_stock.get(id,4)<=0: return "今日库存已售罄，下一天补货。"
		if state.power<value: return "电量不足。"
		state.power-=value
		state.market_stock[id]=state.market_stock.get(id,4)-1
		add_stash(id)
	else:
		if not state.stash.has(id): return "仓库中没有该物品。"
		remove_stash(state.stash.find(id))
		state.power+=value
	save_game()
	return ("购入" if buy else "售出")+Catalog.item(id).name

func customer_offer() -> Dictionary:
	var ids=Catalog.all_ids()
	var rng=RandomNumberGenerator.new()
	rng.seed=int(state.day)*1009+int(state.station)*37+int(state.customer)*17
	var id=ids[rng.randi_range(0,ids.size()-1)]
	var buying=rng.randf()<0.55
	if buying and not state.stash.is_empty(): id=state.stash[rng.randi_range(0,state.stash.size()-1)]
	return {"id":id,"buying":buying,"price":maxi(1,roundi(price(id,not buying)*(1.15 if buying else 0.72)))}

func accept_customer() -> String:
	var offer=customer_offer()
	if offer.buying:
		if not state.stash.has(offer.id): return "没有该顾客需要的货物。"
		remove_stash(state.stash.find(offer.id))
		state.power+=offer.price
	else:
		if state.power<offer.price: return "电量不足。"
		state.power-=offer.price
		add_stash(offer.id)
	state.customer+=1
	save_game()
	return "交易完成，新顾客已到站。"

func begin_run(class_index: int,module: String,weapon: String,drug: String,seed_value: int=-1,source_indices: Dictionary={}) -> bool:
	if not run.is_empty() or class_index<0 or class_index>=Catalog.CLASSES.size():
		last_error="职业无效或探索已开始。"
		return false
	var available: Array=state.stash.duplicate()
	var selections=[module,weapon,drug]
	var selected_indices: Array=[]
	var slot_keys=["module","weapon","drug"]
	for index in range(selections.size()):
		var id: String=selections[index]
		if id=="":continue
		if not available.has(id) or not Catalog.valid_ids().has(id) or int(Catalog.item(id).category)!=[5,4,3][index]:
			last_error="装备必须来自仓库且与槽位类型匹配。"
			return false
		available.erase(id)
		var source_index=int(source_indices.get(slot_keys[index],state.stash.find(id)))
		if source_index<0 or source_index>=state.stash.size() or state.stash[source_index]!=id or selected_indices.has(source_index):
			last_error="仓库格子已变化，请重新选择装备。"
			return false
		selected_indices.append(source_index)
	var floor_data=FloorGenerator.generate(seed_value if seed_value>=0 else randi(),1)
	if state.power<floor_data.budget:
		last_error="本层无掉落保底路线需 %d 电量，账户不足。" % floor_data.budget
		return false
	var stats=Catalog.CLASSES[class_index].duplicate(true)
	if module=="5_0": stats.armor=minf(0.7,stats.armor+0.15)
	if module=="5_1": stats.grid_rows+=1
	stats.capacity=int(stats.grid_cols)*int(stats.grid_rows)
	var bag: Array=[]
	for id in selections:
		if id=="":continue
		var placement=Inventory.first_fit(bag,Vector2i(stats.grid_cols,stats.grid_rows),id)
		if placement.is_empty():
			last_error="所选装备无法放入该职业背包。"
			return false
		placement.merge({"id":id,"uses":Catalog.item(id).uses})
		bag.append(placement)
	ensure_stash()
	selected_indices.sort()
	selected_indices.reverse()
	for index in selected_indices:remove_stash(int(index))
	run={"class":class_index,"stats":stats,"hp":stats.hp,"module":module,"weapon":weapon,"drug":drug,"bag":bag,"floor_data":floor_data,"room":0,"floor":1,"energy":floor_data.budget,"buff":0.0,"shield":0.0,"weapon_cd":0.0,"rewards":[],"damage":1.0,"fighting":false,"seed":floor_data.seed}
	run.equipped_uid={"module":-1,"weapon":-1,"drug":-1}
	run.next_uid=0
	for entry in bag:
		entry.uid=run.next_uid
		run.next_uid+=1
		for key in ["module","weapon","drug"]:
			if entry.id==run[key]:run.equipped_uid[key]=entry.uid
	return true

func move_room(id: int) -> bool:
	var current=run.floor_data.rooms[int(run.room)]
	if run.fighting or not current.links.has(id) or run.energy<1 or state.power<1: return false
	run.energy-=1
	state.power-=1
	run.room=id
	return true

func bag_dimensions() -> Vector2i:
	return Vector2i(int(run.stats.grid_cols),int(run.stats.grid_rows))
func can_pick_up(id: String) -> bool:
	return not run.is_empty() and not Inventory.first_fit(run.bag,bag_dimensions(),id).is_empty()
func pick_up(id: String,remaining_uses: int=-1) -> bool:
	if run.is_empty() or run.fighting or not Catalog.valid_ids().has(id):return false
	var placement=Inventory.first_fit(run.bag,bag_dimensions(),id)
	if placement.is_empty():return false
	placement.merge({"id":id,"uses":Catalog.item(id).uses if remaining_uses<0 else remaining_uses,"uid":run.next_uid})
	run.next_uid+=1
	run.bag.append(placement)
	return true
func move_bag(index: int,position: Vector2i,rotation: int) -> bool:
	if run.is_empty() or run.fighting or index<0 or index>=run.bag.size():return false
	if not Inventory.fits(run.bag,bag_dimensions(),run.bag[index].id,position,rotation,index):return false
	run.bag[index].merge({"x":position.x,"y":position.y,"rot":posmod(rotation,4)},true)
	return true
func set_module(id: String) -> bool:
	if run.is_empty() or run.fighting or (id!="" and not run.bag.any(func(entry):return entry.id==id and Catalog.item(id).category==5)):return false
	var stats: Dictionary=run.stats
	var base: Dictionary=Catalog.CLASSES[int(run["class"])]
	var dimensions=Vector2i(int(base.grid_cols),int(base.grid_rows)+(1 if id=="5_1" else 0))
	if not Inventory.valid(run.bag,dimensions):
		last_error="物品超出基础背包边界；先整理下方扩展格，再卸下背架。"
		return false
	stats.armor=minf(0.7,float(base.armor)+(0.15 if id=="5_0" else 0.0))
	stats.grid_rows=dimensions.y
	stats.capacity=dimensions.x*dimensions.y
	run.module=id
	return true
func equipped_entry(slot_key: String) -> Dictionary:
	if run.is_empty() or run[slot_key]=="":return {}
	for entry in run.bag:
		if entry.id==run[slot_key] and int(entry.uid)==int(run.equipped_uid[slot_key]):return entry
	return {}
func equip_entry(index: int) -> bool:
	if run.is_empty() or run.fighting or index<0 or index>=run.bag.size():return false
	var entry: Dictionary=run.bag[index]
	var key: String={3:"drug",4:"weapon",5:"module"}.get(int(Catalog.item(entry.id).category),"")
	if key=="":return false
	var unequip=int(run.equipped_uid[key])==int(entry.uid)
	if key=="module" and not set_module("" if unequip else entry.id):return false
	run[key]="" if unequip else entry.id
	run.equipped_uid[key]=-1 if unequip else int(entry.uid)
	return true

func claim_reward(index: int) -> String:
	if run.is_empty() or run.fighting or not index in [0,1]:return "当前无法领取奖励。"
	var room=run.floor_data.rooms[int(run.room)]
	if room.kind!="reward" or room.claimed: return "奖励已领取。"
	if index==0:
		run.damage*=1.25
		run.rewards.append("聚焦晶体")
	else:
		if not pick_up("4_1"): return "背包已满，请先整理。"
	room.claimed=true
	return "已获得聚焦晶体：伤害 +25%。" if index==0 else "已获得散射电容，可在背包中装配。"

func next_floor() -> bool:
	if not can_extract():return false
	var next=FloorGenerator.generate(int(run.seed)+int(run.floor)*997,int(run.floor)+1)
	if state.power<next.budget:
		last_error="下一层保底路线需要 %d 电量，请先撤离交易。" % next.budget
		return false
	run.floor+=1
	run.floor_data=next
	run.room=0
	run.energy=next.budget
	return true

func can_extract() -> bool:
	return not run.is_empty() and not run.fighting and run.floor_data.rooms[int(run.room)].kind=="boss" and run.floor_data.rooms[int(run.room)].cleared
func end_run(success: bool) -> String:
	if run.is_empty(): return ""
	if success and not can_extract():return "请先击败本层 Boss，在返程终端返回基地。"
	var count=run.bag.size()
	if success:
		for entry in run.bag:
			add_stash(entry.id)
	else:
		# Equipped items and cargo are lost. Combat already spent electricity.
		count=0
	run={}
	base_arrival=true
	save_game()
	return "安全返程，回收 %d 件物资。已存入基地仓库。" % count if success else "救援队将你送回基地，本次携带物资遗失。"
func craft_furniture(type: int) -> bool:
	if not run.is_empty() or type<0 or type>=Catalog.FURNITURE_RECIPES.size():return false
	var recipe: Dictionary=Catalog.FURNITURE_RECIPES[type]
	for id in recipe:
		if state.stash.count(id)<int(recipe[id]):
			last_error="材料不足：%s 需要 %d 件。" % [Catalog.item(id).name,recipe[id]]
			return false
	for id in recipe:
		for count in range(int(recipe[id])):remove_stash(state.stash.find(id))
	add_stash("furn_%d" % type)
	return save_game()
func place_furniture(type: int,tile: Vector2i) -> bool:
	if not run.is_empty() or type<0 or type>3 or tile.x<0 or tile.x>=10 or tile.y<0 or tile.y>=6:return false
	if tile in [Vector2i(0,4),Vector2i(9,0)]:
		last_error="请保留终端和气闸门的位置。"
		return false
	for entry in state.furniture:
		if Vector2i(int(entry.x),int(entry.y))==tile:
			last_error="这个位置已经放置了家具。"
			return false
	var index=state.stash.find("furn_%d" % type)
	if index<0:
		last_error="请先用材料合成"+Catalog.FURNITURE_NAMES[type]+"，再进行摆放。"
		return false
	remove_stash(index)
	state.furniture.append({"x":tile.x,"y":tile.y,"type":type})
	return save_game()
func reclaim_furniture(index: int) -> bool:
	if not run.is_empty() or index<0 or index>=state.furniture.size():return false
	add_stash("furn_%d" % int(state.furniture[index].type))
	state.furniture.remove_at(index)
	return save_game()

func stash_entries_for(data: Dictionary) -> Array:
	var result: Array=[]
	for index in range(data.stash.size()):
		if not data.stash_layout[index] is Dictionary:return []
		var entry: Dictionary=data.stash_layout[index].duplicate()
		entry.id=data.stash[index]
		result.append(entry)
	return result
func ensure_stash() -> void:
	if state.is_empty():return
	if state.has_all(["stash_layout","stash_rows"]) and state.stash_layout.size()==state.stash.size():return
	state.stash_layout=[]
	state.stash_rows=10
	var entries: Array=[]
	for id in state.stash:
		var placement=Inventory.first_fit(entries,Vector2i(STASH_COLUMNS,int(state.stash_rows)),id)
		while placement.is_empty():
			state.stash_rows+=2
			placement=Inventory.first_fit(entries,Vector2i(STASH_COLUMNS,int(state.stash_rows)),id)
		state.stash_layout.append(placement.duplicate())
		var entry=placement.duplicate()
		entry.id=id
		entries.append(entry)
func stash_entries() -> Array:
	ensure_stash()
	return stash_entries_for(state)
func add_stash(id: String) -> void:
	ensure_stash()
	var entries=stash_entries_for(state)
	var placement=Inventory.first_fit(entries,Vector2i(STASH_COLUMNS,int(state.stash_rows)),id)
	while placement.is_empty():
		state.stash_rows+=2
		placement=Inventory.first_fit(entries,Vector2i(STASH_COLUMNS,int(state.stash_rows)),id)
	state.stash.append(id)
	state.stash_layout.append(placement)
func remove_stash(index: int) -> void:
	ensure_stash()
	if index<0 or index>=state.stash.size():return
	state.stash.remove_at(index)
	state.stash_layout.remove_at(index)
func move_stash(index: int,position: Vector2i,rotation: int) -> bool:
	var entries=stash_entries()
	if not run.is_empty() or index<0 or index>=entries.size() or not Inventory.fits(entries,Vector2i(STASH_COLUMNS,int(state.stash_rows)),entries[index].id,position,rotation,index):return false
	state.stash_layout[index]={"x":position.x,"y":position.y,"rot":posmod(rotation,4)}
	return save_game()
