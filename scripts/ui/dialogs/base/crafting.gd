extends VBoxContainer
const C=preload("res://scripts/catalog.gd")
var app: Control
func build(context: Control) -> void:
	app=context
	add_child(app.wrapped("将仓库材料合成为一件真实家具，再到布置模式放置。回收家具会把同一件物品收回仓库。",16))
	for type in range(4):
		var row=HBoxContainer.new()
		row.add_theme_constant_override("separation",20)
		add_child(row)
		var icon=TextureRect.new()
		icon.texture=load(C.item("furn_%d" % type).icon)
		icon.custom_minimum_size=Vector2(72,72)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var description=VBoxContainer.new()
		description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(description)
		app.section(description,C.FURNITURE_NAMES[type],"仓库已有 %d 件" % Game.state.stash.count("furn_%d" % type))
		var ingredients: Array=[]
		var enough=true
		for id in C.FURNITURE_RECIPES[type]:
			var required=int(C.FURNITURE_RECIPES[type][id])
			ingredients.append("%s %d/%d" % [C.item(id).name,Game.state.stash.count(id),required])
			if Game.state.stash.count(id)<required:enough=false
		description.add_child(app.wrapped(" · ".join(ingredients),15))
		var selected_type=type
		app.button("合成",func():
			if Game.craft_furniture(selected_type):app.say("已合成"+C.FURNITURE_NAMES[selected_type])
			else:app.say(Game.last_error)
			app.show_crafting(),row,not enough)
		add_child(HSeparator.new())
	app.button("布置已合成家具",func():app.show_base(true);app.toggle_drawer(),self)
	app.button("返回基地",app.close_modal,self)
