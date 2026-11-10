extends HBoxContainer
const Art=preload("res://scripts/art_library.gd")
var app: Control
func build(context: Control) -> void:
	app=context
	var hero=$Hero
	hero.custom_minimum_size.x=790
	hero.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hero.alignment=BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation",22)
	hero.add_child(app.label("THE LAST LINE HOME",18,Color("82b2b6")))
	hero.add_child(app.label("最后一班，\n开往明天。",68,Color("e4e2ca")))
	hero.add_child(app.wrapped("地表沉默之后，城市在轨道下重生。\n作为一名回收员，探索、交易，守住属于你的那节车厢。",21))
	var art=TextureRect.new()
	art.texture=Art.texture("station")
	art.custom_minimum_size=Vector2(180,180)
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.add_child(art)
	var menu=$Actions
	menu.custom_minimum_size.x=350
	menu.alignment=BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation",18)
	app.section(menu,"回到轨道之下","原型版本 0.1  /  GODOT 4.6")
	app.button("开始游戏   →",app.show_slots,menu)
	app.button("设置",app.show_settings,menu)
	app.button("退出",func():get_tree().quit(),menu)
	menu.add_child(app.wrapped("原创程序美术\n回收探索 × 车厢家园 × 地下贸易",15))
