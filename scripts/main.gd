extends Control
const C=preload("res://scripts/catalog.gd")
const StoragePresenter=preload("res://scripts/ui/components/storage_presenter.gd")
const PAGE_SCENES={"menu": "res://scenes/frontend/main_menu.tscn", "slots": "res://scenes/frontend/save_slots.tscn", "base": "res://scenes/base/base.tscn", "furniture": "res://scenes/base/furniture_editor.tscn", "map": "res://scenes/base/metro/metro_map.tscn", "prepare": "res://scenes/exploration/preparation.tscn", "combat": "res://scenes/exploration/combat.tscn", "shop": "res://scenes/shop/shop.tscn"}
var current_screen: Control
var storage_panel: Control
var dialogue_data: Dictionary={}
var page="menu"
var root: VBoxContainer
var body: HBoxContainer
var side: VBoxContainer
var toast: Label
var hud: Label
var battle: Control
var modal: Control
var selected_slot=0
var class_select: OptionButton
var loadout: RefCounted
var loadout_slots: HBoxContainer
var warehouse_grid: Control
var storage_grid: Control
var storage_details: VBoxContainer
var stash_selected=-1
var combat_hud: Control
var stage: Control
var topbar: HBoxContainer
var drawer: PanelContainer
var drawer_toggle: Button
var minimap: Control
var base_name: LineEdit
var map_selection=0
var map_view: Control
var map_actions: VBoxContainer
var bag_selected=-1
var notice_text="欢迎来到地下。"
var fonts: Font

func _ready() -> void:
	fonts=load("res://assets/fonts/subway_cjk.otf") if ResourceLoader.exists("res://assets/fonts/subway_cjk.otf") else SystemFont.new()
	if fonts is SystemFont: fonts.font_names=PackedStringArray(["Noto Sans CJK SC","Microsoft YaHei","PingFang SC"])
	var t=Theme.new()
	t.default_font=fonts
	t.default_font_size=17
	t.set_color("font_color","Label",Color("c3d6d9"))
	t.set_color("font_color","Button",Color("d3e1df"))
	t.set_color("font_hover_color","Button",Color("ffffff"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box=StyleBoxFlat.new()
		box.bg_color={"normal":Color("203d48"),"hover":Color("315763"),"pressed":Color("4b7278"),"disabled":Color("182d35"),"focus":Color(0,0,0,0)}[state]
		box.set_corner_radius_all(7)
		box.content_margin_left=16
		box.content_margin_right=16
		box.content_margin_top=10
		box.content_margin_bottom=10
		if state=="focus":
			box.set_border_width_all(2)
			box.border_color=Color("92c6c4")
		t.set_stylebox(state,"Button",box)
	theme=t
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	ThemeDB.fallback_font=fonts
	show_menu()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0a1b24"))
	for i in range(17):
		var x=i*100.0
		draw_line(Vector2(x,0),Vector2(x-250,size.y),Color("102630"),1)
	for i in range(11): draw_line(Vector2(0,i*100),Vector2(size.x,i*100),Color("102630"),1)
	draw_circle(Vector2(size.x-180,130),260,Color(0.21,0.43,0.44,0.06))
func clear_page(id: String) -> void:
	page=id
	current_screen=null
	storage_panel=null
	combat_hud=null
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal=null
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	battle=null
	side=null
	drawer=null
	drawer_toggle=null
	minimap=null
	stage=null
	root=VBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left=36
	root.offset_top=28
	root.offset_right=-36
	root.offset_bottom=-22
	root.add_theme_constant_override("separation",17)
	var top=HBoxContainer.new()
	topbar=top
	root.add_child(top)
	var brand=label("SUBWAY",32,Color("a3d4cf"))
	top.add_child(brand)
	var sub=label("地 铁 余 生    /    上海 · 核战后十年",16,Color("72949e"))
	sub.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(sub)
	top.alignment=BoxContainer.ALIGNMENT_CENTER
	hud=label("",15,Color("e7c595"))
	top.add_child(hud)
	if not Game.state.is_empty() and id not in ["menu","slots"]:
		hud.text="%s   |   DAY %02d   |   水 %d   食物 %d   电 %d" % [Game.state.name,Game.state.day,Game.state.water,Game.state.food,Game.state.power]
	var line=HSeparator.new()
	root.add_child(line)
	body=HBoxContainer.new()
	body.add_theme_constant_override("separation",25)
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	root.add_child(body)
	toast=label(notice_text,16,Color("92b6ba"))
	toast.custom_minimum_size.y=27
	root.add_child(toast)

func label(text: String,fs: int=18,color: Color=Color("c3d6d9")) -> Label:
	var l=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",fs)
	l.add_theme_color_override("font_color",color)
	return l
func wrapped(text: String,fs: int=16) -> Label:
	var l=label(text,fs)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return l
func button(text: String,callback: Callable,parent: Node,disabled: bool=false) -> Button:
	var b=Button.new()
	b.text=text
	b.disabled=disabled
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	parent.add_child(b)
	return b
func section(parent: Node,title: String,text: String="") -> void:
	parent.add_child(label(title,23,Color("e4c493")))
	if text!="": parent.add_child(wrapped(text))
func panel(parent: Node,width: float=360) -> VBoxContainer:
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size.x=width
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var v=VBoxContainer.new()
	v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation",12)
	scroll.add_child(v)
	return v
func say(text: String) -> void:
	notice_text=text
	if is_instance_valid(toast):toast.text=text
func back_button(callback: Callable,parent: Node) -> void:
	button("← 返回",callback,parent)
func show_menu() -> void:
	mount_page("menu")
func show_slots() -> void:
	mount_page("slots")
func empty(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
func show_slot_actions() -> void:
	if is_instance_valid(current_screen) and page=="slots":current_screen.show_slot_actions()
func confirm_replace() -> void:
	mount_dialog("res://scenes/frontend/new_save_dialog.tscn","重建档案")
func gameplay_stage(view: Control) -> void:
	stage=current_screen.get_node_or_null("Stage")
	if stage==null:
		stage=Control.new()
		current_screen.add_child(stage)
	stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size=Vector2(600,500)
	if view.get_parent()!=stage:stage.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func make_drawer(top_offset: float=0) -> VBoxContainer:
	drawer=PanelContainer.new()
	stage.add_child(drawer)
	drawer.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	drawer.offset_left=-370
	drawer.offset_right=0
	drawer.offset_top=top_offset
	var style=StyleBoxFlat.new()
	style.bg_color=Color("112b36")
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	style.set_border_width_all(1)
	style.border_color=Color("365661")
	drawer.add_theme_stylebox_override("panel",style)
	drawer.mouse_filter=Control.MOUSE_FILTER_STOP
	var column=VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	drawer.add_child(column)
	drawer_toggle=button("展开详情 ›",toggle_drawer,topbar)
	drawer.visible=false
	return column
func toggle_drawer() -> void:
	if not is_instance_valid(drawer):return
	drawer.visible=not drawer.visible
	drawer_toggle.text="收起详情 ‹" if drawer.visible else "展开详情 ›"
func show_base(placing: bool=false) -> void:
	mount_page("furniture" if placing else "base")
func show_map() -> void:
	mount_page("map")
func station_detail() -> void:
	if is_instance_valid(current_screen) and page=="map":current_screen.station_detail()
func show_preparation() -> void:
	mount_page("prepare")
func refresh_loadout() -> void:
	if is_instance_valid(current_screen) and page=="prepare":current_screen.refresh_loadout()
func start_run() -> void:
	if is_instance_valid(current_screen) and page=="prepare":current_screen.start_run()
func show_combat() -> void:
	mount_page("combat")
func refresh_combat() -> void:
	if is_instance_valid(current_screen) and page=="combat":current_screen.refresh_combat()
func buy_run_item(id: String,cost: int) -> void:
	if is_instance_valid(current_screen) and page=="combat":current_screen.buy_run_item(id,cost)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.physical_keycode==KEY_ESCAPE:
		if is_instance_valid(modal):close_modal()
		elif page=="combat":show_pause()
		elif page=="furniture":show_base()
	elif event.physical_keycode==KEY_B and page=="combat":
		if is_instance_valid(modal):close_modal()
		else:show_bag()
func open_modal(title: String) -> VBoxContainer:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal=preload("res://scenes/common/modal.tscn").instantiate()
	add_child(modal)
	var content: VBoxContainer=modal.get_node("Frame/Scroll/Content")
	section(content,title)
	if is_instance_valid(battle):battle.paused=true
	return content
func mount_dialog(path: String,title: String) -> void:
	var host=open_modal(title)
	var view=load(path).instantiate()
	host.add_child(view)
	view.build(self)
func close_modal() -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal=null
	if is_instance_valid(battle):battle.paused=false
	if page=="furniture" and is_instance_valid(current_screen):current_screen.refresh_furniture_options()
func show_settings() -> void:
	mount_dialog("res://scenes/frontend/settings_dialog.tscn","设置")
func show_pause() -> void:
	mount_dialog("res://scenes/exploration/pause_dialog.tscn","作业暂停")
func descend_floor() -> void:
	if not is_instance_valid(battle) or battle.nearby_exit()!="descent":return
	if Game.next_floor():
		battle.enter_room()
		refresh_combat()
	else:say(Game.last_error)
func return_to_base() -> void:
	if not is_instance_valid(battle) or battle.nearby_exit()!="return":return
	var message=Game.end_run(true)
	show_base()
	say(message)
func show_reward() -> void:
	if Game.run.is_empty() or Game.run.fighting or not is_instance_valid(battle):return
	var room: Dictionary=Game.run.floor_data.rooms[int(Game.run.room)]
	if room.kind!="reward" or room.claimed or battle.player.distance_to(Vector2(450,280))>battle.INTERACT_DISTANCE:return
	mount_dialog("res://scenes/exploration/reward_dialog.tscn","打开遗留宝箱")
func show_base_dialogue(info: Dictionary) -> void:
	if not page in ["base","furniture"] or not Game.run.is_empty():return
	dialogue_data=info
	close_modal()
	modal=preload("res://scenes/base/dialogue.tscn").instantiate()
	add_child(modal)
	modal.build(self)
func show_crafting() -> void:
	if not page in ["base","furniture"] or not Game.run.is_empty():return
	mount_dialog("res://scenes/base/crafting.tscn","材料合成 / 家具")
func create_storage_grid(mode: String) -> Control:
	return StoragePresenter.create(mode)
func storage_layout(parent: VBoxContainer,mode: String) -> void:
	storage_panel=preload("res://scenes/inventory/storage_panel.tscn").instantiate()
	parent.add_child(storage_panel)
	storage_panel.build(self,mode)
func show_stash() -> void:
	mount_dialog("res://scenes/inventory/warehouse_dialog.tscn","基地仓库")
func consume_stash(id: String) -> void:
	if not Game.state.stash.has(id):return
	Game.remove_stash(Game.state.stash.find(id))
	var grade=int(id.split("_")[1])
	match int(C.item(id).category):
		0:Game.state.water+=[3,5,7,10][grade]
		1:Game.state.power+=[6,10,15,22][grade]
		2:Game.state.food+=[3,5,7,10][grade]
	Game.save_game()
func show_bag() -> void:
	if Game.run.is_empty():return
	if Game.run.fighting:
		say("战斗中不能打开或调整背包。")
		return
	mount_dialog("res://scenes/inventory/backpack_dialog.tscn","随身背包")
func refresh_storage_details(mode: String) -> void:
	if is_instance_valid(storage_panel):storage_panel.refresh_details(mode)
func set_module(id: String) -> bool:
	var ok=Game.set_module(id)
	if not ok:say(Game.last_error)
	return ok
func equip_bag(index: int) -> void:
	if not Game.equip_entry(index):say(Game.last_error)
func drop_bag(index: int) -> void:
	if Game.run.is_empty() or Game.run.fighting or index<0 or index>=Game.run.bag.size():return
	var id: String=Game.run.bag[index].id
	Game.run.floor_data.rooms[int(Game.run.room)].loot.append(Game.run.bag[index].duplicate(true))
	if is_instance_valid(battle):battle.ensure_ground_loot(battle.player)
	Game.run.bag.remove_at(index)
	Game.inventory_changed()
	bag_selected=-1
func show_shop() -> void:
	mount_page("shop")

func mount_page(id: String) -> void:
	if id=="shop" and not Game.open_shop():
		say(Game.last_error)
		return
	if page=="shop" and id!="shop":Game.close_shop()
	clear_page(id)
	current_screen=load(PAGE_SCENES[id]).instantiate()
	body.add_child(current_screen)
	current_screen.build(self)
