extends RefCounted
const Art=preload("res://scripts/art_library.gd")
# Shared by actual combat and the native-render regression, so the latter checks
# engine mirror/rotation semantics rather than merely repeating coordinate math.
static func draw(canvas: CanvasItem,battle: Control,enemy: Dictionary,position: Vector2,scale_factor: float,frame: int=-1) -> void:
	var index=battle.enemy_frame(enemy) if frame<0 else frame
	canvas.draw_set_transform(position,battle.enemy_rotation(enemy),Vector2(-scale_factor if battle.enemy_flipped(enemy) else scale_factor,scale_factor))
	canvas.draw_texture_rect(Art.texture("enemies/%d" % int(enemy.type),index),battle.enemy_sprite_rect(enemy,index),false)
