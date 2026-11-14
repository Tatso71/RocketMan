extends GdUnitTestSuite

const MAP_PATH := "res://design/generated/production-map.json"
const Components = preload("res://scripts/data/component_catalog.gd")
const Industry = preload("res://scripts/data/industry_catalog.gd")

func test_map_includes_early_solar_assembly_and_shared_battery_generation() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	assert_bool(data.nodes.has("solar_panel")).is_true()
	var assembly: Array = data.recipes.filter(func(entry): return entry.id == "assemble_solar_panel")
	assert_int(assembly.size()).is_equal(1)
	if assembly.is_empty(): return
	assert_dict(assembly[0].inputs).is_equal({"structural_component": 2.0, "electronic_component": 1.0})
	assert_str(assembly[0].icon).is_equal("assets/ui/items/solar_panel.svg")
	assert_bool(assembly[0].available_before_first_lab).is_true()
	assert_bool(data.has("solar_generation")).is_true()
	if not data.has("solar_generation"): return
	assert_dict(data.solar_generation).is_equal({
		"available_before_first_lab": true, "footprint_metres": [2.0, 1.0],
		"placement": "outdoor_supported", "kwh_per_second_per_panel": 0.1,
		"cable": "automatic_free_unlimited_to_ship", "additive": true,
		"storage": "shared_ship_battery_capped", "night_cycle": false
	})
	var generation: Array = data.recipes.filter(func(entry): return entry.id == "generate_solar_energy")
	assert_int(generation.size()).is_equal(1)
	if generation.is_empty(): return
	assert_dict(generation[0].inputs).is_empty()
	assert_dict(generation[0].outputs).is_equal({"ship_energy": 6.0})
	assert_float(float(generation[0].seconds)).is_equal(60.0)
	assert_dict(generation[0].energy).is_empty()
	var emergency: Dictionary = data.recipes.filter(func(entry): return entry.id == "recharge_ship")[0]
	assert_dict(emergency.inputs).is_empty()
	assert_dict(emergency.outputs).is_equal({"ship_energy": 15.0})
	assert_bool("assemble_solar_panel" in data.used_by.structural_component).is_true()
	assert_bool("assemble_solar_panel" in data.used_by.electronic_component).is_true()

func test_map_documents_the_raw_mining_distribution() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	assert_bool(data.has("raw_extraction")).is_true()
	if not data.has("raw_extraction"): return
	assert_dict(data.raw_extraction.pieces_percent).is_equal({"1": 65.0, "2": 25.0, "3": 10.0})
	assert_bool(data.raw_extraction.common_rock_cargo).is_false()

func test_production_map_contains_current_component_recipes() -> void:
	assert_bool(FileAccess.file_exists(MAP_PATH)).is_true()
	if not FileAccess.file_exists(MAP_PATH):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	for id: String in Components.RECIPE_IDS:
		var matches: Array = data.recipes.filter(func(recipe): return recipe.id == "fabricate_" + id)
		assert_int(matches.size()).is_equal(1)
		assert_dict(matches[0].inputs).is_equal(JSON.parse_string(JSON.stringify(Components.recipe(id).cost)))
		assert_int(int(matches[0].outputs[Components.recipe(id).output])).is_equal(Components.recipe(id).amount)

func test_map_has_resolvable_unique_ids_and_no_historical_cube_economy() -> void:
	if not FileAccess.file_exists(MAP_PATH):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	var ids := {}
	for recipe: Dictionary in data.recipes:
		assert_bool(ids.has(recipe.id)).is_false()
		ids[recipe.id] = true
		for id: String in recipe.inputs.keys() + recipe.outputs.keys() + recipe.energy.keys():
			assert_bool(data.nodes.has(id)).is_true()
	assert_bool(data.nodes.has("soil") or data.nodes.has("stone") or data.nodes.has("lab_cube")).is_false()
	assert_bool(data.recipes.any(func(recipe): return recipe.id == "craft_scanner")).is_false()
	assert_bool(data.planned.any(func(item): return item.id == "onboard_encyclopedia")).is_true()

func test_reverse_index_and_advanced_processing_match_actual_catalogs() -> void:
	if not FileAccess.file_exists(MAP_PATH):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	assert_bool("fabricate_structural_alloy" in data.used_by.cobalt).is_true()
	for id: String in Industry.load_data().smelting:
		var entry: Dictionary = data.recipes.filter(func(recipe): return recipe.id == "smelt_" + id)[0]
		assert_dict(entry.inputs).is_equal(JSON.parse_string(JSON.stringify(Industry.load_data().smelting[id].cost)))
