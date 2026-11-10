extends VBoxContainer
var app: Control
func build(context: Control) -> void:
	app=context
	add_child(app.wrapped("箱盖卡得很紧……打开后发现两件遗留装备。只能带走其中一件。"))
	app.button("聚焦晶体 / 本次探索伤害 +25%",func():choose(0),self)
	app.button("散射电容 / 2×2主动道具",func():choose(1),self)
	app.button("整理背包",app.show_bag,self)
	app.button("暂不领取",app.close_modal,self)
func choose(index: int) -> void:
	app.say(Game.claim_reward(index))
	if Game.run.floor_data.rooms[int(Game.run.room)].claimed:
		app.close_modal()
		app.refresh_combat()
