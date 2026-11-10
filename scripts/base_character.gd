extends Node2D
const Art=preload("res://scripts/art_library.gd")
var grid_position=Vector2(5,3)
var direction=2
var walk_time=0.0
var undress_elapsed=10.0
const UNDRESS_DURATION=8.0/7.0
func _ready() -> void:
	grid_position=Game.base_position
	if Game.base_arrival:
		undress_elapsed=0
		Game.base_arrival=false
func changing_suit() -> bool:return undress_elapsed<UNDRESS_DURATION
func advance(delta: float,movement: Vector2) -> void:
	if changing_suit():undress_elapsed+=delta
	elif movement.length_squared()>0.01:
		walk_time+=delta
		direction=(0 if movement.x<0 else 1) if absf(movement.x)>absf(movement.y) else (3 if movement.y<0 else 2)
	else:walk_time=0
	queue_redraw()
func current_texture() -> Texture2D:
	if changing_suit():return Art.texture("base/undress",mini(7,int(undress_elapsed*7)))
	return Art.texture("base/heroine/%d" % direction,Art.frames_at_time("base/heroine/%d" % direction,walk_time))
func _draw() -> void:
	draw_texture_rect(current_texture(),Rect2(-40,-72.5,80,80),false)
