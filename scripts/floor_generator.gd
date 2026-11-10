extends RefCounted
# Two tree-grown lobes, joined only by the reward articulation node.
# Additional local links give loops without bypassing the middle reward.
static func generate(seed_value: int, floor_number: int = 1) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var rooms: Array = []
	var at: Dictionary = {}
	for x in range(-5,7):
		var kind = "normal"
		if x == -5: kind = "start"
		if x == 0: kind = "reward"
		if x == 6: kind = "boss"
		add_room(rooms,at,Vector2i(x,0),kind)
		if rooms.size()>1: link(rooms,rooms.size()-2,rooms.size()-1)
	for side in [-1,1]:
		var target = rng.randi_range(6,9)
		for _branch in range(target):
			var candidates: Array = []
			for room in rooms:
				var p: Vector2i = room.pos
				if (side==-1 and p.x<0) or (side==1 and p.x>0 and p.x<6):
					for dir in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						var q: Vector2i = p+dir
						if q.x>=(-5 if side==-1 else 1) and q.x<=(-1 if side==-1 else 5) and absi(q.y)<=2 and not at.has(q):
							candidates.append([int(room.id),q])
			if candidates.is_empty(): break
			var choice: Array = candidates[rng.randi_range(0,candidates.size()-1)]
			add_room(rooms,at,choice[1],"normal")
			link(rooms,choice[0],rooms.size()-1)
	# One shop in the second lobe.
	var shops: Array = []
	for room in rooms:
		if room.pos.x>0 and room.kind=="normal": shops.append(room.id)
	rooms[shops[rng.randi_range(0,shops.size()-1)]].kind="shop"
	for room in rooms:
		for dir in [Vector2i.RIGHT,Vector2i.DOWN]:
			var q: Vector2i = room.pos+dir
			if at.has(q) and room.pos.x*q.x>0 and q.x<6 and rng.randf()<0.45:
				link(rooms,room.id,at[q])
	var route: Array = []
	var seen: Dictionary = {}
	# Traverse all branches first; the unique boss leaf is entered last.
	walk(rooms,0,-1,seen,route)
	# The DFS returns to the root after visiting all non-boss nodes.
	# Then use a shortest route to the boss; no loot is assumed.
	var queue: Array = [0]
	var parents: Dictionary = {0:-1}
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == 11: break
		for neighbor in rooms[current].links:
			if not parents.has(neighbor):
				parents[neighbor]=current
				queue.append(neighbor)
	var tail: Array = []
	var cursor = 11
	while cursor != 0:
		tail.push_front(cursor)
		cursor=parents[cursor]
	route.append_array(tail)
	return {"rooms":rooms,"seed":seed_value,"floor":floor_number,"route":route,"budget":route.size()-1+6,"boss":11,"reward":5}

static func add_room(rooms: Array, at: Dictionary, pos: Vector2i, kind: String) -> void:
	var id = rooms.size()
	rooms.append({"id":id,"pos":pos,"kind":kind,"links":[],"cleared":kind!="normal" and kind!="boss", "visited":false,"claimed":false,"loot":[]})
	at[pos]=id

static func link(rooms: Array,a: int,b: int) -> void:
	if not rooms[a].links.has(b): rooms[a].links.append(b)
	if not rooms[b].links.has(a): rooms[b].links.append(a)

static func walk(rooms: Array,id: int,parent: int,seen: Dictionary,route: Array) -> void:
	seen[id]=true
	route.append(id)
	# Boss-containing spine child last, determined by x on the central spine.
	var children: Array = rooms[id].links.duplicate()
	children.sort_custom(func(a,b): return priority(rooms[a])<priority(rooms[b]))
	for child in children:
		if child!=11 and not seen.has(child):
			walk(rooms,child,id,seen,route)
			route.append(id)

static func priority(room: Dictionary) -> int:
	if room.kind=="boss": return 1000
	if room.pos.y==0: return 100+room.pos.x
	return room.id
