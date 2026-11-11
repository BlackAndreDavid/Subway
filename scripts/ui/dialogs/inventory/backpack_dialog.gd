extends VBoxContainer
const Inventory=preload("res://scripts/inventory.gd")
var app: Control
func build(context: Control) -> void:
	app=context
	var v=self
	v.add_child(app.label("%d×%d · 已占 %d/%d 格" % [Game.run.stats.grid_cols,Game.run.stats.grid_rows,Inventory.used(Game.run.bag),Game.run.stats.capacity],20))
	v.add_child(app.wrapped("背包内按形状整理，R旋转；拖到右侧装备槽装配或替换，拖回背包卸下。已装备物品不占背包。\n资源绿 · 药品紫 · 主动道具白 · 模组蓝 · 其他商品金",15))
	app.storage_layout(v,"bag")
	app.button("返回",func():app.bag_selected=-1;app.close_modal();app.refresh_combat(),v)
