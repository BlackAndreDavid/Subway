extends VBoxContainer
var app: Control
func build(context: Control) -> void:
	app=context
	var v=self
	v.add_child(app.wrapped("这会覆盖档案 %d 的所有进度。" % (app.selected_slot+1)))
	var name_input=LineEdit.new()
	name_input.placeholder_text="新基地名称 / 上海堡垒"
	name_input.max_length=24
	v.add_child(name_input)
	app.button("确认覆盖并创建",func():
		if Game.new_game(app.selected_slot,name_input.text):app.show_base()
		else:app.say(Game.last_error),v)
	app.button("取消",app.close_modal,v)
