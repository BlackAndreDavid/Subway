extends SceneTree
class Probe extends Node2D:
 var battle: Control
 func _draw() -> void:
  for enemy in [false,true]:
   for index in range(4):
    battle.draw_bullet(self,{"enemy":enemy,"vel":Vector2.UP.rotated(index*PI/2)},Vector2(100+index*200,100+(200 if enemy else 0)),3)
func _initialize() -> void:
 if OS.get_environment("SUBWAY_TEST_MODE")!="1":quit(1);return
 call_deferred("run")
func run() -> void:
 var game=root.get_node("Game")
 game.new_game(2,"子弹原生检查")
 game.begin_run(0,"","","",2026)
 var battle=load("res://scenes/exploration/room.tscn").instantiate()
 root.add_child(battle)
 battle.set_process(false)
 battle.hide()
 var viewport=SubViewport.new()
 viewport.size=Vector2i(800,400)
 viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var probe=Probe.new()
 probe.battle=battle
 viewport.add_child(probe)
 await process_frame
 await RenderingServer.frame_post_draw
 var rendered=viewport.get_texture().get_image()
 var failures=0
 for y in [100,300]:
  for x in [100,300,500,700]:
   var bounds=rendered.get_region(Rect2i(x-80,y-80,160,160)).get_used_rect()
   if not bounds.has_area() or Rect2(bounds).get_center().distance_to(Vector2(80,80))>1.5:failures+=1
 rendered.save_png("res://docs/bullet_headings.png")
 print("NATIVE BULLETS: 8 rendered direction/type checks; ",failures," failures")
 game.end_run(false)
 battle.queue_free()
 viewport.queue_free()
 await process_frame
 await create_timer(0.2).timeout
 quit(1 if failures else 0)
