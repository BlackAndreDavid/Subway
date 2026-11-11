extends RefCounted
const C=preload("res://scripts/catalog.gd")
const Rules=preload("res://scripts/shop_rules.gd")
func fixture(game: Node,buying: bool,category: int=-1,appearance: int=-1) -> Dictionary:
	for day in range(2,200):
		for index in range(game.customer_limit()):
			var offer=Rules.generate(day,int(game.state.station),index)
			if offer.buying==buying and (category<0 or int(offer.category)==category) and (appearance<0 or int(offer.appearance)==appearance):
				game.state.day=day
				game.state.customer=index
				game.state.shop_customer=offer
				return offer
	return {}
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	var gestures=preload("res://tests/interaction_checks.gd").new()
	gestures.tree=tree
	game.new_game(0,"分类经营测试")
	var legacy=game.state.duplicate(true)
	legacy.market_stock={"4_0":0}
	game.write_json("user://slot_0.json",legacy)
	check.call(game.load_game(0) and not game.state.has("market_stock"),"legacy save removes system restock")
	check.call(game.customer_limit(0)<game.customer_limit(1),"station traffic changes daily customer cap")
	for station in range(C.STATIONS.size()):
		check.call(game.customer_limit(station)==clampi(ceili(float(C.STATIONS[station].traffic)/20),2,10),"all station customer limits use traffic")
	ui.show_shop()
	var page=ui.current_screen
	var window=page.visitor
	window.set_process(false)
	await tree.process_frame
	await tree.process_frame
	check.call(page.warehouse_grid.visible and not is_instance_valid(ui.modal),"warehouse is embedded without opening a dialog")
	check.call(page.warehouse_grid.global_position.y>=window.get_global_rect().end.y and window.size.y<=300,"warehouse is below a reduced-height customer opening")
	check.call(page.accept_button.disabled and page.skip_button.disabled,"arrival locks transaction and departure")
	var count=game.state.customer
	page.resolve_customer(false)
	check.call(game.state.customer==count,"arrival cannot skip a visitor")
	var far=window.presentation()
	window.advance(0.4)
	var middle=window.presentation()
	check.call(middle.scale>far.scale and middle.alpha>far.alpha and middle.brightness>far.brightness,"approach retains size opacity and brightness transitions")
	window.advance(0.4)
	check.call(window.phase=="ready" and page.accept_button.disabled and not page.skip_button.disabled,"arrival permits selection but not an unselected transaction")
	var original_size=window.size
	var portrait_size=window.portrait_destination().size
	window.size.y=610
	check.call(window.portrait_destination().size==portrait_size and is_equal_approx(portrait_size.y,500.0),"smaller window crops the unchanged 500px portrait instead of rescaling it")
	window.size=original_size
	var before=game.state.duplicate(true)
	page.resolve_customer(true)
	check.call(game.state==before,"confirmation without a dragged item changes nothing")
	var old_appearance=window.appearance
	page.resolve_customer(false)
	check.call(game.state.customer==count+1 and window.phase=="departing","only sending a visitor away consumes a daily customer")
	page.resolve_customer(false)
	check.call(game.state.customer==count+1,"rapid departure clicks cannot consume more customers")
	window.advance(0.3)
	check.call(window.appearance==old_appearance and window.depth<1,"departing portrait remains until the end")
	window.advance(1)
	check.call(window.phase=="arriving","next visitor arrives after previous disappearance")
	window.advance(1)
	var day=game.state.day
	ui.show_shop()
	check.call(game.state.day==day and game.state.customer==count+1,"rerender keeps daily queue and day cost")
	page=ui.current_screen
	window=page.visitor
	window.set_process(false)
	# Real warehouse -> trade grid drag, including rejecting another category.
	fixture(game,true,5)
	game.add_stash("5_0")
	game.add_stash("5_1")
	page.next_customer()
	window.advance(1)
	await tree.process_frame
	await tree.process_frame
	await gestures.drag(page.warehouse_grid.tiles[0],page.cart_grid)
	check.call(page.selection.is_empty(),"real drag rejects medicine for a module customer")
	var module_index=game.state.stash.find("5_0")
	await gestures.drag(page.warehouse_grid.tiles[module_index],page.cart_grid)
	check.call(page.selection.get("id","")=="5_0" and game.state.stash.has("5_0"),"real module drag reserves an owned copy without transferring it")
	page.clear_selection()
	check.call(page.select_item(game.customer_drag("stash",game.state.stash.find("5_1"))),"customer accepts another item in the same category")
	game.state.shop_customer.budget=0
	page.offer=game.customer_offer()
	page.refresh_quote()
	check.call(page.quote_label.text.contains("买不起") and page.accept_button.disabled,"over-budget sale displays cannot afford")
	before=game.state.duplicate(true)
	page.resolve_customer(true)
	check.call(game.state==before,"over-budget transaction cannot transfer goods or electricity")
	game.state.shop_customer.budget=500
	page.offer=game.customer_offer()
	page.clear_selection()
	page.select_item(game.customer_drag("stash",game.state.stash.find("5_0")))
	var selection=page.selection.duplicate(true)
	var value=game.customer_quote(selection).price
	before=game.state.duplicate(true)
	var slot=game.slot
	game.slot=-1
	page.resolve_customer(true)
	check.call(game.state==before and window.phase=="ready","failed save rolls back goods, budget and revision")
	game.slot=slot
	page.resolve_customer(true)
	check.call(game.state.power==before.power+value and game.state.shop_customer.budget==before.shop_customer.budget-value,"customer purchase decreases their budget and pays the player")
	check.call(ui.hud.text.contains("电 %d" % game.state.power),"trade refreshes account electricity in the header")
	check.call(game.state.customer==before.customer and window.phase=="ready" and page.selection.is_empty(),"successful trade keeps the same visitor available for more category purchases")
	check.call(game.state.stash.count("5_0")==before.stash.count("5_0")-1,"one selected physical copy is sold")
	var settled=game.state.duplicate(true)
	game.accept_customer(selection.key,selection)
	check.call(game.state==settled,"stale revision cannot settle the same selection twice")
	var persisted=game.state.shop_customer.duplicate(true)
	check.call(game.load_game(0) and game.state.shop_customer.key==persisted.key and game.state.shop_customer.budget==persisted.budget and game.state.shop_customer.revision==persisted.revision and game.state.shop_customer.stock.size()==persisted.stock.size(),"budget, remaining stock and revision survive save/load")
	game.shop_open=true
	# NPC stock is finite, physical, category-limited and selected via real drag.
	fixture(game,false,4)
	page.next_customer()
	window.advance(1)
	await tree.process_frame
	await tree.process_frame
	await gestures.drag(page.stock_grid.tiles[0],page.cart_grid)
	check.call(not page.selection.is_empty() and page.selection.source=="customer","real merchant stock drag selects a concrete active item")
	selection=page.selection.duplicate(true)
	value=game.customer_quote(selection).price
	game.state.power=0
	page.refresh_quote()
	check.call(page.quote_label.text.contains("买不起") and page.accept_button.disabled,"player affordability is visible before purchase")
	before=game.state.duplicate(true)
	page.resolve_customer(true)
	check.call(game.state==before,"player cannot buy goods without sufficient electricity")
	game.state.power=1000
	before=game.state.duplicate(true)
	page.resolve_customer(true)
	check.call(game.state.power==before.power-value and game.state.shop_customer.budget==before.shop_customer.budget+value,"customer sale increases their budget and debits the player")
	check.call(game.state.shop_customer.stock.size()==before.shop_customer.stock.size()-1 and game.state.stash.count(selection.id)==before.stash.count(selection.id)+1,"one exact merchant copy moves into the shaped warehouse")
	var remaining=game.state.shop_customer.duplicate(true)
	check.call(game.load_game(0) and game.state.shop_customer.stock.size()==remaining.stock.size() and game.state.shop_customer.budget==remaining.budget,"merchant remaining physical stock and earned budget survive loading")
	game.shop_open=true
	while not game.customer_offer().stock.is_empty():
		var current=game.customer_offer()
		game.accept_customer(current.key,game.customer_drag("customer",0))
	check.call(game.customer_offer().stock.is_empty() and game.customer_drag("customer",0).is_empty(),"exhausted customer stock cannot generate infinite supplies")
	# Customer selection cannot survive a source rearrangement or wrong provenance.
	fixture(game,true,5)
	var payload=game.customer_drag("stash",game.state.stash.find("5_1"))
	game.add_stash("scrap")
	check.call(not game.valid_customer_selection(payload),"warehouse mutation invalidates a pending source fingerprint")
	payload=game.customer_drag("stash",game.state.stash.find("5_1"))
	payload.source="customer"
	check.call(not game.valid_customer_selection(payload),"foreign source payload is rejected")
	game.state.customer=game.customer_limit()-1
	game.state.erase("shop_customer")
	page.next_customer()
	window.advance(1)
	page.resolve_customer(false)
	window.advance(1)
	check.call(game.customer_offer().is_empty() and page.offer.is_empty() and window.phase=="hidden" and page.skip_button.disabled,"daily limit closes the counter after the final visitor leaves")
	before=game.state.duplicate(true)
	game.skip_customer("invalid")
	game.accept_customer()
	check.call(game.state==before,"exhausted daily queue cannot advance or trade")
	day=game.state.day
	ui.show_shop()
	check.call(game.state.day==day and game.customer_offer().is_empty(),"rerender cannot refresh the daily quota")
	ui.show_base()
	before=game.state.duplicate(true)
	game.accept_customer()
	check.call(game.state==before,"no trades outside an operating shop")
	await tree.process_frame
