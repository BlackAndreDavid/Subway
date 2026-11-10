extends Control
signal station_selected(index: int)
signal furniture_changed
signal notice(text: String)
signal facility_requested(info: Dictionary)
@export_enum("base","map") var mode="base"
var selected_station=0
var placing=false
var furniture_type=0
var hover=-1
var preview=Vector2i(-1,-1)
var dragging: Dictionary = {}
const Art=preload("res://scripts/art_library.gd")
const Metro=preload("res://scripts/metro.gd")
const MapData=preload("res://scripts/metro_data.gd")
const C=preload("res://scripts/catalog.gd")
var map_texture: Texture2D
var map_zoom=0.38
var map_pan=Vector2(70,105)
var line_filter=""
var panning=false
var font: Font
var entities: Node2D
var heroine: Node2D
var interaction_allowed: Callable
const BASE_BOUNDS=Rect2(180,35,680,465)
func _ready() -> void:
	font=ThemeDB.fallback_font
	if mode=="map":
		map_texture=load("res://assets/maps/shanghai_metro.png")
		clip_contents=true
		call_deferred("reset_map")
	elif not Game.state.is_empty():
		entities=Node2D.new()
		entities.y_sort_enabled=true
		add_child(entities)
		heroine=preload("res://scenes/base/heroine.tscn").instantiate()
		entities.add_child(heroine)
		if occupied(heroine.grid_position):
			var distance=INF
			for x in range(10):
				for y in range(6):
					var point=Vector2(x+0.5,y+0.5)
					if not occupied(point) and point.distance_to(Game.base_position)<distance:
						distance=point.distance_to(Game.base_position)
						heroine.grid_position=point
		heroine.position=iso(heroine.grid_position.x,heroine.grid_position.y)
		refresh_furniture()
	mouse_filter=Control.MOUSE_FILTER_STOP
	queue_redraw()
func base_scale() -> float:
	return minf((size.x-50)/BASE_BOUNDS.size.x,(size.y-70)/BASE_BOUNDS.size.y) if size.x>50 and size.y>70 else 1.0
func base_offset() -> Vector2:
	return size/2-BASE_BOUNDS.get_center()*base_scale()
func base_to_screen(point: Vector2) -> Vector2:
	return base_offset()+point*base_scale()
func iso(x: float,y: float) -> Vector2:
	return Vector2(435+(x-y)*41,140+(x+y)*22)
func tile_at(p: Vector2) -> Vector2i:
	var q=p-Vector2(435,140)
	return Vector2i(floori((q.x/41+q.y/22)/2),floori((q.y/22-q.x/41)/2))
func occupied(point: Vector2) -> bool:
	for item in Game.state.furniture:
		if Rect2(float(item.x)-0.1,float(item.y)-0.1,1.2,1.2).has_point(point):return true
	return Rect2(0,4,1,1).has_point(point)
func refresh_furniture() -> void:
	if not is_instance_valid(entities):return
	for child in entities.get_children():
		if child!=heroine:
			entities.remove_child(child)
			child.queue_free()
	for item in Game.state.furniture:
		var node=preload("res://scenes/base/furniture.tscn").instantiate()
		node.furniture_type=int(item.type)
		node.position=iso(float(item.x)+0.5,float(item.y)+0.5)
		entities.add_child(node)
	var terminal=preload("res://scenes/base/furniture.tscn").instantiate()
	terminal.furniture_type=1
	terminal.position=iso(0.5,4.5)
	entities.add_child(terminal)
func facilities() -> Array:
	var result: Array=[{"name":"站点终端","pos":Vector2(0.5,4.5),"kind":"terminal","thought":"这台终端又在嗡嗡作响。至少线路图还看得清，工具也能借来合成家具。"},{"name":"车窗","pos":Vector2(5,0.3),"kind":"window","thought":"窗外的天气真糟糕。还好这节车厢没有漏雨。"},{"name":"气闸门","pos":Vector2(9.5,0.5),"kind":"explore","thought":"手套戴好了。等准备妥当，再去地表找点有用的东西。"}]
	for item in Game.state.furniture:
		var type=int(item.type)
		result.append({"name":C.FURNITURE_NAMES[type],"pos":Vector2(float(item.x)+0.5,float(item.y)+0.5),"kind":["stash","craft","rest","plants"][type],"thought":["这个箱子很旧了。不过锁扣还牢，战利品交给它保管吧。","废零件也有第二次机会。这里可以把材料拼成实用家具。","能在安静的地方伸个懒腰，就已经很好了。","叶子又绿了一点。总有一天，我们不用再靠压缩饼干过日子。"][type]})
	return result
func nearest_facility() -> Dictionary:
	if not is_instance_valid(heroine):return {}
	var closest: Dictionary={}
	var distance=75.0
	var point=iso(heroine.grid_position.x,heroine.grid_position.y)
	for facility in facilities():
		var delta=point.distance_to(iso(facility.pos.x,facility.pos.y))
		if delta<distance:
			distance=delta
			closest=facility
	return closest
func can_interact() -> bool:
	return mode=="base" and not placing and is_instance_valid(heroine) and not heroine.changing_suit() and (not interaction_allowed.is_valid() or interaction_allowed.call())
func _process(delta: float) -> void:
	if mode!="base" or not is_instance_valid(heroine):return
	entities.position=base_offset()
	entities.scale=Vector2.ONE*base_scale()
	var movement=Vector2.ZERO
	if can_interact():movement=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).normalized()
	if interaction_allowed.is_valid() and not interaction_allowed.call():
		heroine.advance(0,Vector2.ZERO)
		return
	var screen_delta=movement*170*delta
	var step=Vector2((screen_delta.x/41+screen_delta.y/22)/2,(screen_delta.y/22-screen_delta.x/41)/2)
	var point: Vector2=heroine.grid_position
	var before=iso(point.x,point.y)
	var next=(point+Vector2(step.x,0)).clamp(Vector2(0.25,0.25),Vector2(9.75,5.75))
	if not occupied(next):point.x=next.x
	next=(point+Vector2(0,step.y)).clamp(Vector2(0.25,0.25),Vector2(9.75,5.75))
	if not occupied(next):point.y=next.y
	heroine.grid_position=point
	heroine.position=iso(point.x,point.y)
	Game.base_position=point
	heroine.advance(delta,(heroine.position-before).normalized())
	queue_redraw()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.physical_keycode!=KEY_F or not event.pressed or event.echo or not can_interact():return
	var facility=nearest_facility()
	if not facility.is_empty():facility_requested.emit(facility)
	else:notice.emit("靠近设施后按 F 查看。")
	get_viewport().set_input_as_handled()
func map_point(index: int) -> Vector2:
	return map_pan+C.STATIONS[index].pos*map_zoom
func reset_map() -> void:
	map_zoom=minf((size.x-60)/MapData.CANVAS.x,(size.y-150)/MapData.CANVAS.y)
	map_pan=Vector2((size.x-MapData.CANVAS.x*map_zoom)/2,105)
	queue_redraw()
func center_station(index: int) -> void:
	selected_station=index
	map_zoom=maxf(map_zoom,0.8)
	map_pan=Vector2(size.x/2,(size.y+85)/2)-C.STATIONS[index].pos*map_zoom
	queue_redraw()
func nearest_station(position: Vector2) -> int:
	var nearest=-1
	var distance=13.0
	for i in range(C.STATIONS.size()):
		if line_filter!="" and not C.STATIONS[i].lines.has(line_filter):continue
		var current=map_point(i).distance_to(position)
		if current<distance:
			nearest=i
			distance=current
	return nearest
func _gui_input(event: InputEvent) -> void:
	if mode=="map":
		if event is InputEventMouseMotion:
			if panning:map_pan+=event.relative
			hover=nearest_station(event.position)
			tooltip_text="" if hover<0 else "%s\n%s\n地下客流 %d（游戏） · 辐射 %d（游戏）\n产出：%s" % [C.STATIONS[hover].name,Metro.lines_for(hover),C.STATIONS[hover].traffic,C.STATIONS[hover].radiation,C.STATIONS[hover].yield]
			queue_redraw()
		elif event is InputEventMouseButton:
			if event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:panning=event.pressed
			if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				var before=(event.position-map_pan)/map_zoom
				map_zoom=clampf(map_zoom*(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.2),0.25,2.3)
				map_pan=event.position-before*map_zoom
				queue_redraw()
			elif event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
				var index=nearest_station(event.position)
				if index>=0:
					selected_station=index
					station_selected.emit(index)
					queue_redraw()
		return
	event=event.duplicate()
	if event is InputEventMouse:
		event.position=(event.position-base_offset())/base_scale()
	if event is InputEventMouseMotion:
		if mode=="map":
			hover=-1
			for i in range(C.STATIONS.size()):
				if event.position.distance_to(C.STATIONS[i].pos)<27: hover=i
			tooltip_text="" if hover<0 else "%s\n客流 %d 人/日 · 辐射 %d\n产出：%s" % [C.STATIONS[hover].name,C.STATIONS[hover].traffic,C.STATIONS[hover].radiation,C.STATIONS[hover].yield]
		else: preview=tile_at(event.position)
		queue_redraw()
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not dragging.is_empty():
		var target=tile_at(event.position)
		var free=target.x>=0 and target.x<10 and target.y>=0 and target.y<6 and not target in [Vector2i(0,4),Vector2i(9,0)]
		for item in Game.state.furniture:
			if item!=dragging and int(item.x)==target.x and int(item.y)==target.y:free=false
		if free:
			dragging.x=target.x
			dragging.y=target.y
			Game.save_game()
			refresh_furniture()
		dragging={}
		queue_redraw()
	if event is InputEventMouseButton and event.pressed:
		if mode=="map" and event.button_index==MOUSE_BUTTON_LEFT:
			for i in range(C.STATIONS.size()):
				if event.position.distance_to(C.STATIONS[i].pos)<27:
					selected_station=i
					station_selected.emit(i)
					queue_redraw()
		elif placing:
			var tile=tile_at(event.position)
			if tile.x<0 or tile.x>=10 or tile.y<0 or tile.y>=6: return
			if event.button_index==MOUSE_BUTTON_RIGHT:
				for item in Game.state.furniture.duplicate():
					if int(item.x)==tile.x and int(item.y)==tile.y:Game.reclaim_furniture(Game.state.furniture.find(item))
			elif event.button_index==MOUSE_BUTTON_LEFT:
				for item in Game.state.furniture:
					if int(item.x)==tile.x and int(item.y)==tile.y:
						dragging=item
						return
				if not Game.place_furniture(furniture_type,tile):notice.emit(Game.last_error)
			refresh_furniture()
			furniture_changed.emit()
			queue_redraw()
func _draw() -> void:
	draw_style_box(panel_style(),Rect2(Vector2.ZERO,size))
	if Game.state.is_empty(): return
	if mode=="map": draw_map()
	else:
		draw_set_transform(base_offset(),0,Vector2.ONE*base_scale())
		draw_base()
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		text_at(Vector2(24,32),"CAR / 07   车厢基地",Color("b5dfdb"),22)
		var hint="布置：左键放置已合成家具 · 拖动移动 · 右键回收" if placing else "WASD 走动 · 靠近设施按 F 查看"
		if is_instance_valid(heroine) and heroine.changing_suit():hint="返回基地 · 正在脱下外层防护服"
		var facility=nearest_facility() if can_interact() else {}
		if not facility.is_empty():hint="F 查看「%s」   /   WASD 走动" % facility.name
		text_at(Vector2(24,size.y-16),hint,Color("b5c4be"),16)
func panel_style() -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=Color("10242e")
	s.corner_radius_top_left=14
	s.corner_radius_top_right=14
	s.corner_radius_bottom_left=14
	s.corner_radius_bottom_right=14
	return s
func text_at(p: Vector2,t: String,c: Color=Color("8da8b1"),fs: int=16) -> void:
	draw_string(font,p,t,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,c)
func draw_base() -> void:
	# rear walls
	draw_colored_polygon(PackedVector2Array([iso(0,0),iso(10,0),iso(10,0)-Vector2(0,100),iso(0,0)-Vector2(0,100)]),Color("34515a"))
	draw_colored_polygon(PackedVector2Array([iso(0,0),iso(0,6),iso(0,6)-Vector2(0,100),iso(0,0)-Vector2(0,100)]),Color("293e4a"))
	for x in range(1,10,2):
		var p=iso(x,0)-Vector2(0,75)
		draw_rect(Rect2(p,Vector2(56,37)),Color("112b38"))
		draw_line(p+Vector2(3,4),p+Vector2(49,4),Color("83b5bb"),2)
	for x in range(10):
		for y in range(6):
			var p=iso(x,y)
			var poly=PackedVector2Array([p,iso(x+1,y),iso(x+1,y+1),iso(x,y+1)])
			draw_colored_polygon(poly,Color("2a424a") if (x+y)%2==0 else Color("263c44"))
			draw_polyline(PackedVector2Array([p,iso(x+1,y),iso(x+1,y+1)]),Color("34505a"),1)
	var door=iso(9.5,0.5)
	draw_rect(Rect2(door-Vector2(26,90),Vector2(52,90)),Color("172e3c"))
	draw_rect(Rect2(door-Vector2(26,90),Vector2(52,90)),Color("8bc9bf"),false,3)
	var facility=nearest_facility() if can_interact() else {}
	if not facility.is_empty():draw_arc(iso(facility.pos.x,facility.pos.y),30,0,TAU,32,Color("d1a864"),2)
	if placing and preview.x>=0 and preview.x<10 and preview.y>=0 and preview.y<6:
		var p=iso(preview.x,preview.y)
		draw_colored_polygon(PackedVector2Array([p,iso(preview.x+1,preview.y),iso(preview.x+1,preview.y+1),iso(preview.x,preview.y+1)]),Color(0.55,0.9,0.85,0.45))
func draw_map() -> void:
	text_at(Vector2(30,42),"SHANGHAI / 上海地铁主要站点",Color("b5dfdb"),22)
	text_at(Vector2(30,70),"21 条线路 · 110 个站点 · 滚轮缩放 / 右键拖动 / 左键选站",Color("678590"),14)
	if map_texture==null:return
	draw_texture_rect(map_texture,Rect2(map_pan,MapData.CANVAS*map_zoom),false,Color(1,1,1,1 if line_filter=="" else 0.25))
	if line_filter!="":
		for line in MapData.LINES:
			if line.id!=line_filter:continue
			for i in range(line.stations.size()-1):
				draw_line(map_point(line.stations[i]),map_point(line.stations[i+1]),Color(line.color),4,true)
	var route=Metro.route(int(Game.state.station),selected_station)
	for i in range(route.size()-1):draw_line(map_point(route[i]),map_point(route[i+1]),Color(1,0.85,0.5,0.5),5,true)
	var occupied: Array[Rect2]=[]
	var order: Array=[selected_station]
	if hover>=0 and hover!=selected_station:order.append(hover)
	if not order.has(int(Game.state.station)):order.append(int(Game.state.station))
	for i in range(C.STATIONS.size()):
		if not order.has(i):order.append(i)
	for i in order:
		var station=C.STATIONS[i]
		var point=map_point(i)
		if not Rect2(12,90,size.x-24,size.y-125).has_point(point):continue
		var focused=i==selected_station or i==hover or i==int(Game.state.station)
		if line_filter!="" and not station.lines.has(line_filter) and not focused:continue
		if focused:
			draw_circle(point,10,Color("e8bb7a") if i==selected_station else Color("a4d6d1"))
			draw_circle(point,4,Color("142b35"))
		var show_name=focused or (line_filter!="" and station.lines.has(line_filter)) or map_zoom>0.85 or station.name in ["人民广场","徐家汇","陆家嘴","虹桥火车站","滴水湖","迪士尼","上海火车站","朱家角"]
		if not show_name:continue
		var text=station.name+(" · 当前" if i==int(Game.state.station) else "")
		var length=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		var offset=Vector2(12,-12)
		var rect=Rect2(point+offset-Vector2(3,16),Vector2(length+7,24))
		var overlap=false
		for existing in occupied:
			if existing.intersects(rect):overlap=true
		if overlap and not focused:continue
		occupied.append(rect)
		draw_rect(rect,Color(0.04,0.1,0.14,0.9))
		text_at(point+offset,text,Color("e8c48d") if focused else Color("b7cecf"),14)
	draw_rect(Rect2(0,0,size.x,88),Color("10242e"))
	text_at(Vector2(30,42),"SHANGHAI / 上海地铁主要站点",Color("b5dfdb"),22)
	text_at(Vector2(30,70),"21 条线路 · 110 个站点 · 滚轮缩放 / 右键拖动 / 左键选站",Color("678590"),14)
	draw_rect(Rect2(0,size.y-30,size.x,30),Color("10242e"))
	text_at(Vector2(20,size.y-11),"按真实线路顺序压缩的小站省略图 · 非比例尺 · 黄线为拟定路线 · 游戏数值不代表现实",Color("668994"),12)
