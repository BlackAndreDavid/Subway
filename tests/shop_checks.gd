extends RefCounted
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	game.new_game(0,"经营测试")
	check.call(not game.state.has("market_stock"),"new saves have no system restock field")
	var legacy=game.state.duplicate(true)
	legacy.market_stock={"4_0":0}
	game.write_json("user://slot_0.json",legacy)
	check.call(game.load_game(0) and not game.state.has("market_stock"),"legacy saves load and discard retired supply stock")
	ui.show_shop()
	var page=ui.current_screen
	var window=page.visitor
	window.set_process(false)
	var day=game.state.day
	var count=game.state.customer
	check.call(page.accept_button.disabled and page.skip_button.disabled,"arrival locks both transaction actions")
	page.resolve_customer(false)
	check.call(game.state.customer==count,"arrival cannot skip or transact")
	var far=window.presentation()
	window.advance(0.4)
	var middle=window.presentation()
	check.call(middle.scale>far.scale and middle.alpha>far.alpha and middle.brightness>far.brightness,"approaching grows, fades in and brightens")
	window.advance(0.4)
	check.call(window.phase=="ready" and not page.accept_button.disabled,"arrival enables trade exactly at the counter")
	var old_appearance=window.appearance
	page.resolve_customer(false)
	check.call(game.state.customer==count+1 and window.phase=="departing" and page.skip_button.disabled,"decline advances one customer and starts departure")
	page.resolve_customer(false)
	check.call(game.state.customer==count+1,"rapid repeat click cannot skip another visitor")
	window.advance(0.3)
	check.call(window.appearance==old_appearance and window.depth<1,"old portrait remains visible and retreats before replacement")
	window.advance(1)
	check.call(window.phase=="arriving" and page.offer.key==game.customer_offer().key,"next visitor enters only after the old one exits")
	window.advance(1)
	ui.show_stash()
	check.call(game.state.day==day and game.state.customer==count+1,"warehouse does not reset queue or repay opening day")
	ui.close_modal()
	# Exercise both real transaction directions with deterministic visitor offers.
	for buying in [true,false]:
		for index in range(100):
			game.state.customer=index
			if game.customer_offer().buying==buying:break
		page.next_customer()
		window.advance(1)
		var offer=page.offer.duplicate()
		if buying:
			while game.state.stash.has(offer.id):game.remove_stash(game.state.stash.find(offer.id))
		else:game.state.power=0
		var before=game.state.duplicate(true)
		page.resolve_customer(true)
		check.call(game.state==before and window.phase=="ready","failed trade leaves offer, inventory and visitor unchanged")
		if buying:game.add_stash(offer.id)
		else:game.state.power=1000
		before=game.state.duplicate(true)
		var slot=game.slot
		game.slot=-1
		page.resolve_customer(true)
		check.call(game.state==before and window.phase=="ready","save failure rolls back money, goods and visitor queue")
		game.slot=slot
		page.resolve_customer(true)
		check.call(game.state.customer==before.customer+1 and window.phase=="departing","successful trade advances exactly one visitor")
		check.call(game.state.power==before.power+(offer.price if buying else -offer.price),"customer price settles once")
		check.call(game.state.stash.count(offer.id)==before.stash.count(offer.id)+(-1 if buying else 1),"exactly one concrete item changes ownership")
		var settled=game.state.duplicate(true)
		game.accept_customer(offer.key)
		check.call(game.state==settled,"stale offer cannot settle twice")
		check.call(game.validate_save(game.slot_info(0)),"transaction saves retain valid physical warehouse layout")
	check.call(game.state.day==day,"all customer trades remain in the same operating day")
	ui.show_base()
	var before=game.state.duplicate(true)
	game.accept_customer()
	check.call(game.state==before,"customer trade is unavailable outside a shop session")
	await tree.process_frame
