extends RefCounted

const PATH := "res://design/v1/prototype_components.json"
const COMPONENT_IDS := ["structural_component", "electronic_component"]
const RECIPE_IDS := ["structural_component", "electronic_component", "refined_electronics", "structural_alloy", "bomb"]
const STRUCTURE_IDS := ["laboratory", "solar_panel", "lamp", "pump", "fan", "furnace", "gas_converter", "greenhouse", "water_tank"]
const INGREDIENT_IDS := ["copper", "iron", "crystal", "silica", "cobalt", "copper_ingot", "glass", "structural_component", "electronic_component"]
static var cached: Dictionary = {}

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum

static func valid_cost(value: Variant, allowed: Array = INGREDIENT_IDS) -> bool:
	if not value is Dictionary or value.is_empty():
		return false
	for id in value:
		if id not in allowed or not integer(value[id], 1, 120):
			return false
	return true

static func validate(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("version") != 2 or data.get("stack_size") != 4:
		return {}
	if not data.get("recipes") is Dictionary or data.recipes.size() != RECIPE_IDS.size() or not data.get("assembly") is Dictionary or data.assembly.size() != STRUCTURE_IDS.size():
		return {}
	var result: Dictionary = data.duplicate(true)
	for id: String in RECIPE_IDS:
		var entry = result.recipes.get(id)
		if not entry is Dictionary or not entry.get("name_it") is String or entry.name_it.is_empty() or not valid_cost(entry.get("cost")) or entry.get("output") not in COMPONENT_IDS + ["bomb"] or not integer(entry.get("amount"), 1, 20) or not entry.get("advanced") is bool:
			return {}
		for key: String in ["seconds", "energy"]:
			if not (entry.get(key) is int or entry.get(key) is float) or not is_finite(float(entry[key])) or entry[key] <= 0 or entry[key] > 120:
				return {}
		entry.amount = int(entry.amount)
		for ingredient: String in entry.cost:
			entry.cost[ingredient] = int(entry.cost[ingredient])
	for id: String in STRUCTURE_IDS:
		if not valid_cost(result.assembly.get(id), COMPONENT_IDS):
			return {}
		for ingredient: String in result.assembly[id]:
			result.assembly[id][ingredient] = int(result.assembly[id][ingredient])
	return result

static func load_data() -> Dictionary:
	if cached.is_empty():
		cached = validate(JSON.parse_string(FileAccess.get_file_as_string(PATH)))
		if cached.is_empty():
			push_error("Catalogo componenti non valido")
	return cached

static func recipe(id: String) -> Dictionary:
	return load_data().get("recipes", {}).get(id, {}).duplicate(true)

static func assembly_cost(id: String) -> Dictionary:
	return load_data().get("assembly", {}).get(id, {}).duplicate()
