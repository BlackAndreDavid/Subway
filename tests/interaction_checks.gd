extends RefCounted
const Loadout=preload("res://scripts/loadout_model.gd")
const Fog=preload("res://scripts/fog_of_war.gd")
var tree: SceneTree
func key(code: int,pressed: bool,echo: bool=false) -> void:
	var event=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	event.echo=echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func tap(code: int) -> void:
	key(code,true)
	key(code,false)
func mouse(point: Vector2,pressed: bool) -> void:
	var event=InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func motion(point: Vector2,relative: Vector2) -> void:
	var event=InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	event.relative=relative
	event.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func drag(source: Control,target: Control) -> void:
	await drag_to(source,target.get_global_rect().get_center())
func drag_to(source: Control,finish: Vector2) -> void:
	var start=source.get_global_rect().get_center()
	motion(start,Vector2.ZERO)
	mouse(start,true)
	motion(start+Vector2(22,0),Vector2(22,0))
	await tree.process_frame
	motion(finish,finish-start)
	await tree.process_frame
	mouse(finish,false)
	await tree.process_frame
	await tree.process_frame
func run(scene_tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	tree=scene_tree
	# Model validation: ownership, typed slots, stale/foreign payloads, return and replacement.
	var empty=Loadout.new([])
	check.call(empty.drag_data(0).is_empty(),"empty warehouse cannot invent equipment")
	var model=Loadout.new(["5_0","5_0","4_1","3_0","0_0"])
	var data=model.drag_data(0)
	check.call(not model.assign("drug",data),"module cannot enter medicine slot")
	check.call(model.assign("module",data),"owned module enters correct slot")
	check.call(not model.assign("module",data),"stale drag rejected")
	check.call(model.drag_data(0).is_empty(),"reserved warehouse copy cannot be equipped twice")
	check.call(model.assign("module",model.drag_data(1)) and model.item_index("module")==1,"duplicate item copies have distinct warehouse indices")
	check.call(not model.drag_data(0).is_empty(),"replaced module is available in warehouse")
	check.call(model.return_to_warehouse(model.drag_data(1,"module")) and model.selected_id("module")=="","equipped item returns to warehouse")
	data=model.drag_data(2)
	data.index=999
	check.call(not model.assign("weapon",data),"forged out-of-range drag rejected")
	data=model.drag_data(2)
	data.model=empty.get_instance_id()
	check.call(not model.assign("weapon",data),"foreign warehouse drag rejected")
	check.call(not model.assign("weapon",model.drag_data(4)),"water can be moved but cannot enter an equipment slot")
	game.new_game(0,"交互修正测试")
	var stock=game.state.stash.duplicate()
	check.call(not game.begin_run(0,"3_0","","",2026),"departure rejects wrong category")
	check.call(not game.begin_run(99,"","","",2026),"departure rejects invalid class")
	check.call(game.state.stash==stock,"rejected typed/class selections do not consume inventory")
	game.state.stash=[]
	check.call(not game.begin_run(0,"5_0","","",2026) and game.run.is_empty(),"departure independently rejects absent equipment")
	game.state.stash=stock.duplicate()
	check.call(game.state.stash==stock,"rejected departure preserves warehouse")
	# Real viewport mouse gestures exercise Godot's drag/drop routing and previews.
	ui.show_preparation()
	await tree.process_frame
	await tree.process_frame
	check.call(ui.loadout.selected_id("module")=="" and ui.loadout.selected_id("drug")=="","preparation begins with empty slots")
	await drag(ui.warehouse_grid.get_child(8),ui.loadout_slots.get_child(2))
	check.call(ui.loadout.selected_id("drug")=="","real drag rejects wrong category")
	await drag(ui.warehouse_grid.get_child(8),ui.loadout_slots.get_child(0))
	check.call(ui.loadout.selected_id("module")=="5_0","real warehouse mouse drag equips module")
	await drag(ui.warehouse_grid.get_child(5),ui.loadout_slots.get_child(1))
	await drag(ui.warehouse_grid.get_child(0),ui.loadout_slots.get_child(2))
	check.call(ui.loadout.selected_id("weapon")=="4_1" and ui.loadout.selected_id("drug")=="3_0","real mouse drag equips weapon and medicine")
	check.call(game.state.stash==stock,"preparation drag does not consume stock")
	await drag_to(ui.loadout_slots.get_child(0),ui.warehouse_grid.tiles[8].global_position+Vector2(16,16))
	check.call(ui.loadout.selected_id("module")=="","real mouse drag returns module to warehouse")
	await drag(ui.warehouse_grid.get_child(8),ui.loadout_slots.get_child(0))
	ui.start_run()
	await tree.process_frame
	var battle=ui.battle
	battle.set_process(false)
	check.call(game.run.module=="5_0" and game.state.stash.size()==stock.size()-3,"departure consumes only the three selected actual copies")
	# Full-width stage and a true overlay drawer: opening it never resizes the game.
	check.call(not ui.drawer.visible,"data drawer starts hidden")
	var stage_size=ui.stage.size
	var battle_size=battle.size
	check.call(is_equal_approx(stage_size.x,ui.body.size.x),"game stage uses full body width")
	ui.drawer_toggle.pressed.emit()
	await tree.process_frame
	check.call(ui.drawer.visible and ui.stage.size==stage_size and battle.size==battle_size,"expand button opens overlay without shrinking gameplay")
	ui.toggle_drawer()
	check.call(ui.minimap.get_global_rect().end.x<=ui.stage.get_global_rect().end.x and ui.minimap.position.y==12,"minimap stays inside upper-right of gameplay")
	check.call(battle.world_to_screen(battle.world_mouse()).distance_to(battle.get_local_mouse_position())<0.01,"resized gameplay mouse coordinates round trip")
	# F interaction is constrained by position, combat lock, delay and key echo.
	var target=int(battle.room().links[0])
	var initial_room=int(game.run.room)
	var power=int(game.state.power)
	var energy=int(game.run.energy)
	battle.door_delay=0
	check.call(not battle.goto_room(target),"remote transition API is rejected")
	tap(KEY_F)
	check.call(int(game.run.room)==initial_room,"remote F cannot enter a door")
	battle.player=battle.door_position(target).clamp(battle.AREA.position+Vector2(14,14),battle.AREA.end-Vector2(14,14))
	battle._process(0.1)
	check.call(int(game.run.room)==initial_room,"standing at open doorway never changes rooms automatically")
	game.run.fighting=true
	tap(KEY_F)
	check.call(int(game.run.room)==initial_room,"door F is locked during combat")
	game.run.fighting=false
	key(KEY_F,true,true)
	key(KEY_F,false)
	check.call(int(game.run.room)==initial_room,"key echo cannot activate door")
	tap(KEY_F)
	check.call(int(game.run.room)==target,"F at doorway enters linked room")
	check.call(game.state.power==power-1 and game.run.energy==energy-1,"physical door transition charges exactly one energy")
	check.call(battle.player.distance_to(battle.door_position(initial_room))<64,"entry appears beside opposite door")
	check.call(not battle.goto_room(initial_room),"entry cooldown prevents immediate bounce")
	# Pure fog includes spatial neighbors but cannot leak the second ring or full bounds.
	var rooms=[{"id":0,"pos":Vector2i(0,0),"visited":true,"links":[1]},{"id":1,"pos":Vector2i(1,0),"visited":false,"links":[0,2]},{"id":2,"pos":Vector2i(2,0),"visited":false,"links":[1]},{"id":3,"pos":Vector2i(0,1),"visited":false,"links":[]},{"id":4,"pos":Vector2i(3,3),"visited":true,"links":[]}]
	var visible=Fog.visibility(rooms,0)
	check.call(visible=={0:"current",1:"frontier",4:"explored"},"fog shows only current, visited and passage-connected neighbors only")
	rooms[1].visited=true
	visible=Fog.visibility(rooms,1)
	check.call(visible[0]=="explored" and visible[1]=="current" and visible[2]=="frontier","entering a room reveals connected neighbors and updates highlight")
	var mini=ui.minimap
	mini.set_process(false)
	var before_visible=mini.visible_rooms().duplicate()
	check.call(mini.modulate.a==0.5,"minimap defaults to fifty percent opacity")
	key(KEY_TAB,true)
	mini.advance_hold(1.99)
	check.call(mini.modulate.a==0.5 and not is_instance_valid(ui.modal),"short Tab hold neither brightens map nor opens backpack")
	mini.advance_hold(0.01)
	check.call(mini.modulate.a==1.0 and mini.visible_rooms()==before_visible,"two-second Tab hold brightens only already visible map")
	key(KEY_TAB,false)
	check.call(mini.modulate.a==0.5 and mini.hold_elapsed==0,"Tab release immediately restores opacity")
	key(KEY_TAB,true)
	mini.advance_hold(2)
	mini._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check.call(mini.modulate.a==0.5 and not mini.tab_held,"focus loss clears held map")
	key(KEY_TAB,false)
	battle.enemies=[]
	battle.bullets=[]
	game.run.fighting=false
	tap(KEY_B)
	check.call(is_instance_valid(ui.modal) and battle.paused,"B opens non-combat inventory")
	key(KEY_TAB,true)
	mini.advance_hold(3)
	check.call(mini.modulate.a==0.5,"paused map cannot retain bright hold")
	key(KEY_TAB,false)
	tap(KEY_B)
	check.call(not is_instance_valid(ui.modal) and not battle.paused,"B closes backpack and resumes")
	# Physical loot: range, typed icons, magnet motion, slot limits and chest spill.
	battle.room().cleared=true
	battle.room().loot=["power","credits","0_0","chest"]
	battle.room().ground=[]
	battle.ensure_ground_loot()
	check.call(battle.loot_texture("power")==battle.Art.texture("items/1_1") and battle.loot_texture("0_0")==battle.Art.texture("items/0_0"),"ground electricity is battery and water is bottle")
	check.call(battle.loot_texture("chest")==battle.Art.texture("chest"),"ground chest uses chest artwork")
	battle.player=Vector2(790,480)
	var loot_before=battle.room().loot.duplicate(true)
	check.call(not battle.collect(2) and battle.room().loot==loot_before,"remote pickup rejected without removing loot")
	while game.pick_up("1_0"):pass
	var count=game.run.bag.size()
	var old_power=float(game.state.power)
	var old_energy=float(game.run.energy)
	battle.player=battle.room().ground[0].pos+Vector2(100,0)
	var old_pos: Vector2=battle.room().ground[0].pos
	battle.update_ground_loot(0.1)
	check.call(battle.room().ground[0].pos.distance_to(battle.player)<old_pos.distance_to(battle.player),"nearby battery visibly moves toward character")
	for i in range(20):battle.update_ground_loot(0.05)
	check.call(not battle.room().loot.has("power") and not battle.room().loot.has("credits"),"no-slot battery and currency automatically collected")
	check.call(game.state.power>old_power and game.run.energy>old_energy and game.run.bag.size()==count,"automatic pickups work with full backpack without consuming slots")
	var water_index=battle.room().loot.find("0_0")
	battle.player=battle.room().ground[water_index].pos
	tap(KEY_F)
	check.call(battle.room().loot.has("0_0") and game.run.bag.size()==count,"full bag leaves manual water pickup on ground")
	game.run.bag.pop_back()
	game.run.bag.pop_back()
	tap(KEY_F)
	check.call(not battle.room().loot.has("0_0") and game.run.bag.back().id=="0_0","F picks up nearby water into its physical backpack footprint")
	var chest_index=battle.room().loot.find("chest")
	battle.player=battle.room().ground[chest_index].pos
	battle.rng.seed=8004
	tap(KEY_F)
	check.call(not battle.room().loot.has("chest") and battle.room().ground.size()==battle.room().loot.size() and not battle.room().loot.is_empty(),"F opens chest into individually rendered floor pickups")
	for i in range(battle.room().loot.size()):
		check.call(battle.room().ground[i].pos is Vector2 and battle.loot_texture(battle.loot_id(battle.room().loot[i]))!=null,"every ground item has position and matching texture")
	var persisted=battle.room().ground.duplicate(true)
	battle.enter_room(battle.player)
	check.call(battle.room().ground==persisted,"revisiting cleared room preserves uncollected floor positions")
	game.end_run(false)
	ui.show_base()
	await tree.process_frame
	check.call(not is_instance_valid(ui.drawer) and not is_instance_valid(ui.drawer_toggle),"base removes the details drawer and its toggle")
