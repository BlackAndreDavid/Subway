extends Control
signal arrived
signal departed
const Art=preload("res://scripts/art_library.gd")
const ARRIVAL_SECONDS=0.8
const DEPARTURE_SECONDS=0.65
var phase="hidden"
var elapsed=0.0
var depth=0.0
var appearance=0
var paused: Callable
func present(index: int) -> void:
	appearance=clampi(index,0,3)
	phase="arriving"
	elapsed=0.0
	depth=0.0
	queue_redraw()
func dismiss() -> bool:
	if phase!="ready":return false
	phase="departing"
	elapsed=0.0
	return true
func _process(delta: float) -> void:
	if paused.is_valid() and paused.call():return
	advance(delta)
func advance(delta: float) -> void:
	if phase not in ["arriving","departing"]:return
	elapsed+=maxf(0,delta)
	var t=clampf(elapsed/(ARRIVAL_SECONDS if phase=="arriving" else DEPARTURE_SECONDS),0,1)
	var eased=t*t*(3-2*t)
	depth=eased if phase=="arriving" else 1-eased
	queue_redraw()
	if t>=1:
		if phase=="arriving":
			phase="ready"
			arrived.emit()
		else:
			phase="hidden"
			departed.emit()
func presentation() -> Dictionary:
	return {"scale":lerpf(0.38,1.0,depth),"alpha":lerpf(0.12,1.0,depth),"brightness":lerpf(0.3,1.0,depth)}
func portrait_destination() -> Rect2:
	var bounds=Art.bounds("shop/customers/%d" % appearance)
	var height=500.0*float(presentation().scale)
	var sprite_size=Vector2(bounds.size)*height/float(bounds.size.y)
	var feet=Vector2(size.x*0.5,lerpf(size.y*0.66,536.0,depth))
	return Rect2(feet-Vector2(sprite_size.x/2,sprite_size.y),sprite_size)
func _draw() -> void:
	var w=size.x
	var h=size.y
	draw_rect(Rect2(Vector2.ZERO,size),Color("111d2b"))
	draw_rect(Rect2(14,14,w-28,h-28),Color("263c48"))
	draw_rect(Rect2(28,28,w-56,h-56),Color("152733"))
	for i in range(5):
		var y=h*0.45+i*i*h*0.024
		draw_line(Vector2(28,y),Vector2(w-28,y),Color("2a424b"),2)
	for i in range(7):
		draw_line(Vector2(w/2,h*0.4),Vector2(w*i/6.0,h),Color("2a424b"),2)
	draw_rect(Rect2(w*0.32,28,w*0.36,8),Color("94c6ae"))
	if phase!="hidden":
		var look=presentation()
		var bounds=Art.bounds("shop/customers/%d" % appearance)
		var shade=float(look.brightness)
		# Crop the unchanged 500px portrait into the smaller opening; never shrink it.
		var destination=portrait_destination()
		var sprite_size=destination.size
		var visible=destination.intersection(Rect2(28,28,w-56,h-62))
		if visible.has_area():
			var source=Rect2(Vector2(bounds.position)+(visible.position-destination.position)/sprite_size*Vector2(bounds.size),visible.size/sprite_size*Vector2(bounds.size))
			draw_texture_rect_region(Art.texture("shop/customers/%d" % appearance),visible,source,Color(shade,shade,shade,float(look.alpha)))
	draw_rect(Rect2(14,h-34,w-28,20),Color("8d7255"))
	draw_rect(Rect2(14,h-14,w-28,14),Color("182637"))
