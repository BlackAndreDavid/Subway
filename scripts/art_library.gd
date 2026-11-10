extends RefCounted
# Stable asset identifiers separate gameplay from filenames, atlas layout and format.
const Manifest=preload("res://scripts/art_manifest.gd")
static var cache: Dictionary={}
static var bounds_cache: Dictionary={}
static func bounds(id: String,frame: int=0) -> Rect2i:
	var key=id+":"+str(posmod(frame,frame_count(id)))
	if not bounds_cache.has(key):bounds_cache[key]=texture(id,frame).get_image().get_used_rect()
	return bounds_cache[key]
static func texture(id: String,frame: int=0) -> Texture2D:
	if not Manifest.ENTRIES.has(id):
		push_error("Unknown art ID: "+id)
		return null
	var entry: Dictionary=Manifest.ENTRIES[id]
	var file: String=entry.files[posmod(frame,int(entry.frames))]
	if not cache.has(file):cache[file]=load(file)
	return cache[file]
static func path(id: String,frame: int=0) -> String:
	var entry: Dictionary=Manifest.ENTRIES[id]
	return entry.files[posmod(frame,int(entry.frames))]
static func frame_count(id: String) -> int:
	return int(Manifest.ENTRIES[id].frames)
static func frames_at_time(id: String,seconds: float) -> int:
	return int(seconds*float(Manifest.ENTRIES[id].fps))%frame_count(id)
