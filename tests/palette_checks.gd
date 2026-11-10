extends RefCounted
const Manifest=preload("res://scripts/art_manifest.gd")
const Art=preload("res://scripts/art_library.gd")
static func run(check: Callable) -> void:
	var palette=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/palette.json"))
	var report=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/simplification_report.json"))
	var allowed={}
	for color in palette:
		check.call(not allowed.has(color.hex),"unique palette swatch")
		allowed[color.hex]=true
	check.call(allowed.size()<=32,"shared palette color limit")
	for id in Manifest.ENTRIES:
		var entry: Dictionary=Manifest.ENTRIES[id]
		for frame in range(int(entry.frames)):
			var image=Art.texture(id,frame).get_image()
			var colors={}
			var mask_equal=true
			var raw_path="res://work/art-before-simplification/"+Art.path(id,frame).trim_prefix("res://assets/art/runtime/")
			var raw=Image.new()
			var loaded=raw.load_png_from_buffer(FileAccess.get_file_as_bytes(raw_path))==OK
			check.call(loaded,"raw technical import retained for mask comparison")
			var alpha_ok=true
			var colors_ok=true
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var pixel=image.get_pixel(x,y)
					if pixel.a!=0 and pixel.a!=1:alpha_ok=false
					if loaded and (pixel.a>0)!=(raw.get_pixel(x,y).a>0):mask_equal=false
					if pixel.a>0:
						var hex="#"+pixel.to_html(false)
						if not allowed.has(hex):colors_ok=false
						colors[hex]=true
			check.call(alpha_ok,"crisp binary-alpha raster")
			check.call(colors_ok and colors.size()<=32,"all colors use named shared palette")
			check.call(mask_equal,"silhouette preserved after region flattening")
	for asset in report.assets:
		check.call(asset.after_colors<asset.before_colors,"color simplification reduces local noise")
		check.call(asset.regions_flat and asset.mask_preserved,"flat-region processing assertions")
	var review=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/review.json"))
	var sources: Array=review.sources.duplicate()
	sources.append_array(review.regional_materials.sources)
	for source in sources:
		var bytes=FileAccess.get_file_as_bytes("res://assets/art/"+source.path)
		var context=HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(bytes)
		check.call(context.finish().hex_encode()==source.sha256,"generation source preserved: "+source.path)
