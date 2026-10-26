extends RefCounted

const ROOT := "res://design/v1/"
const RESOURCE_ALIASES := {"res_soil": "soil", "res_stone": "stone", "res_copper": "copper"}
const DEVICE_MODULES := {"lamp": "mod_light", "pump": "mod_pump", "fan": "mod_gas_filter"}
const ACTIONS := ["help", "fabricate_lab", "place_lab", "inventory"]
static var cached: Dictionary = {}
static var loaded := false

static func load_data() -> Dictionary:
	if loaded:
		return cached
	loaded = true
	var payload := {}
	for name: String in ["manifest", "progression", "recipes", "modules"]:
		payload[name] = JSON.parse_string(FileAccess.get_file_as_string(ROOT + name + ".json"))
	cached = validate(payload)
	if cached.is_empty():
		push_error("Catalogo tutorial di Ocra non valido: controlla design/v1")
	else:
		var industry := preload("res://scripts/data/industry_catalog.gd").load_data()
		cached.fabrication.merge(industry.get("recipes", {}).duplicate(true))
		for definition: Dictionary in cached.fabrication.values():
			for id: String in definition.cost:
				definition.cost[id] = int(definition.cost[id])
	return cached

static func condition_valid(condition: Variant) -> bool:
	if not condition is Dictionary:
		return false
	if condition.size() == 1 and condition.get("fact") is String:
		return not condition.fact.is_empty()
	return condition.size() == 2 and condition.get("counter") is String and not condition.counter.is_empty() and integer(condition.get("at_least"), 1, 100000)

static func validate(payload: Dictionary) -> Dictionary:
	if not payload.get("manifest") is Dictionary or payload.manifest.get("schema_version") != "1.0.0" or not payload.get("progression") is Dictionary or not payload.get("recipes") is Array or not payload.get("modules") is Array:
		return {}
	var tutorial = payload.progression.get("ocra_tutorial")
	if not tutorial is Dictionary or tutorial.get("version") != 1 or tutorial.get("planet") != "planet_ocra" or not condition_valid(tutorial.get("finish_when")) or not tutorial.get("steps") is Array or tutorial.steps.is_empty():
		return {}
	var ids: Array = []
	for step in tutorial.steps:
		if not step is Dictionary or not step.get("id") is String or step.id.is_empty() or step.id in ids or not condition_valid(step.get("complete_when")) or step.get("action") not in ACTIONS:
			return {}
		for key: String in ["title_it", "hint_it", "detail_it"]:
			if not step.get(key) is String or step[key].is_empty():
				return {}
		ids.append(step.id)
	var recipes: Array = payload.recipes.filter(func(item): return item is Dictionary and item.get("id") == "recipe_cube_lab")
	var modules: Array = payload.modules.filter(func(item): return item is Dictionary and item.get("id") == "mod_lab")
	if recipes.size() != 1 or modules.size() != 1:
		return {}
	var recipe: Dictionary = recipes[0]
	var module: Dictionary = modules[0]
	if recipe.get("station") != "mod_workshop" or recipe.get("research") != "tech_start" or not recipe.get("outputs") is Dictionary or recipe.outputs.size() != 1 or not integer(recipe.outputs.get("mod_lab"), 1, 1) or not recipe.get("inputs") is Dictionary or recipe.inputs.is_empty():
		return {}
	var cost := {}
	for id in recipe.inputs:
		if not RESOURCE_ALIASES.has(id) or not integer(recipe.inputs[id], 1, 120):
			return {}
		cost[RESOURCE_ALIASES[id]] = int(recipe.inputs[id])
	var footprint = module.get("footprint_cells")
	if module.get("kind") != "unfolding_cube" or not footprint is Array or footprint.size() != 2 or not integer(footprint[0], 4, 4) or not integer(footprint[1], 3, 3) or not integer(module.get("packed_inventory_units"), 4, 4):
		return {}
	for value in [recipe.get("seconds"), module.get("deployment_seconds")]:
		if not number(value) or value <= 0 or value > 120:
			return {}
	if not number(recipe.get("energy_kwh")) or recipe.energy_kwh < 0 or recipe.energy_kwh > 60:
		return {}
	var lab := {"name_it": "Laboratorio", "cost": cost, "seconds": float(recipe.seconds), "energy": float(recipe.energy_kwh), "deployment_seconds": float(module.deployment_seconds), "packed_units": 4}
	var fabrication := {"laboratory": lab}
	var devices = payload.progression.get("prototype_fabrication")
	if not devices is Dictionary or devices.get("version") != 1 or devices.get("unlock_after") != "first_completed_laboratory" or not devices.get("recipes") is Array or devices.recipes.size() != DEVICE_MODULES.size():
		return {}
	for entry in devices.recipes:
		if not entry is Dictionary or not DEVICE_MODULES.has(entry.get("id")) or fabrication.has(entry.id) or entry.get("module") != DEVICE_MODULES[entry.id] or not entry.get("name_it") is String or entry.name_it.is_empty() or not entry.get("inputs") is Dictionary or entry.inputs.is_empty():
			return {}
		if payload.modules.filter(func(item): return item is Dictionary and item.get("id") == entry.module).size() != 1:
			return {}
		var device_cost := {}
		for id in entry.inputs:
			if not RESOURCE_ALIASES.has(id) or not integer(entry.inputs[id], 1, 120):
				return {}
			device_cost[RESOURCE_ALIASES[id]] = int(entry.inputs[id])
		for value in [entry.get("seconds"), entry.get("deployment_seconds")]:
			if not number(value) or value <= 0 or value > 120:
				return {}
		if not number(entry.get("energy_kwh")) or entry.energy_kwh < 0 or entry.energy_kwh > 60:
			return {}
		fabrication[entry.id] = {"name_it": entry.name_it, "cost": device_cost, "seconds": float(entry.seconds), "energy": float(entry.energy_kwh), "deployment_seconds": float(entry.deployment_seconds)}
	return {"tutorial": tutorial.duplicate(true), "laboratory": lab, "fabrication": fabrication}

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return number(value) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum
