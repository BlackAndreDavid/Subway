extends RefCounted
const C=preload("res://scripts/catalog.gd")
const I=preload("res://scripts/inventory.gd")
const Geometry=preload("res://scripts/room_geometry.gd")
const Layouts=preload("res://scripts/room_layout_data.gd")
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	var gestures=preload("res://tests/interaction_checks.gd").new()
	gestures.tree=tree
	game.new_game(0,"日耗事务")
	ui.show_preparation()
	check.call(game.state.day==1,"preparation alone does not spend a day")
	var before=game.state.duplicate(true)
	check.call(not game.begin_run(0,"3_0","","",2026) and game.state==before,"invalid departure cannot consume a day or equipment")
	game.state.water=1
	before=game.state.duplicate(true)
	check.call(not game.begin_run(0,"5_0","4_1","3_0",2026) and game.state==before,"insufficient daily supplies cancel departure atomically")
	game.state.water=24
	check.call(game.begin_run(0,"5_0","4_1","3_0",2026),"valid departure starts exploration")
	check.call(game.state.day==2 and game.state.water==22 and game.state.food==22 and game.state.power==235,"departure consumes exactly one ordinary resource day")
	check.call(game.slot_info(0).day==2 and game.slot_info(0).stash.size()==game.state.stash.size(),"departure day and selected equipment deductions are saved together")
	game.run.room=game.run.floor_data.boss
	game.run.floor_data.rooms[game.run.room].cleared=true
	check.call(game.next_floor() and game.state.day==2,"continuing the same expedition does not spend another day")
	game.end_run(false)
	ui.show_base()
	check.call(game.state.day==2,"settlement does not charge the departure day twice")
	ui.show_shop()
	check.call(ui.page=="shop" and game.state.day==3 and game.shop_open,"opening a shop starts one paid activity day")
	game.trade("0_0",true)
	ui.show_shop()
	ui.show_settings()
	ui.close_modal()
	ui.show_stash()
	ui.close_modal()
	check.call(game.state.day==3 and game.state.market_stock["0_0"]==3,"trades, rerenders and child windows do not repay the shop day or reset stock")
	ui.show_base()
	ui.show_shop()
	check.call(game.state.day==4,"a new shop session consumes its own day")
	ui.show_base()
	game.state.water=0
	before=game.state.duplicate(true)
	ui.show_shop()
	check.call(ui.page=="base" and game.state==before and not game.shop_open,"an unaffordable shop session remains at the base without mutation")
	for index in range(3):
		game.new_game(0,"扩容与独立装备")
		game.begin_run(index,"5_0","4_1","3_0",2026)
		check.call(C.CLASSES[index].capacity>=[45,36,27][index] and game.run.bag.is_empty() and I.used(game.run.bag)==0,"all classes gain at least 1.5x cargo capacity; equipped items occupy no cargo")
		check.call(game.run.equipment.values().all(func(entry):return not entry.is_empty()),"all three selected physical items are in independent equipment slots")
		game.end_run(false)
	for id in C.valid_ids():
		var category=int(C.item(id).category)
		var expected="resource" if category in [0,1,2,6] else "medicine" if category==3 else "active" if category==4 else "module" if category==5 else "goods"
		check.call(C.inventory_color(id)==C.INVENTORY_COLORS[expected],"every concrete item uses its category background")
	game.new_game(0,"实际装备拖拽")
	game.begin_run(1,"5_0","4_1","3_0",2026)
	game.pick_up("4_2")
	game.pick_up("5_1")
	game.pick_up("3_0")
	ui.show_combat()
	await tree.process_frame
	ui.battle.set_process(false)
	ui.show_bag()
	await tree.process_frame
	await tree.process_frame
	var panel=ui.storage_panel
	var grid=ui.storage_grid
	var slots=panel.get_node("RightColumn/Equipment")
	check.call(slots.get_child_count()==3 and slots.global_position.x>grid.get_global_rect().end.x,"three runtime equipment slots sit on the right of the enlarged cargo grid")
	var weapon_uid=game.run.bag[0].uid
	var old_uid=game.equipped_entry("weapon").uid
	await gestures.drag(grid.tiles[0],slots.get_child(1))
	check.call(game.equipped_entry("weapon").uid==weapon_uid and game.run.bag.any(func(entry):return entry.uid==old_uid),"real mouse drag equips the selected copy and returns the old weapon into cargo")
	check.call(I.used(game.run.bag)==12,"equipped active item leaves its six cells free while the old four-cell item returns")
	await gestures.drag_to(slots.get_child(1),grid.global_position+Vector2(5.5,2.5)*grid.cell_size)
	check.call(game.equipped_entry("weapon").is_empty() and game.run.bag.any(func(entry):return entry.uid==weapon_uid and entry.x==5 and entry.y==2),"real drag from the right slot places the equipment at the requested cargo cells")
	var module_index=-1
	var medicine_index=-1
	for index in range(game.run.bag.size()):
		if game.run.bag[index].id=="5_1":module_index=index
		if game.run.bag[index].id=="3_0":medicine_index=index
	var previous_module=game.equipped_entry("module").uid
	await gestures.drag(grid.tiles[medicine_index],slots.get_child(0))
	check.call(game.equipped_entry("module").uid==previous_module,"wrong-category drag does not replace an equipped module")
	await gestures.drag(grid.tiles[module_index],slots.get_child(0))
	check.call(game.run.module=="5_1" and game.bag_dimensions()==Vector2i(8,6) and grid.dimensions==Vector2i(8,6),"dragging a back frame grows the actual grid and returns the previous module")
	ui.close_modal()
	var original_medicine=game.equipped_entry("drug").uid
	game.pick_up("3_0",1)
	game.equip_entry(game.run.bag.size()-1)
	ui.battle.use_drug()
	check.call(game.run.drug=="" and game.run.bag.any(func(entry):return entry.uid==original_medicine and entry.uses==3),"consuming the equipped duplicate preserves the returned medicine copy and its uses")
	for index in range(game.run.bag.size()):
		if game.run.bag[index].id=="4_2":game.equip_entry(index);break
	var stale=game.run_drag_data(-1,"weapon")
	while game.pick_up("1_0"):pass
	before=game.run.duplicate(true)
	check.call(not game.unequip_slot("weapon") and game.run==before,"full cargo rejects unequip without deleting or duplicating equipment")
	check.call(not game.valid_run_payload(stale),"inventory changes invalidate stale equipment drags")
	check.call(not game.unequip_slot("module") and game.run.module=="5_1","occupied extension cells prevent removing the back frame")
	game.run.fighting=true
	check.call(game.run_drag_data(0).is_empty() and not game.unequip_slot("weapon") and not game.equip_entry(0),"combat locks both cargo and equipment mutations")
	game.run.fighting=false
	game.end_run(false)
	var geometry=Geometry.new()
	check.call(Layouts.LAYOUTS.size()==10,"ten authored layouts are loaded from the compiled library")
	for layout_id in range(10):
		geometry.configure({"pos":Vector2i.ZERO,"cells":[Vector2i.ZERO],"layout_ids":[layout_id]})
		var navigation=geometry.navigation(14)
		var astar: AStarGrid2D=navigation.grid
		for cell in navigation.free:
			check.call(not astar.get_id_path(navigation.free[0],cell).is_empty(),"every walkable area of every stored layout is connected for the player")
		for normal in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var entrance=geometry.door_position({"cell":Vector2i.ZERO,"normal":normal})-Vector2(normal)*42
			check.call(geometry.can_stand(entrance,14),"each authored layout keeps all four door approaches open")
	var folded=preload("res://scripts/floor_generator.gd").generate(2026)
	geometry.configure(folded.rooms[1])
	var arbitrary_start=Vector2(198.6949,286.9576)
	var arbitrary_goal=Vector2(394.5716,208.7921)
	for tick in range(600):
		var motion=geometry.next_waypoint(arbitrary_start,arbitrary_goal,14)-arbitrary_start
		var keys=Vector2(signf(motion.x) if absf(motion.x)>2 else 0,signf(motion.y) if absf(motion.y)>2 else 0)
		arbitrary_start=geometry.move_actor(arbitrary_start,keys.normalized()*9.5,14)
		if arbitrary_start.distance_to(arbitrary_goal)<18:break
	check.call(arbitrary_start.distance_to(arbitrary_goal)<18,"off-grid positions join navigation corridors without getting stuck on cover corners")
	geometry.configure({"pos":Vector2i.ZERO,"cells":[Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN],"layout_ids":[0,3,7]})
	check.call(not geometry.can_stand(Geometry.PAD+Geometry.UNIT*1.5,14),"missing quarter of an L-shaped three-cell room is a wall, not invisible floor")
	var navigation=geometry.navigation(14)
	for cell in navigation.free:check.call(not navigation.grid.get_id_path(navigation.free[0],cell).is_empty(),"all three cells form one connected arena")
	game.new_game(0,"障碍物理")
	game.begin_run(0,"","4_0","",2026)
	ui.show_combat()
	await tree.process_frame
	var battle=ui.battle
	battle.set_process(false)
	battle.room().layout_ids=[0]
	battle.enter_room()
	var block: Rect2=battle.geometry.obstacles[0]
	var start=Vector2(block.position.x-40,block.get_center().y)
	var finish=Vector2(block.end.x+60,block.get_center().y)
	battle.player=start
	gestures.key(KEY_D,true)
	for tick in range(20):battle._process(0.05)
	gestures.key(KEY_D,false)
	check.call(battle.player.x<block.position.x-14 and battle.geometry.can_stand(battle.player,14),"actual WASD movement collides with obstacle blocks")
	var graze_start=block.position+Vector2(-9,6)
	var graze_end=block.position+Vector2(62,-65)
	check.call(not battle.geometry.segment_clear(graze_start,graze_end,3),"analytic swept collision catches a thin corner graze between sample points")
	battle.bullets=[]
	battle.shoot(start,Vector2.RIGHT,false,20,900)
	battle.update_bullets(0.3)
	check.call(battle.bullets.is_empty(),"continuous projectile collision prevents shots tunneling through cover")
	var rat=battle.make_enemy(0,start)
	battle.enemies=[rat]
	battle.player=finish
	for tick in range(100):battle.update_enemies(0.05)
	check.call(rat.pos.distance_to(finish)<45 and battle.geometry.can_stand(rat.pos,battle.enemy_radius(rat)),"chasing enemies navigate around cover instead of remaining trapped")
	var beast=battle.make_enemy(3,start)
	beast.state="charge"
	beast.timer=1.8
	beast.charge_dir=Vector2.RIGHT
	battle.enemies=[beast]
	battle.update_enemies(0.3)
	check.call(beast.state=="recovery" and beast.pos.x<block.position.x,"shell charge stops against obstacle cover")
	battle.enemies=[]
	game.run.fighting=false
	battle.room().loot=["scrap","3_0","0_0","power"]
	battle.room().ground=[]
	battle.ensure_ground_loot(block.get_center())
	check.call(battle.room().ground.all(func(entry):return battle.geometry.can_stand(entry.pos,22)),"loot spawned near cover is placed on accessible floor")
	game.end_run(false)
	ui.show_base()
	await tree.process_frame
