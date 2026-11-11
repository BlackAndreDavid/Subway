extends Control
signal changed
signal notice(text: String)
signal ended(success: bool)
signal reward_requested
signal descent_requested
signal return_requested
const Loot=preload("res://scripts/loot_rules.gd")
const Art=preload("res://scripts/art_library.gd")
const C=preload("res://scripts/catalog.gd")
const Geometry=preload("res://scripts/room_geometry.gd")
var geometry=Geometry.new()
const EnemyVisual=preload("res://scripts/enemy_visual.gd")
var player=Vector2(450,300)
var enemies: Array=[]
var bullets: Array=[]
var cooldown=0.0
var hurt_cd=0.0
var age=0.0
var paused=false
var direction=2
var frame=0
var door_delay=0.8
var font: Font
var rng=RandomNumberGenerator.new()
var sounds: Dictionary={}
var flash=0.0
var pending_end=false
var pointer_blocked=false
var show_hitboxes=false
var exit_layer: Node2D
var exit_entities: Dictionary={}
const VIEW_SIZE=Vector2(900,600)
const INTERACT_DISTANCE=64.0
const AREA=Rect2(45,65,810,475)
const SHELL_IDLE_TIME=1.4
const SHELL_WINDUP_TIME=0.7
const SHELL_CHARGE_TIME=1.8
const SHELL_RECOVERY_TIME=1.0
const SHELL_SPEED=360.0
const SHELL_TURN_RATE=0.22
const ENEMY_BULLET_SPEED=184.0
const PLAYER_BULLET_SPEED=540.0
func bullet_radius(bullet: Dictionary) -> float:return 6.0 if bullet.enemy else 3.0
func bullet_size(bullet: Dictionary) -> float:return 28.0 if bullet.enemy else 14.0
func bullet_rotation(bullet: Dictionary) -> float:return Vector2(bullet.vel).angle()+PI/2
func draw_bullet(canvas: CanvasItem,bullet: Dictionary,position: Vector2,scale_factor: float=1.0) -> void:
	var id="enemy_bullet" if bullet.enemy else "bullet"
	var texture=Art.texture(id)
	var dimension=bullet_size(bullet)
	var center=Vector2(Art.bounds(id).get_center())/Vector2(texture.get_size())*dimension
	canvas.draw_set_transform(position,bullet_rotation(bullet),Vector2.ONE*scale_factor)
	canvas.draw_texture_rect(texture,Rect2(-center,Vector2.ONE*dimension),false)
func camera_scale() -> float:
	return minf(size.x/VIEW_SIZE.x,size.y/VIEW_SIZE.y) if size.x>0 and size.y>0 else 1.0
func camera_offset() -> Vector2:
	var scroll=(player-VIEW_SIZE/2).clamp(Vector2.ZERO,(geometry.view_extent()-VIEW_SIZE).max(Vector2.ZERO))
	return (size-VIEW_SIZE*camera_scale())/2-scroll*camera_scale()
func world_to_screen(point: Vector2) -> Vector2:
	return camera_offset()+point*camera_scale()
func world_mouse() -> Vector2:
	return (get_local_mouse_position()-camera_offset())/camera_scale()
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	font=ThemeDB.fallback_font
	if Game.run.is_empty():
		set_process(false)
		return
	rng.seed=int(Game.run.seed)
	for key in ["shot","pickup","hit","door"]:
		var p=AudioStreamPlayer.new()
		p.stream=load("res://assets/%s.wav" % key)
		p.volume_db=-13
		add_child(p)
		sounds[key]=p
	setup_exit_entities()
	resized.connect(sync_exit_entities)
	enter_room()
func setup_exit_entities() -> void:
	exit_layer=get_node_or_null("Exits")
	if exit_layer==null:
		exit_layer=Node2D.new()
		exit_layer.name="Exits"
		add_child(exit_layer)
		for action in ["descent","return"]:
			var entity=preload("res://scenes/exploration/exit.tscn").instantiate()
			entity.action=action
			entity.position=Vector2(330 if action=="descent" else 570,285)
			exit_layer.add_child(entity)
	for entity in exit_layer.get_children():exit_entities[entity.action]=entity
func sync_exit_entities() -> void:
	if not is_instance_valid(exit_layer):return
	exit_layer.position=camera_offset()
	exit_layer.scale=Vector2.ONE*camera_scale()
	exit_layer.visible=Game.can_return_to_base()
	for entity in exit_entities.values():
		entity.visible=Game.can_extract() if entity.action=="descent" else Game.can_return_to_base()
		entity.highlighted=not paused and not pending_end and entity.visible and entity.in_range(player)
		entity.queue_redraw()
func nearby_exit() -> String:
	if paused or pending_end or not Game.can_return_to_base():return ""
	for entity in exit_entities.values():
		if entity.visible and entity.in_range(player):return entity.action
	return ""
func _exit_tree() -> void:
	# Release active playback when leaving combat, before queued nodes are freed.
	for sound in sounds.values():
		sound.stop()
		sound.stream=null
	sounds.clear()

func room() -> Dictionary:
	return Game.run.floor_data.rooms[int(Game.run.room)]
func enter_room(spawn: Vector2=Vector2(450,300),from_room: int=-1) -> void:
	enemies=[]
	bullets=[]
	door_delay=0.8
	var data=room()
	geometry.configure(data)
	for entity in exit_entities.values():
		entity.position=Vector2(330 if entity.action=="descent" else 570,285)
		if data.kind=="start":entity.position=geometry.closest_free(entity.position,28)
	if from_room>=0:spawn=door_position(from_room)-Vector2(data.doors[from_room].normal)*42
	player=geometry.closest_free(spawn,14)
	data.visited=true
	rng.seed=int(Game.run.seed)+int(data.id)*171+int(Game.run.floor)*193
	if not data.cleared:
		if data.kind=="boss":
			enemies.append(make_enemy(4,geometry.closest_free(Vector2(650,300),38)))
		else:
			for i in range(rng.randi_range(3,5)+mini(int(Game.run.floor)-1,3)+data.cells.size()-1):
				var pos=enemy_spawn_position()
				enemies.append(make_enemy(rng.randi_range(0,3),pos))
	ensure_ground_loot()
	Game.run.fighting=not enemies.is_empty()
	sync_exit_entities()
	sounds.door.play()
	changed.emit()
	queue_redraw()
func enemy_spawn_position() -> Vector2:
	for attempt in range(80):
		var area: Rect2=geometry.areas[rng.randi_range(0,geometry.areas.size()-1)]
		var point=Vector2(rng.randf_range(area.position.x+45,area.end.x-45),rng.randf_range(area.position.y+45,area.end.y-45))
		if point.distance_to(player)>160 and geometry.can_stand(point,22):return point
	return geometry.closest_free(geometry.bounds.end-Vector2(70,70),22)
func make_enemy(type: int,pos: Vector2) -> Dictionary:
	var hp=([32,45,28,110,400][type])*(1+0.23*(int(Game.run.floor)-1))
	var timer=rng.randf_range(0.3,1.6)
	return {"type":type,"pos":pos,"hp":float(hp),"max":float(hp),"armor":0.4 if type==3 else 0.0,"timer":SHELL_IDLE_TIME if type==3 else timer,"state":"idle","charge_dir":Vector2.LEFT,"phase":0.0,"velocity":Vector2.ZERO,"travel":Vector2.ZERO,"facing":Vector2.LEFT if type in [0,3] else Vector2.RIGHT,"walk_time":0.0}
func _process(delta: float) -> void:
	if Game.run.is_empty() or paused or pending_end: return
	age+=delta
	cooldown=maxf(0,cooldown-delta)
	hurt_cd=maxf(0,hurt_cd-delta)
	door_delay=maxf(0,door_delay-delta)
	flash=maxf(0,flash-delta)
	Game.run.buff=maxf(0,Game.run.buff-delta)
	Game.run.shield=maxf(0,Game.run.shield-delta)
	Game.run.weapon_cd=maxf(0,Game.run.weapon_cd-delta)
	var movement=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var before_player=player
	player=geometry.move_actor(player,movement*float(Game.run.stats.speed)*(1.35 if Game.run.buff>0 else 1.0)*delta,14)
	movement=(player-before_player).normalized()
	if movement.length()>0:
		frame=int(age*9)%4
		if absf(movement.x)>absf(movement.y): direction=0 if movement.x<0 else 1
		else: direction=3 if movement.y<0 else 2
	else: frame=0
	var aim=Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
	if not pointer_blocked and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Rect2(Vector2.ZERO,VIEW_SIZE).has_point(world_mouse()): aim=world_mouse()-player
	if aim.length()>0 and cooldown<=0:
		shoot(player,aim.normalized(),false,14*float(Game.run.damage),float(Game.run.stats.range))
		cooldown=0.28*(0.75 if Game.run.module=="5_2" else 1.0)*(0.6 if Game.run.buff>0 else 1.0)
		sounds.shot.play()
	update_enemies(delta)
	update_bullets(delta)
	if Game.run.hp<=0:
		finish(false)
		return
	if Game.run.fighting and enemies.is_empty():
		room().cleared=true
		Game.run.fighting=false
		create_loot()
		if Game.run.module=="5_3": Game.state.power+=2
		notice.emit("房间已清理。可以拾取、整理背包和使用通道。")
		changed.emit()
	update_ground_loot(delta)
	sync_exit_entities()
	queue_redraw()
func _unhandled_key_input(event: InputEvent) -> void:
	if Game.run.is_empty() or not event.is_pressed() or event.is_echo() or paused: return
	if event.physical_keycode==KEY_F:
		get_viewport().set_input_as_handled()
		interact()
		return
	if event.physical_keycode==KEY_Q: use_drug()
func _input(event: InputEvent) -> void:
	# Capture Space before focused UI buttons can treat it as an activation.
	if not event is InputEventKey or event.physical_keycode!=KEY_SPACE or paused or pending_end or Game.run.is_empty():return
	if event.pressed and not event.echo:use_weapon()
	get_viewport().set_input_as_handled()
func shoot(pos: Vector2,dir: Vector2,enemy: bool,damage: float,distance: float=900,penetrating: bool=false) -> void:
	bullets.append({"pos":pos,"vel":dir.normalized()*(ENEMY_BULLET_SPEED if enemy else PLAYER_BULLET_SPEED),"enemy":enemy,"damage":damage,"distance":distance,"hit":[],"penetrating":penetrating})
func update_enemies(delta: float) -> void:
	for e in enemies:
		var before: Vector2=e.pos
		var to: Vector2=player-e.pos
		e.timer-=delta
		e.phase+=delta
		match int(e.type):
			0: # mutated rat: direct chase
				e.pos+=geometry.navigation_direction(e.pos,player,enemy_radius(e))*95*delta
			1: # bandit: keep distance and aimed shot
				if to.length()>260: e.pos+=geometry.navigation_direction(e.pos,player,enemy_radius(e))*65*delta
				elif to.length()<180: e.pos-=to.normalized()*65*delta
				if e.timer<=0:
					shoot(e.pos,to.normalized(),true,12)
					e.timer=1.5
			2: # spore turret: radial pattern
				if e.timer<=0:
					for i in range(8): shoot(e.pos,Vector2.RIGHT.rotated(i*TAU/8+e.phase*0.3),true,9)
					e.timer=2.7
			3:update_shell_beast(e,to,delta)
			4: # station custodian boss: aimed fans and rotating ring
				e.pos+=geometry.navigation_direction(e.pos,player,enemy_radius(e))*42*delta
				if e.timer<=0:
					for i in range(12): shoot(e.pos,Vector2.RIGHT.rotated(i*TAU/12+e.phase*0.25),true,13)
					for i in range(-1,2): shoot(e.pos,to.normalized().rotated(i*0.15),true,15)
					e.timer=1.6 if e.hp<e.max*0.5 else 2.2
		var proposed: Vector2=e.pos
		e.pos=geometry.move_actor(before,proposed-before,enemy_radius(e))
		if e.type==3 and e.state=="charge" and e.pos.distance_squared_to(proposed)>0.001:
			e.state="recovery"
			e.timer=SHELL_RECOVERY_TIME
			e.velocity=Vector2.ZERO
		update_enemy_facing(e,e.pos-before,delta)
		if player.distance_to(e.pos)<enemy_radius(e)+14: take_damage(18)
func update_enemy_facing(enemy: Dictionary,displacement: Vector2,delta: float) -> void:
	enemy.travel=displacement
	if displacement.length_squared()>0.0001:
		if int(enemy.type) in [0,3]:
			if absf(displacement.x)>0.005:enemy.facing=Vector2.LEFT if displacement.x<0 else Vector2.RIGHT
		else:enemy.facing=displacement.normalized()
		enemy.walk_time+=delta
	else:enemy.walk_time=0.0
func enemy_rotation(enemy: Dictionary) -> float:
	# Billboard-like sprites stay upright in the room; only left/right flips.
	return 0.0
func update_shell_beast(enemy: Dictionary,to_player: Vector2,delta: float) -> void:
	match str(enemy.state):
		"idle":
			if enemy.timer<=0:
				enemy.state="windup"
				enemy.timer=SHELL_WINDUP_TIME
				enemy.charge_dir=to_player.normalized() if to_player.length_squared()>0.01 else Vector2.LEFT
		"windup":
			if to_player.length_squared()>0.01:enemy.charge_dir=to_player.normalized()
			if absf(enemy.charge_dir.x)>0.01:enemy.facing=Vector2.LEFT if enemy.charge_dir.x<0 else Vector2.RIGHT
			if enemy.timer<=0:
				enemy.state="charge"
				enemy.timer=SHELL_CHARGE_TIME
				enemy.velocity=enemy.charge_dir*SHELL_SPEED
		"charge":
			if to_player.length_squared()>0.01:
				var difference=wrapf(to_player.angle()-Vector2(enemy.charge_dir).angle(),-PI,PI)
				enemy.charge_dir=Vector2(enemy.charge_dir).rotated(clampf(difference,-SHELL_TURN_RATE*delta,SHELL_TURN_RATE*delta)).normalized()
			enemy.velocity=enemy.charge_dir*SHELL_SPEED
			enemy.pos+=enemy.velocity*delta
			if enemy.timer<=0:
				enemy.state="recovery"
				enemy.timer=SHELL_RECOVERY_TIME
				enemy.velocity=Vector2.ZERO
		"recovery":
			if enemy.timer<=0:
				enemy.state="idle"
				enemy.timer=SHELL_IDLE_TIME
func damage_enemy(enemy: Dictionary,amount: float) -> float:
	var actual=maxf(0,amount)*(1.0-clampf(float(enemy.get("armor",0)),0,0.8))
	enemy.hp-=actual
	if enemy.hp<=0:enemies.erase(enemy)
	return actual
func enemy_flipped(enemy: Dictionary) -> bool:
	# The bandit atlas faces right; never use player direction while retreating.
	return float(enemy.facing.x)>0.01 if int(enemy.type) in [0,3] else int(enemy.type) in [1,4] and float(enemy.facing.x)<-0.01
func enemy_frame(enemy: Dictionary) -> int:
	return Art.frames_at_time("enemies/%d" % int(enemy.type),float(enemy.walk_time) if int(enemy.type)!=2 else age)
func enemy_sprite_rect(enemy: Dictionary,frame_index: int=-1) -> Rect2:
	var id="enemies/%d" % int(enemy.type)
	var index=enemy_frame(enemy) if frame_index<0 else frame_index
	var texture=Art.texture(id,index)
	var dimension=86.0 if int(enemy.type)==4 else 53.0
	var factor=dimension/texture.get_width()
	var center=Rect2(Art.bounds(id,index)).get_center()*factor
	return Rect2(-center,Vector2.ONE*dimension)
func enemy_visual_center(enemy: Dictionary,frame_index: int=-1) -> Vector2:
	var id="enemies/%d" % int(enemy.type)
	var index=enemy_frame(enemy) if frame_index<0 else frame_index
	var rect=enemy_sprite_rect(enemy,index)
	var fraction=Rect2(Art.bounds(id,index)).get_center()/Vector2(Art.texture(id,index).get_size())
	var local=rect.position+fraction*rect.size
	if enemy_flipped(enemy):local.x=-local.x
	return Vector2(enemy.pos)+local.rotated(enemy_rotation(enemy))
func enemy_radius(enemy: Dictionary) -> float:
	var bound=Art.bounds("enemies/%d" % int(enemy.type),enemy_frame(enemy))
	return maxf(12,maxi(bound.size.x,bound.size.y)*(86.0 if int(enemy.type)==4 else 53.0)/Art.texture("enemies/%d" % int(enemy.type)).get_width()*0.45)
func update_bullets(delta: float) -> void:
	for b in bullets.duplicate():
		var previous: Vector2=b.pos
		b.pos+=b.vel*delta
		b.distance-=b.vel.length()*delta
		if b.distance<=0 or not geometry.segment_clear(previous,b.pos,bullet_radius(b)):
			bullets.erase(b)
			continue
		if b.enemy:
			if b.pos.distance_to(player)<13+bullet_radius(b):
				take_damage(b.damage)
				bullets.erase(b)
		else:
			for e in enemies.duplicate():
				if not b.hit.has(e) and b.pos.distance_to(e.pos)<enemy_radius(e)+bullet_radius(b):
					damage_enemy(e,float(b.damage))
					b.hit.append(e)
					if not b.penetrating:
						bullets.erase(b)
						break
func take_damage(amount: float) -> void:
	if hurt_cd>0 or Game.run.shield>0: return
	Game.run.hp-=amount*(1.0-float(Game.run.stats.armor))
	hurt_cd=0.65
	sounds.hit.play()
func door_position(id: int) -> Vector2:
	return geometry.door_position(room().doors[id])
func nearby_door() -> int:
	if Game.run.is_empty():return -1
	var closest=-1
	var distance=INTERACT_DISTANCE
	for id in room().links:
		var current=player.distance_to(door_position(id))
		if current<=distance:
			closest=id
			distance=current
	return closest
func interact() -> void:
	if paused or pending_end or Game.run.is_empty():return
	if Game.run.fighting:
		notice.emit("战斗中，通道已锁定。")
		return
	var id=nearby_door()
	if id>=0:
		goto_room(id)
	elif nearby_exit()=="descent":
		descent_requested.emit()
	elif nearby_exit()=="return":
		return_requested.emit()
	elif room().kind=="reward" and not room().claimed and player.distance_to(Vector2(450,280))<=INTERACT_DISTANCE:
		reward_requested.emit()
	elif nearest_loot()>=0:collect(nearest_loot())
	else:notice.emit("靠近掉落物或通道后按 F 互动。")
func goto_room(id: int) -> bool:
	# Every call, including tests and UI callbacks, must pass the same physical gate.
	if paused or pending_end or Game.run.is_empty() or id<0 or id>=Game.run.floor_data.rooms.size():return false
	if not room().links.has(id) or door_delay>0 or player.distance_to(door_position(id))>INTERACT_DISTANCE:return false
	var previous_room=int(Game.run.room)
	if Game.move_room(id):
		enter_room(Vector2.ZERO,previous_room)
		return true
	notice.emit("战斗中无法通行，或电量不足。")
	return false
func use_weapon() -> void:
	if Game.run.is_empty() or paused or pending_end:return
	if Game.run.weapon=="" or Game.run.weapon_cd>0: return
	var aim=(world_mouse()-player).normalized()
	if aim==Vector2.ZERO: aim=Vector2.RIGHT
	match Game.run.weapon:
		"4_0":
			for e in enemies.duplicate():
				if e.pos.distance_to(player)<250:
					damage_enemy(e,45*float(Game.run.damage))
					e.pos=geometry.move_actor(e.pos,(e.pos-player).normalized()*90,enemy_radius(e))
					if e.hp<=0: enemies.erase(e)
			flash=0.3
			Game.run.weapon_cd=10.0
		"4_1":
			for i in range(-4,5): shoot(player,aim.rotated(i*0.13),false,23*float(Game.run.damage),600)
			Game.run.weapon_cd=7.0
		"4_2":
			Game.run.shield=4.0
			Game.run.weapon_cd=15.0
		"4_3":
			shoot(player,aim,false,110*float(Game.run.damage),1000,true)
			Game.run.weapon_cd=6.0
	changed.emit()
func use_drug() -> void:
	if Game.run.is_empty() or paused or pending_end:return
	var id: String=Game.run.drug
	if id=="": return
	var entry: Dictionary=Game.equipped_entry("drug")
	if entry.is_empty(): return
	match id:
		"3_0": Game.run.hp=minf(Game.run.stats.hp,Game.run.hp+35)
		"3_1": Game.run.buff=12.0
		"3_2":
			Game.run.hp=minf(Game.run.stats.hp,Game.run.hp+20)
			Game.run.shield=8.0
		"3_3": Game.run.hp=minf(Game.run.stats.hp,Game.run.hp+70)
	entry.uses-=1
	Game.inventory_changed()
	if entry.uses<=0:
		Game.run.equipment.drug={}
		Game.run.drug=""
		Game.run.equipped_uid.drug=-1
	notice.emit("使用了"+C.item(id).name)
	changed.emit()
func create_loot() -> void:
	room().loot.append_array(Loot.roll_room(int(Game.state.station),int(Game.run.floor),rng,room().kind=="boss"))
	ensure_ground_loot(Vector2(450,390) if room().kind=="boss" else geometry.bounds.get_center())
func loot_id(entry: Variant) -> String:
	return str(entry.id) if entry is Dictionary else str(entry)
func automatic_loot(id: String) -> bool:
	return id in ["power","credits"]
func ensure_ground_loot(origin: Vector2=Vector2(-1,-1)) -> void:
	if origin.x<0:origin=geometry.bounds.get_center()
	if not room().has("ground"):room().ground=[]
	while room().ground.size()<room().loot.size():
		var index=room().ground.size()
		var offset=Vector2((index%5-2)*58,(index/5)*55)
		room().ground.append({"pos":geometry.closest_free(origin+offset,22)})
func nearest_loot() -> int:
	ensure_ground_loot()
	var nearest=-1
	var distance=INTERACT_DISTANCE
	for index in range(room().loot.size()):
		if automatic_loot(loot_id(room().loot[index])):continue
		var current=player.distance_to(room().ground[index].pos)
		if current<=distance:
			nearest=index
			distance=current
	return nearest
func update_ground_loot(delta: float) -> void:
	ensure_ground_loot()
	for index in range(room().loot.size()-1,-1,-1):
		if not automatic_loot(loot_id(room().loot[index])):continue
		var ground: Dictionary=room().ground[index]
		if ground.pos.distance_to(player)<=128:
			ground.pos=geometry.move_actor(ground.pos,(player-ground.pos).limit_length(260*delta),8)
			if ground.pos.distance_to(player)<=18:collect(index,true)
func loot_texture(id: String) -> Texture2D:
	if id=="power":return Art.texture("items/1_1")
	if id=="credits":return Art.texture("credits")
	if id=="chest":return Art.texture("chest")
	if id=="scrap":return Art.texture("scrap")
	if id.begins_with("mat_"):return Art.texture("materials/"+id.trim_prefix("mat_"))
	return Art.texture("items/"+id)
func collect(index: int,automatic: bool=false) -> bool:
	if paused or Game.run.fighting or index<0 or index>=room().loot.size():return false
	ensure_ground_loot()
	var id_at_index=loot_id(room().loot[index])
	if automatic and not automatic_loot(id_at_index):return false
	var range_limit=18.0 if automatic else INTERACT_DISTANCE
	if player.distance_to(room().ground[index].pos)>range_limit:return false
	var entry=room().loot[index]
	var id: String=entry.id if entry is Dictionary else entry
	if id=="chest":
		var origin: Vector2=room().ground[index].pos
		room().loot.remove_at(index)
		room().ground.remove_at(index)
		room().loot.append_array(Loot.open_chest(int(Game.state.station),int(Game.run.floor),rng))
		ensure_ground_loot(origin)
		notice.emit("宝箱已打开，物资已散落在地面。")
	elif id=="power" or id=="credits":
		var value=Loot.pickup_value(int(Game.state.station),id)
		Game.state.power+=value
		if id=="power":Game.run.energy+=value
		room().loot.remove_at(index)
		room().ground.remove_at(index)
	else:
		if not Game.pick_up(id,int(entry.uses) if entry is Dictionary else -1):
			notice.emit("背包已满，物品仍留在地上。")
			return false
		room().loot.remove_at(index)
		room().ground.remove_at(index)
	sounds.pickup.play()
	changed.emit()
	return true
func finish(success: bool) -> void:
	if pending_end: return
	pending_end=true
	ended.emit(success)
func _draw() -> void:
	if Game.run.is_empty(): return
	draw_style_box(style(),Rect2(Vector2.ZERO,size))
	draw_set_transform(camera_offset(),0,Vector2.ONE*camera_scale())
	for area in geometry.areas:
		draw_rect(area,Color("162e38"))
		for x in range(0,15):draw_line(area.position+Vector2(x*54,0),area.position+Vector2(x*54,area.size.y),Color("203944"),1)
		for y in range(0,10):draw_line(area.position+Vector2(0,y*geometry.TILE.y),area.position+Vector2(area.size.x,y*geometry.TILE.y),Color("203944"),1)
	for edge in geometry.boundary_segments():draw_line(edge[0],edge[1],Color("47606b"),7)
	for block in geometry.obstacles:
		draw_rect(Rect2(block.position+Vector2(4,5),block.size),Color("10242e"))
		draw_rect(block,Color("34515a"))
		draw_rect(Rect2(block.position,Vector2(block.size.x,7)),Color("587279"))
		draw_rect(block,Color("203944"),false,2)
	var r=room()
	for id in r.links:
		var pos=door_position(id)
		var normal: Vector2i=r.doors[id].normal
		var extent=Vector2(16,34) if normal.x!=0 else Vector2(34,16)
		draw_rect(Rect2(pos-extent,extent*2),Color("9e685e") if Game.run.fighting else Color("79bdb5"))
	if not Game.run.fighting:
		if r.kind=="reward" and not r.claimed: draw_texture_rect(Art.texture("chest"),Rect2(420,250,60,60),false)
		if r.kind=="shop": draw_texture_rect(Art.texture("station"),Rect2(420,240,65,65),false)
	ensure_ground_loot()
	for index in range(r.loot.size()):
		var pos: Vector2=r.ground[index].pos
		var id=loot_id(r.loot[index])
		draw_circle(pos,19,Color(0.04,0.1,0.13,0.65))
		draw_texture_rect(loot_texture(id),Rect2(pos-Vector2(21,21),Vector2(42,42)),false)
	if not Game.run.fighting and nearest_loot()>=0 and nearby_door()<0:
		var id=loot_id(r.loot[nearest_loot()])
		var bounds=C.bounds(id) if id!="chest" else Vector2i.ONE
		var text="F 打开宝箱" if id=="chest" else "F 拾取 · %s（%d×%d / %d格）" % [C.item(id).name,bounds.x,bounds.y,C.cells(id).size()]
		draw_string(font,Vector2(45,559),text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("eed4a1"))
	if not Game.run.fighting and nearby_door()>=0:
		var door=door_position(nearby_door())
		draw_string(font,door+Vector2(-30,-30),"F 进入",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f1d398"))
	if r.kind=="reward" and not r.claimed and player.distance_to(Vector2(450,280))<=INTERACT_DISTANCE:
		draw_string(font,Vector2(365,340),"F 打开奖励宝箱",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f1d398"))
	for e in enemies:
		if e.type==3 and e.state=="windup":draw_line(e.pos,e.pos+e.charge_dir*240,Color(0.9,0.65,0.35,0.65),4)
		EnemyVisual.draw(self,self,e,camera_offset()+Vector2(e.pos)*camera_scale(),camera_scale())
		draw_set_transform(camera_offset(),0,Vector2.ONE*camera_scale())
		if show_hitboxes:draw_arc(e.pos,enemy_radius(e),0,TAU,32,Color("8bc9bf"),1)
		var health_origin=Vector2(e.pos)-Vector2(22,enemy_radius(e)+12)
		draw_rect(Rect2(health_origin,Vector2(44,4)),Color("21323a"))
		draw_rect(Rect2(health_origin,Vector2(44*maxf(0,e.hp/e.max),4)),Color("d5927e"))
	if hurt_cd<=0 or int(age*14)%2==0:
		draw_texture_rect(Art.texture("player/%d" % direction,frame),Rect2(player-Vector2(27,30),Vector2(54,54)),false)
	if Game.run.shield>0: draw_arc(player,35,0,TAU,40,Color("8bd9e3"),3,true)
	if flash>0: draw_arc(player,250*(1-flash/0.3),0,TAU,60,Color("a8ebe2"),4,true)
	for b in bullets:
		draw_bullet(self,b,world_to_screen(b.pos),camera_scale())
	draw_set_transform((size-VIEW_SIZE*camera_scale())/2,0,Vector2.ONE*camera_scale())
	draw_string(font,Vector2(290,34),"%s / 第%d层 · %d格房间" % [{"normal":"回收区","start":"检查站","reward":"遗留物资室","shop":"流动补给商","boss":"站区守卫"}[r.kind],Game.run.floor,r.cells.size()],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("b9d9d6"))
	draw_string(font,Vector2(45,580),"WASD 移动  /  鼠标射击  /  F 互动  /  空格 主动道具  /  Q 药物  /  B 背包  /  长按 Tab 地图  /  Esc 暂停",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("6f949e"))
func style() -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=Color("142a35")
	s.corner_radius_top_left=12
	s.corner_radius_top_right=12
	s.corner_radius_bottom_left=12
	s.corner_radius_bottom_right=12
	return s
