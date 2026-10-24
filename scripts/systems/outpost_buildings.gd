extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const LAB_SIZE := Vector2i(4, 3)
const LAB_COST := {"stone": 6, "copper": 4}
const CACHE_CAPACITY := 32
const LAMP_RECIPE := {"soil": 1, "copper": 1}
var structures: Array = []

func size_for(id: String) -> Vector2i:
	return LAB_SIZE if id == "laboratory" else Vector2i.ONE

func footprint(id: String, origin: Vector2i) -> Rect2i:
	return Rect2i(origin, size_for(id))

func world_rect(building: Dictionary) -> Rect2:
	return Rect2(Grid.to_world(building.origin), Grid.to_world(size_for(building.id)))

func labs() -> Array:
	return structures.filter(func(item: Dictionary): return item.id == "laboratory")

func blocker(id: String, origin: Vector2i, site: RefCounted, field: RefCounted) -> String:
	if id not in ["laboratory", "lamp"]:
		return "Progetto sconosciuto"
	var rect := footprint(id, origin)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if not site.contains(cell) or not site.material(cell).is_empty():
				return "Spazio non libero: scava l'ingombro del progetto"
			if float(field.water.get(cell, 0)) > 0.05 or float(field.gas.get(cell, 0)) > 0.03:
				return "Area non sicura: presenza di acqua o gas"
	for x in range(rect.position.x, rect.end.x):
		var support := Vector2i(x, rect.end.y)
		if not site.contains(support) or site.material(support).is_empty():
			return "Serve un pavimento stabile sotto tutta la struttura"
	for building: Dictionary in structures:
		if rect.intersects(footprint(building.id, building.origin)):
			return "Ingombro gia occupato"
	return ""

func install(id: String, origin: Vector2i) -> Dictionary:
	var building := {"id": id, "origin": origin, "stock": {}}
	structures.append(building)
	return building

func snapshot() -> Array:
	var result: Array = []
	for building: Dictionary in structures:
		result.append({"id": building.id, "origin": [building.origin.x, building.origin.y], "stock": building.stock.duplicate()})
	return result

func restore(data: Variant, site: RefCounted) -> bool:
	if not data is Array or data.size() > 200:
		return false
	var next: Array = []
	for item in data:
		if not item is Dictionary or item.get("id") not in ["laboratory", "lamp"] or not item.get("stock", {}) is Dictionary:
			return false
		var origin = Grid.decode_cell(item.get("origin"))
		if not origin is Vector2i:
			return false
		var rect := footprint(item.id, origin)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if not site.contains(Vector2i(x, y)) or not site.material(Vector2i(x, y)).is_empty():
					return false
		for placed: Dictionary in next:
			if rect.intersects(footprint(placed.id, placed.origin)):
				return false
		for x in range(rect.position.x, rect.end.x):
			var support := Vector2i(x, rect.end.y)
			if not site.contains(support) or site.material(support).is_empty():
				return false
		var stock: Dictionary = item.get("stock", {})
		if not Cargo.valid_stock(stock, CACHE_CAPACITY if item.id == "laboratory" else 0):
			return false
		var normalized := {}
		for id: String in stock:
			normalized[id] = int(stock[id])
		next.append({"id": item.id, "origin": origin, "stock": normalized})
	if next.any(func(item: Dictionary): return item.id == "lamp") and not next.any(func(item: Dictionary): return item.id == "laboratory"):
		return false
	structures = next
	return true
