extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const LAB_SIZE := Vector2i(4, 3)
const LAB_COST := {"stone": 6, "copper": 4}
const CACHE_CAPACITY := 32
const LAMP_RECIPE := {"soil": 1, "copper": 1}
const PUMP_COST := {"stone": 3, "copper": 4}
const PUMP_SIZE := Vector2i(2, 2)
const PUMP_RATE := 0.7
const PUMP_RADIUS := 3
const FAN_COST := {"stone": 2, "copper": 3}
const FAN_RATE := 0.35
const FAN_RADIUS := 3
const CUBE_IDS := ["laboratory", "lamp", "pump", "fan", "furnace", "gas_converter", "greenhouse"]
const DEVICE_IDS := ["lamp", "pump", "fan"]
const INDUSTRIAL_IDS := ["furnace", "gas_converter", "greenhouse"]
const IndustryCatalog = preload("res://scripts/data/industry_catalog.gd")
const NAMES := {"laboratory": "Laboratorio", "lamp": "Luce", "pump": "Pompa acqua", "fan": "Ventilatore gas", "furnace": "Fornace", "gas_converter": "Convertitore gas", "greenhouse": "Serra"}
const CUBE_COLORS := {"laboratory": Color("8be7df"), "lamp": Color("f6d683"), "pump": Color("7cc6ee"), "fan": Color("b9e8a0"), "furnace": Color("ee9c75"), "gas_converter": Color("d4d774"), "greenhouse": Color("9cdb8c")}
const SIZES := {"laboratory": Vector2i(4, 3), "pump": Vector2i(2, 2), "fan": Vector2i(2, 2), "furnace": Vector2i(3, 2), "gas_converter": Vector2i(2, 2), "greenhouse": Vector2i(4, 3)}
const MAX_LAB_LEVEL := 3
var structures: Array = []

static func is_active(building: Dictionary) -> bool:
	return building.get("state", "active") == "active"

static func cost_for(id: String) -> Dictionary:
	if id in INDUSTRIAL_IDS:
		return IndustryCatalog.load_data().recipes[id].cost.duplicate()
	if id == "ladder":
		return {"soil": 2}
	if id == "pump":
		return PUMP_COST.duplicate()
	if id == "fan":
		return FAN_COST.duplicate()
	return LAB_COST.duplicate() if id == "laboratory" else LAMP_RECIPE.duplicate()

static func build_seconds(id: String) -> float:
	if id in INDUSTRIAL_IDS:
		return float(IndustryCatalog.load_data().recipes[id].deployment_seconds)
	if id in ["pump", "fan"]:
		return 4.0
	return 5.0 if id == "laboratory" else (0.0 if id == "ladder" else 2.5)

static func power_draw(building: Dictionary) -> float:
	if building.id in INDUSTRIAL_IDS:
		return 0.06 if building.get("state") == "building" else 0.0
	if building.id == "ladder":
		return 0.0
	if building.id == "pump":
		return 0.08 if building.get("state") == "building" else 0.03
	if building.id == "fan":
		return 0.05 if building.get("state") == "building" else 0.02
	if building.get("state") == "building":
		return 0.06 if building.id == "laboratory" else 0.02
	return (0.04 + 0.01 * (int(building.get("level", 1)) - 1)) if building.id == "laboratory" else 0.008

static func cache_capacity(building: Dictionary) -> int:
	return CACHE_CAPACITY + 16 * (int(building.get("level", 1)) - 1)

static func light_range(building: Dictionary) -> float:
	return 8.0 + 2.0 * (int(building.get("level", 1)) - 1)

static func upgrade_cost(building: Dictionary) -> Dictionary:
	var level := int(building.get("level", 1))
	return {"stone": 4 * level, "copper": 3 * level} if level < MAX_LAB_LEVEL else {}

func size_for(id: String) -> Vector2i:
	return SIZES.get(id, Vector2i.ONE)

func footprint(id: String, origin: Vector2i) -> Rect2i:
	return Rect2i(origin, size_for(id))

func world_rect(building: Dictionary) -> Rect2:
	return Rect2(Grid.to_world(building.origin), Grid.to_world(size_for(building.id)))

func labs() -> Array:
	return structures.filter(func(item: Dictionary): return item.id == "laboratory" and is_active(item))

static func environment_safe(id: String, water: float, gas: float, oil: float = 0) -> bool:
	return oil <= 0.05 and (id == "pump" or water <= 0.05) and (id == "fan" or gas <= 0.03)

func blocker(id: String, origin: Vector2i, site: RefCounted, field: RefCounted, ignore: Dictionary = {}) -> String:
	if id not in CUBE_IDS and id != "ladder":
		return "Progetto sconosciuto"
	var rect := footprint(id, origin)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if not site.contains(cell) or not site.material(cell).is_empty():
				return "Spazio non libero: scava l'ingombro del progetto"
			if not environment_safe(id, float(field.water.get(cell, 0)), float(field.gas.get(cell, 0)), float(field.oil.get(cell, 0))):
				return "Area non sicura: presenza di acqua, gas o petrolio"
	for x in range(rect.position.x, rect.end.x) if id != "ladder" else []:
		var support := Vector2i(x, rect.end.y)
		if not site.contains(support) or site.material(support).is_empty():
			return "Serve un pavimento stabile sotto tutta la struttura"
	for building: Dictionary in structures:
		if building == ignore:
			continue
		if rect.intersects(footprint(building.id, building.origin)):
			return "Ingombro gia occupato"
	return ""

func install(id: String, origin: Vector2i) -> Dictionary:
	var building := {"id": id, "origin": origin, "stock": {}, "level": 1, "state": "active", "progress": 1.0, "enabled": true, "drained": 0.0}
	structures.append(building)
	return building

func plan(id: String, origin: Vector2i) -> Dictionary:
	if id not in CUBE_IDS:
		return {}
	var building := install(id, origin)
	building.state = "planned"
	building.progress = 0.0
	return building

func snapshot() -> Array:
	var result: Array = []
	for building: Dictionary in structures:
		result.append({"id": building.id, "origin": [building.origin.x, building.origin.y], "stock": building.stock.duplicate(), "level": int(building.get("level", 1)), "state": building.get("state", "active"), "progress": float(building.get("progress", 1.0)), "enabled": building.get("enabled", true), "drained": float(building.get("drained", 0))})
	return result

func restore(data: Variant, site: RefCounted) -> bool:
	if not data is Array or data.size() > 200:
		return false
	var next: Array = []
	for item in data:
		if not item is Dictionary or (item.get("id") not in CUBE_IDS and item.get("id") != "ladder") or not item.get("stock", {}) is Dictionary:
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
		for x in range(rect.position.x, rect.end.x) if item.id != "ladder" else []:
			var support := Vector2i(x, rect.end.y)
			if not site.contains(support) or site.material(support).is_empty():
				return false
		var stock: Dictionary = item.get("stock", {})
		var state = item.get("state", "active")
		var progress = item.get("progress", 1.0 if state == "active" else 0.0)
		if state not in ["planned", "building", "active"] or not (progress is int or progress is float) or not is_finite(float(progress)) or progress < 0 or progress > 1 or not item.get("enabled", true) is bool:
			return false
		if (state == "planned" and progress != 0) or (state == "building" and progress >= 1) or (state == "active" and progress != 1) or (state != "active" and not stock.is_empty()):
			return false
		var level = item.get("level", 1)
		if not (level is int or level is float) or not is_finite(float(level)) or float(level) != floorf(float(level)) or level < 1 or level > (MAX_LAB_LEVEL if item.id == "laboratory" else 1):
			return false
		if state != "active" and level != 1:
			return false
		if not Cargo.valid_stock(stock, cache_capacity(item) if item.id == "laboratory" else 0):
			return false
		var normalized := {}
		var drained = item.get("drained", 0.0)
		if not (drained is int or drained is float) or not is_finite(float(drained)) or drained < 0 or (item.id not in ["pump", "fan"] and drained != 0):
			return false
		for id: String in stock:
			normalized[id] = int(stock[id])
		# Earlier saves used ladder cubes: keep paid ladders, drop unfunded plans.
		if item.id == "ladder":
			if state == "planned":
				continue
			state = "active"
			progress = 1.0
		next.append({"id": item.id, "origin": origin, "stock": normalized, "level": int(level), "state": state, "progress": float(progress), "enabled": item.get("enabled", true), "drained": float(drained)})
	if next.any(func(item: Dictionary): return item.id in DEVICE_IDS and is_active(item)) and not next.any(func(item: Dictionary): return item.id == "laboratory" and is_active(item)):
		return false
	structures = next
	return true
