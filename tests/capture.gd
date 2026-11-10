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
	await shot("menu")
	game.new_game(0,"上海堡垒")
	game.state.furniture=[{"x":1,"y":1,"type":0},{"x":3,"y":1,"type":1},{"x":7,"y":1,"type":2},{"x":1,"y":4,"type":3}]
	ui.show_base(true)
	await shot("base")
	ui.toggle_drawer()
	await shot("base_details")
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
	ui.show_stash()
	await shot("warehouse_grid")
	ui.close_modal()
	ui.show_preparation()
	await shot("prepare")
	# Exercise real mouse drags for the visual review too.
	var gestures=load("res://tests/interaction_checks.gd").new()
	gestures.tree=self
	await gestures.drag(ui.warehouse_grid.get_child(8),ui.loadout_slots.get_child(0))
	await gestures.drag(ui.warehouse_grid.get_child(5),ui.loadout_slots.get_child(1))
	await gestures.drag(ui.warehouse_grid.get_child(0),ui.loadout_slots.get_child(2))
	await shot("prepare_equipped")
	ui.show_shop()
	await shot("shop")
	ui.toggle_drawer()
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
	ui.battle.queue_redraw()
	await shot("enemy_facing")
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
