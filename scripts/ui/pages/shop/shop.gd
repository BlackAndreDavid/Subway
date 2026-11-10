extends HBoxContainer
const C=preload("res://scripts/catalog.gd")
var app: Control
func build(context: Control) -> void:
	app=context
	app.stage=$Stage
	app.stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	app.stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var catalog_host=$Stage/Catalog
	catalog_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var catalog=app.panel(catalog_host,890)
	app.section(catalog,"地下市场 / 以电易物","价格受站点与日报影响 · 当日每种商品限购 4 件")
	var cats=HBoxContainer.new()
	catalog.add_child(cats)
	for i in range(6):
		var cat=i
		app.button(C.CATEGORY_NAMES[i],func():app.shop_category=cat;app.show_shop(),cats)
	for j in range(4):
		var id="%d_%d" % [app.shop_category,j]
		app.item_card(catalog,id)
	app.side=app.panel(app.make_drawer(),340)
	app.section(app.side,"开店接客","到站客流：%d 人 / 日" % C.STATIONS[int(Game.state.station)].traffic)
	var offer=Game.customer_offer()
	app.side.add_child(app.wrapped("第 %d 位顾客\n%s %s\n出价 %d 电量" % [int(Game.state.customer)+1,"想买入" if offer.buying else "想出售",C.item(offer.id).name,offer.price],20))
	app.button("成交",func():app.say(Game.accept_customer());app.show_shop(),app.side)
	app.button("下一位",func():Game.state.customer+=1;Game.save_game();app.show_shop(),app.side)
	app.side.add_child(HSeparator.new())
	app.section(app.side,"柜台库存","点击售出一件，按当前站点收购价结算。")
	app.button("仓库",app.show_stash,app.side)
	var stock_grid=app.create_storage_grid("stash")
	stock_grid.cell_size=26
	var stock_scroll=ScrollContainer.new()
	stock_scroll.custom_minimum_size.y=230
	app.side.add_child(stock_scroll)
	stock_scroll.add_child(stock_grid)
	stock_grid.selected.connect(func(index):app.stash_selected=index;app.show_stash())
	app.back_button(app.show_base,app.side)
func item_card(parent: Node,id: String) -> void:
	var item=C.item(id)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	parent.add_child(row)
	var icon=TextureRect.new()
	icon.texture=load(item.icon)
	icon.custom_minimum_size=Vector2(72,72)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var detail=VBoxContainer.new()
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	detail.add_child(app.label(item.name,22,Color("dfd9bf")))
	detail.add_child(app.wrapped(item.desc,15))
	detail.add_child(app.label("售价 %d 电量 · 库存 %d" % [Game.price(id,true),Game.state.market_stock.get(id,4)],15))
	app.button("购入",func():app.say(Game.trade(id,true));app.show_shop(),row,int(Game.state.market_stock.get(id,4))<=0)
	parent.add_child(HSeparator.new())
