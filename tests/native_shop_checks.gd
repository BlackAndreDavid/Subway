extends SceneTree
var ui: Control
var checks=0
var failures=0
func _initialize() -> void:
	if OS.get_environment("SUBWAY_TEST_MODE")!="1":quit(1);return
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func shot(path: String) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	image.save_png(path)
	return image
func run() -> void:
	root.size=Vector2i(1440,900)
	var game=root.get_node("Game")
	game.new_game(0,"上海堡垒")
	ui=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(ui)
	ui.show_shop()
	var page=ui.current_screen
	var visitor=page.visitor
	visitor.set_process(false)
	for index in range(4):
		preload("res://tests/shop_checks.gd").new().fixture(game,false,4,index)
		page.next_customer()
		var far=await shot("res://docs/shop_customer_%d_far.png" % index)
		visitor.advance(1.0)
		var near=await shot("res://docs/shop_customer_%d.png" % index)
		check(far.get_data()!=near.get_data(),"native visitor arrival changes pixels")
		check(visitor.size.x>=340 and visitor.size.y>=240 and visitor.size.y<=300,"native customer window remains usable")
		if index==0:near.save_png("res://docs/shop.png")
		visitor.dismiss()
		visitor.advance(0.325)
		var retreat=await shot("res://docs/shop_customer_%d_leaving.png" % index)
		check(retreat.get_data()!=near.get_data(),"native retreat changes scale, alpha and brightness")
		if index==0:retreat.save_png("res://docs/shop_details.png")
	# Category preview with an over-budget sale and an always-visible warehouse.
	preload("res://tests/shop_checks.gd").new().fixture(game,true,5,0)
	game.state.shop_customer.budget=1
	game.add_stash("5_0")
	page.next_customer()
	visitor.advance(1)
	page.select_item(game.customer_drag("stash",game.state.stash.find("5_0")))
	await shot("res://docs/shop_budget.png")
	# The same board holds multiple items for both sale and purchase.
	preload("res://tests/shop_checks.gd").new().fixture(game,true,5,0)
	game.state.shop_customer.budget=500
	page.next_customer()
	visitor.advance(1)
	page.select_item(game.customer_drag("stash",game.state.stash.find("5_0")))
	page.select_item(game.customer_drag("stash",game.state.stash.find("5_1")))
	await shot("res://docs/shop_batch_sell.png")
	preload("res://tests/shop_checks.gd").new().fixture(game,false,4,1)
	game.state.crystals=500
	page.next_customer()
	visitor.advance(1)
	page.select_item(game.customer_drag("customer",0))
	page.select_item(game.customer_drag("customer",1))
	await shot("res://docs/shop_batch_buy.png")
	await preload("res://tests/shop_checks.gd").new().run(self,game,ui,check)
	await preload("res://tests/travel_checks.gd").new().run(self,game,ui,check)
	await preload("res://tests/shop_basket_checks.gd").new().run(self,game,ui,check)
	await preload("res://tests/crystal_checks.gd").new().run(self,game,ui,check)
	# Ground-drop fixture shows the reviewed crystal at its actual gameplay scale.
	game.new_game(0,"上海堡垒")
	game.begin_run(1,"","","",2026)
	ui.show_combat()
	ui.battle.set_process(false)
	ui.battle.room().loot=["crystal","power"]
	ui.battle.room().ground=[]
	ui.battle.ensure_ground_loot(Vector2(450,300))
	ui.battle.player=Vector2(520,350)
	ui.battle.queue_redraw()
	await shot("res://docs/crystal_drop.png")
	game.end_run(false)
	ui.queue_free()
	await process_frame
	await process_frame
	# Give the audio mixer time to release the screenshot room playback.
	await create_timer(0.2).timeout
	print("NATIVE SHOP CHECKS: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
