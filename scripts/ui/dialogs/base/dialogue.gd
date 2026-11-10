extends HBoxContainer
const Art=preload("res://scripts/art_library.gd")
var app: Control
func build(context: Control) -> void:
	app=context
	var image=AtlasTexture.new()
	image.atlas=Art.texture("base/portrait")
	image.region=Rect2(Art.bounds("base/portrait"))
	$Portrait.texture=image
	var words: VBoxContainer=$Words
	app.section(words,"回收员",str(app.dialogue_data.name))
	var thought=app.wrapped("“%s”" % app.dialogue_data.thought,25)
	thought.custom_minimum_size.y=210
	words.add_child(thought)
	match str(app.dialogue_data.kind):
		"stash","plants":app.button("查看仓库",app.show_stash,words)
		"craft":app.button("打开合成台",app.show_crafting,words)
		"terminal":
			app.button("查看线路图",app.show_map,words)
			app.button("合成家具",app.show_crafting,words)
		"explore":app.button("整理装备 / 探索",app.show_preparation,words)
		"rest":app.button("休息到下一天 / −2水 −2食物 −5电",func():app.say(Game.next_day());app.show_base(),words)
	app.button("继续走走",app.close_modal,words)
