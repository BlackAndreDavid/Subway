extends SceneTree
# Deterministic technical import: atlas slicing, shared scale and foot anchors.
# Artistic editing is done with image generation; this script never synthesizes art.
func _initialize() -> void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/manifest.json"))
	var atlas=Image.load_from_file("res://assets/art/sources/subway_atlas_v1.png")
	if atlas==null:
		push_error("Missing reviewed atlas")
		quit(1)
		return
	var atlas_cache={"subway_atlas_v1.png":atlas}
	var total=0
	var prepared: Array=[]
	var group_extents: Dictionary={}
	for key in manifest.entries:
		var entry=manifest.entries[key]
		var source: String=entry.source
		if not atlas_cache.has(source):atlas_cache[source]=Image.load_from_file("res://assets/art/sources/"+source)
		atlas=atlas_cache[source]
		if atlas==null:
			push_error("Missing reviewed source: "+source)
			quit(1)
			return
		var grid: Array=entry.get("grid",[8,9])
		var frames: Array[Image]=[]
		var bounds: Array[Rect2i]=[]
		var extent=Vector2i.ZERO
		for index in range(int(entry.frames)):
			var col=(int(entry.column)+index)%int(grid[0])
			var row=int(entry.row)+floori(float(int(entry.column)+index)/float(grid[0]))
			var x=roundi(float(col)*atlas.get_width()/float(grid[0]))
			var y=roundi(float(row)*atlas.get_height()/float(grid[1]))
			var right=roundi(float(col+1)*atlas.get_width()/float(grid[0]))
			var bottom=roundi(float(row+1)*atlas.get_height()/float(grid[1]))
			var cell=atlas.get_region(Rect2i(x,y,right-x,bottom-y))
			for cy in range(cell.get_height()):
				for cx in range(cell.get_width()):
					var pixel=cell.get_pixel(cx,cy)
					if pixel.a<0.45:cell.set_pixel(cx,cy,Color.TRANSPARENT)
			var bound=cell.get_used_rect()
			if bound.size.x==0 or bound.size.y==0:
				push_error("Empty sprite: "+key)
				quit(1)
				return
			frames.append(cell)
			bounds.append(bound)
			extent.x=maxi(extent.x,bound.size.x)
			extent.y=maxi(extent.y,bound.size.y)
		prepared.append({"entry":entry,"frames":frames,"bounds":bounds,"extent":extent})
		if entry.has("scale_group"):
			group_extents[entry.scale_group]=Vector2i(group_extents.get(entry.scale_group,Vector2i.ZERO)).max(extent)
	for data in prepared:
		var entry: Dictionary=data.entry
		var frames: Array=data.frames
		var bounds: Array=data.bounds
		var extent: Vector2i=group_extents.get(entry.get("scale_group",""),data.extent)
		var cell_size=int(entry.cell_size)
		var available=float(cell_size-12)
		var scale_factor=minf(available/extent.x,available/extent.y)
		for index in range(frames.size()):
			var image=frames[index].get_region(bounds[index])
			var new_size=Vector2i(maxi(1,roundi(image.get_width()*scale_factor)),maxi(1,roundi(image.get_height()*scale_factor)))
			image.resize(new_size.x,new_size.y,Image.INTERPOLATE_NEAREST)
			# Nearest sampling can drop the final sparse source row; re-anchor the
			# actual remaining silhouette instead of its former transparent bounds.
			image=image.get_region(image.get_used_rect())
			new_size=image.get_size()
			var output=Image.create(cell_size,cell_size,false,Image.FORMAT_RGBA8)
			output.fill(Color.TRANSPARENT)
			var pos=Vector2i((cell_size-new_size.x)/2,cell_size-6-new_size.y if entry.anchor=="feet" else (cell_size-new_size.y)/2)
			output.blit_rect(image,Rect2i(Vector2i.ZERO,new_size),pos)
			var path: String=entry.files[index]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
			var error=output.save_png(path)
			if error!=OK:
				push_error("Cannot save "+path)
				quit(1)
				return
			total+=1
	print("Imported %d reviewed raster animation frames/icons." % total)
	quit()
