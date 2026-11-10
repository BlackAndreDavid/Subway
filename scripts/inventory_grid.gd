extends Control
signal selected(index: int)
signal moved
const C=preload("res://scripts/catalog.gd")
const Inventory=preload("res://scripts/inventory.gd")
var items: Array=[]
var dimensions=Vector2i(12,10)
var cell_size=48.0
var drag_source: Callable
var can_place: Callable
var place_item: Callable
var reserved: Callable
var allowed: Callable
var selected_index=-1
var tiles: Dictionary={}
class ItemTile extends Control:
	var grid: Control
	var index: int
	var icon: Texture2D
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			grid.selected_index=index
			grid.selected.emit(index)
			grid.refresh_selection()
	func _get_drag_data(point: Vector2) -> Variant:
		if not grid.interactive():return null
		var data: Dictionary=grid.drag_source.call(index)
		if data.is_empty():return null
		data.anchor=Vector2i(point/grid.cell_size)
		data.rotation=int(grid.items[index].get("rot",0))
		data.item_id=grid.items[index].id
		data.grid_source=grid.get_instance_id()
		var ghost=DragGhost.new()
		ghost.data=data
		ghost.cell_size=grid.cell_size
		set_drag_preview(ghost)
		return data
	func _can_drop_data(point: Vector2,data: Variant) -> bool:
		return grid._can_drop_data(position+point,data)
	func _drop_data(point: Vector2,data: Variant) -> void:
		grid._drop_data(position+point,data)
	func _draw() -> void:
		var entry: Dictionary=grid.items[index]
		var tint=Color("315766")
		if grid.reserved.is_valid() and grid.reserved.call(index):tint=Color("20333b")
		for cell in C.cells(entry.id,int(entry.get("rot",0))):
			var rect=Rect2(Vector2(cell)*grid.cell_size+Vector2.ONE,Vector2.ONE*(grid.cell_size-2))
			draw_rect(rect,tint)
			draw_rect(rect,Color("f0ce86") if grid.selected_index==index else Color("6b9b9e"),false,2)
		var extent=Vector2(C.bounds(entry.id,int(entry.get("rot",0))))*grid.cell_size
		# Keep icons upright while the footprint rotates, as in a storage case.
		var edge=minf(extent.x,extent.y)-12
		var icon_origin=(extent-Vector2.ONE*edge)/2
		if C.cells(entry.id).size()<C.bounds(entry.id).x*C.bounds(entry.id).y:
			edge=grid.cell_size-12
			icon_origin=Vector2(C.cells(entry.id,int(entry.get("rot",0)))[0])*grid.cell_size+Vector2(6,6)
		draw_texture_rect(icon,Rect2(icon_origin,Vector2.ONE*edge),false,Color(1,1,1,0.45) if grid.reserved.is_valid() and grid.reserved.call(index) else Color.WHITE)
		if C.item(entry.id).category==3 and entry.has("uses"):
			draw_string(ThemeDB.fallback_font,extent-Vector2(24,7),str(entry.uses),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f5d793"))
	func _has_point(point: Vector2) -> bool:
		if not Rect2(Vector2.ZERO,size).has_point(point):return false
		return C.cells(grid.items[index].id,int(grid.items[index].get("rot",0))).has(Vector2i(point/grid.cell_size))
class DragGhost extends Control:
	var data: Dictionary
	var cell_size: float
	var icon: Texture2D
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon=load(C.item(data.item_id).icon)
	func _process(_delta: float) -> void:queue_redraw()
	func _draw() -> void:
		var offset=-Vector2(data.get("anchor",Vector2i.ZERO))*cell_size
		for cell in C.cells(data.item_id,int(data.rotation)):
			draw_rect(Rect2(offset+Vector2(cell)*cell_size+Vector2.ONE,Vector2.ONE*(cell_size-2)),Color(0.5,0.8,0.8,0.7))
		draw_texture_rect(icon,Rect2(offset+Vector2(C.cells(data.item_id,int(data.rotation))[0])*cell_size+Vector2(6,6),Vector2.ONE*(cell_size-12)),false)
func interactive() -> bool:
	return not allowed.is_valid() or allowed.call()
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	refresh()
func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	tiles.clear()
	custom_minimum_size=Vector2(dimensions)*cell_size
	size=custom_minimum_size
	for index in range(items.size()):
		var tile=ItemTile.new()
		tile.grid=self
		tile.index=index
		tile.icon=load(C.item(items[index].id).icon)
		tile.position=Vector2(int(items[index].x),int(items[index].y))*cell_size
		tile.size=Vector2(C.bounds(items[index].id,int(items[index].get("rot",0))))*cell_size
		tile.tooltip_text=C.item(items[index].id).name+"\n"+C.item(items[index].id).desc+"\n拖拽移动 · 拖拽时 R 旋转"
		add_child(tile)
		tiles[index]=tile
	queue_redraw()
func refresh_selection() -> void:
	for tile in tiles.values():tile.queue_redraw()
func drop_position(point: Vector2,data: Dictionary) -> Vector2i:
	return Vector2i(Vector2(floorf(point.x/cell_size),floorf(point.y/cell_size)))-Vector2i(data.get("anchor",Vector2i.ZERO))
func _can_drop_data(point: Vector2,data: Variant) -> bool:
	return interactive() and data is Dictionary and data.has_all(["index","rotation"]) and can_place.is_valid() and can_place.call(data,drop_position(point,data),int(data.rotation))
func _drop_data(point: Vector2,data: Variant) -> void:
	if _can_drop_data(point,data) and place_item.call(data,drop_position(point,data),int(data.rotation)):
		moved.emit()
func _input(event: InputEvent) -> void:
	if not interactive() or not event is InputEventKey or event.physical_keycode!=KEY_R or not event.pressed or event.echo or not get_viewport().gui_is_dragging():return
	var data=get_viewport().gui_get_drag_data()
	if not data is Dictionary or not data.has_all(["rotation","item_id"]):return
	# Only the source inventory handles R, avoiding one rotation per visible grid.
	if not data.get("grid_source",0)==get_instance_id():return
	var bounds=C.bounds(data.item_id,int(data.rotation))
	var anchor=Vector2i(data.get("anchor",Vector2i.ZERO))
	data.anchor=Vector2i(bounds.y-1-anchor.y,anchor.x)
	data.rotation=posmod(int(data.rotation)+1,4)
	get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:queue_redraw()
func _draw() -> void:
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			var rect=Rect2(Vector2(x,y)*cell_size+Vector2.ONE,Vector2.ONE*(cell_size-2))
			draw_rect(rect,Color("102630"))
			draw_rect(rect,Color("304d58"),false)
	if not get_viewport().gui_is_dragging():return
	var data=get_viewport().gui_get_drag_data()
	if not data is Dictionary or not data.has_all(["item_id","rotation"]) or not Rect2(Vector2.ZERO,size).has_point(get_local_mouse_position()):return
	var origin=drop_position(get_local_mouse_position(),data)
	var tint=Color(0.35,0.9,0.65,0.6) if _can_drop_data(get_local_mouse_position(),data) else Color(1,0.3,0.3,0.6)
	for cell in C.cells(data.item_id,int(data.rotation)):
		draw_rect(Rect2(Vector2(origin+cell)*cell_size+Vector2.ONE,Vector2.ONE*(cell_size-2)),tint)
