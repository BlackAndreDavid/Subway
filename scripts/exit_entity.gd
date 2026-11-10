extends Node2D
const Art=preload("res://scripts/art_library.gd")
@export_enum("descent","return") var action="descent"
var highlighted=false
const INTERACT_DISTANCE=64.0
func in_range(player: Vector2) -> bool:
	return player.distance_to(position)<=INTERACT_DISTANCE
func _draw() -> void:
	var accent=Color("8bc9bf") if action=="descent" else Color("d1a864")
	draw_rect(Rect2(-43,-40,86,68),Color("10242e"))
	draw_rect(Rect2(-43,-40,86,68),accent if highlighted else Color("34515a"),false,2)
	if action=="descent":
		# Pixel-aligned stairwell geometry uses the same flat palette as the sprites.
		for step in range(4):
			var width=64-step*10
			draw_rect(Rect2(-width/2,-28+step*12,width,8),Color("34515a"))
			draw_line(Vector2(-width/2,-28+step*12),Vector2(width/2,-28+step*12),accent,2)
		draw_colored_polygon(PackedVector2Array([Vector2(-4,-25),Vector2(4,-25),Vector2(4,-10),Vector2(10,-10),Vector2(0,1),Vector2(-10,-10),Vector2(-4,-10)]),accent)
	else:
		draw_texture_rect(Art.texture("station"),Rect2(-32,-40,64,64),false)
		draw_rect(Rect2(-5,-30,10,5),accent)
	var title="下一层" if action=="descent" else "返回基地"
	draw_string(ThemeDB.fallback_font,Vector2(-72,-52),title,HORIZONTAL_ALIGNMENT_CENTER,144,17,accent)
	if highlighted:
		draw_rect(Rect2(-12,-98,24,22),accent)
		draw_string(ThemeDB.fallback_font,Vector2(-12,-81),"F",HORIZONTAL_ALIGNMENT_CENTER,24,16,Color("10242e"))
