extends VBoxContainer
const Inventory=preload("res://scripts/inventory.gd")
var app: Control
func build(context: Control) -> void:
	app=context
	var v=self
	Game.ensure_stash()
	v.add_child(app.label("%d×%d · 已占 %d 格" % [Game.STASH_COLUMNS,Game.state.stash_rows,Inventory.used(Game.stash_entries())],20))
	v.add_child(app.wrapped("按形状存放，拖拽整理，拖拽时 R 旋转。仓库纵向扩展，购入与回收物资均保留。选择物品可入库使用或售出。",15))
	app.storage_layout(v,"stash")
	app.button("返回",app.close_modal,v)
