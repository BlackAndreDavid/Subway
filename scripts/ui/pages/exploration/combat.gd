extends HBoxContainer
const C=preload("res://scripts/catalog.gd")
const Inventory=preload("res://scripts/inventory.gd")
var app: Control
func build(context: Control) -> void:
	app=context
	app.battle=$Stage/Room
	app.gameplay_stage(app.battle)
	app.minimap=$Stage/Minimap
	app.minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	app.minimap.offset_left=-332
	app.minimap.offset_right=-12
	app.minimap.offset_top=12
	app.minimap.offset_bottom=202
	app.minimap.can_use=func():return is_instance_valid(app.battle) and not app.battle.paused and not is_instance_valid(app.modal)
	app.side=app.panel(app.make_drawer(214),340)
	app.drawer.offset_bottom=-110
	app.combat_hud=$Stage/HUD
	app.combat_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.battle.changed.connect(app.refresh_combat)
	app.battle.notice.connect(app.say)
	app.battle.reward_requested.connect(app.show_reward)
	app.battle.descent_requested.connect(app.descend_floor)
	app.battle.return_requested.connect(app.return_to_base)
	app.battle.ended.connect(func(success):
		var result=Game.end_run(success)
		app.show_base()
		app.say(result))
	app.refresh_combat()
func refresh_combat() -> void:
	if Game.run.is_empty() or not is_instance_valid(app.side):return
	app.empty(app.side)
	app.section(app.side,C.CLASSES[int(Game.run["class"])].name+" / 回收作业")
	if is_instance_valid(app.minimap):app.minimap.queue_redraw()
	var r=Game.run.floor_data.rooms[int(Game.run.room)]
	app.side.add_child(app.wrapped("通道需在门前按 F 进入；战斗时锁定。",14))
	var drug_uses=int(Game.equipped_entry("drug").get("uses",0))
	var equipped=[]
	for slot_key in ["module","weapon","drug"]:
		equipped.append("空槽" if Game.run[slot_key]=="" else C.item(Game.run[slot_key]).name)
	app.side.add_child(app.wrapped("模块  %s\n空格  %s\nQ  %s / %d 次" % [equipped[0],equipped[1],equipped[2],drug_uses],14))
	var visited=0
	for node in Game.run.floor_data.rooms:
		if node.visited:visited+=1
	app.side.add_child(app.label("已探索 %d 间   ·   背包 %d / %d" % [visited,Inventory.used(Game.run.bag),Game.run.stats.capacity],16))
	if Game.run.fighting:app.side.add_child(app.wrapped("战斗中：通道与背包已锁定。",16))
	else:
		if r.kind=="reward" and not r.claimed:
			app.side.add_child(app.wrapped("靠近房间中央宝箱，按 F 选择奖励。",15))
		if r.kind=="shop":
			app.side.add_child(app.label("凝胶绷带 · 22 水晶",15))
			app.button("购买绷带",func():app.buy_run_item("3_0",22),app.side)
			app.side.add_child(app.label("轻量背架 · 40 水晶",15))
			app.button("购买背架",func():app.buy_run_item("5_1",40),app.side)
		if not r.loot.is_empty():app.side.add_child(app.wrapped("地面有 %d 件物资：靠近按 F；电量/水晶自动吸附。" % r.loot.size(),14))
		if r.kind=="start":app.side.add_child(app.wrapped("靠近返程终端按 F 返回基地。"))
		if r.kind=="boss" and r.cleared:app.side.add_child(app.wrapped("楼梯通往下一层，返程终端返回基地。靠近后按 F。"))
	app.button("背包",app.show_bag,app.side,bool(Game.run.fighting))
	app.button("暂停",app.show_pause,app.side)
func buy_run_item(id: String,cost: int) -> void:
	if Game.run.fighting:return
	if Game.state.crystals<cost:app.say("水晶不足。")
	elif not Game.pick_up(id):app.say("背包已满。")
	else:
		Game.state.crystals-=cost
		app.say("已购入"+C.item(id).name)
		app.refresh_combat()
func _process(_delta: float) -> void:
	if not is_instance_valid(app):return
	if app.page=="combat" and not Game.run.is_empty():
		app.battle.pointer_blocked=is_instance_valid(app.drawer) and app.drawer.visible and app.drawer.get_global_rect().has_point(get_global_mouse_position())
		app.hud.text="第 %d 层 · 电量 %d · 水晶 %d" % [Game.run.floor,Game.state.power,Game.state.crystals]
