extends Control
signal changed
signal notice(text: String)
signal ended(success: bool)
const C=preload("res://scripts/catalog.gd")
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
var textures: Dictionary={}
var flash=0.0
var pending_end=false
const AREA=Rect2(45,65,810,475)
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=ThemeDB.fallback_font
	for d in range(4):
		for f in range(4):
			var path="res://assets/player/%d_%d.svg" % [d,f]
			textures[path]=load(path)
	for i in range(5):
		var path="res://assets/enemies/%d.svg" % i
		textures[path]=load(path)
	for path in ["res://assets/chest.svg","res://assets/station.svg","res://assets/bullet.svg","res://assets/enemy_bullet.svg"]:
		textures[path]=load(path)
	rng.seed=int(Game.run.seed)
	for key in ["shot","pickup","hit","door"]:
		var p=AudioStreamPlayer.new()
		p.stream=load("res://assets/%s.wav" % key)
		p.volume_db=-13
		add_child(p)
		sounds[key]=p
	enter_room()
func room() -> Dictionary:
	return Game.run.floor_data.rooms[int(Game.run.room)]
func enter_room(spawn: Vector2=Vector2(450,300)) -> void:
	enemies=[]
	bullets=[]
	player=spawn
	door_delay=0.8
	var data=room()
	data.visited=true
	rng.seed=int(Game.run.seed)+int(data.id)*171+int(Game.run.floor)*193
	if not data.cleared:
		if data.kind=="boss":
			enemies.append(make_enemy(4,Vector2(650,300)))
		else:
			for i in range(rng.randi_range(3,5)+mini(int(Game.run.floor)-1,3)):
				var pos=Vector2(rng.randf_range(180,760),rng.randf_range(140,450))
				if pos.distance_to(player)<160: pos=Vector2(760,450)
				enemies.append(make_enemy(rng.randi_range(0,3),pos))
	Game.run.fighting=not enemies.is_empty()
	sounds.door.play()
	changed.emit()
	queue_redraw()
func make_enemy(type: int,pos: Vector2) -> Dictionary:
	var hp=([32,45,28,38,400][type])*(1+0.23*(int(Game.run.floor)-1))
	return {"type":type,"pos":pos,"hp":float(hp),"max":float(hp),"timer":rng.randf_range(0.3,1.6),"phase":0.0,"velocity":Vector2.ZERO}
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
	Game.run.timer-=delta
	if Game.run.timer<=0:
		finish(false)
		return
	var movement=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).normalized()
	player+=movement*float(Game.run.stats.speed)*(1.35 if Game.run.buff>0 else 1.0)*delta
	if movement.length()>0:
		frame=int(age*9)%4
		if absf(movement.x)>absf(movement.y): direction=0 if movement.x<0 else 1
		else: direction=3 if movement.y<0 else 2
	else: frame=0
	# Walking into the opening moves to the neighboring room.
	if not Game.run.fighting and door_delay<=0:
		for id in room().links:
			var diff: Vector2i=Game.run.floor_data.rooms[id].pos-room().pos
			var at_door=(diff.x<0 and player.x<48 and absf(player.y-300)<48) or (diff.x>0 and player.x>852 and absf(player.y-300)<48) or (diff.y<0 and player.y<68 and absf(player.x-450)<48) or (diff.y>0 and player.y>537 and absf(player.x-450)<48)
			if at_door:
				goto_room(id)
				return
	player=player.clamp(AREA.position+Vector2(14,14),AREA.end-Vector2(14,14))
	var aim=Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Rect2(Vector2.ZERO,Vector2(900,600)).has_point(get_local_mouse_position()): aim=get_local_mouse_position()-player
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
	queue_redraw()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or paused: return
	if event.physical_keycode==KEY_E: use_weapon()
	if event.physical_keycode==KEY_Q: use_drug()
func shoot(pos: Vector2,dir: Vector2,enemy: bool,damage: float,distance: float=900,penetrating: bool=false) -> void:
	bullets.append({"pos":pos,"vel":dir*(230 if enemy else 540),"enemy":enemy,"damage":damage,"distance":distance,"hit":[],"penetrating":penetrating})
func update_enemies(delta: float) -> void:
	for e in enemies:
		var to: Vector2=player-e.pos
		e.timer-=delta
		e.phase+=delta
		match int(e.type):
			0: # mutated rat: direct chase
				e.pos+=to.normalized()*95*delta
			1: # bandit: keep distance and aimed shot
				if to.length()>260: e.pos+=to.normalized()*65*delta
				elif to.length()<180: e.pos-=to.normalized()*65*delta
				if e.timer<=0:
					shoot(e.pos,to.normalized(),true,12)
					e.timer=1.5
			2: # spore turret: radial pattern
				if e.timer<=0:
					for i in range(8): shoot(e.pos,Vector2.RIGHT.rotated(i*TAU/8+e.phase*0.3),true,9)
					e.timer=2.7
			3: # crawler: telegraphed charge, direction is locked during wind-up
				if e.timer<=0:
					e.velocity=to.normalized()*320
					e.timer=2.3
				if e.timer<1.85 and e.timer>1.2: e.pos+=e.velocity*delta
				elif e.timer<1.2: e.pos+=to.normalized()*35*delta
			4: # station custodian boss: aimed fans and rotating ring
				e.pos+=to.normalized()*42*delta
				if e.timer<=0:
					for i in range(12): shoot(e.pos,Vector2.RIGHT.rotated(i*TAU/12+e.phase*0.25),true,13)
					for i in range(-1,2): shoot(e.pos,to.normalized().rotated(i*0.15),true,15)
					e.timer=1.6 if e.hp<e.max*0.5 else 2.2
		e.pos=e.pos.clamp(AREA.position+Vector2(25,25),AREA.end-Vector2(25,25))
		if to.length()<(42 if e.type==4 else 27): take_damage(18)
func update_bullets(delta: float) -> void:
	for b in bullets.duplicate():
		b.pos+=b.vel*delta
		b.distance-=b.vel.length()*delta
		if b.distance<=0 or not AREA.has_point(b.pos):
			bullets.erase(b)
			continue
		if b.enemy:
			if b.pos.distance_to(player)<16:
				take_damage(b.damage)
				bullets.erase(b)
		else:
			for e in enemies.duplicate():
				if not b.hit.has(e) and b.pos.distance_to(e.pos)<(35 if e.type==4 else 23):
					e.hp-=b.damage
					b.hit.append(e)
					if e.hp<=0: enemies.erase(e)
					if not b.penetrating:
						bullets.erase(b)
						break
func take_damage(amount: float) -> void:
	if hurt_cd>0 or Game.run.shield>0: return
	Game.run.hp-=amount*(1.0-float(Game.run.stats.armor))
	hurt_cd=0.65
	sounds.hit.play()
func goto_room(id: int) -> void:
	var diff: Vector2i=Game.run.floor_data.rooms[id].pos-room().pos
	if Game.move_room(id):
		var spawn=Vector2(450,300)
		if diff.x>0: spawn=Vector2(85,300)
		if diff.x<0: spawn=Vector2(815,300)
		if diff.y>0: spawn=Vector2(450,105)
		if diff.y<0: spawn=Vector2(450,500)
		enter_room(spawn)
	else: notice.emit("战斗中无法通行，或电量不足。")
func use_weapon() -> void:
	if Game.run.weapon=="" or Game.run.weapon_cd>0: return
	var aim=(get_local_mouse_position()-player).normalized()
	if aim==Vector2.ZERO: aim=Vector2.RIGHT
	match Game.run.weapon:
		"4_0":
			for e in enemies.duplicate():
				if e.pos.distance_to(player)<250:
					e.hp-=45*float(Game.run.damage)
					e.pos+=(e.pos-player).normalized()*90
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
	var id: String=Game.run.drug
	if id=="": return
	var entry: Dictionary={}
	for candidate in Game.run.bag:
		if candidate.id==id and candidate.uses>0:
			entry=candidate
			break
	if entry.is_empty(): return
	match id:
		"3_0": Game.run.hp=minf(Game.run.stats.hp,Game.run.hp+35)
		"3_1": Game.run.buff=12.0
		"3_2": Game.run.timer+=90.0
		"3_3": Game.run.hp=minf(Game.run.stats.hp,Game.run.hp+70)
	entry.uses-=1
	if entry.uses<=0:
		Game.run.bag.erase(entry)
		Game.run.drug=""
	notice.emit("使用了"+C.item(id).name)
	changed.emit()
func create_loot() -> void:
	var loot: Array=room().loot
	if room().kind=="boss":
		loot.append("5_%d" % rng.randi_range(0,3))
		loot.append("chest")
	else:
		var roll=rng.randf()
		if roll<0.2: pass
		elif roll<0.38: loot.append("power")
		elif roll<0.52: loot.append("5_%d" % rng.randi_range(0,3))
		elif roll<0.66: loot.append("3_%d" % rng.randi_range(0,3))
		elif roll<0.78: loot.append("credits")
		elif roll<0.91: loot.append("scrap")
		else: loot.append("chest")
func collect(index: int) -> void:
	if Game.run.fighting or index>=room().loot.size(): return
	var entry=room().loot[index]
	var id: String=entry.id if entry is Dictionary else entry
	if id=="chest":
		room().loot.remove_at(index)
		var value=20+int(Game.run.floor)*18
		var choices=C.all_ids()+["scrap"]
		for _i in range(8):
			var next: String=choices[rng.randi_range(0,choices.size()-1)]
			if C.item(next).price<=value:
				room().loot.append(next)
				value-=int(C.item(next).price)
			if value<6: break
		notice.emit("宝箱开启，物资价值上限随层数提升。")
	elif id=="power" or id=="credits":
		Game.state.power+=8 if id=="credits" else 5
		if id=="power": Game.run.energy+=5
		room().loot.remove_at(index)
	else:
		if not Game.pick_up(id,int(entry.uses) if entry is Dictionary else -1):
			notice.emit("背包已满，请先整理或丢弃。")
			return
		room().loot.remove_at(index)
	sounds.pickup.play()
	changed.emit()
func finish(success: bool) -> void:
	if pending_end: return
	pending_end=true
	ended.emit(success)
func _draw() -> void:
	if Game.run.is_empty(): return
	draw_style_box(style(),Rect2(0,0,900,600))
	for x in range(45,855,45): draw_line(Vector2(x,65),Vector2(x,540),Color("203944"),1)
	for y in range(65,541,45): draw_line(Vector2(45,y),Vector2(855,y),Color("203944"),1)
	draw_rect(AREA,Color("47606b"),false,7)
	var r=room()
	for id in r.links:
		var diff: Vector2i=Game.run.floor_data.rooms[id].pos-r.pos
		var pos=Vector2(450,65) if diff.y<0 else Vector2(450,540) if diff.y>0 else Vector2(45,300) if diff.x<0 else Vector2(855,300)
		draw_rect(Rect2(pos-Vector2(25,15),Vector2(50,30)),Color("9e685e") if Game.run.fighting else Color("79bdb5"))
	draw_string(font,Vector2(45,34),"%s  /  第 %d 层  ·  房间 %02d" % [{"normal":"回收区","start":"检查站","reward":"遗留物资室","shop":"流动补给商","boss":"站区守卫"}[r.kind],Game.run.floor,int(r.id)+1],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("b9d9d6"))
	if not Game.run.fighting:
		if r.kind=="reward" and not r.claimed: draw_texture_rect(textures["res://assets/chest.svg"],Rect2(420,250,60,60),false)
		if r.kind=="boss" and r.cleared:
			draw_circle(Vector2(450,300),52,Color("3f7479"))
			draw_string(font,Vector2(405,307),"下一层",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("c5e4db"))
		if r.kind=="shop": draw_texture_rect(textures["res://assets/station.svg"],Rect2(420,240,65,65),false)
	for e in enemies:
		var dim=Vector2(86,86) if e.type==4 else Vector2(53,53)
		if e.type==3 and e.timer>1.85: draw_line(e.pos,e.pos+e.velocity*0.5,Color(0.9,0.45,0.35,0.5),3)
		draw_texture_rect(textures["res://assets/enemies/%d.svg" % e.type],Rect2(e.pos-dim*0.5,dim),false)
		draw_rect(Rect2(e.pos-Vector2(22,35),Vector2(44,4)),Color("21323a"))
		draw_rect(Rect2(e.pos-Vector2(22,35),Vector2(44*maxf(0,e.hp/e.max),4)),Color("d5927e"))
	if hurt_cd<=0 or int(age*14)%2==0:
		draw_texture_rect(textures["res://assets/player/%d_%d.svg" % [direction,frame]],Rect2(player-Vector2(27,30),Vector2(54,54)),false)
	if Game.run.shield>0: draw_arc(player,35,0,TAU,40,Color("8bd9e3"),3,true)
	if flash>0: draw_arc(player,250*(1-flash/0.3),0,TAU,60,Color("a8ebe2"),4,true)
	for b in bullets:
		draw_texture_rect(textures["res://assets/enemy_bullet.svg" if b.enemy else "res://assets/bullet.svg"],Rect2(b.pos-Vector2(7,7),Vector2(14,14)),false)
	draw_string(font,Vector2(45,580),"WASD 移动   /   方向键或鼠标射击   /   E 主动武器   /   Q 药物   /   Tab 背包   /   Esc 暂停",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("6f949e"))
func style() -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=Color("142a35")
	s.corner_radius_top_left=12
	s.corner_radius_top_right=12
	s.corner_radius_bottom_left=12
	s.corner_radius_bottom_right=12
	return s
