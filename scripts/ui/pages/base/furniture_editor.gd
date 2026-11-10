extends VBoxContainer
const C=preload("res://scripts/catalog.gd")
var app: Control
var furniture_buttons: Array[Button]=[]
var stock_labels: Array[Label]=[]
func build(context: Control) -> void:
	app=context
	var world=$Stage/World
	world.placing=true
	world.notice.connect(app.say)
	world.interaction_allowed=func():return not is_instance_valid(app.modal)
	world.furniture_changed.connect(refresh_furniture_options)
	app.gameplay_stage(world)
	var actions=$Dock/Actions
	var group=ButtonGroup.new()
	for type in range(4):
		var card=VBoxContainer.new()
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		actions.add_child(card)
		var selected_type=type
		var control=app.button(C.FURNITURE_NAMES[type],func():world.furniture_type=selected_type,card)
		control.icon=load(C.item("furn_%d" % type).icon)
		control.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
		control.expand_icon=true
		control.add_theme_constant_override("icon_max_width",40)
		control.custom_minimum_size=Vector2(170,52)
		control.toggle_mode=true
		control.button_group=group
		control.button_pressed=type==0
		furniture_buttons.append(control)
		var stock=app.label("",13,Color("8faeaf"))
		stock.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(stock)
		stock_labels.append(stock)
	actions.add_child(VSeparator.new())
	app.button("合成",app.show_crafting,actions).custom_minimum_size=Vector2(110,52)
	app.button("完成",app.show_base,actions).custom_minimum_size=Vector2(110,52)
	refresh_furniture_options()
func refresh_furniture_options() -> void:
	var world=$Stage/World
	if Game.state.stash.count("furn_%d" % world.furniture_type)==0:
		for type in range(furniture_buttons.size()):
			if Game.state.stash.has("furn_%d" % type):
				world.furniture_type=type
				break
	for type in range(furniture_buttons.size()):
		var count=Game.state.stash.count("furn_%d" % type)
		stock_labels[type].text="库存 %d" % count
		furniture_buttons[type].disabled=count==0
		furniture_buttons[type].set_pressed_no_signal(count>0 and world.furniture_type==type)
