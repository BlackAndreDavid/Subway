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
	ui=load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await shot("menu")
	game.new_game(0,"上海堡垒")
	game.state.furniture=[{"x":1,"y":1,"type":0},{"x":3,"y":1,"type":1},{"x":7,"y":1,"type":2},{"x":1,"y":4,"type":3}]
	ui.show_base(true)
	await shot("base")
	ui.show_map()
	await shot("map")
	for index in range(ui.C.STATIONS.size()):
		if ui.C.STATIONS[index].name=="张江高科":
			ui.map_selection=index
			ui.map_view.center_station(index)
			ui.station_detail()
			break
	await shot("map_zhangjiang")
	ui.show_preparation()
	await shot("prepare")
	ui.show_shop()
	await shot("shop")
	game.begin_run(1,"5_0","4_1","3_0",2026)
	ui.show_combat()
	ui.battle.goto_room(1)
	await create_timer(0.5).timeout
	await shot("combat")
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
