extends RefCounted
const Art=preload("res://scripts/art_library.gd")
const Manifest=preload("res://scripts/art_manifest.gd")
const Metro=preload("res://scripts/metro.gd")
const Data=preload("res://scripts/metro_data.gd")
static func run(check: Callable) -> void:
	var files: Dictionary={}
	for id in Manifest.ENTRIES:
		var entry: Dictionary=Manifest.ENTRIES[id]
		var hashes: Dictionary={}
		for candidate in entry.candidate_sources:check.call(FileAccess.file_exists("res://assets/art/candidates/"+candidate),"two candidate originals retained")
		for frame in range(int(entry.frames)):
			var path=Art.path(id,frame)
			check.call(path.ends_with(".png"),"raster art format")
			check.call(ResourceLoader.exists(path),"PNG imported: "+id)
			check.call(not files.has(path),"unique runtime frame")
			files[path]=true
			var texture=Art.texture(id,frame)
			check.call(texture is Texture2D,"Texture2D contract: "+id)
			var image=texture.get_image()
			var bound=image.get_used_rect()
			check.call(image.get_width()==int(entry.cell_size) and image.get_height()==int(entry.cell_size),"normalized cell size")
			check.call(image.get_format()==Image.FORMAT_RGBA8 and image.get_pixel(0,0).a==0,"transparent background")
			check.call(bound.has_area() and bound.size.x>3 and bound.size.y>3,"nonempty silhouette")
			check.call(bound.position.x>=4 and bound.end.x<=int(entry.cell_size)-4,"horizontal safe margin")
			if entry.anchor=="feet":check.call(absi(bound.end.y-(int(entry.cell_size)-6))<=1,"stable feet anchor")
			hashes[image.get_data().hex_encode().sha256_text()]=true
		if int(entry.frames)>1:
			check.call(hashes.size()==int(entry.frames),"distinct animation poses: "+id)
			check.call(Art.frames_at_time(id,1.1/float(entry.fps))!=Art.frames_at_time(id,0.0),"animation advances at configured fps: "+id)
	check.call(files.size()==105,"all 105 sprites wired")
	check.call(Data.STATIONS.size()==110,"110 real major stations")
	var line_ids={}
	for line in Data.LINES:
		line_ids[line.id]=true
		check.call(line.stations.size()>=2,"major points on each line")
		for index in line.stations:
			check.call(index>=0 and index<Data.STATIONS.size(),"valid station reference")
			check.call(Data.STATIONS[index].lines.has(line.id),"station line membership")
	check.call(line_ids.size()==21,"all 21 operating metro/linked lines")
	var positions={}
	for index in range(Data.STATIONS.size()):
		var station=Data.STATIONS[index]
		for line_id in station.lines:
			var found=false
			for line in Data.LINES:
				if line.id==line_id and line.stations.has(index):found=true
			check.call(found,"station membership matches actual ordered line path")
		check.call(not positions.has(station.pos),"non-overlapping station centers")
		positions[station.pos]=true
		check.call(station.pos.x>=0 and station.pos.x<Data.CANVAS.x and station.pos.y<Data.CANVAS.y,"station inside map")
		var route=Metro.route(0,index)
		check.call(not route.is_empty() and route.front()==0 and route.back()==index,"main-map connectivity")
		for i in range(route.size()-1):check.call(Metro.neighbors(route[i]).has(route[i+1]),"route follows real selected-stop edges")
	check.call(Data.STATIONS[0].name=="邮电新村" and Data.STATIONS[4].name=="虹桥火车站" and Data.STATIONS[5].name=="滴水湖","legacy save station indices preserved")
