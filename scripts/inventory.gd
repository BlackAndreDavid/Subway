extends RefCounted
# All inventory decisions use occupied cells, never an abstract item count.
const C=preload("res://scripts/catalog.gd")
static func fits(items: Array,dimensions: Vector2i,id: String,position: Vector2i,rotation: int=0,ignore: int=-1) -> bool:
	return fits_cells(occupancy(items,ignore),dimensions,C.cells(id,rotation),position)
static func occupancy(items: Array,ignore: int=-1) -> Dictionary:
	var occupied={}
	for index in range(items.size()):
		if index==ignore:continue
		var item: Dictionary=items[index]
		for cell in C.cells(item.id,int(item.get("rot",0))):occupied[Vector2i(int(item.x),int(item.y))+cell]=true
	return occupied
static func fits_cells(occupied: Dictionary,dimensions: Vector2i,cells: Array,position: Vector2i) -> bool:
	for cell in cells:
		var point: Vector2i=position+cell
		if point.x<0 or point.y<0 or point.x>=dimensions.x or point.y>=dimensions.y or occupied.has(point):return false
	return true
static func first_fit(items: Array,dimensions: Vector2i,id: String) -> Dictionary:
	var occupied=occupancy(items)
	for rotation in range(4):
		var cells=C.cells(id,rotation)
		var extent=C.bounds(id,rotation)
		for y in range(dimensions.y-extent.y+1):
			for x in range(dimensions.x-extent.x+1):
				if fits_cells(occupied,dimensions,cells,Vector2i(x,y)):return {"x":x,"y":y,"rot":rotation}
	return {}
static func valid(items: Array,dimensions: Vector2i) -> bool:
	var prefix: Array=[]
	for item in items:
		if not item is Dictionary or not item.has_all(["id","x","y","rot"]) or not C.valid_ids().has(item.id):return false
		for field in ["x","y","rot"]:
			if not (item[field] is int or item[field] is float) or int(item[field])!=item[field]:return false
		if int(item.rot)<0 or int(item.rot)>3:return false
		if not fits(prefix,dimensions,item.id,Vector2i(int(item.x),int(item.y)),int(item.rot)):return false
		prefix.append(item)
	return dimensions.x>0 and dimensions.y>0
static func used(items: Array) -> int:
	var count=0
	for item in items:count+=C.cells(item.id).size()
	return count
