extends SceneTree
var ui: Control
func _initialize() -> void:
	if OS.get_environment("SUBWAY_TEST_MODE")!="1":
		push_error("Use tools/test.sh or set SUBWAY_TEST_MODE=1 with isolated XDG_DATA_HOME; these scripts create test saves.")
		quit(1)
		return
	call_deferred("capture")
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+name+".png")
func capture() -> void:
	root.size=Vector2i(1440,900)
	var game=root.get_node("Game")
	ui=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(ui)
	var gestures=load("res://tests/interaction_checks.gd").new()
	gestures.tree=self
	await shot("menu")
	game.new_game(0,"上海堡垒")
	ui.show_base()
	for type in range(4):
		game.craft_furniture(type)
		if type!=2:game.place_furniture(type,[Vector2i(1,1),Vector2i(3,1),Vector2i(7,1),Vector2i(1,4)][type])
	# Obtain the missing bandage through a real visitor, not the retired catalogue.
	game.state.crystals=100
	game.open_shop()
	for day in range(2,100):
		game.state.day=day
		game.state.customer=0
		game.state.erase("shop_customer")
		var offer=game.customer_offer()
		if not offer.buying and int(offer.category)==3:
			for index in range(offer.stock.size()):
				if offer.stock[index].id=="3_0":
					game.accept_customer(offer.key,game.customer_drag("customer",index))
					break
			if game.state.stash.has("3_0"):break
	game.close_shop()
	ui.show_base(true)
	await shot("base_decoration")
	ui.show_crafting()
	await shot("crafting")
	ui.close_modal()
	game.place_furniture(2,Vector2i(7,1))
	ui.show_base()
	await shot("base")
	ui.stage.get_child(0).heroine.grid_position=Vector2(2.4,1.5)
	await process_frame
	gestures.tap(KEY_F)
	await shot("base_dialogue")
	ui.close_modal()
	ui.show_map()
	await shot("map")
	ui.toggle_drawer()
	for index in range(ui.C.STATIONS.size()):
		if ui.C.STATIONS[index].name=="张江高科":
			ui.map_selection=index
			ui.map_view.center_station(index)
			ui.station_detail()
			break
	await shot("map_zhangjiang")
	# Reclaim and later restore the real bed so gold finished-goods cells are visible.
	for index in range(game.state.furniture.size()):
		if int(game.state.furniture[index].type)==2:game.reclaim_furniture(index);break
	ui.show_stash()
	await shot("warehouse_grid")
	ui.close_modal()
	ui.show_preparation()
	await shot("prepare")
	# Exercise real mouse drags for the visual review too.
	await gestures.drag(ui.warehouse_grid.get_child(8),ui.loadout_slots.get_child(0))
	await gestures.drag(ui.warehouse_grid.get_child(5),ui.loadout_slots.get_child(1))
	await gestures.drag(ui.warehouse_grid.get_child(0),ui.loadout_slots.get_child(2))
	await shot("prepare_equipped")
	game.place_furniture(2,Vector2i(7,1))
	ui.show_shop()
	await shot("shop")
	ui.current_screen.visitor.set_process(false)
	ui.current_screen.visitor.advance(1.0)
	await shot("shop_details")
	game.begin_run(1,"5_0","4_1","3_0",2026)
	ui.show_combat()
	await shot("combat_start")
	# Screenshot fixture: start at the physical gate and use the same F interaction.
	ui.battle.player=ui.battle.door_position(int(ui.battle.room().links[0]))
	ui.battle.door_delay=0
	gestures.tap(KEY_F)
	gestures.tap(KEY_SPACE)
	await create_timer(0.5).timeout
	await shot("combat")
	ui.toggle_drawer()
	await shot("combat_details")
	ui.toggle_drawer()
	ui.battle.set_process(false)
	ui.minimap.set_process(false)
	gestures.key(KEY_TAB,true)
	ui.minimap.advance_hold(2.0)
	await shot("combat_map_held")
	gestures.key(KEY_TAB,false)
	# Cleared-room screenshot fixture to inspect each resource icon and the pickup prompt.
	ui.battle.enemies=[]
	ui.battle.bullets=[]
	game.run.fighting=false
	ui.battle.room().cleared=true
	ui.battle.room().loot=["power","credits","0_0","2_0","3_0","4_1","5_0","scrap","chest"]
	ui.battle.room().ground=[]
	ui.battle.ensure_ground_loot()
	ui.battle.player=ui.battle.room().ground[2].pos+Vector2(0,-45)
	ui.battle.queue_redraw()
	await shot("ground_loot")
	game.pick_up("0_1")
	game.pick_up("2_2")
	game.pick_up("mat_valve")
	game.pick_up("4_2")
	game.pick_up("5_1")
	game.pick_up("3_0")
	ui.bag_selected=1
	ui.show_bag()
	await shot("backpack_grid")
	ui.close_modal()
	# Facing fixture: left/right/up/down for both mobile quadrupeds.
	ui.battle.room().loot=[]
	ui.battle.room().ground=[]
	var headings=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]
	ui.battle.player=Vector2(100,480)
	for type in [0,3]:
		for i in range(4):
			var enemy=ui.battle.make_enemy(type,Vector2(240+i*150,240+type*55))
			ui.battle.update_enemy_facing(enemy,headings[i]*10,0.2)
			ui.battle.enemies.append(enemy)
	ui.battle.show_hitboxes=true
	ui.battle.queue_redraw()
	ui.say("碰撞检查：可见轮廓中心与碰撞圆心一致。")
	await shot("enemy_facing")
	ui.battle.show_hitboxes=false
	ui.battle.player=Vector2(730,330)
	ui.battle.bullets=[]
	ui.battle.enemies=[ui.battle.make_enemy(0,Vector2(280,300)),ui.battle.make_enemy(3,Vector2(450,300))]
	game.run.fighting=true
	ui.refresh_combat()
	ui.battle._process(1.41)
	await shot("shell_windup")
	ui.battle._process(0.71)
	gestures.key(KEY_S,true)
	for tick in range(12):ui.battle._process(0.05)
	gestures.key(KEY_S,false)
	ui.say("变异鼠持续追击；甲壳兽蓄力后长距离冲刺，并轻微追踪。")
	await shot("shell_charge")
	for amount in [2,3]:
		for room in game.run.floor_data.rooms:
			if room.cells.size()==amount:
				game.run.room=room.id
				ui.battle.enter_room()
				await shot("combat_large_%d" % amount)
				ui.battle.player=ui.battle.geometry.closest_free(ui.battle.geometry.bounds.end-Vector2(70,70),14)
				ui.battle.queue_redraw()
				await shot("combat_large_%d_far" % amount)
				break
	for room in game.run.floor_data.rooms:room.visited=true
	gestures.key(KEY_TAB,true)
	ui.minimap.advance_hold(2)
	await shot("combat_floor_overview")
	gestures.key(KEY_TAB,false)
	game.run.room=game.run.floor_data.reward
	ui.battle.enter_room(Vector2(450,280))
	gestures.tap(KEY_F)
	await shot("reward_chest")
	ui.modal.get_node("Frame/Scroll/Content").get_child(1).choose(0)
	game.run.room=game.run.floor_data.boss
	game.run.floor_data.rooms[game.run.room].cleared=true
	ui.battle.enter_room(ui.battle.exit_entities.descent.position+Vector2(0,48))
	ui.battle.sync_exit_entities()
	await shot("boss_exit")
	ui.battle.player=ui.battle.exit_entities.return.position+Vector2(0,48)
	ui.battle.sync_exit_entities()
	ui.battle.queue_redraw()
	await shot("boss_return")
	gestures.tap(KEY_F)
	await shot("base_undress")
	ui.clear_page("art_gallery")
	var gallery=GridContainer.new()
	gallery.columns=4
	gallery.add_theme_constant_override("h_separation",35)
	gallery.add_theme_constant_override("v_separation",25)
	ui.body.add_child(gallery)
	var material_data=load("res://scripts/regional_data.gd")
	var catalog=load("res://scripts/catalog.gd")
	for id in material_data.MATERIALS:
		var entry=catalog.item(id)
		var tile=VBoxContainer.new()
		tile.custom_minimum_size.x=280
		gallery.add_child(tile)
		var icon=TextureRect.new()
		icon.texture=load(entry.icon)
		icon.custom_minimum_size=Vector2(144,144)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.add_child(icon)
		tile.add_child(ui.label(entry.name,20))
		tile.add_child(ui.wrapped(entry.desc,15))
	await shot("regional_materials")
	print("Captured native Godot screens and material gallery")
	quit()
