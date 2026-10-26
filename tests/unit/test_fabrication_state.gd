extends GdUnitTestSuite

const Factory = preload("res://scripts/systems/fabrication_state.gd")
const Ship = preload("res://scripts/systems/ship_state.gd")

func test_new_ship_starts_without_resources() -> void:
	assert_int(Ship.new().cargo_used()).is_equal(0)

func test_paid_jobs_and_carried_cubes_roundtrip_native_and_json() -> void:
	var state := Factory.new()
	state.jobs.append({"id": "laboratory", "level": 1, "station": ["ship"], "elapsed": 2.5, "seconds": 5.0})
	var cube := state.add_cube(Vector2(-60, -80))
	state.carried_id = cube.uid
	var loaded := Factory.new()
	assert_bool(loaded.restore(state.snapshot())).is_true()
	assert_bool(loaded.restore(JSON.parse_string(JSON.stringify(state.snapshot())))).is_true()
	assert_float(loaded.jobs[0].elapsed).is_equal(2.5)
	assert_int(loaded.carried_id).is_equal(cube.uid)
	assert_vector(loaded.carried().position).is_equal(Vector2(-60, -80))

func test_invalid_jobs_and_duplicate_output_slots_are_atomic() -> void:
	var state := Factory.new()
	state.add_cube(Vector2(-80, -80), ["ship"])
	var original := state.snapshot()
	var bad := original.duplicate(true)
	bad.jobs = [{"id": "laboratory", "level": 1, "station": ["ship"], "elapsed": 0.0, "seconds": 5.0}]
	assert_bool(state.restore(bad)).is_false()
	assert_dict(state.snapshot()).is_equal(original)
	bad = original.duplicate(true)
	bad.carried_id = 999
	assert_bool(state.restore(bad)).is_false()
	bad = original.duplicate(true)
	bad.cubes[0].position[0] = INF
	assert_bool(state.restore(bad)).is_false()
	bad = original.duplicate(true)
	bad.cubes.append(bad.cubes[0].duplicate(true))
	assert_bool(state.restore(bad)).is_false()
	assert_dict(state.snapshot()).is_equal(original)

func test_import_reassigns_ids_without_losing_carried_cube() -> void:
	var destination := Factory.new()
	destination.add_cube(Vector2(-100, 120))
	var ship := Factory.new()
	var cube := ship.add_cube(Vector2(0, -80))
	ship.carried_id = cube.uid
	destination.import_state(ship)
	assert_int(destination.cubes.size()).is_equal(2)
	assert_int(destination.carried_id).is_equal(2)
	assert_vector(destination.carried().position).is_equal(Vector2(0, -80))

func test_ship_does_not_accept_a_planet_factory_and_invalid_job_times_are_rejected() -> void:
	var factory := Factory.new()
	factory.jobs.append({"id": "laboratory", "level": 1, "station": ["laboratory", -5, 1], "elapsed": 0.0, "seconds": 5.0})
	assert_bool(factory.valid_ship()).is_false()
	var before := factory.snapshot()
	for value in [-1.0, 5.0, INF]:
		var bad := before.duplicate(true)
		bad.jobs[0].elapsed = value
		assert_bool(factory.restore(bad)).is_false()
		assert_dict(factory.snapshot()).is_equal(before)

func test_ship_factory_and_laboratory_level_persist_and_legacy_defaults_are_empty() -> void:
	var ship := Ship.new()
	ship.laboratory_level = 3
	ship.fabrication.add_cube(Vector2(-80, -80), ["ship"])
	var loaded := Ship.new()
	assert_bool(loaded.restore(JSON.parse_string(JSON.stringify(ship.snapshot())))).is_true()
	assert_int(loaded.laboratory_level).is_equal(3)
	assert_int(loaded.fabrication.cubes.size()).is_equal(1)
	var legacy := ship.snapshot()
	legacy.erase("fabrication")
	legacy.erase("laboratory_level")
	assert_bool(loaded.restore(legacy)).is_true()
	assert_int(loaded.laboratory_level).is_equal(1)
	assert_array(loaded.fabrication.cubes).is_empty()

func test_all_device_jobs_cubes_and_carried_type_survive_json_and_ship_import() -> void:
	for id: String in ["lamp", "pump", "fan"]:
		var state := Factory.new()
		state.jobs.append({"id": id, "level": 1, "station": ["ship"], "elapsed": 0.5, "seconds": 2.0})
		var cube := state.add_cube(Vector2(-60, -80), [], id)
		state.carried_id = cube.uid
		var loaded := Factory.new()
		assert_bool(loaded.restore(JSON.parse_string(JSON.stringify(state.snapshot())))).is_true()
		assert_str(loaded.jobs[0].id).is_equal(id)
		assert_str(loaded.carried().id).is_equal(id)
		assert_bool(loaded.valid_ship()).is_true()
		var destination := Factory.new()
		destination.add_cube(Vector2(-100, 120))
		destination.import_state(loaded)
		assert_str(destination.carried().id).is_equal(id)
		assert_str(destination.jobs[0].id).is_equal(id)

func test_unknown_device_types_are_rejected_without_mutating_factory() -> void:
	var state := Factory.new()
	state.add_cube(Vector2(-80, -80))
	var before := state.snapshot()
	var bad := before.duplicate(true)
	bad.cubes[0].id = "unknown_device"
	assert_bool(state.restore(bad)).is_false()
	assert_dict(state.snapshot()).is_equal(before)
	assert_dict(state.add_cube(Vector2.ZERO, [], "unknown_device")).is_empty()
	assert_dict(state.snapshot()).is_equal(before)
