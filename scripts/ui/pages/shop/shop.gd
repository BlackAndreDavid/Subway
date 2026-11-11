extends HBoxContainer
const C=preload("res://scripts/catalog.gd")
const WindowScene=preload("res://scenes/shop/customer_window.tscn")
const CUSTOMER_NAMES=["维修员","医疗信使","拾荒者","种植员"]
var app: Control
var visitor: Control
var offer: Dictionary
var detail: VBoxContainer
var accept_button: Button
var skip_button: Button
func build(context: Control) -> void:
	app=context
	app.stage=$Stage
	var layout=VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation",16)
	app.stage.add_child(layout)
	app.section(layout,"地下商铺")
	var body=HBoxContainer.new()
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",24)
	layout.add_child(body)
	visitor=WindowScene.instantiate()
	body.add_child(visitor)
	visitor.paused=func():return is_instance_valid(app.modal)
	visitor.arrived.connect(func():set_actions(true))
	visitor.departed.connect(next_customer)
	detail=app.panel(body,330)
	var footer=HBoxContainer.new()
	footer.add_theme_constant_override("separation",20)
	layout.add_child(footer)
	app.button("仓库",app.show_stash,footer)
	app.button("结束营业",app.show_base,footer)
	next_customer()
func next_customer() -> void:
	offer=Game.customer_offer().duplicate(true)
	app.empty(detail)
	app.section(detail,CUSTOMER_NAMES[int(offer.appearance)])
	detail.add_child(app.label("想购买" if offer.buying else "想出售",20))
	var icon=TextureRect.new()
	icon.texture=load(C.item(offer.id).icon)
	icon.custom_minimum_size=Vector2(112,112)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_back=ColorRect.new()
	icon_back.color=C.inventory_color(offer.id)
	icon_back.custom_minimum_size=Vector2(112,112)
	detail.add_child(icon_back)
	icon_back.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.section(detail,C.item(offer.id).name,C.item(offer.id).desc)
	detail.add_child(app.label("数量 1 · %d 电量" % offer.price,22))
	detail.add_child(app.label("仓库持有 %d" % Game.state.stash.count(offer.id),17))
	accept_button=app.button("成交",func():resolve_customer(true),detail,true)
	skip_button=app.button("婉拒",func():resolve_customer(false),detail,true)
	visitor.present(int(offer.appearance))
func set_actions(enabled: bool) -> void:
	accept_button.disabled=not enabled
	skip_button.disabled=not enabled
func resolve_customer(accept: bool) -> void:
	if visitor.phase!="ready" or is_instance_valid(app.modal):return
	var old_key: String=offer.key
	var message=Game.accept_customer(old_key) if accept else Game.skip_customer(old_key)
	app.say(message)
	if Game.customer_offer().key==old_key:return
	set_actions(false)
	visitor.dismiss()
