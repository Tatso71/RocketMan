extends GdUnitTestSuite

const Tutorial = preload("res://scripts/systems/ocra_tutorial.gd")
const Catalog = preload("res://scripts/data/ocra_catalog.gd")
const Guide = preload("res://scripts/systems/drone_guide_state.gd")

func payload() -> Dictionary:
	var data := {}
	for name: String in ["manifest", "progression", "recipes", "modules"]:
		data[name] = JSON.parse_string(FileAccess.get_file_as_string("res://design/v1/" + name + ".json"))
	return data

func test_loader_rejects_invalid_versions_ids_quantities_and_conditions() -> void:
	var data := payload()
	data.manifest.schema_version = "2.0.0"
	assert_bool(Catalog.validate(data).is_empty()).is_true()
	data = payload()
	data.progression.ocra_tutorial.steps[1].id = data.progression.ocra_tutorial.steps[0].id
	assert_bool(Catalog.validate(data).is_empty()).is_true()
	data = payload()
	data.progression.ocra_tutorial.steps[0].complete_when = {"counter": "mine", "at_least": 1.5}
	assert_bool(Catalog.validate(data).is_empty()).is_true()
	data = payload()
	for recipe: Dictionary in data.recipes:
		if recipe.id == "recipe_cube_lab":
			recipe.inputs = {"res_missing": 6}
	assert_bool(Catalog.validate(data).is_empty()).is_true()
	data = payload()
	for module: Dictionary in data.modules:
		if module.id == "mod_lab":
			module.packed_inventory_units = 4.5
	assert_bool(Catalog.validate(data).is_empty()).is_true()

func test_catalog_loads_the_authored_tasks_and_laboratory_recipe() -> void:
	var data := Catalog.load_data()
	assert_bool(data.is_empty()).is_false()
	if data.is_empty():
		return
	assert_int(data.tutorial.steps.size()).is_equal(9)
	assert_int(data.laboratory.cost.stone).is_equal(6)
	assert_int(data.laboratory.cost.copper).is_equal(4)
	assert_float(data.laboratory.seconds).is_equal(5.0)

func test_task_order_uses_real_events_and_unique_mined_cells() -> void:
	var tutorial := Tutorial.new()
	assert_str(tutorial.current().id).is_equal("reach_workshop")
	tutorial.record("workshop_entered")
	assert_str(tutorial.current().id).is_equal("open_hatch")
	tutorial.record("hatch_opened")
	tutorial.record("mined")
	assert_str(tutorial.current().id).is_equal("first_excavation")
	tutorial.record("mined")
	assert_str(tutorial.current().id).is_equal("return_ladder")
	tutorial.record("ladder")
	assert_str(tutorial.current().id).is_equal("laboratory_materials")
	tutorial.record("lab_materials_ready")
	assert_str(tutorial.current().id).is_equal("laboratory_room")
	tutorial.record("lab_room_ready")
	assert_str(tutorial.current().id).is_equal("laboratory_cube")
	tutorial.record("lab_cube_crafted")
	assert_str(tutorial.current().id).is_equal("carry_laboratory")
	tutorial.record("lab_cube_carried")
	assert_str(tutorial.current().id).is_equal("deploy_laboratory")
	tutorial.record("lab_built")
	assert_bool(tutorial.complete()).is_true()
	assert_bool(tutorial.current().is_empty()).is_true()

func test_tasks_can_be_added_in_data_without_new_guide_code() -> void:
	var definition: Dictionary = Catalog.load_data().tutorial.duplicate(true)
	definition.steps.push_front({"id": "inspect_bed", "title_it": "Controlla il letto", "hint_it": "Clic destro sul letto.", "detail_it": "Piano centrale", "action": "help", "complete_when": {"fact": "bed_inspected"}})
	var tutorial := Tutorial.new(definition)
	assert_str(tutorial.current().id).is_equal("inspect_bed")
	assert_str(tutorial.message("ocra/inspect_bed")[2]).is_equal("Clic destro sul letto.")
	tutorial.record("bed_inspected")
	assert_str(tutorial.current().id).is_equal("reach_workshop")

func test_generic_event_counters_do_not_count_observations_or_restore() -> void:
	var definition: Dictionary = Catalog.load_data().tutorial.duplicate(true)
	definition.steps.push_front({"id": "two_ladders", "title_it": "Due scale", "hint_it": "Costruisci due scale.", "detail_it": "2 scale", "action": "help", "complete_when": {"counter": "ladder", "at_least": 2}})
	var tutorial := Tutorial.new(definition)
	tutorial.mark("ladder")
	tutorial.mark("ladder")
	assert_str(tutorial.current().id).is_equal("two_ladders")
	tutorial.record("ladder")
	assert_str(tutorial.current().id).is_equal("two_ladders")
	assert_bool(tutorial.restore(tutorial.snapshot())).is_true()
	assert_int(tutorial.counters.ladder).is_equal(1)
	tutorial.record("ladder")
	assert_str(tutorial.current().id).is_equal("reach_workshop")

func test_completion_in_any_order_and_json_progress_do_not_reset_tasks() -> void:
	var tutorial := Tutorial.new()
	tutorial.record("lab_cube_crafted")
	tutorial.record("mined")
	var restored := Tutorial.new()
	assert_bool(restored.restore(JSON.parse_string(JSON.stringify(tutorial.snapshot())))).is_true()
	assert_int(restored.counters.mined_cells).is_equal(1)
	assert_bool(restored.facts.lab_cube_crafted).is_true()
	assert_str(restored.current().id).is_equal("reach_workshop")
	restored.record("lab_built")
	assert_bool(restored.complete()).is_true()

func test_invalid_progress_is_rejected_without_live_mutation() -> void:
	var tutorial := Tutorial.new()
	tutorial.record("workshop_entered")
	var before := tutorial.snapshot()
	assert_bool(tutorial.restore({"version": 1, "facts": {"new": true}, "counters": {"mined_cells": -1}})).is_false()
	assert_dict(tutorial.snapshot()).is_equal(before)

func test_native_snapshots_accept_godot_string_name_dictionary_keys() -> void:
	var tutorial := Tutorial.new()
	tutorial.record("mined")
	tutorial.counters.mined_cells = 4
	tutorial.facts.workshop_entered = true
	var restored := Tutorial.new()
	assert_bool(restored.restore(tutorial.snapshot())).is_true()
	assert_int(restored.counters.mined_cells).is_equal(4)
	assert_str(restored.current().id).is_equal("open_hatch")
	restored.record("mined")
	assert_int(restored.counters.mined_cells).is_equal(5)

func test_ocra_balloon_repeats_but_danger_preempts_it() -> void:
	var guide := Guide.new()
	guide.gap = 0
	assert_bool(guide.offer("ocra/reach_workshop")).is_true()
	assert_bool(guide.offer("water_danger")).is_true()
	guide.ocra.record("workshop_entered")
	guide.tick(30, "ocra/open_hatch")
	guide.tick(3, "ocra/open_hatch")
	assert_bool(guide.offer("ocra/open_hatch")).is_true()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(guide.snapshot()))
	assert_bool(guide.restore(saved)).is_true()
	assert_str(guide.ocra.current().id).is_equal("open_hatch")
