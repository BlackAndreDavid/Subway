extends RefCounted
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
 game.new_game(0,"子弹朝向与尺寸")
 game.begin_run(0,"","","",2026)
 ui.show_combat()
 await tree.process_frame
 var battle=ui.battle
 battle.set_process(false)
 for enemy in [false,true]:
  for direction in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2(1,1).normalized(),Vector2(-1,-1).normalized()]:
   battle.bullets=[]
   battle.shoot(Vector2(450,300),direction*3,enemy,10)
   var bullet=battle.bullets[0]
   check.call(is_equal_approx(bullet.vel.length(),184 if enemy else 540),"projectile speed is normalized and enemy speed is reduced twenty percent")
   check.call(Vector2.UP.rotated(battle.bullet_rotation(bullet)).distance_to(direction)<0.0001,"up-facing texture nose follows actual velocity")
   check.call(battle.bullet_size(bullet)==(28 if enemy else 14) and battle.bullet_radius(bullet)==(6 if enemy else 3),"enemy visual dimensions and physical radius double together")
 battle.bullets=[]
 battle.player=Vector2(450,300)
 battle.shoot(Vector2(432,300),Vector2.RIGHT,true,10)
 var hp=game.run.hp
 battle.update_bullets(0)
 check.call(game.run.hp<hp and battle.bullets.is_empty(),"enlarged enemy shot hits at eighteen pixels where the former shot missed")
 var block=Rect2(500,200,48,48)
 battle.geometry.obstacles.clear()
 battle.geometry.obstacles.append(block)
 check.call(battle.geometry.segment_clear(Vector2(450,195),Vector2(600,195),3) and not battle.geometry.segment_clear(Vector2(450,195),Vector2(600,195),6),"doubled enemy radius also blocks tighter obstacle clearances")
 battle.geometry.obstacles.clear()
 battle.bullets=[]
 battle.player=Vector2(700,450)
 battle.shoot(Vector2(450,300),Vector2.RIGHT,true,10)
 battle.update_bullets(0.5)
 check.call(battle.bullets[0].pos.is_equal_approx(Vector2(542,300)),"enemy shot moves ninety-two units in half a second")
 game.end_run(false)
 ui.show_base()
 await tree.process_frame
