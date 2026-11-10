extends Node
const Metro=preload("res://scripts/metro.gd")
const Catalog = preload("res://scripts/catalog.gd")
const FloorGenerator = preload("res://scripts/floor_generator.gd")
const SAVE_VERSION = 1
var slot = -1
var state: Dictionary = {}
var run: Dictionary = {}
var settings = {"volume":0.5,"fullscreen":false}
var last_error = ""

func _ready() -> void:
	var saved = read_json("user://settings.json")
	if not saved.is_empty(): settings.merge(saved,true)
	apply_settings()

func new_game(index: int, base_name: String) -> bool:
	slot=index
	state={"version":SAVE_VERSION,"name":base_name.strip_edges() if not base_name.strip_edges().is_empty() else "上海堡垒", "day":1,"station":0,"water":24,"food":24,"power":240,"stash":["3_0","3_1","3_2","3_3","4_0","4_1","4_2","4_3","5_0","5_1","5_2","5_3"],"furniture":[],"news":0,"market_stock":{},"customer":0}
	run={}
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
	run={}
	return true

func validate_save(data: Dictionary) -> bool:
	for key in ["version","name","day","station","water","food","power","stash","furniture","news","market_stock","customer"]:
		if not data.has(key): return false
	if data.version!=SAVE_VERSION or not data.name is String: return false
	for key in ["day","station","water","food","power","news","customer"]:
		if not (data[key] is int or data[key] is float): return false
	if data.day<1 or data.station<0 or data.station>=Catalog.STATIONS.size(): return false
	if data.water<0 or data.food<0 or data.power<0: return false
	if not data.stash is Array or not data.furniture is Array or not data.market_stock is Dictionary: return false
	var valid = Catalog.valid_ids()
	for id in data.stash:
		if not id is String or not valid.has(id): return false
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
	return write_json("user://slot_%d.json" % slot,state)

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,settings.volume)))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

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
		state.stash.append(id)
	else:
		if not state.stash.has(id): return "仓库中没有该物品。"
		state.stash.erase(id)
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
		state.stash.erase(offer.id)
		state.power+=offer.price
	else:
		if state.power<offer.price: return "电量不足。"
		state.power-=offer.price
		state.stash.append(offer.id)
	state.customer+=1
	save_game()
	return "交易完成，新顾客已到站。"

func begin_run(class_index: int,module: String,weapon: String,drug: String,seed_value: int=-1) -> bool:
	var floor_data=FloorGenerator.generate(seed_value if seed_value>=0 else randi(),1)
	if state.power<floor_data.budget:
		last_error="本层无掉落保底路线需 %d 电量，账户不足。" % floor_data.budget
		return false
	for id in [module,weapon,drug]:
		if id!="" and not state.stash.has(id):
			last_error="仓库中缺少装备。"
			return false
	var stats=Catalog.CLASSES[class_index].duplicate(true)
	var bag: Array=[]
	for id in [module,weapon,drug]:
		if id!="":
			state.stash.erase(id)
			bag.append({"id":id,"uses":Catalog.item(id).uses})
	if module=="5_0": stats.armor=minf(0.7,stats.armor+0.15)
	if module=="5_1": stats.capacity+=6
	run={"class":class_index,"stats":stats,"hp":stats.hp,"module":module,"weapon":weapon,"drug":drug,"bag":bag,"floor_data":floor_data,"room":0,"floor":1,"energy":floor_data.budget,"timer":360.0-float(Catalog.STATIONS[int(state.station)].radiation)*20.0,"buff":0.0,"shield":0.0,"weapon_cd":0.0,"rewards":[],"damage":1.0,"fighting":false,"seed":floor_data.seed}
	return true

func move_room(id: int) -> bool:
	var current=run.floor_data.rooms[int(run.room)]
	if run.fighting or not current.links.has(id) or run.energy<1 or state.power<1: return false
	run.energy-=1
	state.power-=1
	run.room=id
	return true

func pick_up(id: String,remaining_uses: int=-1) -> bool:
	if run.bag.size()>=int(run.stats.capacity): return false
	run.bag.append({"id":id,"uses":Catalog.item(id).uses if remaining_uses<0 else remaining_uses})
	return true

func claim_reward(index: int) -> String:
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
	var room=run.floor_data.rooms[int(run.room)]
	if room.kind!="boss" or not room.cleared: return false
	var next=FloorGenerator.generate(int(run.seed)+int(run.floor)*997,int(run.floor)+1)
	if state.power<next.budget:
		last_error="下一层保底路线需要 %d 电量，请先撤离交易。" % next.budget
		return false
	run.floor+=1
	run.floor_data=next
	run.room=0
	run.energy=next.budget
	run.timer=360.0-float(Catalog.STATIONS[int(state.station)].radiation)*20.0
	return true

func end_run(success: bool) -> String:
	if run.is_empty(): return ""
	var count=run.bag.size()
	if success:
		for entry in run.bag:
			state.stash.append(entry.id)
	else:
		# Equipped items and cargo are lost. Combat already spent electricity.
		count=0
	run={}
	save_game()
	return "安全返程，回收 %d 件物资。已存入基地仓库。" % count if success else "救援队将你送回基地，本次携带物资遗失。"
