extends Control
const Art=preload("res://scripts/art_library.gd")
const Loot=preload("res://scripts/loot_rules.gd")
const Metro=preload("res://scripts/metro.gd")
const MapData=preload("res://scripts/metro_data.gd")
const C=preload("res://scripts/catalog.gd")
const World=preload("res://scripts/world_view.gd")
const Combat=preload("res://scripts/combat.gd")
const MiniMap=preload("res://scripts/minimap.gd")
var page="menu"
var root: VBoxContainer
var body: HBoxContainer
var side: VBoxContainer
var toast: Label
var hud: Label
var battle: Control
var modal: Control
var selected_slot=0
var class_select: OptionButton
var module_select: OptionButton
var weapon_select: OptionButton
var drug_select: OptionButton
var base_name: LineEdit
var map_selection=0
var map_view: Control
var bag_selected=-1
var shop_category=0
var notice_text="欢迎来到地下。"
var fonts: Font

func _ready() -> void:
	fonts=load("res://assets/fonts/subway_cjk.otf") if ResourceLoader.exists("res://assets/fonts/subway_cjk.otf") else SystemFont.new()
	if fonts is SystemFont: fonts.font_names=PackedStringArray(["Noto Sans CJK SC","Microsoft YaHei","PingFang SC"])
	var t=Theme.new()
	t.default_font=fonts
	t.default_font_size=17
	t.set_color("font_color","Label",Color("c3d6d9"))
	t.set_color("font_color","Button",Color("d3e1df"))
	t.set_color("font_hover_color","Button",Color("ffffff"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box=StyleBoxFlat.new()
		box.bg_color={"normal":Color("203d48"),"hover":Color("315763"),"pressed":Color("4b7278"),"disabled":Color("182d35"),"focus":Color(0,0,0,0)}[state]
		box.set_corner_radius_all(7)
		box.content_margin_left=16
		box.content_margin_right=16
		box.content_margin_top=10
		box.content_margin_bottom=10
		if state=="focus":
			box.set_border_width_all(2)
			box.border_color=Color("92c6c4")
		t.set_stylebox(state,"Button",box)
	theme=t
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	ThemeDB.fallback_font=fonts
	show_menu()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0a1b24"))
	for i in range(17):
		var x=i*100.0
		draw_line(Vector2(x,0),Vector2(x-250,size.y),Color("102630"),1)
	for i in range(11): draw_line(Vector2(0,i*100),Vector2(size.x,i*100),Color("102630"),1)
	draw_circle(Vector2(size.x-180,130),260,Color(0.21,0.43,0.44,0.06))
func clear_page(id: String) -> void:
	page=id
	if is_instance_valid(modal): modal.queue_free()
	modal=null
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	battle=null
	root=VBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left=36
	root.offset_top=28
	root.offset_right=-36
	root.offset_bottom=-22
	root.add_theme_constant_override("separation",17)
	var top=HBoxContainer.new()
	root.add_child(top)
	var brand=label("SUBWAY",32,Color("a3d4cf"))
	top.add_child(brand)
	var sub=label("地 铁 余 生    /    上海 · 核战后十年",16,Color("72949e"))
	sub.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(sub)
	top.alignment=BoxContainer.ALIGNMENT_CENTER
	hud=label("",15,Color("e7c595"))
	top.add_child(hud)
	if not Game.state.is_empty() and id not in ["menu","slots"]:
		hud.text="%s   |   DAY %02d   |   水 %d   食物 %d   电 %d" % [Game.state.name,Game.state.day,Game.state.water,Game.state.food,Game.state.power]
	var line=HSeparator.new()
	root.add_child(line)
	body=HBoxContainer.new()
	body.add_theme_constant_override("separation",25)
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	root.add_child(body)
	toast=label(notice_text,16,Color("92b6ba"))
	toast.custom_minimum_size.y=27
	root.add_child(toast)

func label(text: String,fs: int=18,color: Color=Color("c3d6d9")) -> Label:
	var l=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",fs)
	l.add_theme_color_override("font_color",color)
	return l
func wrapped(text: String,fs: int=16) -> Label:
	var l=label(text,fs)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return l
func button(text: String,callback: Callable,parent: Node,disabled: bool=false) -> Button:
	var b=Button.new()
	b.text=text
	b.disabled=disabled
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	parent.add_child(b)
	return b
func section(parent: Node,title: String,text: String="") -> void:
	parent.add_child(label(title,23,Color("e4c493")))
	if text!="": parent.add_child(wrapped(text))
func panel(parent: Node,width: float=360) -> VBoxContainer:
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size.x=width
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var v=VBoxContainer.new()
	v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation",12)
	scroll.add_child(v)
	return v
func say(text: String) -> void:
	notice_text=text
	if is_instance_valid(toast):toast.text=text
func back_button(callback: Callable,parent: Node) -> void:
	button("← 返回",callback,parent)
func show_menu() -> void:
	clear_page("menu")
	var hero=VBoxContainer.new()
	hero.custom_minimum_size.x=790
	hero.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hero.alignment=BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation",22)
	body.add_child(hero)
	hero.add_child(label("THE LAST LINE HOME",18,Color("82b2b6")))
	hero.add_child(label("最后一班，\n开往明天。",68,Color("e4e2ca")))
	hero.add_child(wrapped("地表沉默之后，城市在轨道下重生。\n作为一名回收员，探索、交易，守住属于你的那节车厢。",21))
	var art=TextureRect.new()
	art.texture=Art.texture("station")
	art.custom_minimum_size=Vector2(180,180)
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.add_child(art)
	var menu=VBoxContainer.new()
	menu.custom_minimum_size.x=350
	menu.alignment=BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation",18)
	body.add_child(menu)
	section(menu,"回到轨道之下","原型版本 0.1  /  GODOT 4.6")
	button("开始游戏   →",show_slots,menu)
	button("设置",show_settings,menu)
	button("退出",func():get_tree().quit(),menu)
	menu.add_child(wrapped("原创程序美术\n回收探索 × 车厢家园 × 地下贸易",15))
func show_slots() -> void:
	clear_page("slots")
	var left=panel(body,570)
	section(left,"回收员档案","三份独立存档 · 创建基地后自动保存")
	for i in range(3):
		var data=Game.slot_info(i)
		var title="%02d   空白档案" % (i+1)
		if not data.is_empty(): title="%02d   %s  ·  第 %d 天" % [i+1,str(data.get("name","损坏档案")),int(data.get("day",0))]
		var idx=i
		button(title,func():selected_slot=idx; show_slot_actions(),left)
	back_button(show_menu,left)
	side=panel(body,650)
	show_slot_actions()
func empty(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
func show_slot_actions() -> void:
	empty(side)
	var data=Game.slot_info(selected_slot)
	section(side,"档案 %02d" % (selected_slot+1))
	if data.is_empty():
		side.add_child(wrapped("为你的车厢基地命名。留空则使用「上海堡垒」。"))
		base_name=LineEdit.new()
		base_name.placeholder_text="上海堡垒"
		base_name.max_length=24
		side.add_child(base_name)
		button("创建并进入基地",func():
			if Game.new_game(selected_slot,base_name.text):show_base()
			else:say(Game.last_error),side)
	else:
		side.add_child(wrapped("基地：%s\n日期：第 %s 天\n电量：%s\n水 / 食物：%s / %s" % [data.get("name","?"),data.get("day","?"),data.get("power","?"),data.get("water","?"),data.get("food","?")]))
		button("读取存档",func():
			if Game.load_game(selected_slot):show_base()
			else:say(Game.last_error),side)
		button("重建此档案…",func():confirm_replace(),side)
func confirm_replace() -> void:
	var v=open_modal("重建档案")
	v.add_child(wrapped("这会覆盖档案 %d 的所有进度。" % (selected_slot+1)))
	var name_input=LineEdit.new()
	name_input.placeholder_text="新基地名称 / 上海堡垒"
	name_input.max_length=24
	v.add_child(name_input)
	button("确认覆盖并创建",func():
		if Game.new_game(selected_slot,name_input.text):show_base()
		else:say(Game.last_error),v)
	button("取消",close_modal,v)
func show_base(placing: bool=false) -> void:
	clear_page("base")
	var world=World.new()
	world.custom_minimum_size=Vector2(900,610)
	world.size_flags_vertical=Control.SIZE_EXPAND_FILL
	world.placing=placing
	body.add_child(world)
	side=panel(body)
	section(side,"车厢基地",C.STATIONS[int(Game.state.station)].name+"  /  自由轨道停泊中")
	side.add_child(wrapped("每日简报\n"+["农场恢复供水，水价上扬。","充电站检修，电池供应紧张。","水培歉收，食品需求上涨。","医院补充库存，医疗用品走俏。"][int(Game.state.news)]))
	button("摆放家具   /   方块原型",func():show_base(true),side)
	if placing:
		var opts=OptionButton.new()
		for text in ["储物箱","工作台","休息舱","水培箱"]:opts.add_item(text)
		opts.item_selected.connect(func(i):world.furniture_type=i)
		side.add_child(opts)
		side.add_child(wrapped("左键放置，拖动已有家具移动，右键回收。10×6 格，布置自动保存。",14))
		button("完成布置",show_base,side)
	button("线路地图   →",show_map,side)
	button("探索   /   整备出发",show_preparation,side)
	button("开店   /   接待与交易",show_shop,side)
	button("下一天   −2 水 / −2 食 / −5 电",func():say(Game.next_day());show_base(),side)
	button("仓库   /   物资清单",show_stash,side)
	button("设置",show_settings,side)
	button("返回主界面",show_menu,side)
func show_map() -> void:
	clear_page("map")
	map_selection=int(Game.state.station)
	var world=World.new()
	world.mode="map"
	map_view=world
	world.selected_station=map_selection
	world.custom_minimum_size=Vector2(900,610)
	world.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(world)
	side=panel(body)
	world.station_selected.connect(func(i):map_selection=i;station_detail())
	station_detail()
func station_detail() -> void:
	empty(side)
	section(side,"上海地下交通网","真实线路 · 主要站点压缩图")
	var lines=OptionButton.new()
	lines.add_item("全部 21 条线路")
	lines.set_item_metadata(0,"")
	var ids: Array=[]
	for line in MapData.LINES:
		if ids.has(line.id):continue
		ids.append(line.id)
		lines.add_item(line.name)
		lines.set_item_metadata(lines.item_count-1,line.id)
		if map_view.line_filter==line.id:lines.select(lines.item_count-1)
	lines.item_selected.connect(func(index):
		map_view.line_filter=lines.get_item_metadata(index)
		map_view.queue_redraw()
		station_detail())
	side.add_child(lines)
	var stops=OptionButton.new()
	stops.clip_text=true
	for i in range(C.STATIONS.size()):
		if map_view.line_filter!="" and not C.STATIONS[i].lines.has(map_view.line_filter):continue
		stops.add_item(C.STATIONS[i].name)
		stops.set_item_metadata(stops.item_count-1,i)
		if i==map_selection:stops.select(stops.item_count-1)
	stops.item_selected.connect(func(index):
		map_selection=int(stops.get_item_metadata(index))
		map_view.center_station(map_selection)
		station_detail())
	side.add_child(stops)
	button("重置视图 / 查看全网",func():map_view.reset_map(),side)
	var s=C.STATIONS[map_selection]
	section(side,s.name,Metro.lines_for(map_selection))
	side.add_child(wrapped("选站依据："+s.selection_reason,14))
	var exclusive_names: Array=[]
	for id in Loot.exclusive_ids(map_selection):exclusive_names.append(C.item(id).name)
	side.add_child(wrapped("区域：%s\n丰富度 ×%.2f\n专属：%s" % [s.zone_name,Loot.profile(map_selection).richness,"无" if exclusive_names.is_empty() else " / ".join(exclusive_names)],15))
	side.add_child(wrapped("经济参考：%s（2025）\n区域数据仅作游戏校准，非单站统计。" % s.economy_area,12))
	side.add_child(wrapped("地下客流（游戏） %d 人/日\n辐射度（游戏） %d / 5\n产出物资   %s\n价格指数   × %.2f\n地表防护   %d 秒" % [s.traffic,s.radiation,s.yield,s.factor,360-int(s.radiation)*20],15))
	side.add_child(wrapped("路线："+Metro.route_names(int(Game.state.station),map_selection),13))
	button("前往   /   %d 电量" % Game.travel_cost(map_selection),func():say(Game.travel(map_selection));show_map(),side,map_selection==int(Game.state.station))
	back_button(show_base,side)
func equipment_select(parent: Node,category: int,title: String) -> OptionButton:
	parent.add_child(label(title,16))
	var option=OptionButton.new()
	option.add_item("不携带")
	option.set_item_metadata(0,"")
	for id in C.all_ids():
		if int(C.item(id).category)==category and Game.state.stash.has(id):
			option.add_item(C.item(id).name+"  /  "+C.item(id).desc)
			option.set_item_metadata(option.item_count-1,id)
	if option.item_count>1:option.select(1)
	option.custom_minimum_size.x=550
	option.clip_text=true
	parent.add_child(option)
	return option
func show_preparation() -> void:
	clear_page("prepare")
	var left=panel(body,820)
	section(left,"探索整备","选择职业与三个独立装备槽；所有携带物品占据背包格。")
	class_select=OptionButton.new()
	for stats in C.CLASSES:
		class_select.add_item("%s   HP %d / 容量 %d / 护甲 %d%% / 射程 %d" % [stats.name,stats.hp,stats.capacity,stats.armor*100,stats.range])
	left.add_child(class_select)
	module_select=equipment_select(left,5,"模块 / 可拆卸被动")
	weapon_select=equipment_select(left,4,"武器 / E 键主动能力")
	drug_select=equipment_select(left,3,"药物 / Q 键有限次数")
	left.add_child(wrapped("模块和主动武器采用原创效果设计。常规子弹由方向键或鼠标发射；主动道具独立冷却。\n\n基地库存中的装备将被带出；失败会遗失随身物品。安全返程后物品回到仓库，药物在下一次整备补充次数。",17))
	side=panel(body)
	section(side,"出发须知","目标区域："+C.STATIONS[int(Game.state.station)].name)
	side.add_child(wrapped("每层 24–30 个连通房间。\n中段必经奖励房，末端 Boss。\n相邻房间移动消耗 1 电量。\n保底路线覆盖全部房间，出发时检查电量。\n\n房间清空后可撤离；战斗中背包与通道锁定。\n防护倒计时耗尽或生命归零会触发救援。"))
	button("通过检查站   →",start_run,side)
	back_button(show_base,side)
func start_run() -> void:
	var ok=Game.begin_run(class_select.selected,module_select.get_item_metadata(module_select.selected),weapon_select.get_item_metadata(weapon_select.selected),drug_select.get_item_metadata(drug_select.selected))
	if ok:show_combat()
	else:say(Game.last_error)
func show_combat() -> void:
	clear_page("combat")
	battle=Combat.new()
	battle.custom_minimum_size=Vector2(900,600)
	body.add_child(battle)
	side=panel(body)
	battle.changed.connect(refresh_combat)
	battle.notice.connect(say)
	battle.ended.connect(func(success):
		var result=Game.end_run(success)
		show_base()
		say(result))
	refresh_combat()
func refresh_combat() -> void:
	if Game.run.is_empty() or not is_instance_valid(side):return
	empty(side)
	section(side,C.CLASSES[int(Game.run["class"])].name+" / 回收作业")
	var minimap=MiniMap.new()
	minimap.selected.connect(func(id):battle.goto_room(id))
	side.add_child(minimap)
	var r=Game.run.floor_data.rooms[int(Game.run.room)]
	side.add_child(wrapped("保底预算 %d 步 / %d 间房\n金：奖励  紫：商店  红：Boss" % [Game.run.floor_data.budget,Game.run.floor_data.rooms.size()],14))
	var drug_uses=0
	for entry in Game.run.bag:
		if entry.id==Game.run.drug:drug_uses+=int(entry.uses)
	var equipped=[]
	for slot_key in ["module","weapon","drug"]:
		equipped.append("空槽" if Game.run[slot_key]=="" else C.item(Game.run[slot_key]).name)
	side.add_child(wrapped("模块  %s\nE  %s\nQ  %s / %d 次" % [equipped[0],equipped[1],equipped[2],drug_uses],14))
	var visited=0
	for node in Game.run.floor_data.rooms:
		if node.visited:visited+=1
	side.add_child(label("已探索 %d / %d   ·   背包 %d / %d" % [visited,Game.run.floor_data.rooms.size(),Game.run.bag.size(),Game.run.stats.capacity],16))
	if Game.run.fighting:side.add_child(wrapped("战斗中：通道与背包已锁定。",16))
	else:
		if r.kind=="reward" and not r.claimed:
			button("奖励：聚焦晶体 / 伤害 +25%",func():say(Game.claim_reward(0));refresh_combat(),side)
			button("奖励：散射电容 / 主动道具",func():say(Game.claim_reward(1));refresh_combat(),side)
		if r.kind=="shop":
			button("补给商：凝胶绷带 / 22 电量",func():buy_run_item("3_0",22),side)
			button("补给商：轻量背架 / 40 电量",func():buy_run_item("5_1",40),side)
		for i in range(r.loot.size()):
			var index=i
			var loot_entry=r.loot[i]
			var id: String=loot_entry.id if loot_entry is Dictionary else loot_entry
			var title={"power":"电量补给 +%d" % Loot.pickup_value(int(Game.state.station),"power"),"credits":"电卡余额 +%d" % Loot.pickup_value(int(Game.state.station),"credits"),"chest":"随机宝箱 / 点击开启"}.get(id,"")
			if title=="":title=C.item(id).name
			button("拾取   "+title,func():battle.collect(index),side)
		if r.kind=="boss" and r.cleared:
			button("通往下一层   →",func():
				if Game.next_floor():battle.enter_room()
				else:say(Game.last_error),side)
		for id in r.links:
			var next_id=id
			button("通道 → 房间 %02d" % (int(id)+1),func():battle.goto_room(next_id),side)
	button("背包 / Tab",show_bag,side,bool(Game.run.fighting))
	button("安全撤离",confirm_extract,side,bool(Game.run.fighting))
	button("暂停 / Esc",show_pause,side)
func buy_run_item(id: String,cost: int) -> void:
	if Game.run.fighting:return
	if Game.state.power<cost:say("电量不足。")
	elif not Game.pick_up(id):say("背包已满。")
	else:
		Game.state.power-=cost
		say("已购入"+C.item(id).name)
		refresh_combat()
func _process(_delta: float) -> void:
	if page=="combat" and not Game.run.is_empty():
		hud.text="生命 %d/%d   电量 %d / 账户 %d   防护 %d 秒   E %.1fs" % [maxi(0,int(Game.run.hp)),Game.run.stats.hp,Game.run.energy,Game.state.power,maxi(0,int(Game.run.timer)),Game.run.weapon_cd]
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.physical_keycode==KEY_ESCAPE:
		if is_instance_valid(modal):close_modal()
		elif page=="combat":show_pause()
	elif event.physical_keycode==KEY_TAB and page=="combat":
		if is_instance_valid(modal):close_modal()
		else:show_bag()
func open_modal(title: String) -> VBoxContainer:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal=Control.new()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade=ColorRect.new()
	shade.color=Color(0.02,0.07,0.10,0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var center=PanelContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.offset_left=-430
	center.offset_right=430
	center.offset_top=-340
	center.offset_bottom=340
	modal.add_child(center)
	var style=StyleBoxFlat.new()
	style.bg_color=Color("152f3a")
	style.set_corner_radius_all(12)
	style.content_margin_left=26
	style.content_margin_top=24
	style.content_margin_right=26
	style.content_margin_bottom=24
	center.add_theme_stylebox_override("panel",style)
	var scroll=ScrollContainer.new()
	center.add_child(scroll)
	var v=VBoxContainer.new()
	v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation",14)
	scroll.add_child(v)
	section(v,title)
	if is_instance_valid(battle):battle.paused=true
	return v
func close_modal() -> void:
	if is_instance_valid(modal):modal.queue_free()
	modal=null
	if is_instance_valid(battle):battle.paused=false
func show_settings() -> void:
	var v=open_modal("设置")
	v.add_child(label("主音量"))
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
	v.add_child(wrapped("WASD 移动 · 方向键 / 鼠标左键射击\nE 主动武器 · Q 药物 · Tab 背包 · Esc 暂停\n\n战斗原型支持鼠标与键盘。存档保存在 Godot user:// 目录。"))
	button("保存设置并返回",func():Game.save_settings();close_modal(),v)
func show_pause() -> void:
	var v=open_modal("作业暂停")
	v.add_child(wrapped("计时与战斗已暂停。战斗进度暂不支持中途保存。"))
	button("继续探索",close_modal,v)
	button("设置",show_settings,v)
	button("放弃本次探索并返回基地",func():
		say(Game.end_run(false))
		show_base(),v)
func confirm_extract() -> void:
	if Game.run.fighting:return
	var v=open_modal("检查站 / 安全返程")
	v.add_child(wrapped("将随身物资带回基地并保存，结束本次探索。返程不额外消耗电量。"))
	button("确认返程",func():
		say(Game.end_run(true))
		show_base(),v)
	button("继续探索",close_modal,v)
func show_stash() -> void:
	var v=open_modal("基地仓库")
	v.add_child(wrapped("所有购入和回收货物均存入仓库，可择站出售。水、食物和电池也可入库使用，转为基地储备。"))
	var counts={}
	for id in Game.state.stash:counts[id]=counts.get(id,0)+1
	for id in counts:
		var row=HBoxContainer.new()
		v.add_child(row)
		row.add_child(label("%s × %d" % [C.item(id).name,counts[id]],16))
		if int(C.item(id).category)<3:
			var item_id: String=id
			button("入库使用",func():consume_stash(item_id);show_stash(),row)
	button("返回基地",close_modal,v)
func consume_stash(id: String) -> void:
	if not Game.state.stash.has(id):return
	Game.state.stash.erase(id)
	var grade=int(id.split("_")[1])
	match int(C.item(id).category):
		0:Game.state.water+=[3,5,7,10][grade]
		1:Game.state.power+=[6,10,15,22][grade]
		2:Game.state.food+=[3,5,7,10][grade]
	Game.save_game()
func show_bag() -> void:
	if Game.run.is_empty():return
	if Game.run.fighting:
		say("战斗中不能打开或调整背包。")
		return
	var v=open_modal("随身背包 / %d 格" % Game.run.stats.capacity)
	v.add_child(wrapped("选择两件物品交换位置；模块、武器与药物可在非战斗时重新装配。装备仍占背包格。"))
	var bag: Array=Game.run.bag
	for i in range(bag.size()):
		var index=i
		var entry=bag[i]
		var item=C.item(entry.id)
		var row=HBoxContainer.new()
		v.add_child(row)
		var item_button=button("%02d  %s%s" % [i+1,item.name," [%d次]" % entry.uses if item.category==3 else ""],func():swap_bag(index),row)
		item_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		if i==bag_selected:item_button.modulate=Color("f6c67c")
		if int(item.category) in [3,4,5]:
			var equipped=(entry.id==Game.run.module or entry.id==Game.run.weapon or entry.id==Game.run.drug)
			button("卸下" if equipped else "装配",func():equip_bag(index);show_bag(),row)
		button("丢弃",func():drop_bag(index);show_bag(),row)
	button("返回探索",func():bag_selected=-1;close_modal();refresh_combat(),v)
func swap_bag(index: int) -> void:
	if bag_selected<0:bag_selected=index
	else:
		if bag_selected<Game.run.bag.size():
			var temp=Game.run.bag[index]
			Game.run.bag[index]=Game.run.bag[bag_selected]
			Game.run.bag[bag_selected]=temp
		bag_selected=-1
	show_bag()
func set_module(id: String) -> bool:
	var old: String=Game.run.module
	var stats: Dictionary=Game.run.stats
	if old=="5_1" and id!="5_1" and Game.run.bag.size()>int(C.CLASSES[int(Game.run["class"])].capacity):
		say("背包超出基础容量，先丢弃物品再卸下背架。")
		return false
	stats.armor=C.CLASSES[int(Game.run["class"])].armor
	stats.capacity=C.CLASSES[int(Game.run["class"])].capacity
	if id=="5_0":stats.armor=minf(0.7,stats.armor+0.15)
	if id=="5_1":stats.capacity+=6
	Game.run.module=id
	return true
func equip_bag(index: int) -> void:
	var id: String=Game.run.bag[index].id
	match int(C.item(id).category):
		3:Game.run.drug="" if Game.run.drug==id else id
		4:Game.run.weapon="" if Game.run.weapon==id else id
		5:set_module("" if Game.run.module==id else id)
func drop_bag(index: int) -> void:
	var id: String=Game.run.bag[index].id
	if Game.run.module==id and not set_module(""):return
	if Game.run.weapon==id:Game.run.weapon=""
	if Game.run.drug==id:Game.run.drug=""
	Game.run.floor_data.rooms[int(Game.run.room)].loot.append(Game.run.bag[index].duplicate(true))
	Game.run.bag.remove_at(index)
	bag_selected=-1
func show_shop() -> void:
	clear_page("shop")
	var catalog=panel(body,890)
	section(catalog,"地下市场 / 以电易物","价格受站点与日报影响 · 当日每种商品限购 4 件")
	var cats=HBoxContainer.new()
	catalog.add_child(cats)
	for i in range(6):
		var cat=i
		button(C.CATEGORY_NAMES[i],func():shop_category=cat;show_shop(),cats)
	for j in range(4):
		var id="%d_%d" % [shop_category,j]
		item_card(catalog,id)
	side=panel(body)
	section(side,"开店接客","到站客流：%d 人 / 日" % C.STATIONS[int(Game.state.station)].traffic)
	var offer=Game.customer_offer()
	side.add_child(wrapped("第 %d 位顾客\n%s %s\n出价 %d 电量" % [int(Game.state.customer)+1,"想买入" if offer.buying else "想出售",C.item(offer.id).name,offer.price],20))
	button("成交",func():say(Game.accept_customer());show_shop(),side)
	button("婉拒 / 下一位",func():Game.state.customer+=1;Game.save_game();show_shop(),side)
	side.add_child(HSeparator.new())
	section(side,"柜台库存","点击售出一件，按当前站点收购价结算。")
	var counts={}
	for id in Game.state.stash:counts[id]=counts.get(id,0)+1
	for id in counts:
		var item_id: String=id
		button("%s ×%d  /  卖 %d 电" % [C.item(id).name,counts[id],Game.price(id,false)],func():say(Game.trade(item_id,false));show_shop(),side)
	back_button(show_base,side)
func item_card(parent: Node,id: String) -> void:
	var item=C.item(id)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	parent.add_child(row)
	var icon=TextureRect.new()
	icon.texture=load(item.icon)
	icon.custom_minimum_size=Vector2(72,72)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var detail=VBoxContainer.new()
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	detail.add_child(label(item.name,22,Color("dfd9bf")))
	detail.add_child(wrapped(item.desc,15))
	button("%d 电量 / 购入\n余量 %d" % [Game.price(id,true),Game.state.market_stock.get(id,4)],func():say(Game.trade(id,true));show_shop(),row,int(Game.state.market_stock.get(id,4))<=0)
	parent.add_child(HSeparator.new())
