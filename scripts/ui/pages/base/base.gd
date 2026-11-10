extends HBoxContainer
const C=preload("res://scripts/catalog.gd")
var app: Control
@export var furniture_mode=false
func build(context: Control,placing: bool=false) -> void:
	app=context
	var world=$Stage/World
	placing=placing or furniture_mode
	world.placing=placing
	app.gameplay_stage(world)
	app.side=app.panel(app.make_drawer(),340)
	app.section(app.side,"车厢基地",C.STATIONS[int(Game.state.station)].name+"  /  自由轨道停泊中")
	app.side.add_child(app.wrapped("每日简报\n"+["农场恢复供水，水价上扬。","充电站检修，电池供应紧张。","水培歉收，食品需求上涨。","医院补充库存，医疗用品走俏。"][int(Game.state.news)]))
	app.button("摆放家具   /   方块原型",func():app.show_base(true),app.side)
	if placing:
		var opts=OptionButton.new()
		for text in ["储物箱","工作台","休息舱","水培箱"]:opts.add_item(text)
		opts.item_selected.connect(func(i):world.furniture_type=i)
		app.side.add_child(opts)
		app.side.add_child(app.wrapped("左键放置，拖动已有家具移动，右键回收。10×6 格，布置自动保存。",14))
		app.button("完成布置",app.show_base,app.side)
	app.button("线路地图   →",app.show_map,app.side)
	app.button("探索   /   整备出发",app.show_preparation,app.side)
	app.button("开店   /   接待与交易",app.show_shop,app.side)
	app.button("下一天   −2 水 / −2 食 / −5 电",func():app.say(Game.next_day());app.show_base(),app.side)
	app.button("仓库   /   物资清单",app.show_stash,app.side)
	app.button("设置",app.show_settings,app.side)
	app.button("返回主界面",app.show_menu,app.side)
