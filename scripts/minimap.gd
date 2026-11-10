extends Control
signal selected(id: int)
var font: Font
func _ready() -> void:
	custom_minimum_size=Vector2(320,190)
	font=ThemeDB.fallback_font
	mouse_filter=Control.MOUSE_FILTER_STOP
func location(p: Vector2i) -> Vector2:
	return Vector2(24+(p.x+5)*24,95+p.y*31)
func _draw() -> void:
	if Game.run.is_empty(): return
	var rooms: Array=Game.run.floor_data.rooms
	for r in rooms:
		for id in r.links:
			if id>r.id: draw_line(location(r.pos),location(rooms[id].pos),Color("3e626c"),2)
	for r in rooms:
		var c=Color("3c535c")
		match r.kind:
			"start":c=Color("87bdac")
			"reward":c=Color("d6ba7c")
			"shop":c=Color("ad9dc8")
			"boss":c=Color("c77e73")
		if r.visited and r.kind=="normal":c=Color("7bacae")
		var p=location(r.pos)
		draw_rect(Rect2(p-Vector2(7,7),Vector2(14,14)),c)
		if int(r.id)==int(Game.run.room):draw_rect(Rect2(p-Vector2(10,10),Vector2(20,20)),Color("e7e7bf"),false,2)
	draw_string(font,Vector2(7,183),"起点 · 奖励 · 商店 · Boss   |   点击相邻房间通行",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("83a2ab"))
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for r in Game.run.floor_data.rooms:
			if location(r.pos).distance_to(event.position)<13:
				selected.emit(r.id)
				break
