extends Control
signal station_selected(index: int)
signal furniture_changed
var mode="base"
var selected_station=0
var placing=false
var furniture_type=0
var hover=-1
var preview=Vector2i(-1,-1)
var dragging: Dictionary = {}
const C=preload("res://scripts/catalog.gd")
var font: Font
var textures: Dictionary = {}
func _ready() -> void:
	font=ThemeDB.fallback_font
	for path in ["res://assets/furniture/crate.svg","res://assets/player/2_0.svg"]:
		textures[path]=load(path)
	mouse_filter=Control.MOUSE_FILTER_STOP
	queue_redraw()
func iso(x: float,y: float) -> Vector2:
	return Vector2(435+(x-y)*41,140+(x+y)*22)
func tile_at(p: Vector2) -> Vector2i:
	var q=p-Vector2(435,140)
	return Vector2i(floori((q.x/41+q.y/22)/2),floori((q.y/22-q.x/41)/2))
func _gui_input(event: InputEvent) -> void:
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
	else: draw_base()
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
		var tint=[Color("e8bd82"),Color("91d3ce"),Color("b5a2cd"),Color("a3c585")][int(item.type)]
		draw_texture_rect(textures["res://assets/furniture/crate.svg"],Rect2(p-Vector2(32,58),Vector2(64,64)),false,tint)
	if placing and preview.x>=0 and preview.x<10 and preview.y>=0 and preview.y<6:
		var p=iso(preview.x,preview.y)
		draw_colored_polygon(PackedVector2Array([p,iso(preview.x+1,preview.y),iso(preview.x+1,preview.y+1),iso(preview.x,preview.y+1)]),Color(0.55,0.9,0.85,0.45))
	draw_texture_rect(textures["res://assets/player/2_0.svg"],Rect2(iso(5,3)-Vector2(28,53),Vector2(56,56)),false)
	text_at(Vector2(30,size.y-55),"布置模式：左键放置 · 拖动已有家具 · 右键回收 · 同格不可重叠" if placing else "车窗外，是仍在呼吸的地下城市。",Color("8da8b1"),17)
	text_at(Vector2(30,size.y-28),"每日消耗   2 水 / 2 食物 / 5 电量     ·     基地操作后自动保存",Color("5f8390"),14)
func draw_map() -> void:
	text_at(Vector2(30,42),"SHANGHAI / 地下交通网",Color("b5dfdb"),22)
	text_at(Vector2(30,70),"悬停查看站点信息 · 点击选择目的地",Color("678590"),15)
	for pair in [[0,1],[1,2],[0,3],[3,4],[2,5],[3,2]]:
		var a: Vector2=C.STATIONS[pair[0]].pos
		var b: Vector2=C.STATIONS[pair[1]].pos
		draw_line(a,b,Color("385965"),14,true)
		draw_line(a,b,Color("6facae") if pair[0]%2==0 else Color("a18cb9"),5,true)
	for i in range(C.STATIONS.size()):
		var station=C.STATIONS[i]
		var p: Vector2=station.pos
		if i==selected_station: draw_circle(p,25,Color(0.93,0.72,0.42,0.18))
		draw_circle(p,12,Color("efc58d") if i==int(Game.state.station) else Color("b3d7d4"))
		draw_circle(p,5,Color("18343f"))
		text_at(p+Vector2(-30,-29),station.name,Color("f0c78f") if i==selected_station else Color("c0d3d3"),18)
		if i==int(Game.state.station): text_at(p+Vector2(-25,37),"当前站点",Color("e4b97e"),14)
	text_at(Vector2(30,size.y-30),"示意线路 · 单次移动消耗 6–21 电量 · 各站价格与辐射不同",Color("668994"),14)
