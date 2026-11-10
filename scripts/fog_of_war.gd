extends RefCounted
# Reveal only rooms joined by a real passage to a visited room.
static func visibility(rooms: Array,current: int) -> Dictionary:
	var visible: Dictionary={}
	for room in rooms:
		if room.visited or int(room.id)==current:
			visible[int(room.id)]="explored"
	for room in rooms:
		if not room.visited and int(room.id)!=current:continue
		for neighbor in room.links:
			if not visible.has(int(neighbor)):visible[int(neighbor)]="frontier"
	if current>=0 and current<rooms.size():visible[current]="current"
	return visible
