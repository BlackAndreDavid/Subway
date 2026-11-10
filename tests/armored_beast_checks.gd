extends RefCounted
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	game.new_game(0,"甲壳兽行为")
	game.begin_run(0,"5_0","4_0","3_0",2026)
	ui.show_combat()
	await tree.process_frame
	var battle=ui.battle
	battle.set_process(false)
	var rat=battle.make_enemy(0,Vector2(300,300))
	var beast=battle.make_enemy(3,Vector2(300,300))
	check.call(beast.max==110 and beast.max>rat.max*3 and beast.armor==0.4 and rat.armor==0,"shell beast has substantially higher health and real armor")
	for type in [0,3]:
		var enemy=battle.make_enemy(type,Vector2(400,300))
		for heading in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized()]:
			battle.update_enemy_facing(enemy,heading*10,0.1)
			check.call(battle.enemy_rotation(enemy)==0 and absf(enemy.facing.x)==1 and enemy.facing.y==0,"animal sprite stays upright with horizontal facing only")
	battle.player=Vector2(650,300)
	battle.enemies=[beast]
	battle.update_enemies(0.4)
	check.call(beast.pos==Vector2(300,300) and beast.state=="idle","shell beast waits instead of continuously pursuing")
	battle.enemies=[rat]
	battle.update_enemies(0.4)
	check.call(rat.pos.x>330 and rat.travel.length()>30,"rat retains continuous pursuit")
	battle.enemies=[beast]
	beast.timer=0.05
	battle.update_enemies(0.1)
	check.call(beast.state=="windup" and beast.pos==Vector2(300,300),"idle transitions into a stationary telegraph")
	battle.update_enemies(battle.SHELL_WINDUP_TIME+0.01)
	check.call(beast.state=="charge" and beast.timer==battle.SHELL_CHARGE_TIME,"telegraph starts the long charge")
	var original_direction: Vector2=beast.charge_dir
	battle.player=Vector2(650,350)
	battle.update_enemies(0.5)
	var turned=absf(original_direction.angle_to(beast.charge_dir))
	check.call(beast.travel.length()>170 and beast.state=="charge","charge covers a long distance at high speed")
	check.call(turned>0 and turned<=battle.SHELL_TURN_RATE*0.5+0.0001,"charge tracks slightly within a fixed angular speed limit")
	check.call(beast.facing==Vector2.RIGHT and battle.enemy_rotation(beast)==0,"tracking bends the path without rotating the sprite")
	battle.player=Vector2(790,360)
	battle.update_enemies(0.75)
	check.call(beast.pos.distance_to(Vector2(300,300))>400,"charge remains sustained beyond the former short dash")
	battle.update_enemies(0.4)
	check.call(beast.state=="recovery" and beast.velocity==Vector2.ZERO,"wall impact stops charge and starts recovery")
	var stopped: Vector2=beast.pos
	battle.update_enemies(0.4)
	check.call(beast.pos==stopped and beast.state=="recovery","recovery remains stationary")
	battle.update_enemies(0.61)
	check.call(beast.state=="idle" and beast.timer==battle.SHELL_IDLE_TIME,"recovery returns to an idle interval")
	var armored=battle.make_enemy(3,Vector2(350,300))
	check.call(is_equal_approx(battle.damage_enemy(armored,50),30) and armored.hp==80,"forty percent armor reduces incoming damage")
	var unarmored=battle.make_enemy(0,Vector2(350,300))
	check.call(battle.damage_enemy(unarmored,10)==10 and unarmored.hp==22,"rat does not inherit shell armor")
	armored=battle.make_enemy(3,Vector2(350,300))
	battle.enemies=[armored]
	battle.bullets=[]
	battle.shoot(armored.pos,Vector2.RIGHT,false,50,500)
	battle.update_bullets(0.001)
	check.call(armored.hp==80,"real projectiles obey enemy armor")
	battle.player=Vector2(450,300)
	game.run.weapon_cd=0
	battle.use_weapon()
	check.call(armored.hp==53,"active area damage also obeys enemy armor")
	game.end_run(false)
	ui.show_base()
	await tree.process_frame
