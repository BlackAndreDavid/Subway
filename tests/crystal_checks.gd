extends RefCounted
const Loot=preload("res://scripts/loot_rules.gd")
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	game.new_game(0,"水晶账户")
	var legacy=game.state.duplicate(true)
	legacy.erase("crystals")
	game.write_json("user://slot_0.json",legacy)
	check.call(game.load_game(0) and game.state.crystals==0 and game.state.power==240,"legacy saves migrate to a separate zero crystal balance without converting power")
	var bad=game.state.duplicate(true)
	for value in [-1,0.5,"10"]:
		bad.crystals=value
		check.call(not game.validate_save(bad),"invalid crystal balances are rejected")
	game.begin_run(1,"","","",2026)
	ui.show_combat()
	await tree.process_frame
	var battle=ui.battle
	battle.set_process(false)
	while game.pick_up("1_0"):pass
	var before_bag=game.run.bag.duplicate(true)
	var before_power=game.state.power
	var before_energy=game.run.energy
	battle.room().loot=["crystal"]
	battle.room().ground=[]
	battle.ensure_ground_loot()
	battle.player=battle.room().ground[0].pos
	var expected=Loot.pickup_value(int(game.state.station),"crystal")
	battle.update_ground_loot(0.1)
	check.call(game.state.crystals==expected and battle.room().loot.is_empty(),"crystal floor loot is automatically attracted and collected")
	check.call(game.run.bag==before_bag and game.state.power==before_power and game.run.energy==before_energy,"crystals require no cells and cannot refill electricity or room energy")
	check.call(battle.loot_texture("crystal")==battle.Art.texture("credits"),"crystal loot uses the reviewed crystal sprite through the stable currency art ID")
	game.state.crystals=0
	var count=game.run.bag.size()
	ui.buy_run_item("3_0",22)
	check.call(game.run.bag.size()==count and game.state.power==before_power,"combat shop cannot spend power as substitute currency")
	# Free one cargo cell footprint and buy via crystals.
	game.run.bag=[]
	game.state.crystals=30
	ui.buy_run_item("3_0",22)
	check.call(game.state.crystals==8 and game.state.power==before_power and game.run.bag.size()==1,"combat shop spends crystals and preserves electrical supplies")
	game.end_run(true)
	check.call(game.slot_info(0).crystals==8 and game.load_game(0) and game.state.crystals==8,"crystals persist through safe return and load")
	var found=false
	var rng=RandomNumberGenerator.new()
	rng.seed=2026
	for index in range(1000):
		if Loot.roll_room(0,1,rng).has("crystal"):found=true;break
	check.call(found,"normal combat drop tables can produce crystal currency")
	ui.show_base()
