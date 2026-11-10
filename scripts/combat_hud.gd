extends Control
const C=preload("res://scripts/catalog.gd")
const Art=preload("res://scripts/art_library.gd")
var weapon_rect=Rect2(12,12,222,106)
var medicine_rect=Rect2()
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	medicine_rect=Rect2(size-Vector2(234,102),Vector2(222,90))
	queue_redraw()
func charge_ratio() -> float:
	if Game.run.is_empty() or Game.run.weapon=="":return 0.0
	return clampf(1.0-float(Game.run.weapon_cd)/C.weapon_cooldown(Game.run.weapon),0,1)
func drug_uses() -> int:
	if Game.run.is_empty() or Game.run.drug=="":return 0
	var entry=Game.equipped_entry("drug")
	return int(entry.get("uses",0))
func _draw() -> void:
	if Game.run.is_empty():return
	medicine_rect=Rect2(size-Vector2(234,102),Vector2(222,90))
	draw_panel(weapon_rect)
	draw_panel(medicine_rect)
	var font=ThemeDB.fallback_font
	var weapon: String=Game.run.weapon
	if weapon!="":draw_texture_rect(Art.texture("items/"+weapon),Rect2(weapon_rect.position+Vector2(10,14),Vector2(54,54)),false)
	draw_string(font,weapon_rect.position+Vector2(72,25),"主动道具 / 空格",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f0ce86"))
	draw_string(font,weapon_rect.position+Vector2(72,49),"空槽" if weapon=="" else C.item(weapon).name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c3d6d9"))
	var bar=Rect2(weapon_rect.position+Vector2(12,72),Vector2(198,9))
	draw_rect(bar,Color("304651"))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*charge_ratio(),bar.size.y)),Color("8cc9be"))
	var status="未装备" if weapon=="" else "充能完成" if charge_ratio()>=1.0 else "充能 %d%% · %.1fs" % [charge_ratio()*100,Game.run.weapon_cd]
	draw_string(font,weapon_rect.position+Vector2(12,99),status,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("9fb7bc"))
	var drug: String=Game.run.drug
	if drug!="":draw_texture_rect(Art.texture("items/"+drug),Rect2(medicine_rect.position+Vector2(10,13),Vector2(54,54)),false)
	draw_string(font,medicine_rect.position+Vector2(72,25),"药物 / Q",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f0ce86"))
	draw_string(font,medicine_rect.position+Vector2(72,48),"空槽" if drug=="" else C.item(drug).name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c3d6d9"))
	draw_string(font,medicine_rect.position+Vector2(72,72),"剩余 %d 次" % drug_uses(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("9fb7bc"))
func draw_panel(rect: Rect2) -> void:
	var style=StyleBoxFlat.new()
	style.bg_color=Color(0.04,0.12,0.16,0.92)
	style.border_color=Color("456872")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	draw_style_box(style,rect)
