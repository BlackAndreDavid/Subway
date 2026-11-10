extends RefCounted
signal changed
const C=preload("res://scripts/catalog.gd")
const Inventory=preload("res://scripts/inventory.gd")
const CATEGORIES={"module":5,"weapon":4,"drug":3}
var stock: Array=[]
var slots={"module":-1,"weapon":-1,"drug":-1}
var revision=0
var layout: Array=[]
var dimensions=Vector2i(12,10)
func _init(inventory: Array=[],positions: Array=[],bounds: Vector2i=Vector2i(12,10)) -> void:
	stock=inventory.duplicate()
	dimensions=bounds
	layout=positions.duplicate(true)
	if layout.size()!=stock.size():
		layout=[]
		var placed: Array=[]
		for id in stock:
			var pos=Inventory.first_fit(placed,dimensions,id)
			while pos.is_empty():
				dimensions.y+=2
				pos=Inventory.first_fit(placed,dimensions,id)
			layout.append(pos.duplicate())
			pos.id=id
			placed.append(pos)
func entries() -> Array:
	var result: Array=[]
	for index in range(stock.size()):
		var entry: Dictionary=layout[index].duplicate()
		entry.id=stock[index]
		result.append(entry)
	return result
func item_index(slot: String) -> int:
	return int(slots.get(slot,-1))
func equipped_slot(index: int) -> String:
	for key in slots:
		if int(slots[key])==index:return key
	return ""
func selected_id(slot: String) -> String:
	var index=item_index(slot)
	return "" if index<0 else str(stock[index])
func drag_data(index: int,origin: String="warehouse") -> Dictionary:
	if index<0 or index>=stock.size():return {}
	if origin=="warehouse" and equipped_slot(index)!="":return {}
	if origin!="warehouse" and item_index(origin)!=index:return {}
	return {"kind":"warehouse_equipment","model":get_instance_id(),"revision":revision,"index":index,"origin":origin}
func valid_payload(data: Variant) -> bool:
	if not data is Dictionary or not data.has_all(["kind","model","revision","index","origin"]):return false
	if data.kind!="warehouse_equipment" or data.model!=get_instance_id() or data.revision!=revision:return false
	if not data.index is int or data.index<0 or data.index>=stock.size():return false
	return not drag_data(int(data.index),str(data.origin)).is_empty()
func accepts(slot: String,data: Variant) -> bool:
	return CATEGORIES.has(slot) and valid_payload(data) and int(C.item(stock[data.index]).category)==int(CATEGORIES[slot])
func assign(slot: String,data: Variant) -> bool:
	if not accepts(slot,data):return false
	slots[slot]=data.index
	revision+=1
	changed.emit()
	return true
func return_to_warehouse(data: Variant) -> bool:
	if not valid_payload(data) or data.origin=="warehouse":return false
	slots[data.origin]=-1
	revision+=1
	changed.emit()
	return true
func can_move(data: Variant,position: Vector2i,rotation: int) -> bool:
	return valid_payload(data) and Inventory.fits(entries(),dimensions,stock[data.index],position,rotation,int(data.index))
func move(data: Variant,position: Vector2i,rotation: int) -> bool:
	if not can_move(data,position,rotation):return false
	if data.origin!="warehouse":slots[data.origin]=-1
	layout[data.index]={"x":position.x,"y":position.y,"rot":posmod(rotation,4)}
	revision+=1
	changed.emit()
	return true
