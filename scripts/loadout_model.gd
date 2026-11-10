extends RefCounted
signal changed
const C=preload("res://scripts/catalog.gd")
const CATEGORIES={"module":5,"weapon":4,"drug":3}
var stock: Array=[]
var slots={"module":-1,"weapon":-1,"drug":-1}
var revision=0
func _init(inventory: Array=[]) -> void:
	stock=inventory.duplicate()
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
	if not int(C.item(stock[index]).category) in [3,4,5]:return {}
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
