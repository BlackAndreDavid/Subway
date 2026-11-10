extends SceneTree
const Visual=preload("res://scripts/enemy_visual.gd")
class Probe extends Node2D:
	var battle: Control
	var enemy: Dictionary={}
	var frame_index=0
	var scale_factor=1.0
	func _draw() -> void:
		if not enemy.is_empty():Visual.draw(self,battle,enemy,Vector2(128,128),scale_factor,frame_index)
func _initialize() -> void:
	if OS.get_environment("SUBWAY_TEST_MODE")!="1":
		push_error("Set SUBWAY_TEST_MODE=1 and use isolated XDG directories")
		quit(1)
		return
	call_deferred("verify")
func verify() -> void:
	var game=root.get_node("Game")
	game.new_game(2,"原生贴图中心检查")
	game.begin_run(0,"","","",2026)
	var battle=load("res://scenes/exploration/room.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.hide()
	var viewport=SubViewport.new()
	viewport.size=Vector2i(256,256)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe=Probe.new()
	probe.battle=battle
	viewport.add_child(probe)
	var checks=0
	var failures=0
	for type in range(5):
		probe.enemy=battle.make_enemy(type,Vector2.ZERO)
		for frame in range(4):
			probe.frame_index=frame
			for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				probe.enemy.facing=direction
				for scale_factor in [1.0,1.5]:
					probe.scale_factor=scale_factor
					probe.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					var rendered=viewport.get_texture().get_image()
					var bound=rendered.get_used_rect()
					checks+=1
					if not bound.has_area() or Rect2(bound).get_center().distance_to(Vector2(128,128))>1.5:
						failures+=1
						push_error("Native sprite center type %d frame %d direction %s scale %.1f bounds %s" % [type,frame,direction,scale_factor,bound])
	game.end_run(false)
	battle.queue_free()
	viewport.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	DirAccess.make_dir_recursive_absolute("res://work")
	var report=FileAccess.open("res://work/native-alignment-report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":"native X11 OpenGL, transparent SubViewport readback","types":5,"frames_per_type":4,"headings_per_frame":4,"scales":[1.0,1.5],"tolerance_pixels":1.5},"\t"))
	report.close()
	print("NATIVE ALIGNMENT: %d rendered frame/heading/scale checks; %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
