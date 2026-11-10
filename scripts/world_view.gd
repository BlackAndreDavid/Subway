extends Control
signal station_selected(index: int)
signal furniture_changed
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
func _ready() -> void:
	font=ThemeDB.fallback_font
	if mode=="map":
		map_texture=load("res://assets/maps/shanghai_metro.png")
		clip_contents=true
		call_deferred("reset_map")
	mouse_filter=Control.MOUSE_FILTER_STOP
	queue_redraw()
func base_scale() -> float:
	return minf(size.x/900.0,size.y/610.0) if size.x>0 and size.y>0 else 1.0
func base_offset() -> Vector2:
	return (size-Vector2(900,610)*base_scale())/2
func base_to_screen(point: Vector2) -> Vector2:
	return base_offset()+point*base_scale()
func iso(x: float,y: float) -> Vector2:
	return Vector2(435+(x-y)*41,140+(x+y)*22)
func tile_at(p: Vector2) -> Vector2i:
	var q=p-Vector2(435,140)
	return Vector2i(floori((q.x/41+q.y/22)/2),floori((q.y/22-q.x/41)/2))
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
		var free=target.x>=0 and target.x<10 and target.y>=0 and target.y<6
		for item in Game.state.furniture:
			if item!=dragging and int(item.x)==target.x and int(item.y)==target.y:free=false
		if free:
			dragging.x=target.x
			dragging.y=target.y
			Game.save_game()
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
					if int(item.x)==tile.x and int(item.y)==tile.y: Game.state.furniture.erase(item)
			elif event.button_index==MOUSE_BUTTON_LEFT:
				for item in Game.state.furniture:
					if int(item.x)==tile.x and int(item.y)==tile.y:
						dragging=item
						return
				Game.state.furniture.append({"x":tile.x,"y":tile.y,"type":furniture_type})
			Game.save_game()
			furniture_changed.emit()
			queue_redraw()
func _draw() -> void:
	draw_style_box(panel_style(),Rect2(Vector2.ZERO,size))
	if Game.state.is_empty(): return
	if mode=="map": draw_map()
	else:
		draw_set_transform(base_offset(),0,Vector2.ONE*base_scale())
		draw_base()
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
	text_at(Vector2(30,42),"CAR / 07     车厢基地",Color("b5dfdb"),22)
	text_at(Vector2(30,70),"上海地下交通共同体 · 自由线路",Color("678590"),15)
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
	var furniture: Array=Game.state.furniture.duplicate()
	furniture.sort_custom(func(a,b):return a.x+a.y<b.x+b.y)
	for item in furniture:
		var p=iso(float(item.x)+0.5,float(item.y)+0.5)
		draw_texture_rect(Art.texture("furniture/%d" % int(item.type)),Rect2(p-Vector2(32,58),Vector2(64,64)),false)
	if placing and preview.x>=0 and preview.x<10 and preview.y>=0 and preview.y<6:
		var p=iso(preview.x,preview.y)
		draw_colored_polygon(PackedVector2Array([p,iso(preview.x+1,preview.y),iso(preview.x+1,preview.y+1),iso(preview.x,preview.y+1)]),Color(0.55,0.9,0.85,0.45))
	draw_texture_rect(Art.texture("player/2"),Rect2(iso(5,3)-Vector2(28,53),Vector2(56,56)),false)
	text_at(Vector2(30,555),"布置模式：左键放置 · 拖动已有家具 · 右键回收 · 同格不可重叠" if placing else "车窗外，是仍在呼吸的地下城市。",Color("8da8b1"),17)
	text_at(Vector2(30,582),"每日消耗   2 水 / 2 食物 / 5 电量     ·     基地操作后自动保存",Color("5f8390"),14)
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
