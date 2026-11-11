extends RefCounted
const C=preload("res://scripts/catalog.gd")
const I=preload("res://scripts/inventory.gd")
const Cart=preload("res://scripts/shop_cart.gd")
func drag_to_cell(gestures: RefCounted,source: Control,grid: Control,position: Vector2i) -> void:
	var anchor=Vector2i(source.size/(2*grid.cell_size))
	await gestures.drag_to(source,grid.global_position+Vector2(position+anchor)*grid.cell_size+Vector2(8,8))
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	var gestures=preload("res://tests/interaction_checks.gd").new()
	gestures.tree=tree
	game.new_game(0,"整批水晶交易")
	ui.show_shop()
	var page=ui.current_screen
	page.visitor.set_process(false)
	preload("res://tests/shop_checks.gd").new().fixture(game,true,5)
	game.state.shop_customer.budget=1000
	page.next_customer()
	page.visitor.advance(1)
	await tree.process_frame
	await tree.process_frame
	check.call(page.cart_grid.dimensions==Vector2i(8,4) and page.cart_grid.cell_size==page.warehouse_grid.cell_size and page.stock_grid.cell_size==page.cart_grid.cell_size,"warehouse, stock and shared 8x4 transaction board use identical 48px cells")
	var stock=game.state.stash.duplicate()
	await drag_to_cell(gestures,page.warehouse_grid.tiles[game.state.stash.find("5_0")],page.cart_grid,Vector2i(0,0))
	await drag_to_cell(gestures,page.warehouse_grid.tiles[game.state.stash.find("5_1")],page.cart_grid,Vector2i(3,0))
	check.call(page.cart.entries.size()==2 and game.state.stash==stock,"two real warehouse drags reserve distinct physical items without selling them yet")
	var quote=game.customer_quote(page.cart.selections())
	var expected=game.customer_price("5_0",page.offer)+game.customer_price("5_1",page.offer)
	check.call(quote.price==expected and quote.count==2 and page.quote_label.text.contains(str(expected)),"basket automatically totals each selected item price")
	check.call(not page.select_item(game.customer_drag("stash",game.state.stash.find("5_0"))),"same source copy cannot be counted twice")
	var third=game.customer_drag("stash",game.state.stash.find("5_2"))
	check.call(not page.can_place_cart(third,Vector2i.ZERO,0) and not page.can_place_cart(third,Vector2i(7,3),0),"transaction shapes reject overlap and out-of-bounds placement")
	await drag_to_cell(gestures,page.cart_grid.tiles[0],page.cart_grid,Vector2i(6,0))
	check.call(page.cart.entries.size()==2 and page.cart.entries[0].x==6 and game.customer_quote(page.cart.selections()).price==expected,"real in-board drag moves the item without duplicating it or changing total")
	check.call(page.place_cart(page.cart.drag(1),Vector2i(2,2),1) and I.valid(page.cart.entries,Cart.DIMENSIONS),"transaction items can rotate and pack into real geometric space")
	await gestures.drag(page.cart_grid.tiles[0],page.warehouse_grid)
	check.call(page.cart.entries.size()==1 and game.state.stash==stock,"dragging one item back cancels only that reservation")
	page.select_item(game.customer_drag("stash",game.state.stash.find("5_0")))
	var selected=page.cart.selections()
	var total=game.customer_quote(selected).price
	game.state.shop_customer.budget=total-1
	page.offer=game.customer_offer()
	page.refresh_quote()
	var before=game.state.duplicate(true)
	page.resolve_customer(true)
	check.call(page.quote_label.text.contains("买不起") and game.state==before,"combined total above customer budget rejects the entire sale")
	game.state.shop_customer.budget=total
	page.offer=game.customer_offer()
	var slot=game.slot
	game.slot=-1
	before=game.state.duplicate(true)
	page.resolve_customer(true)
	check.call(game.state==before and page.cart.entries.size()==2,"failed batch save restores all items, budget, currency and pending basket")
	game.slot=slot
	var power=game.state.power
	page.resolve_customer(true)
	check.call(game.state.crystals==before.crystals+total and game.state.power==power and game.state.shop_customer.budget==0,"whole sale pays crystal total once without consuming power")
	check.call(game.state.stash.size()==stock.size()-2 and page.cart.entries.is_empty(),"batch removes correct source indices in descending order and clears the shared board")
	before=game.state.duplicate(true)
	game.accept_customer(page.offer.key,selected)
	check.call(game.state==before,"stale batch cannot pay or remove copies twice")
	preload("res://tests/shop_checks.gd").new().fixture(game,false,4)
	game.state.crystals=1000
	page.next_customer()
	page.visitor.advance(1)
	await tree.process_frame
	await tree.process_frame
	await drag_to_cell(gestures,page.stock_grid.tiles[0],page.cart_grid,Vector2i.ZERO)
	await drag_to_cell(gestures,page.stock_grid.tiles[1],page.cart_grid,Vector2i(4,0))
	check.call(page.cart.entries.size()==2,"customer goods use the same transaction board for a multi-item purchase")
	selected=page.cart.selections()
	total=game.customer_quote(selected).price
	game.state.crystals=total-1
	page.refresh_quote()
	before=game.state.duplicate(true)
	page.resolve_customer(true)
	check.call(game.state==before,"player cannot buy an affordable subset when the whole basket is unaffordable")
	game.state.crystals=total
	before=game.state.duplicate(true)
	page.resolve_customer(true)
	check.call(game.state.crystals==0 and game.state.power==before.power and game.state.shop_customer.budget==before.shop_customer.budget+total,"batch purchase debits only crystal total and credits customer budget")
	check.call(game.state.stash.size()==before.stash.size()+2 and game.state.shop_customer.stock.size()==before.shop_customer.stock.size()-2,"two merchant copies change ownership in one confirmation")
	check.call(game.validate_save(game.slot_info(0)),"batch purchase saves a valid shaped warehouse")
	# Reject forged duplicate selections and overflowing board coordinates at the model boundary.
	preload("res://tests/shop_checks.gd").new().fixture(game,true,6)
	var payload=game.customer_drag("stash",game.state.stash.find("scrap"))
	payload.merge({"cart_x":0,"cart_y":0,"cart_rot":0})
	check.call(not game.customer_quote([payload,payload]).valid,"model refuses duplicate source indices even in a forged batch")
	payload.cart_x=8
	check.call(not game.customer_quote([payload]).valid,"model independently enforces the 8x4 board boundary")
	ui.show_base()
	await tree.process_frame
