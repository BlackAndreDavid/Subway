extends VBoxContainer
var app: Control
func build(context: Control) -> void:
	app=context
	var v=self
	v.add_child(app.wrapped("计时与战斗已暂停。战斗进度暂不支持中途保存。"))
	app.button("继续探索",app.close_modal,v)
	app.button("设置",app.show_settings,v)
	app.button("放弃本次探索并返回基地",func():
		app.say(Game.end_run(false))
		app.show_base(),v)
