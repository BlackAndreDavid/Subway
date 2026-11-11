extends RefCounted
# Daily traffic, deterministic category requests and finite physical merchant stock.
const C=preload("res://scripts/catalog.gd")
const I=preload("res://scripts/inventory.gd")
const CATEGORY_NAMES=["水","电","食物","药物","主动道具","强化模块","材料","家具"]
const STOCK_COLUMNS=8
static func limit(station: int) -> int:
	return clampi(ceili(float(C.STATIONS[station].traffic)/20.0),2,10)
static func key(day: int,station: int,customer: int) -> String:
	return "%d:%d:%d" % [day,station,customer]
static func generate(day: int,station: int,customer: int) -> Dictionary:
	var rng=RandomNumberGenerator.new()
	rng.seed=day*1009+station*37+customer*17
	var buying=rng.randf()<0.55
	var category=rng.randi_range(0,7 if buying else 5)
	var offer={"key":key(day,station,customer),"buying":buying,"category":category,"appearance":rng.randi_range(0,3),"budget":roundi(rng.randi_range(35,110)*float(C.STATIONS[station].factor)),"revision":0,"stock":[],"rows":4}
	if not buying:
		for unit in range(rng.randi_range(3,5)):
			var id="%d_%d" % [category,rng.randi_range(0,3)]
			var placement=I.first_fit(offer.stock,Vector2i(STOCK_COLUMNS,int(offer.rows)),id)
			while placement.is_empty():
				offer.rows+=2
				placement=I.first_fit(offer.stock,Vector2i(STOCK_COLUMNS,int(offer.rows)),id)
			placement.id=id
			offer.stock.append(placement)
	return offer
static func valid(offer: Variant,day: int,station: int,customer: int) -> bool:
	if not offer is Dictionary or not offer.has_all(["key","buying","category","appearance","budget","revision","stock","rows"]):return false
	if offer.key!=key(day,station,customer) or not offer.buying is bool:return false
	for field in ["category","appearance","budget","revision","rows"]:
		if not (offer[field] is int or offer[field] is float) or int(offer[field])!=offer[field]:return false
	if offer.budget<0 or offer.revision<0 or offer.rows<4 or offer.rows>20 or not offer.stock is Array:return false
	var initial=generate(day,station,customer)
	for field in ["category","appearance","buying"]:
		if offer[field]!=initial[field]:return false
	if offer.buying:return offer.stock.is_empty()
	if not I.valid(offer.stock,Vector2i(STOCK_COLUMNS,int(offer.rows))):return false
	var available: Array=initial.stock.map(func(entry):return entry.id)
	for entry in offer.stock:
		if not available.has(entry.id):return false
		available.erase(entry.id)
	return true
