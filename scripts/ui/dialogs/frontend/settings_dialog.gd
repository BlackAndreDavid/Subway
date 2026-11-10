extends VBoxContainer
var app: Control
func build(context: Control) -> void:
	app=context
	var v=self
	v.add_child(app.label("主音量"))
	var slider=HSlider.new()
	slider.min_value=0
	slider.max_value=1
	slider.step=0.01
	slider.value=Game.settings.volume
	slider.value_changed.connect(func(value):Game.settings.volume=value;Game.apply_settings())
	v.add_child(slider)
	var full=CheckButton.new()
	full.text="全屏显示"
	full.button_pressed=Game.settings.fullscreen
	full.toggled.connect(func(value):Game.settings.fullscreen=value;Game.apply_settings())
	v.add_child(full)
	v.add_child(app.wrapped("WASD 移动 · 方向键 / 鼠标左键射击\nF 门前互动 · 空格 主动道具 · Q 药物 · B 背包 · R 旋转物品
长按 Tab 2 秒看清地图 · Esc 暂停\n\n战斗原型支持鼠标与键盘。存档保存在 Godot user:// 目录。"))
	app.button("保存设置并返回",func():Game.save_settings();app.close_modal(),v)
