extends HBoxContainer
var app: Control
func build(context: Control) -> void:
	app=context
	var left=app.panel(self,570)
	app.section(left,"回收员档案","三份独立存档 · 创建基地后自动保存")
	for i in range(3):
		var data=Game.slot_info(i)
		var title="%02d   空白档案" % (i+1)
		if not data.is_empty(): title="%02d   %s  ·  第 %d 天" % [i+1,str(data.get("name","损坏档案")),int(data.get("day",0))]
		var idx=i
		app.button(title,func():app.selected_slot=idx; app.show_slot_actions(),left)
	app.back_button(app.show_menu,left)
	app.side=app.panel(self,650)
	app.show_slot_actions()
func show_slot_actions() -> void:
	app.empty(app.side)
	var data=Game.slot_info(app.selected_slot)
	app.section(app.side,"档案 %02d" % (app.selected_slot+1))
	if data.is_empty():
		app.side.add_child(app.wrapped("为你的车厢基地命名。留空则使用「上海堡垒」。"))
		app.base_name=LineEdit.new()
		app.base_name.placeholder_text="上海堡垒"
		app.base_name.max_length=24
		app.side.add_child(app.base_name)
		app.button("创建并进入基地",func():
			if Game.new_game(app.selected_slot,app.base_name.text):app.show_base()
			else:app.say(Game.last_error),app.side)
	else:
		app.side.add_child(app.wrapped("基地：%s\n日期：第 %s 天\n电量：%s\n水 / 食物：%s / %s" % [data.get("name","?"),data.get("day","?"),data.get("power","?"),data.get("water","?"),data.get("food","?")]))
		app.button("读取存档",func():
			if Game.load_game(app.selected_slot):app.show_base()
			else:app.say(Game.last_error),app.side)
		app.button("重建此档案…",func():app.confirm_replace(),app.side)
