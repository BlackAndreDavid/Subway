extends Control
signal changed
signal selected(slot_key: String)
const C=preload("res://scripts/catalog.gd")
const Grid=preload("res://scripts/inventory_grid.gd")
@export_enum("module","weapon","drug") var slot_type="module"
func _ready() -> void:
	custom_minimum_size=Vector2(260,84)
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _process(_delta: float) -> void:
	var entry=Game.equipped_entry(slot_type)
	tooltip_text="" if entry.is_empty() else C.item(entry.id).name+"\n"+C.item(entry.id).desc
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:selected.emit(slot_type)
func _get_drag_data(_point: Vector2) -> Variant:
	var data=Game.run_drag_data(-1,slot_type)
	if data.is_empty():return null
	data.grid_source=get_instance_id()
	var ghost=Grid.DragGhost.new()
	ghost.data=data
	ghost.cell_size=48
	set_drag_preview(ghost)
	return data
func _can_drop_data(_point: Vector2,data: Variant) -> bool:return Game.can_equip_payload(slot_type,data)
func _drop_data(_point: Vector2,data: Variant) -> void:
	if Game.equip_payload(slot_type,data):changed.emit()
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.physical_keycode!=KEY_R or not event.pressed or event.echo or not get_viewport().gui_is_dragging():return
	var data=get_viewport().gui_get_drag_data()
	if not Game.valid_run_payload(data) or data.get("grid_source",0)!=get_instance_id():return
	var bounds=C.bounds(data.item_id,int(data.rotation))
	var anchor=Vector2i(data.get("anchor",Vector2i.ZERO))
	data.anchor=Vector2i(bounds.y-1-anchor.y,anchor.x)
	data.rotation=posmod(int(data.rotation)+1,4)
	get_viewport().set_input_as_handled()
func _draw() -> void:
	var entry=Game.equipped_entry(slot_type)
	var color=C.INVENTORY_COLORS[{"module":"module","weapon":"active","drug":"medicine"}[slot_type]]
	draw_rect(Rect2(Vector2.ZERO,size),Color("102630"))
	draw_rect(Rect2(Vector2.ZERO,size),color,false,2)
	draw_rect(Rect2(8,8,68,68),color.darkened(0.15) if not entry.is_empty() else color.darkened(0.7))
	var font=ThemeDB.fallback_font
	draw_string(font,Vector2(88,26),{"module":"模块","weapon":"主动道具","drug":"药物"}[slot_type],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("98b4b7"))
	if not entry.is_empty():
		draw_texture_rect(load(C.item(entry.id).icon),Rect2(15,15,54,54),false)
		draw_string(font,Vector2(88,54),C.item(entry.id).name,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e1e8de"))
		if slot_type=="drug":draw_string(font,Vector2(size.x-44,74),str(entry.uses),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e1ce9a"))
	else:draw_string(font,Vector2(88,54),"空",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("6a858f"))
