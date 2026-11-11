extends RefCounted
# Reservations keep source copies intact until one atomic checkout.
const I=preload("res://scripts/inventory.gd")
const DIMENSIONS=Vector2i(8,4)
const CELL_SIZE=48
var entries: Array=[]
var revision=0
func clear() -> void:
	entries.clear()
	revision+=1
func contains(source: String,index: int) -> bool:
	return entries.any(func(entry):return entry.payload.source==source and entry.payload.index==index)
func drag(index: int) -> Dictionary:
	if index<0 or index>=entries.size():return {}
	return {"kind":"shop_cart","cart":get_instance_id(),"cart_revision":revision,"index":index,"id":entries[index].id}
func valid_drag(data: Variant) -> bool:
	return data is Dictionary and data.get("kind","")=="shop_cart" and data.get("cart",0)==get_instance_id() and data.get("cart_revision",-1)==revision and data.get("index",-1)>=0 and data.index<entries.size() and data.get("id","")==entries[data.index].id
func can_place(data: Dictionary,position: Vector2i,rotation: int) -> bool:
	if data.get("kind","")=="shop_cart":
		return valid_drag(data) and I.fits(entries,DIMENSIONS,data.id,position,rotation,int(data.index))
	return data.has_all(["id","source","index"]) and not contains(data.source,int(data.index)) and I.fits(entries,DIMENSIONS,data.id,position,rotation)
func place(data: Dictionary,position: Vector2i,rotation: int) -> bool:
	if not can_place(data,position,rotation):return false
	if valid_drag(data):
		entries[int(data.index)].merge({"x":position.x,"y":position.y,"rot":posmod(rotation,4)},true)
	else:entries.append({"id":data.id,"x":position.x,"y":position.y,"rot":posmod(rotation,4),"payload":data.duplicate(true)})
	revision+=1
	return true
func remove(data: Dictionary) -> bool:
	if not valid_drag(data):return false
	entries.remove_at(int(data.index))
	revision+=1
	return true
func selections() -> Array:
	var result: Array=[]
	for entry in entries:
		var payload: Dictionary=entry.payload.duplicate(true)
		payload.merge({"cart_x":entry.x,"cart_y":entry.y,"cart_rot":entry.rot},true)
		result.append(payload)
	return result
