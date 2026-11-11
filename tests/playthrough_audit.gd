extends SceneTree
# Fixed-input automated play sessions against the actual combat loop.
# No health, enemy damage, timer, collision or drop overrides.
const Generator=preload("res://scripts/floor_generator.gd")
const C=preload("res://scripts/catalog.gd")
var game: Node
var failed=false
var finished=false
var returned=false
var key_states={}
var rows: Array=[]
var current_battle: Control
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
func walk_toward(point: Vector2,player: Vector2) -> void:
	var move=current_battle.geometry.next_waypoint(player,point,14)-player
	key(KEY_A,move.x< -2)
	key(KEY_D,move.x>2)
	key(KEY_W,move.y< -2)
	key(KEY_S,move.y>2)
	Input.flush_buffered_events()
func should_heal() -> bool:
	if game.run.drug not in ["3_0","3_2","3_3"]:return false
	var amount={"3_0":35,"3_2":20,"3_3":70}[game.run.drug]
	return game.run.hp<=float(game.run.stats.hp)-amount or game.run.hp<=25
func audit() -> void:
	game=root.get_node("Game")
	root.size=Vector2i(1440,900)
	for scenario in [{"name":"minimum80","coverage":0.8},{"name":"complete100","coverage":1.0}]:
		for station in [0,3,5]:
			for class_index in range(3):
				game.new_game(0,"自动操作验收")
				game.state.station=station
				var start_power=float(game.state.power)
				if not game.begin_run(class_index,"5_0","4_0","3_3",2026):
					push_error(game.last_error)
					quit(1)
					return
				var battle=load("res://scripts/combat.gd").new()
				battle.size=Vector2(900,600)
				finished=false
				returned=false
				battle.ended.connect(func(_success):finished=true)
				battle.return_requested.connect(func():returned=true)
				root.add_child(battle)
				current_battle=battle
				battle.set_process(false)
				await process_frame
				var initial_time=battle.age
				var route: Array=Generator.compact_route(game.run.floor_data.rooms,int(game.run.floor_data.budget),float(scenario.coverage))
				var step=1
				var ticks=0
				var cleared=0
				var recovered=0
				var managed_equips=0
				var doors_entered=0
				var ignored_loot={}
				var previous={}
				var next_enemy_id=100
				var dt=0.05
				var mouse=InputEventMouseButton.new()
				mouse.button_index=MOUSE_BUTTON_LEFT
				mouse.pressed=true
				Input.parse_input_event(mouse)
				while not finished and ticks<24000:
					ticks+=1
					if battle.enemies.is_empty() and not game.run.fighting:
						# Only normal owned-item inventory APIs are used between fights; no grants or stat edits.
						if game.run.drug=="" or game.run.drug=="3_1":
							for healing_id in ["3_3","3_0","3_2"]:
								var healing_index=-1
								for index in range(game.run.bag.size()):
									if game.run.bag[index].id==healing_id:healing_index=index;break
								if healing_index>=0 and game.equip_entry(healing_index):managed_equips+=1;break
						if should_heal():tap(KEY_Q)
						if battle.room().kind=="reward":game.claim_reward(0)
						if step>=route.size():break
						# Walk to real loot and doors. Never teleport or call goto_room/collect remotely.
						battle.ensure_ground_loot()
						var loot_target=-1
						var loot_distance=INF
						for index in range(battle.room().loot.size()):
							var id=battle.loot_id(battle.room().loot[index])
							if not battle.automatic_loot(id) and id!="chest" and not game.can_pick_up(id):continue
							var token=str(game.run.room)+":"+str(battle.room().ground[index].pos)+":"+id
							if ignored_loot.has(token):continue
							var distance=battle.player.distance_to(battle.room().ground[index].pos)
							if distance<loot_distance:
								loot_target=index
								loot_distance=distance
						if loot_target>=0:
							var pos: Vector2=battle.room().ground[loot_target].pos
							walk_toward(pos,battle.player)
							if loot_distance<40 and not battle.automatic_loot(battle.loot_id(battle.room().loot[loot_target])):
								var before=game.run.bag.size()
								var token=str(game.run.room)+":"+str(pos)+":"+battle.loot_id(battle.room().loot[loot_target])
								tap(KEY_F)
								if before==game.run.bag.size():ignored_loot[token]=true
								recovered+=maxi(0,game.run.bag.size()-before)
						else:
							var door: Vector2=battle.door_position(int(route[step]))
							walk_toward(door,battle.player)
							if battle.player.distance_to(door)<55 and battle.door_delay<=0:
								var from=int(game.run.room)
								tap(KEY_F)
								if int(game.run.room)!=from:
									step+=1
									doors_entered+=1
									previous={}
						battle._process(dt)
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
					var navigation_target=Vector2.INF
					var bounds: Rect2=battle.geometry.bounds
					if battle.player.x<bounds.position.x+45:move.x+=2
					if battle.player.x>bounds.end.x-45:move.x-=2
					if battle.player.y<bounds.position.y+45:move.y+=2
					if battle.player.y>bounds.end.y-45:move.y-=2
					if distance>preferred+30 or not battle.geometry.segment_clear(battle.player,nearest.pos,3):
						navigation_target=battle.geometry.next_waypoint(battle.player,nearest.pos,14)
						move=(navigation_target-battle.player).normalized()
					for enemy in battle.enemies:
						if enemy.type==3 and enemy.state in ["windup","charge"] and enemy.pos.distance_to(battle.player)<360:
							var dodge=Vector2(enemy.charge_dir).orthogonal()
							if dodge.dot(move)<0:dodge=-dodge
							move+=dodge*1.8
					var destination=battle.geometry.closest_free(battle.player+move.normalized()*65,14)
					var pressed_direction=Vector2(signf(move.x) if absf(move.x)>0.25 else 0,signf(move.y) if absf(move.y)>0.25 else 0)
					if not navigation_target.is_finite() and (not battle.geometry.segment_clear(battle.player,destination,14) or not battle.geometry.can_stand(battle.player+pressed_direction.normalized()*12,14)):navigation_target=battle.geometry.next_waypoint(battle.player,nearest.pos,14)
					if navigation_target.is_finite():walk_toward(navigation_target,battle.player)
					else:
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
					motion.position=battle.world_to_screen(aim).clamp(Vector2(24,24),battle.size-Vector2(24,24))
					motion.global_position=motion.position
					Input.parse_input_event(motion)
					if should_heal():tap(KEY_Q)
					if game.run.weapon_cd<=0:tap(KEY_SPACE)
					Input.flush_buffered_events()
					var before=battle.enemies.size()
					battle._process(dt)
					if before>0 and battle.enemies.is_empty():cleared+=1
				var won=not finished and battle.room().kind=="boss" and battle.room().cleared
				if won:
					release_inputs()
					# Complete the successful route through the separate physical return terminal.
					for walk_tick in range(200):
						walk_toward(battle.exit_entities.return.position,battle.player)
						if battle.exit_entities.return.in_range(battle.player):tap(KEY_F)
						if returned:break
						battle._process(dt)
					if not returned:failed=true
				var visited=0
				cleared=0
				for room in game.run.floor_data.rooms:
					if room.visited:visited+=1
					if room.kind in ["normal","boss"] and room.cleared:cleared+=1
				rows.append({"scenario":scenario.name,"coverage_target":scenario.coverage,"station":C.STATIONS[station].name,"radiation":C.STATIONS[station].radiation,"class":C.CLASSES[class_index].name,"seed":2026,"boss_defeated":won,"termination_reason":"boss_return" if won and returned else "health_depleted" if finished else "controller_guard","return_terminal_with_f":returned,"day_spent":int(game.state.day)-1,"occupied_map_cells":game.run.floor_data.occupied_cells,"time_used":snappedf(battle.age-initial_time,0.01),"hp_remaining":snappedf(maxf(0,game.run.hp),0.01),"visited":visited,"rooms":game.run.floor_data.rooms.size(),"rooms_cleared":cleared,"items_picked":recovered,"owned_medicine_equips":managed_equips,"starting_loadout":["5_0","4_0","3_3"],"doors_entered_with_f":doors_entered,"account_change":snappedf(float(game.state.power)-start_power,0.01)})
				release_inputs()
				game.end_run(won)
				if not game.load_game(0):failed=true
				battle.queue_free()
				await process_frame
				await create_timer(0.20).timeout
	var low_wins=0
	for row in rows:
		if row.station==C.STATIONS[0].name and row.scenario=="minimum80" and row.boss_defeated and row.return_terminal_with_f:low_wins+=1
		print("PLAY ",JSON.stringify(row))
	# Validate that a reproducible ordinary-input strategy can complete the introductory floor.
	if low_wins==0:
		failed=true
		push_error("No introductory class completed the minimum-coverage expedition")
	DirAccess.make_dir_recursive_absolute("res://work")
	var report={"scenarios":["minimum80","complete100"],"controller":"WASD movement, mouse fire, F at doors/pickups/return terminal, Space/Q; normal owned-medicine inventory APIs between cleared rooms; not human-player feedback","stat_overrides":false,"cases":rows,"introductory_wins":low_wins,"passed":not failed}
	var file=FileAccess.open("res://work/playthrough-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("PLAY AUDIT: ",rows.size()," cases; introductory boss wins ",low_wins,"/3")
	# Let the asynchronous mixer release the last stopped playback references.
	await create_timer(0.20).timeout
	quit(1 if failed else 0)
