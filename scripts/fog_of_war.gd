extends RefCounted
# Pure visibility rule: only visited cells and their four spatial neighbors.
static func visibility(rooms: Array,current: int) -> Dictionary:
	var visible: Dictionary={}
	var explored_positions: Dictionary={}
	for room in rooms:
		if room.visited or int(room.id)==current:
			visible[int(room.id)]="explored"
			explored_positions[room.pos]=true
	for room in rooms:
		if visible.has(int(room.id)):continue
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if explored_positions.has(room.pos+direction):
				visible[int(room.id)]="frontier"
				break
	if current>=0 and current<rooms.size():visible[current]="current"
	return visible
