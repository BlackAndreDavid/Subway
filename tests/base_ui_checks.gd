extends RefCounted
const Art=preload("res://scripts/art_library.gd")
func button_named(parent: Node,text: String) -> Button:
	for control in parent.find_children("*","Button",true,false):
		if control.text==text:return control
	return null
func click(gestures: RefCounted,control: Control,tree: SceneTree) -> void:
	var point=control.get_global_rect().get_center()
	gestures.motion(point,Vector2.ZERO)
	gestures.mouse(point,true)
	gestures.mouse(point,false)
	await tree.process_frame
	await tree.process_frame
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	var gestures=preload("res://tests/interaction_checks.gd").new()
	gestures.tree=tree
	game.new_game(0,"底栏与字幕")
	ui.show_base()
	await tree.process_frame
	await tree.process_frame
	check.call(not is_instance_valid(ui.drawer) and not is_instance_valid(ui.drawer_toggle),"base has no right drawer or toggle")
	var page=ui.current_screen
	var dock=page.get_node("Dock")
	check.call(dock.get_global_rect().position.y>=ui.stage.get_global_rect().end.y,"base navigation is below the world")
	check.call(not is_instance_valid(button_named(page,"完成")) and not is_instance_valid(button_named(page,"合成")),"base navigation does not mix in decoration sub-actions")
	for control in page.find_children("*","Button",true,false):
		check.call(not control.text.contains("/") and not control.text.contains("\n"),"navigation labels contain only the action")
	var girl=ui.stage.get_child(0).heroine
	check.call(not girl.changing_suit(),"new game starts standing without undressing")
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.DOWN,Vector2.UP]:
		girl.advance(0.2,direction)
		check.call(girl.moving,"movement enables walk animation")
		girl.advance(0.1,Vector2.ZERO)
		check.call(not girl.moving and girl.walk_time==0 and girl.current_texture()==Art.texture("base/heroine/%d" % girl.direction,girl.IDLE_FRAME),"stopping restores the current direction's collected-feet standing pose")
	var initial_world=ui.stage.get_child(0)
	initial_world.set_process(false)
	girl.grid_position=Vector2(0.25,0.25)
	gestures.key(KEY_W,true)
	initial_world._process(0.1)
	gestures.key(KEY_W,false)
	check.call(not girl.moving,"holding movement into the carriage boundary stays in the standing pose")
	await click(gestures,button_named(page,"装修"),tree)
	check.call(ui.page=="furniture" and ui.current_screen.get_script().resource_path.ends_with("furniture_editor.gd"),"real decoration click opens its independent scene controller")
	page=ui.current_screen
	for title in ["地图","探索","开店","下一天"]:check.call(button_named(page,title)==null,"decoration page does not retain base navigation")
	check.call(page.furniture_buttons.all(func(control):return control.disabled),"absent crafted furniture cannot be selected")
	await click(gestures,button_named(page,"合成"),tree)
	check.call(is_instance_valid(ui.modal) and ui.page=="furniture","crafting opens as a child window of decoration")
	await click(gestures,button_named(ui.modal,"合成"),tree)
	check.call(game.state.stash.count("scrap")==10 and game.state.stash.count("furn_0")==1 and not page.furniture_buttons[0].disabled,"real craft click consumes ingredients and enables that concrete furniture")
	gestures.tap(KEY_ESCAPE)
	await tree.process_frame
	await click(gestures,page.furniture_buttons[0],tree)
	var world=ui.stage.get_child(0)
	var point=world.global_position+world.base_to_screen(world.iso(1.5,1.5))
	gestures.mouse(point,true)
	gestures.mouse(point,false)
	check.call(game.state.furniture.size()==1 and game.state.stash.count("furn_0")==0 and page.furniture_buttons[0].disabled,"real world click places furniture and updates stock without reloading the page")
	await click(gestures,button_named(page,"完成"),tree)
	check.call(ui.page=="base" and not ui.stage.get_child(0).heroine.changing_suit(),"decoration completion restores base navigation without replaying suit removal")
	world=ui.stage.get_child(0)
	world.set_process(false)
	world.heroine.grid_position=Vector2(2.4,1.5)
	gestures.tap(KEY_F)
	await tree.process_frame
	await tree.process_frame
	check.call(is_instance_valid(ui.modal) and ui.modal.scene_file_path=="res://scenes/base/dialogue.tscn" and not ui.modal.has_node("Frame"),"F opens an overlay subtitle scene without the common centered window")
	var portrait=ui.modal.get_node("Portrait")
	var subtitle=ui.modal.get_node("Subtitle")
	check.call(portrait.get_global_rect().end.x<subtitle.get_global_rect().position.x and subtitle.position.y>ui.size.y*0.65,"portrait stands on the left and opinions float at the bottom")
	check.call(subtitle.get_node("Words/Thought").text.contains("箱子很旧"),"subtitle retains contextual facility dialogue")
	await click(gestures,button_named(ui.modal,"继续"),tree)
	check.call(not is_instance_valid(ui.modal),"subtitle Continue closes its overlay")
	ui.show_settings()
	ui.close_modal()
	ui.show_base()
	check.call(not ui.stage.get_child(0).heroine.changing_suit(),"settings and ordinary base navigation never trigger undressing")
	game.next_day()
	ui.show_base()
	check.call(not ui.stage.get_child(0).heroine.changing_suit(),"advancing a day does not trigger expedition arrival")
	game.load_game(0)
	ui.show_base()
	check.call(not ui.stage.get_child(0).heroine.changing_suit(),"ordinary save loading starts in standing clothes")
