extends RefCounted
const Layouts=preload("res://scripts/room_layout_data.gd")
const UNIT=Vector2(810,475)
const PAD=Vector2(45,65)
const TILE=UNIT/Vector2(15,9)
const SAMPLES=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-0.707,-0.707),Vector2(0.707,-0.707),Vector2(-0.707,0.707),Vector2(0.707,0.707)]
var origin=Vector2i.ZERO
var cells: Array=[]
var areas: Array[Rect2]=[]
var obstacles: Array[Rect2]=[]
var voids: Array[Rect2]=[]
var bounds=Rect2(PAD,UNIT)
var navigation_cache={}
func configure(room: Dictionary) -> void:
	cells=room.get("cells",[room.pos]).duplicate()
	origin=cells[0]
	var end: Vector2i=cells[0]
	for cell in cells:
		origin=origin.min(cell)
		end=end.max(cell)
	bounds=Rect2(PAD,Vector2(end-origin+Vector2i.ONE)*UNIT)
	areas.clear()
	obstacles.clear()
	voids.clear()
	navigation_cache.clear()
	for y in range(origin.y,end.y+1):
		for x in range(origin.x,end.x+1):
			if not cells.has(Vector2i(x,y)):voids.append(Rect2(PAD+Vector2(Vector2i(x,y)-origin)*UNIT,UNIT))
	for index in range(cells.size()):
		var area=Rect2(PAD+Vector2(cells[index]-origin)*UNIT,UNIT)
		areas.append(area)
		var layout_id=int(room.get("layout_ids",[-1])[index])
		if layout_id<0:continue
		var rows: Array=Layouts.LAYOUTS[layout_id].rows
		for y in range(rows.size()):
			for x in range(rows[y].length()):
				if rows[y][x]=="#":obstacles.append(Rect2(area.position+Vector2(x,y)*TILE+Vector2(3,3),TILE-Vector2(6,6)))
func view_extent() -> Vector2:return bounds.end+Vector2(45,60)
func contains_point(point: Vector2) -> bool:
	for area in areas:
		if area.has_point(point):return true
	return false
func can_stand(point: Vector2,radius: float) -> bool:
	if not bounds.grow(-radius).has_point(point):return false
	for block in obstacles+voids:
		if point.distance_squared_to(point.clamp(block.position,block.end))<radius*radius:return false
	return true
func move_actor(point: Vector2,motion: Vector2,radius: float) -> Vector2:
	var steps=maxi(1,ceili(motion.length()/maxf(8,radius*0.7)))
	var increment=motion/steps
	for step in range(steps):
		var next=point+Vector2(increment.x,0)
		if can_stand(next,radius):point.x=next.x
		next=point+Vector2(0,increment.y)
		if can_stand(next,radius):point.y=next.y
	return point
func segment_clear(start: Vector2,finish: Vector2,radius: float=3) -> bool:
	if not can_stand(start,radius) or not can_stand(finish,radius):return false
	var sweep=Rect2(start.min(finish),(finish-start).abs()).grow(radius+0.01)
	for block in obstacles+voids:
		if not sweep.intersects(block):continue
		if segment_intersects_box(start,finish,block):return false
		for corner in [block.position,Vector2(block.end.x,block.position.y),block.end,Vector2(block.position.x,block.end.y)]:
			if corner.distance_squared_to(Geometry2D.get_closest_point_to_segment(corner,start,finish))<radius*radius:return false
	return true
func segment_intersects_box(start: Vector2,finish: Vector2,block: Rect2) -> bool:
	var delta=finish-start
	var enter=0.0
	var leave=1.0
	for axis in range(2):
		if absf(delta[axis])<0.000001:
			if start[axis]<block.position[axis] or start[axis]>block.end[axis]:return false
		else:
			var a=(block.position[axis]-start[axis])/delta[axis]
			var b=(block.end[axis]-start[axis])/delta[axis]
			enter=maxf(enter,minf(a,b))
			leave=minf(leave,maxf(a,b))
			if enter>leave:return false
	return true
func closest_free(point: Vector2,radius: float=14) -> Vector2:
	if can_stand(point,radius):return point
	var closest=Vector2.ZERO
	var best=INF
	for area in areas:
		for y in range(9):
			for x in range(15):
				var candidate=area.position+(Vector2(x,y)+Vector2.ONE*0.5)*TILE
				var distance=candidate.distance_squared_to(point)
				if distance<best and can_stand(candidate,radius):
					closest=candidate
					best=distance
	return closest
func navigation(radius: float) -> Dictionary:
	var bucket=14 if radius<=14 else 22 if radius<=22 else 38
	if navigation_cache.has(bucket):return navigation_cache[bucket]
	var grid=AStarGrid2D.new()
	grid.region=Rect2i(Vector2i.ZERO,Vector2i((bounds.size/UNIT)*Vector2(15,9)))
	grid.cell_size=TILE
	grid.offset=PAD+TILE/2
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var free: Array[Vector2i]=[]
	for y in range(grid.region.size.y):
		for x in range(grid.region.size.x):
			var cell=Vector2i(x,y)
			var solid=not can_stand(grid.get_point_position(cell),bucket)
			grid.set_point_solid(cell,solid)
			if not solid:free.append(cell)
	navigation_cache[bucket]={"grid":grid,"free":free}
	return navigation_cache[bucket]
func nearest_navigation_cell(point: Vector2,data: Dictionary) -> Vector2i:
	var grid: AStarGrid2D=data.grid
	var cell=Vector2i(floori((point.x-PAD.x)/TILE.x),floori((point.y-PAD.y)/TILE.y))
	if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):return cell
	var best=INF
	var closest=Vector2i.ZERO
	for candidate in data.free:
		var distance=grid.get_point_position(candidate).distance_squared_to(point)
		if distance<best:
			closest=candidate
			best=distance
	return closest
func next_waypoint(start: Vector2,finish: Vector2,radius: float=14) -> Vector2:
	if segment_clear(start,finish,radius):return finish
	var data=navigation(radius)
	var grid: AStarGrid2D=data.grid
	var path=grid.get_point_path(nearest_navigation_cell(start,data),nearest_navigation_cell(finish,data))
	if path.is_empty():return start
	# Join the grid from the actor's actual position before cutting any corner.
	for index in range(mini(4,path.size()-1),-1,-1):
		if segment_clear(start,path[index],radius):return path[index]
	return start
func navigation_direction(start: Vector2,finish: Vector2,radius: float=14) -> Vector2:
	return (next_waypoint(start,finish,radius)-start).normalized()
func door_position(portal: Dictionary) -> Vector2:
	return PAD+Vector2(Vector2i(portal.cell)-origin)*UNIT+UNIT/2+Vector2(portal.normal)*UNIT/2
func boundary_segments() -> Array:
	var result: Array=[]
	for cell in cells:
		var area=Rect2(PAD+Vector2(cell-origin)*UNIT,UNIT)
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if cells.has(cell+direction):continue
			var center=area.get_center()+Vector2(direction)*UNIT/2
			var half=Vector2(0,UNIT.y/2) if direction.x!=0 else Vector2(UNIT.x/2,0)
			result.append([center-half,center+half])
	return result
