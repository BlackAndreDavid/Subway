extends Control
const Art=preload("res://scripts/art_library.gd")
var app: Control
func build(context: Control) -> void:
	app=context
	var image=AtlasTexture.new()
	image.atlas=Art.texture("base/portrait")
	image.region=Rect2(Art.bounds("base/portrait"))
	$Portrait.texture=image
	$Subtitle/Words/Speaker.text="回收员 · "+str(app.dialogue_data.name)
	$Subtitle/Words/Thought.text=str(app.dialogue_data.thought)
	var actions=$Subtitle/Words/Actions
	match str(app.dialogue_data.kind):
		"stash","plants":app.button("仓库",app.show_stash,actions)
		"craft":app.button("合成",app.show_crafting,actions)
		"terminal":
			app.button("地图",app.show_map,actions)
			app.button("装修",func():app.show_base(true),actions)
		"explore":app.button("整备",app.show_preparation,actions)
		"rest":
			$Subtitle/Words/Thought.text+="\n休息消耗：2水、2食物、5电量。"
			app.button("休息",func():app.say(Game.next_day());app.show_base(),actions)
	app.button("继续",app.close_modal,actions)
