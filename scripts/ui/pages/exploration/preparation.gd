extends HBoxContainer
const C=preload("res://scripts/catalog.gd")
const Loadout=preload("res://scripts/loadout_model.gd")
var app: Control
func build(context: Control) -> void:
	app=context
	Game.ensure_stash()
	app.loadout=Loadout.new(Game.state.stash,Game.state.stash_layout,Vector2i(Game.STASH_COLUMNS,int(Game.state.stash_rows)))
	app.loadout.changed.connect(app.refresh_loadout)
	var layout=$Layout
	layout.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation",14)
	app.section(layout,"探索整备","从仓库拖入装备槽；物品按形状占格。拖拽时 R 旋转，绿色可放置，红色表示重叠或越界。")
	var header=HBoxContainer.new()
	header.add_theme_constant_override("separation",16)
	layout.add_child(header)
	app.class_select=OptionButton.new()
	app.class_select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for stats in C.CLASSES:
		app.class_select.add_item("%s   HP %d / 背包 %d×%d / 护甲 %d%% / 射程 %d" % [stats.name,stats.hp,stats.grid_cols,stats.grid_rows,stats.armor*100,stats.range])
	header.add_child(app.class_select)
	app.button("出发",app.start_run,header)
	app.back_button(app.show_base,header)
	app.loadout_slots=HBoxContainer.new()
	app.loadout_slots.add_theme_constant_override("separation",16)
	layout.add_child(app.loadout_slots)
	layout.add_child(app.label("基地仓库 / 按形状占格",20,Color("e4c493")))
	var scroll=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	app.warehouse_grid=preload("res://scenes/inventory/grid.tscn").instantiate()
	app.warehouse_grid.cell_size=64
	app.warehouse_grid.dimensions=app.loadout.dimensions
	app.warehouse_grid.items=app.loadout.entries()
	app.warehouse_grid.drag_source=app.loadout.drag_data
	app.warehouse_grid.can_place=app.loadout.can_move
	app.warehouse_grid.place_item=app.loadout.move
	app.warehouse_grid.reserved=func(index):return app.loadout.equipped_slot(index)!=""
	scroll.add_child(app.warehouse_grid)
	layout.add_child(app.wrapped("目标：%s · 房间清空后靠近门按 F 通行；B 背包，长按 Tab 2 秒看清地图。
整备不消耗天数；出发时消耗一天（2水、2食物、5电）并扣除选中实物，装备不占背包。击败Boss后可选择下一层或安全返程；失败遗失随身物资。" % C.STATIONS[int(Game.state.station)].name,15))
	app.refresh_loadout()
func refresh_loadout() -> void:
	app.empty(app.loadout_slots)
	for slot_key in ["module","weapon","drug"]:
		var cell=preload("res://scenes/inventory/equipment_slot.tscn").instantiate()
		cell.model=app.loadout
		cell.slot_type=slot_key
		cell.title={"module":"模块 / 被动","weapon":"主动道具 / 空格","drug":"药物 / Q 使用"}[slot_key]
		cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		app.loadout_slots.add_child(cell)
	app.warehouse_grid.items=app.loadout.entries()
	app.warehouse_grid.refresh()
	Game.state.stash_layout=app.loadout.layout.duplicate(true)
	Game.save_game()
func start_run() -> void:
	var ok=Game.begin_run(app.class_select.selected,app.loadout.selected_id("module"),app.loadout.selected_id("weapon"),app.loadout.selected_id("drug"),-1,app.loadout.slots)
	if ok:app.show_combat()
	else:app.say(Game.last_error)
