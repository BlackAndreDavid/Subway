extends HBoxContainer
const Loot=preload("res://scripts/loot_rules.gd")
const Metro=preload("res://scripts/metro.gd")
const MapData=preload("res://scripts/metro_data.gd")
const C=preload("res://scripts/catalog.gd")
var app: Control
func build(context: Control) -> void:
	app=context
	app.map_selection=int(Game.state.station)
	var world=$Stage/World
	world.mode="map"
	app.map_view=world
	world.selected_station=app.map_selection
	app.gameplay_stage(world)
	var right=app.make_drawer()
	app.side=app.panel(right,340)
	app.map_actions=VBoxContainer.new()
	app.map_actions.add_theme_constant_override("separation",12)
	right.add_child(app.map_actions)
	world.station_selected.connect(func(i):app.map_selection=i;app.station_detail())
	app.station_detail()
func station_detail() -> void:
	app.empty(app.side)
	app.empty(app.map_actions)
	app.section(app.side,"上海地下交通网","真实线路 · 主要站点压缩图")
	var lines=OptionButton.new()
	lines.add_item("全部 21 条线路")
	lines.set_item_metadata(0,"")
	var ids: Array=[]
	for line in MapData.LINES:
		if ids.has(line.id):continue
		ids.append(line.id)
		lines.add_item(line.name)
		lines.set_item_metadata(lines.item_count-1,line.id)
		if app.map_view.line_filter==line.id:lines.select(lines.item_count-1)
	lines.item_selected.connect(func(index):
		app.map_view.line_filter=lines.get_item_metadata(index)
		app.map_view.queue_redraw()
		app.station_detail())
	app.side.add_child(lines)
	var stops=OptionButton.new()
	stops.clip_text=true
	for i in range(C.STATIONS.size()):
		if app.map_view.line_filter!="" and not C.STATIONS[i].lines.has(app.map_view.line_filter):continue
		stops.add_item(C.STATIONS[i].name)
		stops.set_item_metadata(stops.item_count-1,i)
		if i==app.map_selection:stops.select(stops.item_count-1)
	stops.item_selected.connect(func(index):
		app.map_selection=int(stops.get_item_metadata(index))
		app.map_view.center_station(app.map_selection)
		app.station_detail())
	app.side.add_child(stops)
	app.button("重置视图 / 查看全网",func():app.map_view.reset_map(),app.side)
	var s=C.STATIONS[app.map_selection]
	app.section(app.side,s.name,Metro.lines_for(app.map_selection))
	app.side.add_child(app.wrapped("选站依据："+s.selection_reason,14))
	var exclusive_names: Array=[]
	for id in Loot.exclusive_ids(app.map_selection):exclusive_names.append(C.item(id).name)
	app.side.add_child(app.wrapped("区域：%s\n%s\n丰富度 ×%.2f\n专属：%s" % [s.zone_name,s.local_area,Loot.profile(app.map_selection).richness,"无" if exclusive_names.is_empty() else " / ".join(exclusive_names)],15))
	app.side.add_child(app.wrapped("经济参考：%s（%d）\n区域数据仅作游戏校准，非单站统计。%s" % [s.economy_area,s.economy_year," 黄浦采用公报转录。" if s.economy_verification=="official_report_secondary_transcription" else ""],12))
	app.side.add_child(app.wrapped("地下客流（游戏） %d 人/日\n辐射度（游戏） %d / 5\n产出物资   %s\n价格指数   × %.2f\n地表防护   %d 秒" % [s.traffic,s.radiation,s.yield,s.factor,360-int(s.radiation)*20],15))
	app.side.add_child(app.wrapped("路线："+Metro.route_names(int(Game.state.station),app.map_selection),13))
	app.button("前往   /   %d 电量" % Game.travel_cost(app.map_selection),func():app.say(Game.travel(app.map_selection));app.show_map(),app.map_actions,app.map_selection==int(Game.state.station))
	app.back_button(app.show_base,app.map_actions)
