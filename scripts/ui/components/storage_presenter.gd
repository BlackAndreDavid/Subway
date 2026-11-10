extends RefCounted
const Inventory=preload("res://scripts/inventory.gd")
static func create(mode: String) -> Control:
	var grid=preload("res://scenes/inventory/grid.tscn").instantiate()
	grid.cell_size=48 if mode=="stash" else 66
	grid.dimensions=Vector2i(Game.STASH_COLUMNS,int(Game.state.stash_rows)) if mode=="stash" else Game.bag_dimensions()
	grid.items=Game.stash_entries() if mode=="stash" else Game.run.bag
	grid.allowed=func():return Game.run.is_empty() if mode=="stash" else not Game.run.is_empty() and not Game.run.fighting
	grid.drag_source=func(index):return {"kind":mode,"source":grid.get_instance_id(),"index":index}
	grid.can_place=func(data,pos,rotation):
		return data.get("kind","")==mode and data.get("source",0)==grid.get_instance_id() and int(data.index)>=0 and int(data.index)<grid.items.size() and Inventory.fits(grid.items,grid.dimensions,grid.items[data.index].id,pos,rotation,int(data.index))
	grid.place_item=func(data,pos,rotation):
		var ok=Game.move_stash(int(data.index),pos,rotation) if mode=="stash" else Game.move_bag(int(data.index),pos,rotation)
		if ok:
			grid.items=Game.stash_entries() if mode=="stash" else Game.run.bag
			grid.refresh()
		return ok
	return grid
