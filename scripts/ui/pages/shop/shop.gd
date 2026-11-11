extends HBoxContainer
const C=preload("res://scripts/catalog.gd")
const Rules=preload("res://scripts/shop_rules.gd")
const I=preload("res://scripts/inventory.gd")
const WindowScene=preload("res://scenes/shop/customer_window.tscn")
const GridScene=preload("res://scenes/inventory/grid.tscn")
const CUSTOMER_NAMES=["维修员","医疗信使","拾荒者","种植员"]
var app: Control
var visitor: Control
var offer: Dictionary
var selection: Dictionary={}
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
	detail.custom_minimum_size.x=330
	body.add_child(detail)
	request_label=app.label("",20,Color("e4c493"))
	detail.add_child(request_label)
	budget_label=app.label("",16)
	detail.add_child(budget_label)
	cart_grid=GridScene.instantiate()
	cart_grid.cell_size=30
	cart_grid.dimensions=Vector2i(3,3)
	cart_grid.drag_source=func(_index):return {}
	cart_grid.can_place=func(data,_point,_rotation):return can_select(data)
	cart_grid.place_item=func(data,_point,_rotation):return select_item(data)
	cart_grid.allowed=func():return visitor.phase=="ready" and not is_instance_valid(app.modal)
	detail.add_child(cart_grid)
	quote_label=app.wrapped("",16)
	quote_label.custom_minimum_size.y=40
	detail.add_child(quote_label)
	var actions=HBoxContainer.new()
	detail.add_child(actions)
	accept_button=app.button("确认交易",func():resolve_customer(true),actions,true)
	app.button("清空",clear_selection,actions)
	skip_button=app.button("送客",func():resolve_customer(false),actions,true)
	var goods=VBoxContainer.new()
	goods.custom_minimum_size.x=272
	body.add_child(goods)
	stock_title=app.label("顾客货物",18)
	goods.add_child(stock_title)
	stock_hint=app.wrapped("",16)
	goods.add_child(stock_hint)
	var stock_scroll=ScrollContainer.new()
	stock_scroll.custom_minimum_size=Vector2(272,200)
	goods.add_child(stock_scroll)
	stock_grid=GridScene.instantiate()
	stock_grid.cell_size=34
	stock_grid.drag_source=func(index):return Game.customer_drag("customer",index)
	stock_grid.allowed=func():return visitor.phase=="ready" and not offer.is_empty() and not offer.buying and not is_instance_valid(app.modal)
	stock_grid.reserved=func(index):return selection.get("source","")=="customer" and selection.get("index",-1)==index
	stock_scroll.add_child(stock_grid)
	app.section(layout,"基地仓库")
	var warehouse_row=HBoxContainer.new()
	warehouse_row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	warehouse_row.add_theme_constant_override("separation",24)
	layout.add_child(warehouse_row)
	var warehouse_scroll=ScrollContainer.new()
	warehouse_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	warehouse_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	warehouse_scroll.custom_minimum_size.y=140
	warehouse_row.add_child(warehouse_scroll)
	warehouse_grid=app.create_storage_grid("stash")
	warehouse_grid.cell_size=48
	warehouse_grid.drag_source=warehouse_drag
	warehouse_grid.can_place=func(data,pos,rotation):
		return valid_warehouse_drag(data) and I.fits(warehouse_grid.items,warehouse_grid.dimensions,data.id,pos,rotation,int(data.index))
	warehouse_grid.place_item=func(data,pos,rotation):
		return valid_warehouse_drag(data) and Game.move_stash(int(data.index),pos,rotation)
	warehouse_grid.reserved=func(index):return selection.get("source","")=="stash" and selection.get("index",-1)==index
	warehouse_grid.moved.connect(func():clear_selection();refresh_storage())
	warehouse_grid.selected.connect(show_item)
	warehouse_scroll.add_child(warehouse_grid)
	item_details=VBoxContainer.new()
	item_details.custom_minimum_size.x=300
	warehouse_row.add_child(item_details)
	show_item(-1)
	next_customer()
func next_customer() -> void:
	offer=Game.customer_offer()
	selection={}
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
	stock_hint.text="从下方仓库拖入同类物品。" if offer.buying else "从顾客货物拖入交易格。"
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
	budget_label.text="顾客预算 %d 电量" % int(offer.get("budget",0)) if not offer.is_empty() else ""
	refresh_quote()
func can_select(data: Variant) -> bool:
	return visitor.phase=="ready" and not is_instance_valid(app.modal) and Game.valid_customer_selection(data)
func select_item(data: Dictionary) -> bool:
	if not can_select(data):return false
	selection=data.duplicate(true)
	refresh_quote()
	warehouse_grid.refresh_selection()
	stock_grid.refresh_selection()
	return true
func clear_selection() -> void:
	selection={}
	refresh_quote()
	warehouse_grid.refresh_selection()
	stock_grid.refresh_selection()
func refresh_quote() -> void:
	var quote=Game.customer_quote(selection)
	if not quote.valid:selection={}
	cart_grid.items=[]
	if not selection.is_empty():
		var entry=I.first_fit([],Vector2i(3,3),selection.id)
		entry.id=selection.id
		cart_grid.items=[entry]
	cart_grid.refresh()
	quote_label.text=quote.message if not offer.is_empty() else "本日客流已结束。"
	quote_label.modulate=Color("f3a58a") if quote.valid and not quote.affordable else Color.WHITE
	accept_button.disabled=visitor.phase!="ready" or not quote.valid or not quote.affordable
func set_actions(enabled: bool) -> void:
	skip_button.disabled=not enabled
	refresh_quote()
func resolve_customer(accept: bool) -> void:
	if visitor.phase!="ready" or is_instance_valid(app.modal) or offer.is_empty():return
	if accept:
		var message=Game.accept_customer(offer.key,selection)
		app.say(message)
		var current=Game.customer_offer()
		if not current.is_empty() and current.revision!=offer.revision:
			offer=current
			selection={}
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
		item_details.add_child(app.wrapped("拖拽整理仓库；将同类商品拖入交易格后确认交易。",16))
		return
	var id: String=Game.state.stash[index]
	app.section(item_details,C.item(id).name,C.item(id).desc)
	if int(C.item(id).category)<3:
		app.button("入库使用",func():app.consume_stash(id);clear_selection();refresh_storage();show_item(-1),item_details)

func warehouse_drag(index: int) -> Dictionary:
	var data=Game.customer_drag("stash",index)
	if not data.is_empty():return data
	if index<0 or index>=Game.state.stash.size():return {}
	return {"key":"","revision":-1,"source":"stash","index":index,"id":Game.state.stash[index],"signature":Game.stash_signature()}
func valid_warehouse_drag(data: Variant) -> bool:
	return data is Dictionary and data.has_all(["source","index","id","signature"]) and data.source=="stash" and data.index is int and data.index>=0 and data.index<Game.state.stash.size() and data.id==Game.state.stash[data.index] and data.signature==Game.stash_signature()
