extends VBoxContainer
const Inventory=preload("res://scripts/inventory.gd")
var app: Control
func build(context: Control) -> void:
	app=context
	var v=self
	v.add_child(app.label("%d×%d · 已占 %d/%d 格" % [Game.run.stats.grid_cols,Game.run.stats.grid_rows,Inventory.used(Game.run.bag),Game.run.stats.capacity],20))
	v.add_child(app.wrapped("拖动到空位整理，拖拽时 R 旋转；绿色可放、红色冲突。装备也实际占格，主动道具至少 2×2。",15))
	app.storage_layout(v,"bag")
	app.button("返回",func():app.bag_selected=-1;app.close_modal();app.refresh_combat(),v)
