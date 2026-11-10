extends RefCounted
const C=preload("res://scripts/catalog.gd")
const I=preload("res://scripts/inventory.gd")
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	# Every runtime item has a concrete, connected footprint and four lossless rotations.
	for id in C.valid_ids():
		var cells=C.cells(id)
		check.call(not cells.is_empty(),"footprint exists: "+id)
		for rotation in range(4):
			var turned=C.cells(id,rotation)
			var bounds=C.bounds(id,rotation)
			check.call(turned.size()==cells.size() and turned.all(func(cell):return cell.x>=0 and cell.y>=0 and cell.x<bounds.x and cell.y<bounds.y),"rotation preserves valid occupied cells: "+id)
		if C.item(id).category==4:
			check.call(C.bounds(id).x>=2 and C.bounds(id).y>=2 and cells.size()>=4,"active item at least 2x2: "+id)
	var l=[{"id":"2_2","x":0,"y":0,"rot":0}]
	check.call(I.fits(l,Vector2i(2,2),"1_0",Vector2i(1,1)),"L-shaped empty corner can hold a different item")
	check.call(not I.fits(l,Vector2i(2,2),"1_0",Vector2i(0,1)),"occupied part of irregular shape rejects overlap")
	check.call(not I.fits([],Vector2i(2,2),"3_0",Vector2i(1,1)),"tall item rejects boundary overflow")
	check.call(I.fits([],Vector2i(2,2),"3_0",Vector2i(0,1),1),"rotation allows a long item into horizontal space")
	var fragmented: Array=[]
	for y in range(4):
		for x in range(4):
			if (x+y)%2==0:fragmented.append({"id":"1_0","x":x,"y":y,"rot":0})
	check.call(I.used(fragmented)==8 and I.first_fit(fragmented,Vector2i(4,4),"4_0").is_empty(),"eight free cells cannot replace a contiguous 2x2 placement")
	# A v1 string inventory migrates without losing duplicates or requiring spare capacity.
	game.new_game(2,"旧档迁移")
	var legacy=game.state.duplicate(true)
	legacy.version=1
	legacy.erase("stash_layout")
	legacy.erase("stash_rows")
	legacy.stash=[]
	for n in range(70):legacy.stash.append("4_1" if n%2==0 else "0_0")
	check.call(game.validate_save(legacy),"legacy save remains accepted")
	game.write_json("user://slot_2.json",legacy)
	check.call(game.load_game(2) and game.state.stash==legacy.stash and game.state.stash_rows>10,"legacy inventory auto-arranges all actual copies and expands warehouse")
	check.call(I.valid(game.stash_entries(),Vector2i(game.STASH_COLUMNS,game.state.stash_rows)),"migrated warehouse has no overlap or overflow")
	var stash_entries=game.stash_entries()
	var destination=Vector2i(10,int(game.state.stash_rows)-2)
	if not I.fits(stash_entries,Vector2i(12,game.state.stash_rows),stash_entries[0].id,destination,0,0):
		game.state.stash_rows+=2
		destination=Vector2i(10,int(game.state.stash_rows)-2)
	check.call(game.move_stash(0,destination,0),"warehouse copy can be moved to a specific empty position")
	var layout=game.state.stash_layout.duplicate(true)
	check.call(game.load_game(2) and int(game.state.version)==2 and game.state.stash_layout==layout,"warehouse coordinates survive version 2 save and reload")
	var bad=game.state.duplicate(true)
	bad.stash_layout[1]=bad.stash_layout[0].duplicate()
	check.call(not game.validate_save(bad),"overlapping saved inventory is rejected")
	bad=game.state.duplicate(true)
	bad.stash_layout[0].x=0.5
	check.call(not game.validate_save(bad),"fractional saved grid coordinates rejected")
	game.remove_stash(1)
	check.call(game.state.stash_layout[0]==layout[0] and game.state.stash_layout[1]==layout[2],"removing one duplicate preserves all other placements")
	game.new_game(0,"实际副本")
	game.add_stash("5_0")
	var first_armor=game.state.stash_layout[8].duplicate()
	check.call(game.begin_run(0,"5_0","","",2026,{"module":12}),"departure accepts a selected duplicate's real index")
	check.call(game.state.stash.size()==12 and game.state.stash[8]=="5_0" and game.state.stash_layout[8]==first_armor,"departure removes the selected duplicate rather than the first matching ID")
	game.end_run(true)
	# Backpack expansion is geometric. Removing a module cannot delete occupied rows.
	game.new_game(0,"网格背包")
	check.call(game.begin_run(2,"5_1","4_1","3_0",2026),"small class can pack its starting equipment")
	check.call(game.bag_dimensions()==Vector2i(6,4) and I.valid(game.run.bag,game.bag_dimensions()),"back frame adds an actual six-cell row")
	check.call(game.pick_up("3_2"),"pickup places a small item")
	var last=game.run.bag.size()-1
	check.call(game.move_bag(last,Vector2i(5,3),0),"item can be moved into expanded row")
	var original=game.run.bag.duplicate(true)
	check.call(not game.set_module("") and game.run.stats.grid_rows==4 and game.run.bag==original,"cannot remove occupied extension row")
	check.call(game.move_bag(last,Vector2i(5,0),0) and game.set_module("") and game.run.stats.grid_rows==3,"clearing extension permits safe shrink")
	original=game.run.bag.duplicate(true)
	check.call(not game.move_bag(1,Vector2i(0,0),0) and game.run.bag==original,"invalid overlap leaves inventory unchanged")
	game.run.fighting=true
	check.call(not game.move_bag(1,Vector2i(4,1),0) and not game.pick_up("1_0"),"combat blocks all storage mutation and manual pickup")
	game.run.fighting=false
	game.end_run(true)
	# Scene files are real resources used by the router, with independent page controllers.
	var unstarted_room=load("res://scenes/exploration/room.tscn").instantiate()
	tree.root.add_child(unstarted_room)
	check.call(not unstarted_room.is_processing(),"standalone room without a run stays inactive safely")
	unstarted_room.queue_free()
	for id in ui.PAGE_SCENES:
		var path=ui.PAGE_SCENES[id]
		var page=load(path).instantiate()
		check.call(page.has_method("build") and page.scene_file_path==path and page.get_script().resource_path.begins_with("res://scripts/ui/pages/"),"page has its own scene and controller: "+id)
		page.free()
	ui.show_base(true)
	await tree.process_frame
	check.call(ui.current_screen.scene_file_path=="res://scenes/base/furniture_editor.tscn" and ui.current_screen.get_parent()==ui.body,"furniture editor uses its own mounted scene")
	ui.show_stash()
	await tree.process_frame
	check.call(ui.modal.scene_file_path=="res://scenes/common/modal.tscn" and ui.storage_panel.scene_file_path=="res://scenes/inventory/storage_panel.tscn","storage composes modal shell, dialog and grid panel scenes")
	# Actual mouse placement and R rotation on the spatial warehouse.
	var gestures=preload("res://tests/interaction_checks.gd").new()
	gestures.tree=tree
	var grid=ui.storage_grid
	check.call(grid.tiles.values().all(func(tile):return tile.icon is Texture2D),"grid tiles retain texture references for rendering")
	var initial=game.state.stash_layout[0].duplicate()
	var finish=grid.global_position+Vector2(8.5,5.5)*grid.cell_size
	await gestures.drag_to(grid.tiles[0],finish)
	check.call(game.state.stash_layout[0]!=initial and game.state.stash_layout[0].x==8,"real drag moves a warehouse footprint to a grid coordinate")
	var source: Control=grid.tiles[0]
	var point=source.global_position+Vector2(12,12)
	gestures.motion(point,Vector2.ZERO)
	gestures.mouse(point,true)
	gestures.motion(point+Vector2(22,0),Vector2(22,0))
	await tree.process_frame
	gestures.tap(KEY_R)
	var drag_data=tree.root.gui_get_drag_data()
	check.call(drag_data is Dictionary and int(drag_data.rotation)==1,"R rotates the active real mouse drag")
	finish=grid.global_position+Vector2(5.5,5.5)*grid.cell_size
	gestures.motion(finish,finish-point)
	await tree.process_frame
	gestures.mouse(finish,false)
	await tree.process_frame
	await tree.process_frame
	check.call(game.state.stash_layout[0].rot==1,"rotated drag commits its orientation")
	ui.close_modal()
	game.new_game(0,"HUD与朝向")
	game.begin_run(1,"5_0","4_1","3_0",2026)
	ui.show_combat()
	await tree.process_frame
	var battle=ui.battle
	battle.set_process(false)
	ui.drawer_toggle.grab_focus()
	gestures.tap(KEY_E)
	check.call(game.run.weapon_cd==0,"E no longer activates the active item")
	gestures.tap(KEY_SPACE)
	check.call(game.run.weapon_cd==7.0 and not ui.drawer.visible and ui.combat_hud.charge_ratio()==0,"Space activates once even when a UI button has keyboard focus")
	gestures.key(KEY_SPACE,true,true)
	gestures.key(KEY_SPACE,false)
	check.call(game.run.weapon_cd==7.0,"Space key echo does not retrigger an item")
	battle._process(1.0)
	check.call(ui.combat_hud.charge_ratio()>0 and ui.combat_hud.charge_ratio()<1,"charge progress follows actual cooldown")
	ui.combat_hud._process(0)
	check.call(ui.combat_hud.weapon_rect.position==Vector2(12,12) and ui.combat_hud.medicine_rect.end==ui.stage.size-Vector2(12,12),"HUD anchors active item upper left and medicine lower right")
	game.run.hp=50
	gestures.tap(KEY_Q)
	check.call(ui.combat_hud.drug_uses()==2 and game.run.hp==85,"medicine HUD tracks Q consumption")
	ui.show_bag()
	var cd=game.run.weapon_cd
	gestures.tap(KEY_SPACE)
	check.call(game.run.weapon_cd==cd,"paused storage cannot use active item")
	ui.close_modal()
	check.call(game.pick_up("3_0",1),"a second medicine copy can be carried")
	last=game.run.bag.size()-1
	game.equip_entry(last)
	gestures.tap(KEY_Q)
	check.call(game.run.drug=="" and game.run.bag[2].uses==2,"using selected duplicate consumes that exact copy")
	# Facing follows actual motion, including retreat, locked charges, walls and idle.
	for type in [0,3]:
		var enemy=battle.make_enemy(type,Vector2(400,300))
		battle.update_enemy_facing(enemy,Vector2.RIGHT*20,0.1)
		check.call(battle.enemy_flipped(enemy) and is_zero_approx(battle.enemy_rotation(enemy)),"rightward quadruped mirrors without turning upside-down")
		battle.update_enemy_facing(enemy,Vector2.LEFT*20,0.1)
		check.call(not battle.enemy_flipped(enemy) and is_zero_approx(battle.enemy_rotation(enemy)),"leftward quadruped follows source heading")
		battle.update_enemy_facing(enemy,Vector2.UP*20,0.1)
		check.call(is_equal_approx(absf(battle.enemy_rotation(enemy)),PI/2),"vertical quadruped heading follows movement")
		var facing=enemy.facing
		battle.update_enemy_facing(enemy,Vector2.ZERO,0.1)
		check.call(enemy.facing==facing and enemy.walk_time==0,"idle or wall collision stops walking animation")
	var bandit=battle.make_enemy(1,Vector2(400,300))
	battle.player=Vector2(450,300)
	battle.enemies=[bandit]
	battle.update_enemies(0.1)
	check.call(bandit.pos.x<400 and battle.enemy_flipped(bandit),"retreating bandit faces actual leftward displacement")
	var charger=battle.make_enemy(3,Vector2(400,300))
	charger.timer=1.7
	charger.velocity=Vector2.LEFT*320
	battle.enemies=[charger]
	battle.update_enemies(0.05)
	check.call(charger.travel.x<0 and charger.facing.x<0,"charger faces its locked charge rather than current player position")
	battle.enemies=[]
	game.run.fighting=false
	game.end_run(true)
	ui.show_base()
	await tree.process_frame
