extends VBoxContainer
var app: Control
func build(context: Control) -> void:
	app=context
	add_child(app.wrapped("站区守卫已被击败。可以继续深入，或携带本次物资安全返回基地。"))
	var choices=HBoxContainer.new()
	choices.add_theme_constant_override("separation",20)
	add_child(choices)
	app.button("进入下一层",func():
		if Game.next_floor():
			app.close_modal()
			app.battle.enter_room()
			app.refresh_combat()
		else:app.say(Game.last_error),choices)
	app.button("安全返程并保存",func():
		if not Game.can_extract():return
		var message=Game.end_run(true)
		app.show_base()
		app.say(message),choices)
	app.button("返回房间 / 继续拾取",app.close_modal,self)
