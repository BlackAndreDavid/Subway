extends Node2D
const Art=preload("res://scripts/art_library.gd")
@export_range(0,3) var furniture_type=0
func _draw() -> void:
	draw_texture_rect(Art.texture("furniture/%d" % furniture_type),Rect2(-32,-58,64,64),false)
