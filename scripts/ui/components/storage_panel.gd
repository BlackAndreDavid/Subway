extends HBoxContainer
const C=preload("res://scripts/catalog.gd")
var app: Control
var grid: Control
var details: VBoxContainer
func build(context: Control,mode: String) -> void:
	app=context
	var row=self
	row.add_theme_constant_override("separation",24)
	var scroll=$StorageScroll
	scroll.custom_minimum_size=Vector2(620 if mode=="stash" else 430,440)
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid=app.create_storage_grid(mode)
	scroll.add_child(grid)
	details=$ItemDetails
	details.custom_minimum_size.x=290
	grid.selected.connect(func(index):
		if mode=="stash":app.stash_selected=index
		else:app.bag_selected=index
		refresh_details(mode))
	refresh_details(mode)
	app.storage_grid=grid
	app.storage_details=details
func refresh_details(mode: String) -> void:
	app.empty(details)
	var index=app.stash_selected if mode=="stash" else app.bag_selected
	var items: Array=grid.items
	if index<0 or index>=items.size():
		details.add_child(app.wrapped("点击物品查看信息。\n拖动时按 R 旋转。\n空白形状孔位可容纳其他物品。",16))
		return
	var entry: Dictionary=items[index]
	var item=C.item(entry.id)
	app.section(details,item.name,item.desc)
	var bounds=C.bounds(entry.id,int(entry.rot))
	details.add_child(app.label("%d×%d / 实占 %d 格" % [bounds.x,bounds.y,C.cells(entry.id).size()],17))
	if item.category==3 and entry.has("uses"):details.add_child(app.label("剩余 %d 次" % entry.uses))
	app.button("旋转 90°",func():
		var data=grid.drag_source.call(index)
		data.rotation=posmod(int(entry.rot)+1,4)
		if grid.can_place.call(data,Vector2i(entry.x,entry.y),int(data.rotation)):
			grid.place_item.call(data,Vector2i(entry.x,entry.y),int(data.rotation))
			refresh_details(mode)
		else:app.say("旋转后会重叠或越界；请拖到合适位置。"),details)
	if mode=="stash":
		if int(item.category)<3:app.button("入库使用",func():app.consume_stash(entry.id);app.show_stash(),details)
		app.button("售出 / %d 电" % Game.price(entry.id,false),func():app.say(Game.trade(entry.id,false));app.show_stash(),details)
	else:
		if int(item.category) in [3,4,5]:
			var equipped=int(entry.uid) in Game.run.equipped_uid.values()
			app.button("卸下" if equipped else "装配",func():app.equip_bag(index);app.show_bag(),details)
		app.button("丢弃",func():app.drop_bag(index);app.show_bag(),details)
