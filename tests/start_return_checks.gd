extends RefCounted
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	var gestures=preload("res://tests/interaction_checks.gd").new()
	gestures.tree=tree
	game.new_game(0,"起点安全返程")
	var initial=game.state.stash.duplicate()
	game.begin_run(1,"5_0","4_1","3_0",2026)
	ui.show_combat()
	await tree.process_frame
	var battle=ui.battle
	battle.set_process(false)
	check.call(battle.room().kind=="start" and game.can_return_to_base() and not game.can_extract(),"starting room permits return without granting boss completion")
	check.call(battle.exit_entities.return.visible and not battle.exit_entities.descent.visible,"start shows a return terminal without next-floor stairs")
	check.call(battle.geometry.can_stand(battle.exit_entities.return.position,28),"starting terminal is placed on walkable floor")
	check.call(not game.next_floor() and game.run.floor==1,"starting return permission cannot bypass boss progression")
	ui.return_to_base()
	check.call(not game.run.is_empty(),"return callback still requires physical terminal proximity")
	battle.player=battle.exit_entities.return.position
	battle.paused=true
	gestures.tap(KEY_F)
	check.call(not game.run.is_empty(),"paused starting-room interaction cannot return")
	battle.paused=false
	game.run.fighting=true
	gestures.tap(KEY_F)
	check.call(not game.run.is_empty() and not game.can_return_to_base(),"combat locks the starting-room exit")
	game.run.fighting=false
	gestures.key(KEY_F,true,true)
	gestures.key(KEY_F,false)
	check.call(not game.run.is_empty(),"key repeat cannot activate starting return")
	var day=game.state.day
	var power=game.state.power
	gestures.tap(KEY_F)
	check.call(game.run.is_empty() and ui.page=="base","F at the starting terminal returns to base")
	check.call(game.state.stash.size()==initial.size() and initial.all(func(id):return initial.count(id)==game.state.stash.count(id)),"immediate return restores all carried equipment without duplicates")
	check.call(game.state.day==day and game.state.power==power,"return neither refunds the departure day nor charges another day")
	check.call(game.validate_save(game.slot_info(0)) and game.slot_info(0).stash.size()==initial.size(),"starting-room settlement persists in a valid save")
	check.call(ui.stage.get_child(0).heroine.changing_suit(),"starting return follows the expedition arrival animation")
	# Walking back to the starting room after exploring preserves collected cargo.
	game.new_game(0,"回到入口撤离")
	game.begin_run(1,"","","",2026)
	ui.show_combat()
	await tree.process_frame
	battle=ui.battle
	battle.set_process(false)
	var neighbor=int(battle.room().links[0])
	game.move_room(neighbor)
	battle.enter_room()
	battle.enemies=[]
	game.run.fighting=false
	battle.room().cleared=true
	check.call(not game.can_return_to_base(),"ordinary cleared rooms still have no return permission")
	game.pick_up("mat_watch")
	game.move_room(0)
	battle.enter_room()
	battle.player=battle.exit_entities.return.position
	gestures.tap(KEY_F)
	check.call(game.run.is_empty() and game.state.stash.has("mat_watch"),"revisiting the initial room safely brings explored cargo home")
	await tree.process_frame
