extends SceneTree
const Generator=preload("res://scripts/floor_generator.gd")
const C=preload("res://scripts/catalog.gd")
var checks=0
var failures: Array=[]
var game: Node
func check(ok: bool,description: String) -> void:
	checks+=1
	if not ok:
		failures.append(description)
		push_error(description)
func _initialize() -> void:
	if OS.get_environment("SUBWAY_TEST_MODE")!="1":
		push_error("Use tools/test.sh or set SUBWAY_TEST_MODE=1 with isolated XDG_DATA_HOME; these scripts create test saves.")
		quit(1)
		return
	call_deferred("run_tests")
func run_tests() -> void:
	root.size=Vector2i(1440,900)
	game=root.get_node("Game")
	preload("res://tests/art_and_map_checks.gd").run(check)
	preload("res://tests/palette_checks.gd").run(check)
	preload("res://tests/regional_loot_checks.gd").run(check)
	var floor_summary={"seeds":1000,"minimum_coverage":1.0,"min_occupied_cells":1000,"max_occupied_cells":0,"minimum_spine_turns":1000}
	for seed_value in range(1000):
		var data=Generator.generate(seed_value)
		var rooms: Array=data.rooms
		floor_summary.minimum_coverage=minf(floor_summary.minimum_coverage,data.coverage)
		floor_summary.min_occupied_cells=mini(floor_summary.min_occupied_cells,data.occupied_cells)
		floor_summary.max_occupied_cells=maxi(floor_summary.max_occupied_cells,data.occupied_cells)
		floor_summary.minimum_spine_turns=mini(floor_summary.minimum_spine_turns,data.spine_turns)
		var occupied={}
		for room in rooms:
			check(room.cells.size() in [1,2,3] and room.layout_ids.size()==room.cells.size(),"each room owns its complete footprint and interior layouts")
			for cell in room.cells:
				check(not occupied.has(cell),"different rooms never overlap occupied map cells")
				occupied[cell]=room.id
		check(rooms.size()>=36 and rooms.size()<=45,"room count seed %d" % seed_value)
		check(rooms.size()==ceili(data.base_room_count*1.5) and data.budget==2*data.base_room_count+13,"one-and-a-half rooms with unchanged electrical budget")
		check(rooms[data.reward].links.size()==4 and rooms[data.boss].links.size()==3,"reward and boss have more connected doors")
		check(rooms.all(func(room):return room.cells.all(func(cell):return cell.x>=-5 and cell.x<=6 and absi(cell.y)<=2)),"expanded floor preserves horizontal and vertical bounds")
		var distances={0:0}
		var path_queue: Array=[0]
		while not path_queue.is_empty():
			var current: int=path_queue.pop_front()
			for neighbor in rooms[current].links:
				if not distances.has(neighbor):
					distances[neighbor]=int(distances[current])+1
					path_queue.append(neighbor)
		check(int(distances[data.boss])==11,"start-to-boss depth remains eleven passages")
		check(data.route.front()==0 and data.route.back()==data.boss,"route endpoints")
		var visited={}
		var previous=-1
		var shops=0
		for id in data.route:
			visited[id]=true
			if previous>=0:check(rooms[previous].links.has(id),"legal route edge")
			previous=id
		check(visited.size()>=ceili(rooms.size()*0.8),"80 percent coverage seed %d" % seed_value)
		check(data.spine_turns>=3 and rooms.any(func(room):return room.cells.size()==2) and rooms.any(func(room):return room.cells.size()==3),"curved spine and two/three-cell rooms")
		check(data.route.size()-1<=data.budget,"sufficient energy")
		for r in rooms:
			if r.kind=="shop":shops+=1
			for id in r.links:
				check(rooms[id].links.has(r.id),"symmetric link")
				check(r.doors.has(id) and r.cells.has(r.doors[id].cell) and rooms[id].cells.has(r.doors[id].cell+r.doors[id].normal),"linked room footprints share a physical portal")
		check(shops==1,"one shop")
		var pending: Array=[0]
		var seen={0:true}
		while not pending.is_empty():
			var id: int=pending.pop_front()
			for neighbor in rooms[id].links:
				if neighbor!=data.reward and not seen.has(neighbor):
					seen[neighbor]=true
					pending.append(neighbor)
		check(not seen.has(data.boss),"reward articulation required")
	var example=Generator.generate(2026)
	floor_summary.example={"seed":2026,"rooms":example.rooms.size(),"occupied_cells":example.occupied_cells,"budget":example.budget,"route_steps":example.route.size()-1,"spine_depth":example.spine_depth,"spine_turns":example.spine_turns,"coverage":example.coverage}
	DirAccess.make_dir_recursive_absolute("res://work")
	var floor_report=FileAccess.open("res://work/floor-report.json",FileAccess.WRITE)
	floor_report.store_string(JSON.stringify(floor_summary,"\t"))
	floor_report.close()
	print("FLOOR AUDIT: ",JSON.stringify(floor_summary))
	check(C.all_ids().size()==24,"six categories with four items")
	for id in C.all_ids():check(ResourceLoader.exists(C.item(id).icon),"item asset exists")
	for i in range(3):
		check(game.new_game(i,"" if i==0 else "测试基地%d" % i),"create slot")
		check(game.state.name==("上海堡垒" if i==0 else "测试基地%d" % i),"base naming")
		game.state.power=240+i
		game.save_game()
	for i in range(3):
		check(game.load_game(i),"load independent slot")
		check(game.state.power==240+i,"separate slot data")
	check(not game.validate_save({"version":999}),"reject corrupt save")
	var bad=game.state.duplicate(true)
	bad.stash=["999_0"]
	check(not game.validate_save(bad),"reject unknown items")
	var before=int(game.state.power)
	game.travel(1)
	check(game.state.station==1 and game.state.power==before-6,"adjacent selected-station route energy")
	game.state.water=0
	before=int(game.state.day)
	game.next_day()
	check(game.state.day==before,"insufficient resource day blocked")
	game.state.water=20
	game.state.food=20
	game.state.power=500
	game.next_day()
	check(game.state.day==before+1 and game.state.water==18 and game.state.food==18 and game.state.power==495,"daily costs")
	game.state.station=0
	var old_price=game.price("4_0",true)
	game.state.station=5
	check(game.price("4_0",true)>old_price,"station prices")
	game.state.station=0
	game.state.power=10000
	for i in range(4):game.trade("4_0",true)
	var balance=game.state.power
	game.trade("4_0",true)
	check(game.state.power==balance,"stock limit enforced")
	game.next_day()
	check(game.state.market_stock.is_empty(),"daily stock resets")
	game.trade("4_0",false)
	check(game.state.power>0,"selling works")
	for c in range(3):
		game.load_game(0)
		game.state.power=300
		check(game.begin_run(c,"5_1","4_1","3_0",42),"begin each class")
		check(game.run.stats.capacity==C.CLASSES[c].capacity+C.CLASSES[c].grid_cols,"module capacity")
		var neighbor=int(game.run.floor_data.rooms[0].links[0])
		game.run.fighting=true
		check(not game.move_room(neighbor),"combat door lock")
		game.run.fighting=false
		var energy=int(game.run.energy)
		balance=game.state.power
		check(game.move_room(neighbor),"room transition")
		check(game.run.energy==energy-1 and game.state.power==balance-1,"room energy cost")
		while game.pick_up("1_0"):pass
		check(not game.pick_up("1_0"),"physical capacity bound")
		if c!=2:
			game.run.room=game.run.floor_data.boss
			game.run.floor_data.rooms[game.run.room].cleared=true
		var output=game.end_run(c!=2)
		check(game.run.is_empty(),"run settled")
		check(output!="","settlement message")
	# Exercise UI routes, equipment, inventory, drops, combat patterns and settlement.
	game.new_game(0,"界面测试")
	var ui=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.show_slots()
	check(game.craft_furniture(0),"craft owned furniture before placement")
	ui.show_base(true)
	await process_frame
	var world=ui.stage.get_child(0)
	var click=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.position=world.base_to_screen(world.iso(1.5,1.5))
	world._gui_input(click)
	check(game.state.furniture.size()==1,"place furniture")
	world._gui_input(click)
	click.pressed=false
	click.position=world.base_to_screen(world.iso(3.5,2.5))
	world._gui_input(click)
	check(int(game.state.furniture[0].x)==3 and int(game.state.furniture[0].y)==2,"drag furniture")
	click.pressed=true
	click.button_index=MOUSE_BUTTON_RIGHT
	world._gui_input(click)
	check(game.state.furniture.is_empty(),"recycle furniture")
	ui.show_map()
	await process_frame
	ui.map_view.center_station(1)
	var map_click=InputEventMouseButton.new()
	map_click.button_index=MOUSE_BUTTON_LEFT
	map_click.pressed=true
	map_click.position=ui.map_view.map_point(1)
	ui.map_view._gui_input(map_click)
	check(ui.map_selection==1,"main map point selection")
	check(ui.map_actions.get_child_count()==2 and not ui.map_actions.get_child(0).disabled,"map travel and back actions remain available outside details scroll")
	map_click=map_click.duplicate()
	map_click.button_index=MOUSE_BUTTON_WHEEL_UP
	var zoom_before=float(ui.map_view.map_zoom)
	ui.map_view._gui_input(map_click)
	check(ui.map_view.map_zoom>zoom_before,"main map wheel zoom")
	ui.map_view.line_filter="10"
	check(ui.map_view.nearest_station(ui.map_view.map_point(1))==1,"line filter retains selected line station")
	ui.station_detail()
	ui.show_preparation()
	ui.show_shop()
	ui.show_settings()
	ui.close_modal()
	game.state.power=1000
	check(game.begin_run(1,"5_0","4_0","3_0",43),"UI run begins")
	ui.show_combat()
	await process_frame
	ui.show_bag()
	check(ui.battle.paused,"inventory pauses")
	check(game.pick_up("1_0"),"cargo can be placed independently of equipped items")
	ui.bag_selected=0
	check(game.move_bag(0,Vector2i(0,2),0),"inventory position move")
	ui.close_modal()
	check(not ui.battle.paused,"resume from inventory")
	var battle=ui.battle
	game.run.hp=50.0
	battle.use_drug()
	check(game.run.hp==85.0 and game.equipped_entry("drug").uses==2,"medicine effect and finite uses")
	check(game.unequip_slot("drug"),"unequip medicine into real bag space")
	ui.drop_bag(game.run.bag.size()-1)
	battle.player=battle.room().ground.back().pos
	battle.collect(battle.room().loot.size()-1)
	check(game.run.bag.back().uses==2,"drop and pickup preserve drug uses")
	var key=InputEventKey.new()
	key.physical_keycode=KEY_D
	key.pressed=true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	var start=Vector2(battle.player)
	battle._process(0.1)
	check(battle.player.x>start.x,"WASD moves player")
	key=key.duplicate()
	key.pressed=false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	var target=battle.make_enemy(0,Vector2(300,300))
	battle.enemies=[target]
	battle.shoot(Vector2(300,300),Vector2.RIGHT,false,100,500)
	battle.update_bullets(0.001)
	check(battle.enemies.is_empty(),"player projectile kills enemy")
	for i in range(4):
		game.run.weapon="4_%d" % i
		game.run.weapon_cd=0.0
		battle.use_weapon()
		check(game.run.weapon_cd>0,"active weapon cooldown")
	for i in range(5):battle.enemies.append(battle.make_enemy(i,Vector2(650,300)))
	game.run.fighting=true
	battle.update_enemies(3.0)
	battle.update_bullets(0.01)
	check(battle.bullets.size()>0,"enemy shooting patterns")
	ui.show_bag()
	check(not is_instance_valid(ui.modal),"combat bag lock")
	game.run.fighting=false
	battle.enemies=[]
	game.run.room=game.run.floor_data.reward
	battle.enter_room()
	game.claim_reward(0)
	check(game.run.damage==1.25,"passive reward")
	game.claim_reward(0)
	check(game.run.damage==1.25,"reward once only")
	game.run.room=game.run.floor_data.boss
	battle.enter_room()
	check(battle.enemies.size()==1 and battle.enemies[0].type==4,"boss spawns")
	battle.enemies=[]
	battle._process(0.01)
	check(battle.room().cleared,"boss cleared")
	check(game.next_floor(),"boss allows next floor")
	check(game.run.floor==2 and game.run.room==0,"next floor generated")
	game.end_run(false)
	ui.show_base()
	await process_frame
	check(game.load_game(0),"settlement persisted")
	await preload("res://tests/interaction_checks.gd").new().run(self,game,ui,check)
	await preload("res://tests/inventory_checks.gd").new().run(self,game,ui,check)
	await preload("res://tests/base_combat_revision_checks.gd").new().run(self,game,ui,check)
	await preload("res://tests/base_ui_checks.gd").new().run(self,game,ui,check)
	await preload("res://tests/armored_beast_checks.gd").new().run(self,game,ui,check)
	await preload("res://tests/expansion_checks.gd").new().run(self,game,ui,check)
	await preload("res://tests/bullet_checks.gd").new().run(self,game,ui,check)
	ui.queue_free()
	await process_frame
	await process_frame
	# The audio mixer releases stopped playback on its own thread.
	await create_timer(0.15).timeout
	print("TEST RESULT: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
