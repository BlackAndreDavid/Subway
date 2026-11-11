extends Control
const Fog=preload("res://scripts/fog_of_war.gd")
const NORMAL_ALPHA=0.5
const HOLD_SECONDS=2.0
const EXPLORED_COLOR=Color("c0c4ca")
const FRONTIER_COLOR=Color("424850")
const CURRENT_COLOR=Color("efc778")
var font: Font
var tab_held=false
var hold_elapsed=0.0
var can_use: Callable
func _ready() -> void:
	custom_minimum_size=Vector2(320,190)
	font=ThemeDB.fallback_font
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	modulate.a=NORMAL_ALPHA
func enabled() -> bool:
	return not Game.run.is_empty() and (not can_use.is_valid() or can_use.call())
func reset_hold() -> void:
	tab_held=false
	hold_elapsed=0.0
	modulate.a=NORMAL_ALPHA
	queue_redraw()
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.physical_keycode!=KEY_TAB:return
	if not enabled():
		reset_hold()
		return
	if not event.is_echo():
		tab_held=event.pressed
		if not tab_held:reset_hold()
	get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:reset_hold()
func advance_hold(delta: float) -> void:
	if not enabled():
		reset_hold()
		return
	if tab_held:hold_elapsed+=delta
	modulate.a=1.0 if tab_held and hold_elapsed>=HOLD_SECONDS else NORMAL_ALPHA
func _process(delta: float) -> void:
	advance_hold(delta)
	queue_redraw()
func visible_rooms() -> Dictionary:
	if Game.run.is_empty():return {}
	return Fog.visibility(Game.run.floor_data.rooms,int(Game.run.room))
func layout_for(visible: Dictionary) -> Dictionary:
	# Hidden cells never contribute to the bounds or reveal the full map's shape.
	var lo=Vector2(INF,INF)
	var hi=Vector2(-INF,-INF)
	for id in visible:
		var room: Dictionary=Game.run.floor_data.rooms[id]
		for cell in room.get("cells",[room.pos]):
			lo=lo.min(Vector2(cell))
			hi=hi.max(Vector2(cell))
	var span=hi-lo+Vector2.ONE
	var cell=minf(24,minf((size.x-32)/span.x,(size.y-55)/span.y))
	return {"cell":cell,"center":(lo+hi)/2,"origin":Vector2(size.x/2,(size.y+10)/2)}
func location(pos: Vector2i,layout: Dictionary) -> Vector2:
	return layout.origin+(Vector2(pos)-layout.center)*float(layout.cell)
func _draw() -> void:
	if not enabled():return
	draw_style_box(background(),Rect2(Vector2.ZERO,size))
	var visible=visible_rooms()
	if visible.is_empty():return
	var layout=layout_for(visible)
	var rooms: Array=Game.run.floor_data.rooms
	for id in visible:
		for neighbor in rooms[id].links:
			if neighbor>id and visible.has(neighbor) and (rooms[id].visited or rooms[neighbor].visited):
				var portal: Dictionary=rooms[id].doors[neighbor]
				draw_line(location(portal.cell,layout),location(portal.cell+portal.normal,layout),Color("77818c"),2)
	var radius=minf(8,float(layout.cell)*0.38)
	for id in visible:
		var color=CURRENT_COLOR if visible[id]=="current" else EXPLORED_COLOR if visible[id]=="explored" else FRONTIER_COLOR
		var cells: Array=rooms[id].get("cells",[rooms[id].pos])
		for cell in cells:
			var p=location(cell,layout)
			draw_rect(Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2),color)
			for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
				if cells.has(cell+direction):
					var end=location(cell+direction,layout)
					draw_line(p,end,color,radius*2)
			if visible[id]=="current":
				for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					if cells.has(cell+direction):continue
					var center=p+Vector2(direction)*(radius+2)
					var extent=Vector2(0,radius+2) if direction.x!=0 else Vector2(radius+2,0)
					draw_line(center-extent,center+extent,CURRENT_COLOR,1)
	draw_string(font,Vector2(12,22),"探索地图",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("dde1e0"))
	draw_string(font,Vector2(12,size.y-10),"长按 Tab 2 秒看清 · 松开还原",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a7b2b6"))
func background() -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=Color("10232d")
	style.set_corner_radius_all(8)
	return style
