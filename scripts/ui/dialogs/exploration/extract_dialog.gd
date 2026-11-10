extends VBoxContainer
var app: Control
func build(context: Control) -> void:
	app=context
	var v=self
	v.add_child(app.wrapped("将随身物资带回基地并保存，结束本次探索。返程不额外消耗电量。"))
	app.button("确认返程",func():
		app.say(Game.end_run(true))
		app.show_base(),v)
	app.button("继续探索",app.close_modal,v)
