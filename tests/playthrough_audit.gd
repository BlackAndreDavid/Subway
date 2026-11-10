extends SceneTree
# Fixed-input automated play sessions against the actual combat loop.
# No health, enemy damage, timer, collision or drop overrides.
const C=preload("res://scripts/catalog.gd")
var game: Node
var failed=false
var finished=false
var key_states={}
var rows: Array=[]
func _initialize() -> void:
	if OS.get_environment("SUBWAY_TEST_MODE")!="1":
		push_error("Use an isolated test data directory with SUBWAY_TEST_MODE=1")
		quit(1)
		return
	call_deferred("audit")
func key(code: int,pressed: bool) -> void:
	if key_states.get(code,false)==pressed:return
	key_states[code]=pressed
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
func tap(code: int) -> void:
	key(code,true)
	Input.flush_buffered_events()
	key(code,false)
func release_inputs() -> void:
	for code in key_states.keys():key(code,false)
	var button=InputEventMouseButton.new()
	button.button_index=MOUSE_BUTTON_LEFT
	button.pressed=false
	Input.parse_input_event(button)
	Input.flush_buffered_events()
func audit() -> void:
	game=root.get_node("Game")
	root.size=Vector2i(1440,900)
	for station in [0,3,5]:
		for class_index in range(3):
			game.new_game(0,"自动操作验收")
			game.state.station=station
			var start_power=float(game.state.power)
			if not game.begin_run(class_index,"5_0","4_1","3_0",2026):
				push_error(game.last_error)
				quit(1)
				return
			var battle=load("res://scripts/combat.gd").new()
			battle.size=Vector2(900,600)
			finished=false
			battle.ended.connect(func(_success):finished=true)
			root.add_child(battle)
			battle.set_process(false)
			await process_frame
			var initial_time=float(game.run.timer)
			var route: Array=game.run.floor_data.route.duplicate()
			var step=1
			var ticks=0
			var cleared=0
			var recovered=0
			var previous={}
			var next_enemy_id=100
			var dt=0.05
			var mouse=InputEventMouseButton.new()
			mouse.button_index=MOUSE_BUTTON_LEFT
			mouse.pressed=true
			Input.parse_input_event(mouse)
			while not finished and ticks<10000:
				if battle.enemies.is_empty() and not game.run.fighting:
					if battle.room().kind=="reward":game.claim_reward(0)
					for index in range(battle.room().loot.size()-1,-1,-1):
						var before=game.run.bag.size()
						battle.collect(index)
						recovered+=maxi(0,game.run.bag.size()-before)
					if step>=route.size():break
					for code in [KEY_W,KEY_A,KEY_S,KEY_D]:key(code,false)
					Input.flush_buffered_events()
					battle.goto_room(int(route[step]))
					step+=1
					previous={}
					battle._process(0.2) # Human-scale transition allowance, no paused timer.
					if finished:break
					continue
				var nearest: Dictionary={}
				var distance=INF
				for e in battle.enemies:
					var d=battle.player.distance_to(e.pos)
					if d<distance:
						distance=d
						nearest=e
				if nearest.is_empty():
					battle._process(dt)
					continue
				var delta: Vector2=nearest.pos-battle.player
				var preferred=minf(350,float(game.run.stats.range)*0.72)
				var move=delta.normalized()*clampf((distance-preferred)/70,-1,1)+delta.normalized().orthogonal()*0.7
				for bullet in battle.bullets:
					if bullet.enemy and bullet.pos.distance_to(battle.player)<100:move+=(battle.player-bullet.pos).normalized()*2.0
				if battle.player.x<90:move.x+=2
				if battle.player.x>810:move.x-=2
				if battle.player.y<110:move.y+=2
				if battle.player.y>490:move.y-=2
				key(KEY_A,move.x< -0.25)
				key(KEY_D,move.x>0.25)
				key(KEY_W,move.y< -0.25)
				key(KEY_S,move.y>0.25)
				# Aim with a synthetic mouse event; firing remains the normal held-left-button path.
				var velocity=Vector2.ZERO
				for e in battle.enemies:
					if not e.has("audit_id"):
						e.audit_id=next_enemy_id
						next_enemy_id+=1
				var target_id=int(nearest.audit_id)
				if previous.has(target_id):velocity=(nearest.pos-previous[target_id])/dt
				var aim: Vector2=nearest.pos+velocity*(distance/540.0)
				for e in battle.enemies:
					previous[e.audit_id]=e.pos
				var motion=InputEventMouseMotion.new()
				motion.position=aim.clamp(Vector2(46,66),Vector2(854,539))
				motion.global_position=motion.position
				Input.parse_input_event(motion)
				if game.run.hp<float(game.run.stats.hp)-35:tap(KEY_Q)
				if game.run.weapon_cd<=0:tap(KEY_E)
				Input.flush_buffered_events()
				var before=battle.enemies.size()
				battle._process(dt)
				if before>0 and battle.enemies.is_empty():cleared+=1
				ticks+=1
			var won=not finished and battle.room().kind=="boss" and battle.room().cleared
			var visited=0
			cleared=0
			for room in game.run.floor_data.rooms:
				if room.visited:visited+=1
				if room.kind in ["normal","boss"] and room.cleared:cleared+=1
			rows.append({"station":C.STATIONS[station].name,"radiation":C.STATIONS[station].radiation,"class":C.CLASSES[class_index].name,"seed":2026,"boss_defeated":won,"time_used":snappedf(initial_time-float(game.run.timer),0.01),"hp_remaining":snappedf(maxf(0,game.run.hp),0.01),"visited":visited,"rooms":game.run.floor_data.rooms.size(),"rooms_cleared":cleared,"items_picked":recovered,"account_change":snappedf(float(game.state.power)-start_power,0.01)})
			release_inputs()
			game.end_run(won)
			if not game.load_game(0):failed=true
			battle.queue_free()
			await process_frame
			await create_timer(0.20).timeout
	var low_wins=0
	for row in rows:
		if row.station==C.STATIONS[0].name and row.boss_defeated:low_wins+=1
		print("PLAY ",JSON.stringify(row))
	# Validate that a reproducible ordinary-input strategy can complete the introductory floor.
	if low_wins==0:
		failed=true
		push_error("No introductory class completed the scripted playthrough")
	DirAccess.make_dir_recursive_absolute("res://work")
	var report={"controller":"fixed-input test controller, not human-player feedback","stat_overrides":false,"cases":rows,"introductory_wins":low_wins,"passed":not failed}
	var file=FileAccess.open("res://work/playthrough-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("PLAY AUDIT: ",rows.size()," cases; introductory boss wins ",low_wins,"/3")
	# Let the asynchronous mixer release the last stopped playback references.
	await create_timer(0.20).timeout
	quit(1 if failed else 0)
