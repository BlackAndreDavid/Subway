extends HBoxContainer
const C=preload("res://scripts/catalog.gd")
const Rules=preload("res://scripts/shop_rules.gd")
const I=preload("res://scripts/inventory.gd")
const Cart=preload("res://scripts/shop_cart.gd")
const WindowScene=preload("res://scenes/shop/customer_window.tscn")
const GridScene=preload("res://scenes/inventory/grid.tscn")
const CUSTOMER_NAMES=["维修员","医疗信使","拾荒者","种植员"]
var app: Control
var visitor: Control
var offer: Dictionary
var cart=Cart.new()
var selection: Dictionary:
	get:return {} if cart.entries.is_empty() else cart.entries[0].payload
var detail: VBoxContainer
var accept_button: Button
var skip_button: Button
var warehouse_grid: Control
var stock_grid: Control
var cart_grid: Control
var traffic_label: Label
var budget_label: Label
var quote_label: Label
var request_label: Label
var stock_title: Label
var stock_hint: Label
var item_details: VBoxContainer
func build(context: Control) -> void:
	app=context
	app.stage=$Stage
	var layout=VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation",10)
	app.stage.add_child(layout)
	var header=HBoxContainer.new()
	layout.add_child(header)
	app.section(header,"地下商铺")
	traffic_label=app.label("",17)
	traffic_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(traffic_label)
	app.button("结束营业",app.show_base,header)
	var body=HBoxContainer.new()
	body.custom_minimum_size.y=285
	body.add_theme_constant_override("separation",20)
	layout.add_child(body)
	visitor=WindowScene.instantiate()
	visitor.custom_minimum_size=Vector2(340,285)
	body.add_child(visitor)
	visitor.paused=func():return is_instance_valid(app.modal)
	visitor.arrived.connect(func():set_actions(true))
	visitor.departed.connect(next_customer)
	detail=VBoxContainer.new()
	detail.custom_minimum_size.x=450
	body.add_child(detail)
	request_label=app.label("",20,Color("e4c493"))
	detail.add_child(request_label)
	budget_label=app.label("",16)
	detail.add_child(budget_label)
	quote_label=app.wrapped("",18)
	quote_label.custom_minimum_size.y=52
	detail.add_child(quote_label)
	var actions=HBoxContainer.new()
	detail.add_child(actions)
	accept_button=app.button("确认交易",func():resolve_customer(true),actions,true)
	app.button("清空",clear_selection,actions)
	skip_button=app.button("送客",func():resolve_customer(false),actions,true)
	item_details=VBoxContainer.new()
	detail.add_child(item_details)
	var storage_row=HBoxContainer.new()
	storage_row.add_theme_constant_override("separation",8)
	storage_row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	layout.add_child(storage_row)
	var warehouse_column=VBoxContainer.new()
	warehouse_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	storage_row.add_child(warehouse_column)
	app.section(warehouse_column,"基地仓库")
	var warehouse_scroll=ScrollContainer.new()
	warehouse_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	warehouse_scroll.custom_minimum_size=Vector2(Game.STASH_COLUMNS*Cart.CELL_SIZE,140)
	warehouse_column.add_child(warehouse_scroll)
	warehouse_grid=app.create_storage_grid("stash")
	warehouse_grid.cell_size=Cart.CELL_SIZE
	warehouse_grid.drag_source=warehouse_drag
	warehouse_grid.can_place=func(data,pos,rotation):
		if cart.valid_drag(data):return true
		return valid_warehouse_drag(data) and I.fits(warehouse_grid.items,warehouse_grid.dimensions,data.id,pos,rotation,int(data.index))
	warehouse_grid.place_item=func(data,pos,rotation):
		if cart.valid_drag(data):return remove_from_cart(data)
		return valid_warehouse_drag(data) and Game.move_stash(int(data.index),pos,rotation)
	warehouse_grid.reserved=func(index):return cart.contains("stash",index)
	warehouse_grid.moved.connect(refresh_storage)
	warehouse_grid.selected.connect(show_item)
	warehouse_scroll.add_child(warehouse_grid)
	var trade_column=VBoxContainer.new()
	storage_row.add_child(trade_column)
	app.section(trade_column,"交易区 · 8×4")
	cart_grid=GridScene.instantiate()
	cart_grid.cell_size=Cart.CELL_SIZE
	cart_grid.dimensions=Cart.DIMENSIONS
	cart_grid.drag_source=cart.drag
	cart_grid.can_place=can_place_cart
	cart_grid.place_item=place_cart
	cart_grid.allowed=can_interact
	trade_column.add_child(cart_grid)
	trade_column.add_child(app.wrapped("拖拽摆放 · R 旋转 · 拖回库存取消",14))
	var goods=VBoxContainer.new()
	storage_row.add_child(goods)
	stock_title=app.label("顾客货物",23,Color("e4c493"))
	goods.add_child(stock_title)
	stock_hint=app.wrapped("",14)
	goods.add_child(stock_hint)
	var stock_scroll=ScrollContainer.new()
	stock_scroll.custom_minimum_size=Vector2(Rules.STOCK_COLUMNS*Cart.CELL_SIZE,192)
	stock_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	goods.add_child(stock_scroll)
	stock_grid=GridScene.instantiate()
	stock_grid.cell_size=Cart.CELL_SIZE
	stock_grid.drag_source=func(index):return {} if cart.contains("customer",index) else Game.customer_drag("customer",index)
	stock_grid.allowed=func():return can_interact() and not offer.is_empty() and not offer.buying
	stock_grid.reserved=func(index):return cart.contains("customer",index)
	stock_grid.can_place=func(data,_pos,_rot):return cart.valid_drag(data)
	stock_grid.place_item=func(data,_pos,_rot):return remove_from_cart(data)
	stock_scroll.add_child(stock_grid)
	show_item(-1)
	next_customer()
func can_interact() -> bool:
	return visitor.phase=="ready" and not is_instance_valid(app.modal)
func next_customer() -> void:
	offer=Game.customer_offer()
	cart.clear()
	refresh_storage()
	if offer.is_empty():
		visitor.phase="hidden"
		visitor.queue_redraw()
		request_label.text="今日顾客已全部接待"
		budget_label.text=""
		stock_title.text="营业结束"
		stock_hint.text="可以结束营业返回基地。"
		set_actions(false)
		return
	request_label.text="%s · %s%s" % [CUSTOMER_NAMES[int(offer.appearance)],"收购" if offer.buying else "出售",Rules.CATEGORY_NAMES[int(offer.category)]]
	stock_title.text="顾客需求" if offer.buying else "顾客货物"
	stock_hint.text="从仓库拖入同类物品。" if offer.buying else "拖入中间交易区后确认购买。"
	visitor.present(int(offer.appearance))
	set_actions(false)
func refresh_storage() -> void:
	app.refresh_resource_hud()
	warehouse_grid.items=Game.stash_entries()
	warehouse_grid.dimensions=Vector2i(Game.STASH_COLUMNS,int(Game.state.stash_rows))
	warehouse_grid.refresh()
	stock_grid.items=offer.get("stock",[])
	stock_grid.dimensions=Vector2i(Rules.STOCK_COLUMNS,int(offer.get("rows",4)))
	stock_grid.visible=not offer.is_empty() and not offer.buying
	stock_grid.refresh()
	if not offer.is_empty() and not offer.buying and offer.stock.is_empty():stock_hint.text="货物已售完。"
	traffic_label.text="  今日已接待 %d / %d 人" % [Game.state.customer,Game.customer_limit()]
	budget_label.text="顾客预算 %d 水晶" % int(offer.get("budget",0)) if not offer.is_empty() else ""
	refresh_quote()
func can_select(data: Variant) -> bool:
	return can_interact() and Game.valid_customer_selection(data)
func can_place_cart(data: Variant,position: Vector2i,rotation: int) -> bool:
	return can_interact() and data is Dictionary and (cart.valid_drag(data) or Game.valid_customer_selection(data)) and cart.can_place(data,position,rotation)
func place_cart(data: Dictionary,position: Vector2i,rotation: int) -> bool:
	if not can_place_cart(data,position,rotation) or not cart.place(data,position,rotation):return false
	refresh_quote()
	refresh_reservations()
	return true
func select_item(data: Dictionary) -> bool:
	if not can_select(data):return false
	var placement=I.first_fit(cart.entries,Cart.DIMENSIONS,data.id)
	return not placement.is_empty() and place_cart(data,Vector2i(placement.x,placement.y),int(placement.rot))
func remove_from_cart(data: Dictionary) -> bool:
	if not can_interact() or not cart.remove(data):return false
	refresh_quote()
	refresh_reservations()
	return true
func clear_selection() -> void:
	cart.clear()
	refresh_quote()
	refresh_reservations()
func refresh_reservations() -> void:
	warehouse_grid.refresh_selection()
	stock_grid.refresh_selection()
func refresh_quote() -> void:
	var quote=Game.customer_quote(cart.selections())
	if not quote.valid and not cart.entries.is_empty():cart.clear()
	cart_grid.items=cart.entries
	cart_grid.refresh()
	quote_label.text=quote.message if not offer.is_empty() else "本日客流已结束。"
	quote_label.modulate=Color("f3a58a") if quote.valid and not quote.affordable else Color.WHITE
	accept_button.disabled=visitor.phase!="ready" or not quote.valid or not quote.affordable
func set_actions(enabled: bool) -> void:
	skip_button.disabled=not enabled
	refresh_quote()
func resolve_customer(accept: bool) -> void:
	if not can_interact() or offer.is_empty():return
	if accept:
		app.say(Game.accept_customer(offer.key,cart.selections()))
		var current=Game.customer_offer()
		if not current.is_empty() and current.revision!=offer.revision:
			offer=current
			cart.clear()
			refresh_storage()
			show_item(-1)
		return
	var old_key: String=offer.key
	app.say(Game.skip_customer(old_key))
	var next=Game.customer_offer()
	if not next.is_empty() and next.key==old_key:return
	set_actions(false)
	visitor.dismiss()
func show_item(index: int) -> void:
	app.empty(item_details)
	if index<0 or index>=Game.state.stash.size():
		item_details.add_child(app.wrapped("同类物品拖入交易区，自动合计金额后确认。",16))
		return
	var id: String=Game.state.stash[index]
	app.section(item_details,C.item(id).name,C.item(id).desc)
	if int(C.item(id).category)<3:
		app.button("入库使用",func():app.consume_stash(id);clear_selection();refresh_storage();show_item(-1),item_details)
func warehouse_drag(index: int) -> Dictionary:
	if cart.contains("stash",index):return {}
	var data=Game.customer_drag("stash",index)
	if not data.is_empty():return data
	if index<0 or index>=Game.state.stash.size():return {}
	return {"key":"","revision":-1,"source":"stash","index":index,"id":Game.state.stash[index],"signature":Game.stash_signature()}
func valid_warehouse_drag(data: Variant) -> bool:
	return data is Dictionary and data.has_all(["source","index","id","signature"]) and data.source=="stash" and data.index is int and data.index>=0 and data.index<Game.state.stash.size() and data.id==Game.state.stash[data.index] and data.signature==Game.stash_signature()
