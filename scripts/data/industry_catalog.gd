extends RefCounted

const PATH := "res://design/v1/prototype_industry.json"
const MACHINE_IDS := ["furnace", "gas_converter", "greenhouse"]
const CROP_IDS := ["potato", "ochre_tuber", "verdant_leaf", "frost_berry"]
const FOOD_NAMES := {"copper_ingot": "Lingotto rame", "glass": "Vetro", "potato": "Patata", "ochre_tuber": "Tubero ocra", "verdant_leaf": "Verdura viridia", "frost_berry": "Bacca brina"}
const ITEM_COLORS := {"copper_ingot": Color("e8a76c"), "glass": Color("a0dce4"), "potato": Color("e6d28b"), "ochre_tuber": Color("e4a57f"), "verdant_leaf": Color("a8db86"), "frost_berry": Color("c7acf0")}
static var cached: Dictionary = {}

static func positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value) and value > 0

static func cost_valid(cost: Variant) -> bool:
	if not cost is Dictionary or cost.is_empty():
		return false
	for id in cost:
		if id not in ["soil", "stone", "copper", "copper_ingot", "glass"] or not positive(cost[id]) or cost[id] != floorf(cost[id]) or cost[id] > 120:
			return false
	return true

static func validate(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("version") != 1:
		return {}
	for key: String in ["recipes", "smelting", "crops", "converter"]:
		if not data.get(key) is Dictionary:
			return {}
	if data.recipes.size() != MACHINE_IDS.size() or data.crops.size() != CROP_IDS.size() or data.smelting.size() != 2:
		return {}
	for id: String in MACHINE_IDS:
		var recipe = data.recipes.get(id)
		if not recipe is Dictionary or not recipe.get("name_it") is String or not cost_valid(recipe.get("cost")):
			return {}
		for key: String in ["seconds", "energy", "deployment_seconds"]:
			if not positive(recipe.get(key)):
				return {}
	for id: String in ["copper_ingot", "glass"]:
		var recipe = data.smelting.get(id)
		if not recipe is Dictionary or not recipe.get("name_it") is String or not cost_valid(recipe.get("cost")) or not positive(recipe.get("seconds")) or not positive(recipe.get("power")):
			return {}
	for id: String in CROP_IDS:
		var crop = data.crops.get(id)
		if not crop is Dictionary or not crop.get("name_it") is String or crop.get("food") != id:
			return {}
		for key: String in ["seconds", "water", "power", "yield", "seeds"]:
			if not positive(crop.get(key)):
				return {}
		for key: String in ["yield", "seeds"]:
			if crop[key] != floorf(crop[key]) or crop[key] > 20:
				return {}
	for key: String in ["gas_per_second", "kwh_per_gas", "capacity"]:
		if not positive(data.converter.get(key)):
			return {}
	return data.duplicate(true) if positive(data.get("pump_capacity")) and cost_valid(data.get("conduit_cost")) else {}

static func load_data() -> Dictionary:
	if cached.is_empty():
		cached = validate(JSON.parse_string(FileAccess.get_file_as_string(PATH)))
		if cached.is_empty():
			push_error("Catalogo industria non valido: " + PATH)
		else:
			for recipe: Dictionary in cached.recipes.values() + cached.smelting.values():
				for id: String in recipe.cost:
					recipe.cost[id] = int(recipe.cost[id])
			for id: String in cached.conduit_cost:
				cached.conduit_cost[id] = int(cached.conduit_cost[id])
	return cached

static func initial_seeds() -> Dictionary:
	return {"potato": 3, "ochre_tuber": 0, "verdant_leaf": 0, "frost_berry": 0}

static func seeds_valid(data: Variant) -> bool:
	if not data is Dictionary or data.keys().any(func(id): return id not in CROP_IDS):
		return false
	for value in data.values():
		if not (value is int or value is float) or not is_finite(value) or value != floorf(value) or value < 0 or value > 999:
			return false
	return true

static func seed_sites(seed_value: int) -> Array:
	var crop: String = {0: "ochre_tuber", 11: "verdant_leaf", 23: "frost_berry"}.get(seed_value, "ochre_tuber")
	return [{"id": "pod_west", "cell": Vector2i(-10, 8), "crop": crop}, {"id": "pod_east", "cell": Vector2i(6, 9), "crop": crop}]
