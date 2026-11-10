extends RefCounted
const C=preload("res://scripts/catalog.gd")
const Art=preload("res://scripts/art_library.gd")
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	var gestures=preload("res://tests/interaction_checks.gd").new()
	gestures.tree=tree
	game.new_game(0,"基地与战斗修正")
	var before=game.state.duplicate(true)
	check.call(not game.place_furniture(0,Vector2i(1,1)) and game.state==before,"furniture cannot be placed from nothing")
	for type in range(4):check.call(game.craft_furniture(type),"craft each furniture from real ingredients")
	check.call(game.state.stash.count("scrap")==0 and game.state.stash.count("1_0")==0,"crafting consumes exact alloy and battery totals")
	before=game.state.duplicate(true)
	check.call(not game.craft_furniture(0) and game.state==before,"failed crafting cannot consume materials or create items")
	check.call(game.place_furniture(0,Vector2i(1,1)),"placing consumes a crafted warehouse item")
	check.call(not game.place_furniture(1,Vector2i(1,1)) and game.state.stash.has("furn_1"),"occupied tile leaves crafted item in warehouse")
	check.call(game.reclaim_furniture(0) and game.state.stash.count("furn_0")==1,"reclaim returns that furniture instead of duplicating materials")
	for type in range(4):check.call(game.place_furniture(type,[Vector2i(1,1),Vector2i(3,1),Vector2i(7,1),Vector2i(1,4)][type]),"place crafted furniture fixture")
	check.call(game.load_game(0) and game.state.furniture.size()==4,"crafted furniture and consumption survive reload")
	ui.show_base()
	await tree.process_frame
	await tree.process_frame
	var world=ui.stage.get_child(0)
	world.set_process(false)
	var girl=world.heroine
	check.call(world.entities.y_sort_enabled and girl.scene_file_path=="res://scenes/base/heroine.tscn","base uses an independently sorted heroine scene")
	check.call(world.base_scale()>minf(world.size.x/900.0,world.size.y/610.0) and world.base_scale()*world.BASE_BOUNDS.size.y/world.size.y>0.85,"base camera fits actual carriage bounds at a larger scale")
	check.call(not girl.changing_suit() and Art.frame_count("base/undress")==8,"loading a base does not replay expedition suit removal")
	girl.advance(2.0,Vector2.ZERO)
	check.call(girl.current_texture()==Art.texture("base/heroine/2",girl.IDLE_FRAME),"base starts in the casual standing pose")
	var start: Vector2=girl.grid_position
	gestures.key(KEY_D,true)
	world._process(0.15)
	gestures.key(KEY_D,false)
	check.call(world.iso(girl.grid_position.x,girl.grid_position.y).x>world.iso(start.x,start.y).x and girl.direction==1,"WASD moves base heroine and updates facing")
	girl.grid_position=Vector2(2.3,1.5)
	gestures.key(KEY_A,true)
	world._process(0.1)
	gestures.key(KEY_A,false)
	check.call(not world.occupied(girl.grid_position),"base heroine cannot walk inside furniture")
	girl.grid_position=Vector2(2.4,1.5)
	gestures.tap(KEY_F)
	check.call(is_instance_valid(ui.modal) and ui.dialogue_data.kind=="stash","nearby F opens the old-box interaction")
	var dialogue=ui.modal
	check.call(dialogue.scene_file_path=="res://scenes/base/dialogue.tscn" and dialogue.get_node("Portrait").texture is AtlasTexture,"facility interaction shows a real heroine portrait scene")
	check.call(dialogue.get_node("Subtitle/Words/Thought").text.contains("箱子很旧"),"facility subtitle contains the heroine's contextual opinion")
	start=girl.grid_position
	gestures.key(KEY_D,true)
	world._process(0.2)
	gestures.key(KEY_D,false)
	check.call(girl.grid_position==start,"dialogue suspends base movement")
	ui.close_modal()
	ui.show_crafting()
	check.call(ui.modal.get_node("Frame/Scroll/Content").get_child(1).scene_file_path=="res://scenes/base/crafting.tscn","crafting has its own scene")
	ui.close_modal()
	ui.show_map()
	await tree.process_frame
	check.call(ui.map_view.heroine==null,"casual heroine never appears on the main map")
	game.new_game(0,"碰撞与房间交互")
	game.begin_run(1,"5_0","4_1","3_0",2026)
	ui.show_combat()
	await tree.process_frame
	var battle=ui.battle
	battle.set_process(false)
	check.call(ui.stage.find_children("Heroine","Node2D",true,false).is_empty(),"casual heroine remains exclusive to base")
	for type in range(5):
		var enemy=battle.make_enemy(type,Vector2(430,300))
		for frame in range(4):
			for facing in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,-1).normalized()]:
				enemy.facing=facing
				check.call(battle.enemy_visual_center(enemy,frame).distance_to(enemy.pos)<0.001,"enemy visible center stays on its collider in every frame and turn")
		check.call(battle.enemy_radius(enemy)>=12,"collider size comes from visible sprite bounds")
	check.call(not game.run.has("timer"),"expedition protection timer no longer exists")
	battle.enemies=[]
	game.run.fighting=false
	var hp=game.run.hp
	battle._process(1000)
	check.call(not game.run.is_empty() and game.run.hp==hp and not battle.pending_end,"long exploration does not force timeout failure")
	var hud=ui.combat_hud
	check.call(hud.health_rect.position.x>hud.weapon_rect.end.x and hud.energy_rect.position.y>hud.health_rect.end.y,"health and electricity bars stack to the right of active item")
	before=game.run.duplicate(true)
	game.end_run(true)
	check.call(not game.run.is_empty() and game.run.bag==before.bag and not game.can_extract(),"normal rooms cannot extract through the game API")
	ui.return_to_base()
	check.call(not is_instance_valid(ui.modal) and not game.run.is_empty(),"normal rooms cannot trigger the return action")
	check.call(game.pick_up("3_2"),"antiradiation medicine can be carried")
	game.equip_entry(game.run.bag.size()-1)
	game.run.hp=50
	battle.use_drug()
	check.call(game.run.hp==70 and game.run.shield==8 and not game.run.has("timer"),"antiradiation medicine now restores health and shields without a time mechanic")
	game.run.room=game.run.floor_data.reward
	battle.enter_room(Vector2(100,100))
	gestures.tap(KEY_F)
	check.call(not is_instance_valid(ui.modal),"reward chest cannot be opened remotely")
	battle.player=Vector2(450,280)
	gestures.tap(KEY_F)
	check.call(is_instance_valid(ui.modal) and battle.paused,"F beside treasure chest opens reward selection")
	var reward=ui.modal.get_node("Frame/Scroll/Content").get_child(1)
	reward.choose(0)
	check.call(battle.room().claimed and game.run.damage==1.25 and not is_instance_valid(ui.modal),"treasure choice applies and closes correctly")
	game.claim_reward(0)
	check.call(game.run.damage==1.25,"treasure chest cannot be claimed twice")
	# A separate fresh-chest fixture checks inventory failure without deleting the reward.
	battle.room().claimed=false
	while game.pick_up("1_0"):pass
	game.claim_reward(1)
	check.call(not battle.room().claimed,"full bag keeps the active-item treasure available")
	for index in range(game.run.bag.size()-1,-1,-1):
		var entry: Dictionary=game.run.bag[index]
		if entry.id=="1_0" and int(entry.x)>=4 and int(entry.y)>=2:game.run.bag.remove_at(index)
	game.claim_reward(1)
	check.call(battle.room().claimed,"freeing a real 2x2 area permits active-item treasure")
	game.run.room=game.run.floor_data.boss
	battle.enter_room(Vector2(450,300))
	check.call(not game.can_extract() and not battle.exit_layer.visible,"live boss hides and blocks both exit entities")
	var boss: Dictionary=battle.enemies[0]
	battle.shoot(boss.pos,Vector2.RIGHT,false,10000,500)
	battle.update_bullets(0.001)
	battle._process(0.01)
	check.call(game.can_extract() and battle.room().cleared and battle.exit_layer.visible,"defeating boss unlocks the two physical exits")
	gestures.tap(KEY_F)
	check.call(game.run.floor==1 and not is_instance_valid(ui.modal),"former shared center no longer opens an exit choice")
	ui.descend_floor()
	ui.return_to_base()
	check.call(game.run.floor==1,"exit callbacks cannot bypass physical proximity")
	battle.player=battle.exit_entities.descent.position
	game.state.power=0
	gestures.tap(KEY_F)
	check.call(game.run.floor==1 and ui.page=="combat","insufficient next-floor energy leaves the player beside the stairs")
	game.state.power=500
	gestures.tap(KEY_F)
	check.call(game.run.floor==2 and game.run.room==0 and not game.run.has("timer") and not is_instance_valid(ui.modal),"descent enters the next floor without restoring a removed timer")
	check.call(not battle.exit_layer.visible,"leaving boss room hides both exits")
	game.run.room=game.run.floor_data.boss
	game.run.floor_data.rooms[game.run.room].cleared=true
	battle.enter_room(battle.exit_entities.return.position)
	battle.paused=true
	gestures.tap(KEY_F)
	check.call(not game.run.is_empty(),"paused input cannot activate the return terminal")
	battle.paused=false
	gestures.key(KEY_F,true,true)
	gestures.key(KEY_F,false)
	check.call(not game.run.is_empty(),"key echo cannot activate the return terminal")
	gestures.tap(KEY_F)
	check.call(game.run.is_empty() and ui.page=="base" and ui.stage.get_child(0).heroine.changing_suit(),"return terminal settles cargo and plays the expedition-only suit removal")
	var returned_girl=ui.stage.get_child(0).heroine
	returned_girl.advance(2,Vector2.ZERO)
	check.call(not returned_girl.changing_suit() and returned_girl.current_texture()==Art.texture("base/heroine/2",returned_girl.IDLE_FRAME),"expedition suit removal finishes in a stationary casual pose")
	ui.show_base()
	check.call(not ui.stage.get_child(0).heroine.changing_suit(),"the same expedition arrival animation cannot be replayed by rebuilding the base page")
	check.call(game.load_game(0) and not game.base_arrival,"return cargo persists without marking ordinary loading as an arrival")
	await tree.process_frame
