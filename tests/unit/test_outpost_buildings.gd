extends GdUnitTestSuite

const Site = preload("res://scripts/systems/dig_site.gd")
const Field = preload("res://scripts/systems/environment_field.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")

func _room(site: RefCounted) -> void:
	for y in range(1, 4):
		for x in range(-5, -1):
			site.removed[Vector2i(x, y)] = true

func test_lab_requires_excavation_and_full_four_metre_floor() -> void:
	var site := Site.new()
	var field := Field.new(site)
	var buildings := Buildings.new()
	assert_str(buildings.blocker("laboratory", Vector2i(-5, 1), site, field)).is_not_empty()
	_room(site)
	assert_str(buildings.blocker("laboratory", Vector2i(-5, 1), site, field)).is_empty()
	site.removed[Vector2i(-4, 4)] = true
	assert_str(buildings.blocker("laboratory", Vector2i(-5, 1), site, field)).contains("pavimento")

func test_fluid_and_overlapping_structures_block_placement() -> void:
	var site := Site.new()
	_room(site)
	var field := Field.new(site)
	var buildings := Buildings.new()
	field.water[Vector2i(-5, 3)] = 0.5
	assert_str(buildings.blocker("laboratory", Vector2i(-5, 1), site, field)).contains("sicura")
	field.water.erase(Vector2i(-5, 3))
	buildings.install("laboratory", Vector2i(-5, 1))
	assert_str(buildings.blocker("laboratory", Vector2i(-5, 1), site, field)).contains("occupato")

func test_structure_and_local_cache_survive_json_roundtrip() -> void:
	var site := Site.new()
	_room(site)
	var buildings := Buildings.new()
	var lab := buildings.install("laboratory", Vector2i(-5, 1))
	lab.stock.soil = 12
	var data: Array = JSON.parse_string(JSON.stringify(buildings.snapshot()))
	var restored := Buildings.new()
	assert_bool(restored.restore(data, site)).is_true()
	assert_int(int(restored.structures[0].stock.soil)).is_equal(12)
	data[0].stock.soil = 33
	assert_bool(restored.restore(data, site)).is_false()
	assert_int(int(restored.structures[0].stock.soil)).is_equal(12)

func test_lab_upgrade_limits_and_effects() -> void:
	var lab := {"level": 1}
	assert_int(Buildings.cache_capacity(lab)).is_equal(32)
	assert_float(Buildings.light_range(lab)).is_equal(8.0)
	assert_dict(Buildings.upgrade_cost(lab)).is_equal({"stone": 4, "copper": 3})
	lab.level = 2
	assert_int(Buildings.cache_capacity(lab)).is_equal(48)
	assert_float(Buildings.light_range(lab)).is_equal(10.0)
	lab.level = 3
	assert_int(Buildings.cache_capacity(lab)).is_equal(64)
	assert_dict(Buildings.upgrade_cost(lab)).is_empty()

func test_upgraded_cache_and_level_survive_json_and_reject_invalid_levels() -> void:
	var site := Site.new()
	_room(site)
	var buildings := Buildings.new()
	var lab := buildings.install("laboratory", Vector2i(-5, 1))
	lab.level = 2
	lab.stock.soil = 45
	var data: Array = JSON.parse_string(JSON.stringify(buildings.snapshot()))
	var restored := Buildings.new()
	assert_bool(restored.restore(data, site)).is_true()
	assert_int(int(restored.labs()[0].level)).is_equal(2)
	assert_int(int(restored.labs()[0].stock.soil)).is_equal(45)
	for invalid in [0, 4, 1.5, "2", true]:
		data[0].level = invalid
		assert_bool(restored.restore(data, site)).is_false()
		assert_int(int(restored.labs()[0].level)).is_equal(2)

func test_legacy_laboratories_default_to_level_one() -> void:
	var site := Site.new()
	_room(site)
	var buildings := Buildings.new()
	assert_bool(buildings.restore([{"id": "laboratory", "origin": [-5, 1], "stock": {}}], site)).is_true()
	assert_int(int(buildings.labs()[0].level)).is_equal(1)

func test_creator_cube_reserves_space_but_is_not_an_active_lab() -> void:
	var site := Site.new()
	_room(site)
	var buildings := Buildings.new()
	var cube := buildings.plan("laboratory", Vector2i(-5, 1))
	assert_str(cube.state).is_equal("planned")
	assert_bool(Buildings.is_active(cube)).is_false()
	assert_array(buildings.labs()).is_empty()
	assert_str(buildings.blocker("laboratory", cube.origin, site, Field.new(site))).contains("occupato")
	assert_str(buildings.blocker("laboratory", cube.origin, site, Field.new(site), cube)).is_empty()

func test_pending_and_unfolding_cubes_roundtrip_without_becoming_active() -> void:
	var site := Site.new()
	_room(site)
	var buildings := Buildings.new()
	var cube := buildings.plan("laboratory", Vector2i(-5, 1))
	var restored := Buildings.new()
	assert_bool(restored.restore(JSON.parse_string(JSON.stringify(buildings.snapshot())), site)).is_true()
	assert_str(restored.structures[0].state).is_equal("planned")
	cube.state = "building"
	cube.progress = 0.42
	assert_bool(restored.restore(JSON.parse_string(JSON.stringify(buildings.snapshot())), site)).is_true()
	assert_bool(is_equal_approx(float(restored.structures[0].progress), 0.42)).is_true()
	assert_array(restored.labs()).is_empty()

func test_invalid_cube_states_do_not_replace_live_structures() -> void:
	var site := Site.new()
	_room(site)
	var buildings := Buildings.new()
	buildings.plan("laboratory", Vector2i(-5, 1))
	for bad: Dictionary in [{"state": "wrong"}, {"progress": 0.5}, {"stock": {"stone": 1}}, {"level": 2}, {"enabled": "true"}, {"state": "building", "progress": 1.0}]:
		var data := buildings.snapshot()
		data[0].merge(bad, true)
		assert_bool(buildings.restore(data, site)).is_false()
		assert_str(buildings.structures[0].state).is_equal("planned")

func test_power_rates_and_raw_material_costs() -> void:
	assert_dict(Buildings.cost_for("laboratory")).is_equal({"stone": 6, "copper": 4})
	assert_dict(Buildings.cost_for("lamp")).is_equal({"soil": 1, "copper": 1})
	assert_float(Buildings.power_draw({"id": "laboratory", "level": 1})).is_equal(0.04)
	assert_float(Buildings.power_draw({"id": "lamp"})).is_equal(0.008)

func test_ladders_cannot_be_planned_as_creator_cubes() -> void:
	var buildings := Buildings.new()
	assert_dict(buildings.plan("ladder", Vector2i(0, 3))).is_empty()
	assert_array(buildings.structures).is_empty()
	assert_float(Buildings.build_seconds("ladder")).is_equal(0.0)

func test_legacy_ladder_cubes_preserve_paid_work_only() -> void:
	var site := Site.new()
	_room(site)
	var buildings := Buildings.new()
	var data := [{"id": "ladder", "origin": [-5, 3], "stock": {}, "state": "planned", "progress": 0.0}]
	assert_bool(buildings.restore(data, site)).is_true()
	assert_array(buildings.structures).is_empty()
	data[0].state = "building"
	data[0].progress = 0.4
	assert_bool(buildings.restore(data, site)).is_true()
	assert_str(buildings.structures[0].state).is_equal("active")
	assert_float(float(buildings.structures[0].progress)).is_equal(1.0)

func test_pump_accepts_water_where_laboratory_cannot_be_built() -> void:
	var site := Site.new()
	_room(site)
	var field := Field.new(site)
	field.water[Vector2i(-5, 3)] = 1.0
	var buildings := Buildings.new()
	assert_str(buildings.blocker("laboratory", Vector2i(-5, 1), site, field)).contains("sicura")
	assert_str(buildings.blocker("pump", Vector2i(-5, 2), site, field)).is_empty()
	assert_dict(Buildings.cost_for("pump")).is_equal({"stone": 3, "copper": 4})
	assert_float(Buildings.power_draw({"id": "pump", "state": "active"})).is_equal(0.03)

func test_pump_statistics_and_dependencies_are_validated_on_restore() -> void:
	var site := Site.new()
	_room(site)
	for y in range(2, 4):
		for x in range(1, 3):
			site.removed[Vector2i(x, y)] = true
	var buildings := Buildings.new()
	buildings.install("laboratory", Vector2i(-5, 1))
	var pump := buildings.install("pump", Vector2i(1, 2))
	pump.drained = 2.5
	var data: Array = JSON.parse_string(JSON.stringify(buildings.snapshot()))
	var restored := Buildings.new()
	assert_bool(restored.restore(data, site)).is_true()
	assert_float(float(restored.structures[1].drained)).is_equal(2.5)
	data[1].drained = -1
	assert_bool(restored.restore(data, site)).is_false()
	assert_float(float(restored.structures[1].drained)).is_equal(2.5)

func test_fan_accepts_gas_but_not_water_and_uses_real_power() -> void:
	var site := Site.new()
	_room(site)
	var field := Field.new(site)
	field.gas[Vector2i(-5, 3)] = 1.0
	var buildings := Buildings.new()
	assert_str(buildings.blocker("fan", Vector2i(-5, 2), site, field)).is_empty()
	assert_str(buildings.blocker("pump", Vector2i(-5, 2), site, field)).contains("sicura")
	assert_str(buildings.blocker("lamp", Vector2i(-5, 3), site, field)).contains("sicura")
	field.water[Vector2i(-5, 3)] = 1.0
	assert_str(buildings.blocker("fan", Vector2i(-5, 2), site, field)).contains("sicura")
	assert_vector(buildings.size_for("fan")).is_equal(Vector2i(2, 2))
	assert_dict(Buildings.cost_for("fan")).is_equal({"stone": 2, "copper": 3})
	assert_float(Buildings.power_draw({"id": "fan", "state": "active"})).is_equal(0.02)
	assert_float(Buildings.power_draw({"id": "fan", "state": "building"})).is_equal(0.05)

func test_fan_state_statistics_and_dependency_survive_save() -> void:
	var site := Site.new()
	_room(site)
	for y in range(2, 4):
		for x in range(1, 3):
			site.removed[Vector2i(x, y)] = true
	var buildings := Buildings.new()
	buildings.install("laboratory", Vector2i(-5, 1))
	var fan := buildings.install("fan", Vector2i(1, 2))
	fan.drained = 1.25
	fan.enabled = false
	var restored := Buildings.new()
	var data: Array = JSON.parse_string(JSON.stringify(buildings.snapshot()))
	assert_bool(restored.restore(data, site)).is_true()
	assert_float(restored.structures[1].drained).is_equal(1.25)
	assert_bool(restored.structures[1].enabled).is_false()
	var before := restored.snapshot()
	data[1].drained = INF
	assert_bool(restored.restore(data, site)).is_false()
	assert_array(restored.snapshot()).is_equal(before)
	data = buildings.snapshot()
	data.remove_at(0)
	assert_bool(restored.restore(data, site)).is_false()
