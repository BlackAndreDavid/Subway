extends PanelContainer
const C=preload("res://scripts/catalog.gd")
const Art=preload("res://scripts/art_library.gd")
var model: RefCounted
var stock_index=-1
var slot_type=""
var return_zone=false
var title=""
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	custom_minimum_size=Vector2(128,116)
	var style=StyleBoxFlat.new()
	style.bg_color=Color("18333f") if slot_type=="" else Color("254650")
	style.set_border_width_all(1)
	style.border_color=Color("436770")
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel",style)
	var box=VBoxContainer.new()
	box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var index=model.item_index(slot_type) if slot_type!="" else stock_index
	var heading=Label.new()
	heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.text=title
	heading.add_theme_font_size_override("font_size",14)
	box.add_child(heading)
	if index>=0:
		var item=C.item(model.stock[index])
		var icon=TextureRect.new()
		icon.texture=load(item.icon)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size=Vector2(60,60)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var name_label=Label.new()
		name_label.text=item.name
		name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_font_size_override("font_size",14)
		box.add_child(name_label)
		tooltip_text=item.name+"\n"+item.desc
		if slot_type=="" and model.equipped_slot(index)!="":
			modulate=Color(0.55,0.65,0.67)
			tooltip_text+="\n已装配；可从装备槽拖回仓库。"
	else:
		var hint=Label.new()
		hint.text="拖回仓库" if return_zone else "拖入物品" if slot_type!="" else "空格"
		hint.custom_minimum_size.y=68
		hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
		hint.add_theme_font_size_override("font_size",15)
		box.add_child(hint)
func _get_drag_data(_at_position: Vector2) -> Variant:
	var index=model.item_index(slot_type) if slot_type!="" else stock_index
	var data=model.drag_data(index,slot_type if slot_type!="" else "warehouse")
	if data.is_empty():return null
	data.rotation=int(model.layout[index].rot)
	data.item_id=model.stock[index]
	data.anchor=Vector2i.ZERO
	var preview=TextureRect.new()
	preview.texture=load(C.item(model.stock[index]).icon)
	preview.custom_minimum_size=Vector2(72,72)
	preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	return data
func _can_drop_data(_at_position: Vector2,data: Variant) -> bool:
	if slot_type!="":return model.accepts(slot_type,data)
	return model.valid_payload(data) and data.origin!="warehouse"
func _drop_data(_at_position: Vector2,data: Variant) -> void:
	if slot_type!="":model.assign(slot_type,data)
	else:model.return_to_warehouse(data)
