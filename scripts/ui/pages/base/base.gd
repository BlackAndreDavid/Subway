extends HBoxContainer
const C=preload("res://scripts/catalog.gd")
var app: Control
@export var furniture_mode=false
var furniture_options: OptionButton
func build(context: Control,placing: bool=false) -> void:
	app=context
	var world=$Stage/World
	placing=placing or furniture_mode
	world.placing=placing
	world.notice.connect(app.say)
	world.facility_requested.connect(app.show_base_dialogue)
	world.interaction_allowed=func():return not is_instance_valid(app.modal)
	world.furniture_changed.connect(refresh_furniture_options)
	app.gameplay_stage(world)
	app.side=app.panel(app.make_drawer(),340)
	app.section(app.side,"车厢基地",C.STATIONS[int(Game.state.station)].name+"  /  自由轨道停泊中")
	app.side.add_child(app.wrapped("每日简报\n"+["农场恢复供水，水价上扬。","充电站检修，电池供应紧张。","水培歉收，食品需求上涨。","医院补充库存，医疗用品走俏。"][int(Game.state.news)]))
	app.button("家具布置 / 使用已合成物品",func():app.show_base(true),app.side)
	app.button("材料合成 / 制作家具",app.show_crafting,app.side)
	if placing:
		var opts=OptionButton.new()
		furniture_options=opts
		for text in C.FURNITURE_NAMES:opts.add_item(text)
		refresh_furniture_options()
		opts.item_selected.connect(func(i):world.furniture_type=i)
		app.side.add_child(opts)
		app.side.add_child(app.wrapped("左键放置已合成家具，拖动移动，右键收回仓库。10×6格，自动保存。",14))
		app.button("完成布置",app.show_base,app.side)
	app.button("线路地图   →",app.show_map,app.side)
	app.button("探索   /   整备出发",app.show_preparation,app.side)
	app.button("开店   /   接待与交易",app.show_shop,app.side)
	app.button("下一天   −2 水 / −2 食 / −5 电",func():app.say(Game.next_day());app.show_base(),app.side)
	app.button("仓库   /   物资清单",app.show_stash,app.side)
	app.button("设置",app.show_settings,app.side)
	app.button("返回主界面",app.show_menu,app.side)
func refresh_furniture_options() -> void:
	if not is_instance_valid(furniture_options):return
	for type in range(4):furniture_options.set_item_text(type,"%s / 仓库 %d 件" % [C.FURNITURE_NAMES[type],Game.state.stash.count("furn_%d" % type)])
