extends RefCounted

const Modules = preload("res://scripts/data/ship_module_catalog.gd")
const Tools = preload("res://scripts/data/digital_tool_catalog.gd")
const FieldCargo = preload("res://scripts/systems/field_cargo.gd")
const GuideState = preload("res://scripts/systems/drone_guide_state.gd")
const Fabrication = preload("res://scripts/systems/fabrication_state.gd")
const IndustryCatalog = preload("res://scripts/data/industry_catalog.gd")
const RESOURCE_IDS := FieldCargo.ITEM_IDS
var modules: Dictionary = {"hull": 1, "engine": 1, "cargo": 1, "battery": 1, "drill": 1, "landing_gear": 1, "habitat": 1, "drone": 1}
var resources: Dictionary = {"soil": 0, "stone": 0, "copper": 0, "crystal": 0, "lamp_kit": 0}
var laboratory_level := 1
var fabrication := Fabrication.new()
var field_cargo := FieldCargo.new()
var drone_guide := GuideState.new()
var lab_research_unlocked := false
var seed_bank := IndustryCatalog.initial_seeds()
var hull := 100.0
var fuel := 80.0
var energy := 60.0
var suit_integrity := 100.0
var crew_energy := 100.0
var tool_slots: Array[String] = ["pulse", "scanner", "", ""]
var active_tool_slot := 0

func hull_capacity() -> float:
	return 100.0 + 40.0 * (int(modules.hull) - 1)

func fuel_capacity() -> float:
	return 80.0

func energy_capacity() -> float:
	return 60.0 + 40.0 * (int(modules.battery) - 1)

func cargo_capacity() -> int:
	return 120 + 80 * (int(modules.cargo) - 1)

func cargo_used() -> int:
	return field_cargo.used(resources)

func dry_mass_kg() -> float:
	var mass := 8000.0
	for definition: Resource in Modules.all():
		mass += definition.mass_kg * (int(modules[definition.module_id]) - 1)
	return mass

func crew_capacity() -> int:
	return int(modules.habitat)

func oxygen_reserve_minutes() -> float:
	return 120.0 + 60.0 * (int(modules.habitat) - 1)

func drill_power() -> int:
	return int(modules.drill)

func drone_capacity() -> int:
	return 12 + 4 * (int(modules.drone) - 1)

func drone_range_metres() -> float:
	return 15.0 + 5.0 * (int(modules.drone) - 1)

func upgrade_blocker(id: String) -> String:
	return "Richiede un laboratorio operativo" if id in ["drill", "drone"] and not lab_research_unlocked else ""

func route_cost(planet: Resource) -> float:
	return ceilf(planet.route_fuel * (1.0 - 0.12 * (int(modules.engine) - 1)))

func flight_blocker(planet: Resource) -> String:
	if hull < 20:
		return "Scafo critico: riparazione necessaria"
	if fuel < route_cost(planet) + 6:
		return "Carburante insufficiente (inclusa riserva decollo)"
	if energy < 7:
		return "Energia insufficiente"
	return ""

func can_afford(cost: Dictionary) -> bool:
	for id: String in cost:
		if id not in RESOURCE_IDS or not cost[id] is int or int(cost[id]) < 0 or int(resources.get(id, 0)) < int(cost[id]):
			return false
	return true

func _pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for id: String in cost:
		resources[id] = int(resources.get(id, 0)) - int(cost[id])
	return true

func upgrade_cost(id: String) -> Dictionary:
	var definition := Modules.find(id)
	if definition == null or int(modules[id]) >= definition.max_level:
		return {}
	var cost := {}
	for resource_id: String in definition.base_cost:
		cost[resource_id] = int(definition.base_cost[resource_id]) * int(modules[id])
	return cost

func upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if not upgrade_blocker(id).is_empty() or cost.is_empty() or not _pay(cost):
		return false
	modules[id] = int(modules[id]) + 1
	field_cargo.drone_capacity = drone_capacity()
	if id == "drill":
		for tool: Resource in Tools.all():
			if tool.required_level <= drill_power() and tool.tool_id not in tool_slots:
				var empty := tool_slots.find("")
				if empty >= 0:
					tool_slots[empty] = tool.tool_id
	return true

func repair() -> bool:
	if hull >= hull_capacity() or not _pay({"stone": 2, "copper": 1}):
		return false
	hull = minf(hull_capacity(), hull + 25)
	return true

func refuel() -> bool:
	if fuel >= fuel_capacity() or not _pay({"soil": 2}):
		return false
	fuel = minf(fuel_capacity(), fuel + 20)
	return true

func recharge() -> bool:
	if energy >= energy_capacity():
		return false
	energy = minf(energy_capacity(), energy + 15)
	return true

func snapshot() -> Dictionary:
	return {"modules": modules.duplicate(), "resources": resources.duplicate(), "seed_bank": seed_bank.duplicate(), "field_cargo": field_cargo.snapshot(), "drone_guide": drone_guide.snapshot(), "lab_research_unlocked": lab_research_unlocked, "laboratory_level": laboratory_level, "fabrication": fabrication.snapshot(), "hull": hull, "fuel": fuel, "energy": energy, "suit_integrity": suit_integrity, "crew_energy": crew_energy, "tool_slots": tool_slots.duplicate(), "active_tool_slot": active_tool_slot}

func restore(data: Dictionary) -> bool:
	# Validate completely before replacing state, including references held by inventory.
	if not data.get("modules") is Dictionary or not data.get("resources") is Dictionary:
		return false
	var next: RefCounted = get_script().new()
	if not IndustryCatalog.seeds_valid(data.get("seed_bank", IndustryCatalog.initial_seeds())):
		return false
	if data.has("seed_bank"):
		for crop: String in IndustryCatalog.CROP_IDS:
			next.seed_bank[crop] = int(data.seed_bank.get(crop, 0))
	if not _integer(data.get("laboratory_level", 1), 1, 3) or not next.fabrication.restore(data.get("fabrication", {})) or not next.fabrication.valid_ship():
		return false
	next.laboratory_level = int(data.get("laboratory_level", 1))
	for definition: Resource in Modules.all():
		var level = data.modules.get(definition.module_id, 1 if definition.module_id == "drone" else null)
		if not _integer(level, 1, definition.max_level):
			return false
		next.modules[definition.module_id] = int(level)
	for id: String in RESOURCE_IDS:
		var amount = data.resources.get(id, 0)
		if not _integer(amount, 0, next.cargo_capacity()):
			return false
		next.resources[id] = int(amount)
	if next.cargo_used() > next.cargo_capacity():
		return false
	next.field_cargo.drone_capacity = next.drone_capacity()
	if not next.field_cargo.restore(data.get("field_cargo", {"backpack": {}, "drone": {}})) or not data.get("lab_research_unlocked", false) is bool:
		return false
	if not next.drone_guide.restore(data.get("drone_guide", {})):
		return false
	var slots = data.get("tool_slots", ["pulse", "scanner", "", ""])
	if not slots is Array or slots.size() != Tools.SLOT_COUNT:
		return false
	var seen: Array = []
	for id in slots:
		if not id is String:
			return false
		if id.is_empty():
			continue
		var tool := Tools.find(id)
		if tool == null or tool.required_level > next.drill_power() or id in seen:
			return false
		seen.append(id)
	if seen.is_empty() or not _integer(data.get("active_tool_slot", 0), 0, Tools.SLOT_COUNT - 1):
		return false
	var active := int(data.get("active_tool_slot", 0))
	if str(slots[active]).is_empty():
		return false
	for stat: String in ["hull", "fuel", "energy", "suit_integrity", "crew_energy"]:
		var value = data.get(stat, 100 if stat in ["suit_integrity", "crew_energy"] else null)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0:
			return false
		var maximum: float = 100 if stat in ["suit_integrity", "crew_energy"] else (next.hull_capacity() if stat == "hull" else (next.fuel_capacity() if stat == "fuel" else next.energy_capacity()))
		if float(value) > maximum:
			return false
	modules = next.modules.duplicate()
	resources.clear()
	resources.merge(next.resources)
	field_cargo.drone_capacity = next.drone_capacity()
	field_cargo.restore(next.field_cargo.snapshot())
	drone_guide.restore(next.drone_guide.snapshot())
	lab_research_unlocked = data.get("lab_research_unlocked", false)
	laboratory_level = next.laboratory_level
	seed_bank.clear()
	seed_bank.merge(next.seed_bank)
	fabrication.restore(next.fabrication.snapshot())
	hull = float(data.hull)
	fuel = float(data.fuel)
	energy = float(data.energy)
	suit_integrity = float(data.get("suit_integrity", 100))
	crew_energy = float(data.get("crew_energy", 100))
	tool_slots.assign(slots)
	active_tool_slot = active
	return true

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum
