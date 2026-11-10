extends VBoxContainer
var app: Control
func build(context: Control) -> void:
	app=context
	var world=$Stage/World
	world.notice.connect(app.say)
	world.facility_requested.connect(app.show_base_dialogue)
	world.interaction_allowed=func():return not is_instance_valid(app.modal)
	app.gameplay_stage(world)
	var actions=$Dock/Actions
	for action in [["装修",func():app.show_base(true)],["地图",app.show_map],["探索",app.show_preparation],["开店",app.show_shop],["下一天",func():app.say(Game.next_day());app.show_base()]]:
		var control=app.button(action[0],action[1],actions)
		control.custom_minimum_size=Vector2(122,56)
		control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions.add_child(VSeparator.new())
	for action in [["仓库",app.show_stash],["设置",app.show_settings],["主界面",app.show_menu]]:
		app.button(action[0],action[1],actions)
