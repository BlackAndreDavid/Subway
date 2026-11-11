extends RefCounted
const C=preload("res://scripts/catalog.gd")
const Metro=preload("res://scripts/metro.gd")
func run(tree: SceneTree,game: Node,ui: Control,check: Callable) -> void:
	game.new_game(0,"按日旅行")
	var farthest=0
	for index in range(C.STATIONS.size()):
		var plan=game.travel_plan(index)
		var hops=Metro.route(0,index).size()-1
		check.call(plan.days==ceili(float(hops)/4) and plan.water==2*plan.days and plan.food==2*plan.days and plan.power==5*plan.days,"all station routes charge days and matching daily supplies")
		if plan.days>game.travel_plan(farthest).days:farthest=index
	check.call(game.travel_plan(farthest).days>1,"long route takes multiple days")
	var before=game.state.duplicate(true)
	game.travel(0)
	game.travel(-1)
	game.travel(C.STATIONS.size())
	check.call(game.state==before,"same station and invalid stations cannot consume a day")
	for resource in ["water","food","power"]:
		game.state[resource]=0
		before=game.state.duplicate(true)
		game.travel(farthest)
		check.call(game.state==before,"insufficient route supplies cannot partially travel or spend other resources")
		game.state[resource]=1000
	game.state.water=1000
	game.state.food=1000
	game.state.power=1000
	var plan=game.travel_plan(farthest)
	before=game.state.duplicate(true)
	var slot=game.slot
	game.slot=-1
	game.travel(farthest)
	check.call(game.state==before,"failed travel save rolls back days, station, news and resource costs")
	game.slot=slot
	game.travel(farthest)
	check.call(game.state.station==farthest and game.state.day==before.day+plan.days,"travel reaches destination and advances the whole route duration")
	check.call(game.state.water==before.water-plan.water and game.state.food==before.food-plan.food and game.state.power==before.power-plan.power,"travel consumes only days times daily supplies")
	check.call(game.state.customer==0 and not game.state.has("shop_customer") and game.state.news==(int(game.state.day)*7)%4,"arrival resets daily queue and updates the calendar news")
	check.call(game.slot_info(0).station==farthest and game.slot_info(0).day==game.state.day,"arrival and all costs are saved atomically")
	ui.show_map()
	ui.map_selection=0
	ui.station_detail()
	await tree.process_frame
	check.call(ui.map_actions.get_node("TravelButton").disabled==not game.travel_plan(0).available,"map action agrees with the route affordability preview")
	check.call(ui.map_actions.get_child(0).text.contains("路程") and ui.map_actions.get_child(0).text.contains("食物"),"travel duration and total supplies stay beside the action outside the details scroll")
	game.state.water=0
	ui.station_detail()
	check.call(ui.map_actions.get_node("TravelButton").disabled,"map disables a trip without enough daily supplies")
	ui.show_base()
