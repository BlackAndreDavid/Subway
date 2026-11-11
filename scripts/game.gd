extends Node
const Metro=preload("res://scripts/metro.gd")
const Catalog = preload("res://scripts/catalog.gd")
const FloorGenerator = preload("res://scripts/floor_generator.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Shop=preload("res://scripts/shop_rules.gd")
const TRAVEL_HOPS_PER_DAY=4
const DAILY_WATER=2
const DAILY_FOOD=2
const DAILY_POWER=5
const SAVE_VERSION = 2
const STASH_COLUMNS=12
var slot = -1
var state: Dictionary = {}
var run: Dictionary = {}
var settings = {"volume":0.5,"fullscreen":false}
var last_error = ""
var shop_open=false
var run_serial=0
var base_arrival=false
var base_position=Vector2(5,3)

func _ready() -> void:
	var saved = read_json("user://settings.json")
	if not saved.is_empty(): settings.merge(saved,true)
	apply_settings()

func new_game(index: int, base_name: String) -> bool:
	slot=index
	state={"version":SAVE_VERSION,"name":base_name.strip_edges() if not base_name.strip_edges().is_empty() else "上海堡垒", "day":1,"station":0,"water":24,"food":24,"power":240,"stash":["3_0","3_1","3_2","3_3","4_0","4_1","4_2","4_3","5_0","5_1","5_2","5_3"],"furniture":[],"news":0,"customer":0}
	run={}
	state.stash.append_array(["scrap","scrap","scrap","scrap","scrap","scrap","scrap","scrap","scrap","scrap","scrap","scrap","1_0","1_0","0_0","0_0"])
	shop_open=false
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
	state.erase("market_stock") # Retire legacy system stock.
	ensure_stash()
	state.stash_rows=int(state.stash_rows)
	for placement in state.stash_layout:
		for field in ["x","y","rot"]:placement[field]=int(placement[field])
	state.version=SAVE_VERSION
	run={}
	shop_open=false
	base_arrival=false
	base_position=Vector2(5,3)
	return true

func validate_save(data: Dictionary) -> bool:
	for key in ["version","name","day","station","water","food","power","stash","furniture","news","customer"]:
		if not data.has(key): return false
	if not (data.version is int or data.version is float) or not int(data.version) in [1,SAVE_VERSION] or float(int(data.version))!=float(data.version) or not data.name is String: return false
	for key in ["day","station","water","food","power","news","customer"]:
		if not (data[key] is int or data[key] is float): return false
	if data.day<1 or data.station<0 or data.station>=Catalog.STATIONS.size(): return false
	if data.water<0 or data.food<0 or data.power<0: return false
	if not data.stash is Array or not data.furniture is Array: return false
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
	if data.has("shop_customer") and not Shop.valid(data.shop_customer,int(data.day),int(data.station),int(data.customer)):return false
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

func advance_days(days: int,reserve: int=0) -> bool:
	if days<1 or not run.is_empty() or state.water<DAILY_WATER*days or state.food<DAILY_FOOD*days or state.power<DAILY_POWER*days+reserve:
		last_error="需要 %d 天的补给：%d 水、%d 食物、%d 电量。" % [days,DAILY_WATER*days,DAILY_FOOD*days,DAILY_POWER*days+reserve]
		return false
	state.water-=DAILY_WATER*days
	state.food-=DAILY_FOOD*days
	state.power-=DAILY_POWER*days
	state.day+=days
	state.news=(int(state.day)*7)%4
	state.customer=0
	state.erase("shop_customer")
	return true
func advance_activity_day(reserve: int=0) -> bool:
	return advance_days(1,reserve)
func next_day() -> String:
	var before=state.duplicate(true)
	if not advance_activity_day():return last_error
	if not save_game():
		state=before
		return last_error
	return "进入第 %d 天。基地已保存。" % state.day
func open_shop() -> bool:
	if shop_open:return true
	var before=state.duplicate(true)
	if not advance_activity_day():return false
	if not save_game():
		state=before
		return false
	shop_open=true
	return true
func close_shop() -> void:shop_open=false

func travel_plan(index: int) -> Dictionary:
	var path=Metro.route(int(state.station),index)
	var hops=maxi(0,path.size()-1)
	var days=ceili(float(hops)/TRAVEL_HOPS_PER_DAY)
	var cost={"route":path,"days":days,"water":DAILY_WATER*days,"food":DAILY_FOOD*days,"power":DAILY_POWER*days,"available":false}
	cost.available=not path.is_empty() and days>0 and run.is_empty() and state.water>=cost.water and state.food>=cost.food and state.power>=cost.power
	return cost
func travel(index: int) -> String:
	if index<0 or index>=Catalog.STATIONS.size():return "无效站点。"
	if index==int(state.station):return "已经位于该站点。"
	var plan=travel_plan(index)
	if plan.route.is_empty():return "该站点没有连通路线。"
	var before=state.duplicate(true)
	if not advance_days(int(plan.days)):return last_error
	state.station=index
	if not save_game():
		state=before
		return last_error if not last_error.is_empty() else "行程保存失败，请重试。"
	shop_open=false
	return "抵达%s，经过 %d 天，消耗 %d 水、%d 食物、%d 电量。" % [Catalog.STATIONS[index].name,plan.days,plan.water,plan.food,plan.power]
func travel_cost(index: int) -> int:
	return int(travel_plan(index).power)

func price(id: String,buy: bool) -> int:
	var item = Catalog.item(id)
	var factor = Catalog.STATIONS[int(state.station)].factor
	if int(state.news)==int(item.category)%4: factor*=1.25
	return maxi(1,roundi(item.price*factor*(1.0 if buy else 0.62)))

func trade(_id: String,_buy: bool) -> String:
	return "请在营业窗口与到店顾客交易。"

func customer_limit(station: int=-1) -> int:
	return Shop.limit(int(state.station) if station<0 else station)
func customer_offer() -> Dictionary:
	if int(state.customer)>=customer_limit():return {}
	var key=Shop.key(int(state.day),int(state.station),int(state.customer))
	if not state.has("shop_customer") or state.shop_customer.key!=key:
		state.shop_customer=Shop.generate(int(state.day),int(state.station),int(state.customer))
	return state.shop_customer.duplicate(true)
func stash_signature() -> String:
	ensure_stash()
	return JSON.stringify([state.stash,state.stash_layout]).sha256_text()
func customer_price(id: String,offer: Dictionary) -> int:
	return maxi(1,roundi(price(id,not offer.buying)*(1.15 if offer.buying else 0.72)))
func customer_drag(source: String,index: int) -> Dictionary:
	var offer=customer_offer()
	if not shop_open or offer.is_empty() or not source in ["stash","customer"]:return {}
	var entries=stash_entries() if source=="stash" else offer.stock
	if index<0 or index>=entries.size():return {}
	return {"key":offer.key,"revision":int(offer.revision),"source":source,"index":index,"id":entries[index].id,"signature":stash_signature() if source=="stash" else ""}
func valid_customer_selection(data: Variant) -> bool:
	var offer=customer_offer()
	if not shop_open or offer.is_empty() or not data is Dictionary or not data.has_all(["key","revision","source","index","id","signature"]):return false
	if data.key!=offer.key or data.revision!=offer.revision or not data.index is int:return false
	if data.source!=("stash" if offer.buying else "customer"):return false
	var entries=stash_entries() if offer.buying else offer.stock
	if data.index<0 or data.index>=entries.size() or data.id!=entries[data.index].id:return false
	if offer.buying and data.signature!=stash_signature():return false
	return int(Catalog.item(data.id).category)==int(offer.category)
func customer_quote(selection: Dictionary) -> Dictionary:
	if not valid_customer_selection(selection):return {"valid":false,"affordable":false,"price":0,"message":"拖入同类物品选择交易。"}
	var offer=customer_offer()
	var value=customer_price(selection.id,offer)
	var affordable=value<=int(offer.budget) if offer.buying else value<=int(state.power)
	var message="%s · %d 电量" % [Catalog.item(selection.id).name,value]
	if not affordable:message+="\n买不起：顾客预算不足。" if offer.buying else "\n买不起：你的电量不足。"
	return {"valid":true,"affordable":affordable,"price":value,"message":message}
func accept_customer(expected_key: String="",selection: Dictionary={}) -> String:
	if not shop_open:return "请先开店。"
	var offer=customer_offer()
	if offer.is_empty():return "今日顾客已全部接待。"
	if expected_key!=offer.key:return "该顾客已离开。"
	var quote=customer_quote(selection)
	if not quote.valid or not quote.affordable:return quote.message
	var before=state.duplicate(true)
	if offer.buying:
		remove_stash(int(selection.index))
		state.power+=int(quote.price)
		state.shop_customer.budget-=int(quote.price)
	else:
		state.power-=int(quote.price)
		add_stash(selection.id)
		state.shop_customer.budget+=int(quote.price)
		state.shop_customer.stock.remove_at(int(selection.index))
	state.shop_customer.revision+=1
	if not save_game():
		state=before
		return last_error if not last_error.is_empty() else "交易保存失败，请重试。"
	return "交易完成。"
func skip_customer(expected_key: String) -> String:
	var offer=customer_offer()
	if not shop_open or offer.is_empty() or expected_key!=offer.key:return "该顾客已离开。"
	var before=state.duplicate(true)
	state.customer+=1
	state.erase("shop_customer")
	if not save_game():
		state=before
		return last_error if not last_error.is_empty() else "保存失败，请重试。"
	return "顾客离开了。"

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
	var stats=Catalog.CLASSES[class_index].duplicate(true)
	if module=="5_0":stats.armor=minf(0.7,stats.armor+0.15)
	if module=="5_1":stats.grid_rows+=1
	stats.capacity=int(stats.grid_cols)*int(stats.grid_rows)
	var equipment={"module":{},"weapon":{},"drug":{}}
	var equipped_uid={"module":-1,"weapon":-1,"drug":-1}
	var next_uid=0
	for index in range(selections.size()):
		var id: String=selections[index]
		if id=="":continue
		equipment[slot_keys[index]]={"id":id,"uses":Catalog.item(id).uses,"uid":next_uid,"rot":0}
		equipped_uid[slot_keys[index]]=next_uid
		next_uid+=1
	var before=state.duplicate(true)
	if not advance_activity_day(int(floor_data.budget)):return false
	ensure_stash()
	selected_indices.sort()
	selected_indices.reverse()
	for index in selected_indices:remove_stash(int(index))
	if not save_game():
		state=before
		return false
	run_serial+=1
	run={"class":class_index,"stats":stats,"hp":stats.hp,"module":module,"weapon":weapon,"drug":drug,"bag":[],"equipment":equipment,"equipped_uid":equipped_uid,"next_uid":next_uid,"inventory_revision":0,"inventory_token":run_serial,"floor_data":floor_data,"room":0,"floor":1,"energy":floor_data.budget,"buff":0.0,"shield":0.0,"weapon_cd":0.0,"rewards":[],"damage":1.0,"fighting":false,"seed":floor_data.seed}
	shop_open=false
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
func inventory_changed() -> void:run.inventory_revision+=1
func pick_up(id: String,remaining_uses: int=-1) -> bool:
	if run.is_empty() or run.fighting or not Catalog.valid_ids().has(id):return false
	var placement=Inventory.first_fit(run.bag,bag_dimensions(),id)
	if placement.is_empty():return false
	placement.merge({"id":id,"uses":Catalog.item(id).uses if remaining_uses<0 else remaining_uses,"uid":run.next_uid})
	run.next_uid+=1
	run.bag.append(placement)
	inventory_changed()
	return true
func move_bag(index: int,position: Vector2i,rotation: int) -> bool:
	if run.is_empty() or run.fighting or index<0 or index>=run.bag.size():return false
	if not Inventory.fits(run.bag,bag_dimensions(),run.bag[index].id,position,rotation,index):return false
	run.bag[index].merge({"x":position.x,"y":position.y,"rot":posmod(rotation,4)},true)
	inventory_changed()
	return true
func equipment_dimensions(module: String) -> Vector2i:
	var base: Dictionary=Catalog.CLASSES[int(run["class"])]
	return Vector2i(base.grid_cols,int(base.grid_rows)+(1 if module=="5_1" else 0))
func apply_equipment_stats() -> void:
	var base: Dictionary=Catalog.CLASSES[int(run["class"])]
	var dimensions=equipment_dimensions(run.module)
	run.stats.armor=minf(0.7,float(base.armor)+(0.15 if run.module=="5_0" else 0.0))
	run.stats.grid_rows=dimensions.y
	run.stats.capacity=dimensions.x*dimensions.y
func equipped_entry(slot_key: String) -> Dictionary:
	return {} if run.is_empty() else run.equipment.get(slot_key,{})
func equipment_plan(index: int,slot_key: String) -> Dictionary:
	if run.is_empty() or run.fighting or index<0 or index>=run.bag.size() or not run.equipment.has(slot_key):return {}
	var incoming: Dictionary=run.bag[index]
	if int(Catalog.item(incoming.id).category)!={"module":5,"weapon":4,"drug":3}[slot_key]:return {}
	var bag: Array=run.bag.duplicate(true)
	bag.remove_at(index)
	var dimensions=equipment_dimensions(incoming.id if slot_key=="module" else run.module)
	if not Inventory.valid(bag,dimensions):return {}
	var old=equipped_entry(slot_key)
	if not old.is_empty():
		var position=Inventory.first_fit(bag,dimensions,old.id)
		if position.is_empty():return {}
		var returning=old.duplicate(true)
		returning.merge(position,true)
		bag.append(returning)
	return {"bag":bag,"entry":incoming.duplicate(true)}
func equip_entry(index: int) -> bool:
	if run.is_empty() or run.fighting or index<0 or index>=run.bag.size():return false
	var slot_key: String={3:"drug",4:"weapon",5:"module"}.get(int(Catalog.item(run.bag[index].id).category),"")
	var plan=equipment_plan(index,slot_key)
	if plan.is_empty():
		last_error="无法装配：物品类型不符，或背包没有空间收回旧装备。"
		return false
	run.bag=plan.bag
	run.equipment[slot_key]=plan.entry
	run[slot_key]=plan.entry.id
	run.equipped_uid[slot_key]=plan.entry.uid
	apply_equipment_stats()
	inventory_changed()
	return true
func unequip_plan(slot_key: String,position: Vector2i=Vector2i(-1,-1),rotation: int=0) -> Dictionary:
	if run.is_empty() or run.fighting:return {}
	var entry=equipped_entry(slot_key)
	if entry.is_empty():return {}
	var dimensions=equipment_dimensions("" if slot_key=="module" else run.module)
	if not Inventory.valid(run.bag,dimensions):return {}
	var placement=Inventory.first_fit(run.bag,dimensions,entry.id) if position.x<0 else {"x":position.x,"y":position.y,"rot":rotation}
	if placement.is_empty() or not Inventory.fits(run.bag,dimensions,entry.id,Vector2i(placement.x,placement.y),int(placement.rot)):return {}
	var returning=entry.duplicate(true)
	returning.merge(placement,true)
	return returning
func unequip_slot(slot_key: String,position: Vector2i=Vector2i(-1,-1),rotation: int=0) -> bool:
	var entry=unequip_plan(slot_key,position,rotation)
	if entry.is_empty():
		last_error="背包没有足够的连续空间，或物品仍占用背架扩展行。"
		return false
	run.bag.append(entry)
	run.equipment[slot_key]={}
	run[slot_key]=""
	run.equipped_uid[slot_key]=-1
	apply_equipment_stats()
	inventory_changed()
	return true
func set_module(id: String) -> bool:
	if id=="":return unequip_slot("module")
	if run.is_empty():return false
	for index in range(run.bag.size()):
		if run.bag[index].id==id:return equip_entry(index)
	return false
func run_drag_data(index: int=-1,origin: String="bag") -> Dictionary:
	if run.is_empty() or run.fighting:return {}
	var entry: Dictionary={}
	if origin=="bag":
		if index<0 or index>=run.bag.size():return {}
		entry=run.bag[index]
	else:entry=equipped_entry(origin)
	if entry.is_empty():return {}
	return {"kind":"run_item","token":run.inventory_token,"revision":run.inventory_revision,"origin":origin,"index":index,"uid":entry.uid,"item_id":entry.id,"rotation":int(entry.get("rot",0)),"anchor":Vector2i.ZERO}
func valid_run_payload(data: Variant) -> bool:
	if run.is_empty() or run.fighting or not data is Dictionary or not data.has_all(["kind","token","revision","origin","index","uid","item_id"]):return false
	if data.kind!="run_item" or data.token!=run.inventory_token or data.revision!=run.inventory_revision:return false
	var actual=run_drag_data(int(data.index),str(data.origin))
	return not actual.is_empty() and actual.uid==data.uid and actual.item_id==data.item_id
func can_equip_payload(slot_key: String,data: Variant) -> bool:
	return valid_run_payload(data) and (data.origin==slot_key or data.origin=="bag" and not equipment_plan(int(data.index),slot_key).is_empty())
func equip_payload(slot_key: String,data: Variant) -> bool:
	if not can_equip_payload(slot_key,data):return false
	return true if data.origin==slot_key else equip_entry(int(data.index))
func can_place_payload(data: Variant,position: Vector2i,rotation: int) -> bool:
	if not valid_run_payload(data):return false
	return Inventory.fits(run.bag,bag_dimensions(),data.item_id,position,rotation,int(data.index)) if data.origin=="bag" else not unequip_plan(str(data.origin),position,rotation).is_empty()
func place_payload(data: Variant,position: Vector2i,rotation: int) -> bool:
	if not can_place_payload(data,position,rotation):return false
	return move_bag(int(data.index),position,rotation) if data.origin=="bag" else unequip_slot(str(data.origin),position,rotation)

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
func can_return_to_base() -> bool:
	if run.is_empty() or run.fighting:return false
	var current: Dictionary=run.floor_data.rooms[int(run.room)]
	return (current.kind=="start" and current.cleared) or can_extract()
func end_run(success: bool) -> String:
	if run.is_empty(): return ""
	if success and not can_return_to_base():return "请在起始房间或已清场的 Boss 房间使用返程终端。"
	var cargo: Array=run.bag.duplicate(true)
	for entry in run.equipment.values():
		if not entry.is_empty():cargo.append(entry)
	var count=cargo.size()
	if success:
		for entry in cargo:
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
