extends RefCounted
const DIRECTIONS=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
static func region(position: Vector2i) -> int:
	return -1 if position.x<-1 or (position.x==-1 and position.y<-1) else 1
static func generate(seed_value: int,floor_number: int=1) -> Dictionary:
	var original=legacy_generate(seed_value,floor_number)
	var target=ceili(original.rooms.size()*1.5)
	for attempt in range(128):
		var rng=RandomNumberGenerator.new()
		rng.seed=(seed_value^0xB453)+attempt*104729
		var result=grow_floor(rng,target)
		if result.is_empty():continue
		var rooms: Array=result.rooms
		var route=compact_route(rooms,int(original.budget))
		var seen={}
		for id in route:seen[id]=true
		var coverage=float(seen.size())/rooms.size()
		if coverage<0.8:continue
		var mirror_x=rng.randf()<0.5
		var mirror_y=rng.randf()<0.5
		for room in rooms:
			for index in range(room.cells.size()):
				var point: Vector2i=room.cells[index]
				room.cells[index]=Vector2i(1-point.x if mirror_x else point.x,-point.y if mirror_y else point.y)
			room.pos=room.cells[0]
			room.layout_ids=[]
			for cell in room.cells:room.layout_ids.append(-1 if room.kind in ["start","reward","shop"] else 0 if room.kind=="boss" else rng.randi_range(0,9))
		make_portals(rooms,rng)
		var occupied=0
		for room in rooms:occupied+=room.cells.size()
		return {"rooms":rooms,"seed":seed_value,"floor":floor_number,"route":route,"budget":original.budget,"boss":11,"reward":5,"base_room_count":original.rooms.size(),"base_budget":original.budget,"spine_depth":11,"coverage":coverage,"occupied_cells":occupied,"spine_turns":result.turns}
	push_error("Unable to construct a connected floor for seed %d" % seed_value)
	return {}
static func inside(point: Vector2i) -> bool:
	return point.x>=-5 and point.x<=6 and absi(point.y)<=2
static func footprint(origin: Vector2i,amount: int,variant: int) -> Array:
	var cells: Array=[Vector2i.ZERO]
	if amount>=2:cells.append(Vector2i.RIGHT)
	if amount==3:cells.append(Vector2i.DOWN if variant>=4 else Vector2i.RIGHT*2)
	for turn in range(variant%4):
		for index in range(cells.size()):cells[index]=Vector2i(-cells[index].y,cells[index].x)
	for index in range(cells.size()):cells[index]+=origin
	return cells
static func ensure_cell(rooms: Array,at: Dictionary,point: Vector2i,parent: Vector2i) -> void:
	if at.has(point):return
	add_room(rooms,at,point,"normal")
	link(rooms,int(at[parent]),rooms.size()-1)
static func distance(rooms: Array,start: int,finish: int) -> int:
	var queue: Array=[start]
	var distances={start:0}
	for current in queue:
		if current==finish:return distances[current]
		for neighbor in rooms[current].links:
			if not distances.has(neighbor):
				distances[neighbor]=int(distances[current])+1
				queue.append(neighbor)
	return -1
static func grow_floor(rng: RandomNumberGenerator,target: int) -> Dictionary:
	var rooms: Array=[]
	var at={}
	var spine: Array=[]
	var first_corner=rng.randi_range(-4,-3)
	var first_drop=rng.randi_range(-1,0)
	var second_drop=rng.randi_range(1,2)
	for x in range(-5,first_corner+1):spine.append(Vector2i(x,0))
	spine.append(Vector2i(first_corner,-1))
	for x in range(first_corner+1,0):spine.append(Vector2i(x,-1))
	for x in range(0,first_drop+1):spine.append(Vector2i(x,-1))
	spine.append(Vector2i(first_drop,0))
	for x in range(first_drop+1,second_drop+1):spine.append(Vector2i(x,0))
	spine.append(Vector2i(second_drop,1))
	for x in range(second_drop+1,4):spine.append(Vector2i(x,1))
	var turns=0
	var last=Vector2i.ZERO
	for index in range(spine.size()):
		var kind="start" if index==0 else "reward" if index==5 else "boss" if index==11 else "normal"
		add_room(rooms,at,spine[index],kind)
		if index>0:
			link(rooms,index-1,index)
			var direction: Vector2i=spine[index]-spine[index-1]
			if last!=Vector2i.ZERO and direction!=last:turns+=1
			last=direction
	# Connect the middle reward on four sides and the boss on three sides.
	ensure_cell(rooms,at,Vector2i(-2,-2),Vector2i(-2,-1))
	ensure_cell(rooms,at,Vector2i(-1,-2),Vector2i(-2,-2))
	ensure_cell(rooms,at,Vector2i(-1,0),Vector2i(0,0))
	ensure_cell(rooms,at,Vector2i(0,-1),Vector2i(0,0))
	for direction in DIRECTIONS:link(rooms,5,int(at[Vector2i(-1,-1)+direction]))
	ensure_cell(rooms,at,Vector2i(2,0),Vector2i(2,1))
	ensure_cell(rooms,at,Vector2i(3,0),Vector2i(2,0))
	ensure_cell(rooms,at,Vector2i(2,2),Vector2i(2,1))
	ensure_cell(rooms,at,Vector2i(3,2),Vector2i(2,2))
	link(rooms,11,int(at[Vector2i(3,0)]))
	link(rooms,11,int(at[Vector2i(3,2)]))
	var large=0
	while rooms.size()<target:
		var amount=2+large%2 if large<4 else 1
		var candidates: Array=[]
		for room in rooms:
			if room.kind in ["start","boss"]:continue
			for cell in room.cells:
				for direction in DIRECTIONS:
					var point: Vector2i=cell+direction
					if not inside(point) or at.has(point) or (room.kind!="reward" and region(point)!=region(cell)):continue
					for variant in range(8 if amount==3 else 4 if amount==2 else 1):
						var cells=footprint(point,amount,variant)
						if cells.all(func(p):return inside(p) and not at.has(p) and region(p)==region(point)):
							candidates.append({"parent":room.id,"cells":cells})
		if candidates.is_empty():return {}
		var choice: Dictionary=candidates[rng.randi_range(0,candidates.size()-1)]
		add_room(rooms,at,choice.cells[0],"normal")
		rooms.back().cells=choice.cells
		for cell in choice.cells:at[cell]=rooms.size()-1
		link(rooms,int(choice.parent),rooms.size()-1)
		if amount>1:large+=1
	var pairs: Array=[]
	for room in rooms:
		for cell in room.cells:
			for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
				var neighbor=at.get(cell+direction,-1)
				if neighbor<0 or neighbor==room.id or rooms[neighbor].kind in ["start","boss"] or room.kind in ["start","boss"]:continue
				if region(cell)==region(cell+direction) or room.kind=="reward" or rooms[neighbor].kind=="reward":pairs.append(Vector2i(room.id,neighbor))
	for index in range(pairs.size()-1,0,-1):
		var other=rng.randi_range(0,index)
		var swap=pairs[index]
		pairs[index]=pairs[other]
		pairs[other]=swap
	for pair in pairs:
		if rooms[pair.x].links.has(pair.y) or rng.randf()>0.65:continue
		link(rooms,pair.x,pair.y)
		if distance(rooms,0,11)<11:
			rooms[pair.x].links.erase(pair.y)
			rooms[pair.y].links.erase(pair.x)
	var shops: Array=[]
	for room in rooms:
		if room.kind=="normal" and room.cells.size()==1 and region(room.pos)==1:shops.append(room.id)
	rooms[shops[rng.randi_range(0,shops.size()-1)]].kind="shop"
	return {"rooms":rooms,"turns":turns}
static func make_portals(rooms: Array,rng: RandomNumberGenerator) -> void:
	for room in rooms:room.doors={}
	for room in rooms:
		for neighbor in room.links:
			if neighbor<room.id:continue
			var choices: Array=[]
			for cell in room.cells:
				for direction in DIRECTIONS:
					if rooms[neighbor].cells.has(cell+direction):choices.append({"cell":cell,"normal":direction})
			var portal: Dictionary=choices[rng.randi_range(0,choices.size()-1)]
			room.doors[neighbor]=portal
			rooms[neighbor].doors[room.id]={"cell":portal.cell+portal.normal,"normal":-portal.normal}
static func path_table(rooms: Array) -> Dictionary:
	var paths={}
	for start in range(rooms.size()):
		var queue: Array=[start]
		var parents={start:-1}
		while not queue.is_empty():
			var current: int=queue.pop_front()
			if current==11 and start!=11:continue
			for neighbor in rooms[current].links:
				if not parents.has(neighbor):
					parents[neighbor]=current
					queue.append(neighbor)
		for finish in range(rooms.size()):
			var path: Array=[finish]
			var cursor=finish
			while cursor!=start:
				cursor=int(parents[cursor])
				path.push_front(cursor)
			paths[Vector2i(start,finish)]=path
	return paths
static func compact_route(rooms: Array,budget: int,target_coverage: float=1.0) -> Array:
	var paths=path_table(rooms)
	var route: Array=paths[Vector2i(0,11)].duplicate()
	var seen={}
	for id in route:seen[id]=true
	while seen.size()<ceili(rooms.size()*target_coverage):
		var best={}
		var best_score=-1.0
		for id in range(rooms.size()):
			if seen.has(id):continue
			for edge in range(route.size()-1):
				var left: Array=paths[Vector2i(route[edge],id)]
				var right: Array=paths[Vector2i(id,route[edge+1])]
				var cost=left.size()+right.size()-3
				if route.size()-1+cost>budget:continue
				var additions={}
				for node in left:
					if not seen.has(node):additions[node]=true
				for node in right:
					if not seen.has(node):additions[node]=true
				var score=float(additions.size())/maxi(1,cost)+(10 if cost==0 else 0)
				if score>best_score:
					best_score=score
					best={"edge":edge,"left":left,"right":right}
		if best.is_empty():break
		route=route.slice(0,best.edge)+best.left+best.right.slice(1)+route.slice(int(best.edge)+2)
		for id in route:seen[id]=true
	return route
# Two tree-grown lobes, joined only by the reward articulation node.
# Additional local links give loops without bypassing the middle reward.
static func legacy_generate(seed_value: int, floor_number: int = 1) -> Dictionary:
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
	rooms.append({"id":id,"pos":pos,"cells":[pos],"kind":kind,"links":[],"cleared":kind!="normal" and kind!="boss", "visited":false,"claimed":false,"loot":[]})
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
