extends GdUnitTestSuite

const Ship = preload("res://scripts/systems/ship_state.gd")
const Planets = preload("res://scripts/data/planet_catalog.gd")
const Modules = preload("res://scripts/data/ship_module_catalog.gd")

func test_personal_energy_is_distinct_from_ship_battery_and_persists() -> void:
	var ship := Ship.new()
	ship.crew_energy = 23
	ship.energy = 41
	var restored := Ship.new()
	assert_bool(restored.restore(JSON.parse_string(JSON.stringify(ship.snapshot())))).is_true()
	assert_float(restored.crew_energy).is_equal(23.0)
	assert_float(restored.energy).is_equal(41.0)
	var bad := ship.snapshot()
	bad.crew_energy = 101
	assert_bool(restored.restore(bad)).is_false()
	assert_float(restored.crew_energy).is_equal(23.0)
	bad.erase("crew_energy")
	assert_bool(restored.restore(bad)).is_true()
	assert_float(restored.crew_energy).is_equal(100.0)

func test_ship_has_three_floor_baseline_and_metric_module_footprints() -> void:
	var ship := Ship.new()
	assert_int(ship.cargo_capacity()).is_equal(120)
	assert_float(ship.hull_capacity()).is_equal(100.0)
	for definition: Resource in Modules.all():
		assert_int(definition.footprint_cells.x).is_greater(0)
		assert_int(definition.footprint_cells.y).is_greater(0)

func test_upgrade_pays_once_and_changes_derived_attribute() -> void:
	var ship := Ship.new()
	ship.resources = {"stone": 8, "copper": 6}
	assert_bool(ship.upgrade("cargo")).is_true()
	assert_int(ship.modules.cargo).is_equal(2)
	assert_int(ship.cargo_capacity()).is_equal(200)
	assert_int(ship.resources.stone).is_equal(2)
	assert_int(ship.resources.copper).is_equal(2)
	var before := ship.snapshot()
	assert_bool(ship.upgrade("cargo")).is_false()
	assert_dict(ship.snapshot()).is_equal(before)
	assert_bool(ship.upgrade("invalid")).is_false()

func test_repair_and_supplies_do_not_charge_when_full() -> void:
	var ship := Ship.new()
	var original := ship.resources.duplicate()
	assert_bool(ship.repair()).is_false()
	assert_bool(ship.refuel()).is_false()
	assert_bool(ship.recharge()).is_false()
	assert_dict(ship.resources).is_equal(original)
	ship.hull = 90
	ship.resources = {"soil": 2, "stone": 2, "copper": 1}
	assert_bool(ship.repair()).is_true()
	assert_float(ship.hull).is_equal(100.0)
	ship.fuel = 70
	assert_bool(ship.refuel()).is_true()
	assert_float(ship.fuel).is_equal(80.0)

func test_engine_upgrade_reduces_route_fuel_and_launcher_reserves_takeoff() -> void:
	var ship := Ship.new()
	var planet := Planets.find("ochre")
	ship.resources.copper = 20
	ship.resources.crystal = 10
	var old_cost := ship.route_cost(planet)
	assert_bool(ship.upgrade("engine")).is_true()
	assert_float(ship.route_cost(planet)).is_less(old_cost)
	ship.fuel = ship.route_cost(planet)
	assert_str(ship.flight_blocker(planet)).is_not_empty()

func test_restore_is_transactional_and_preserves_cargo_reference() -> void:
	var ship := Ship.new()
	var cargo: Dictionary = ship.resources
	var data: Dictionary = JSON.parse_string(JSON.stringify(ship.snapshot()))
	data.resources.soil = 4
	assert_bool(ship.restore(data)).is_true()
	assert_int(cargo.soil).is_equal(4)
	data.modules.cargo = 99
	var before := ship.snapshot()
	assert_bool(ship.restore(data)).is_false()
	assert_dict(ship.snapshot()).is_equal(before)

func test_restore_rejects_overfilled_cargo_and_nonfinite_stats() -> void:
	var ship := Ship.new()
	var data := ship.snapshot()
	data.resources.soil = 120
	data.resources.stone = 120
	assert_bool(ship.restore(data)).is_false()
	data = ship.snapshot()
	data.energy = INF
	assert_bool(ship.restore(data)).is_false()
	assert_bool(ship.can_afford({"soil": -1})).is_false()

func test_digital_tool_unlocks_and_four_slot_limit_survive_save() -> void:
	var ship := Ship.new()
	ship.lab_research_unlocked = true
	ship.resources = {"stone": 8, "copper": 6}
	assert_int(ship.tool_slots.size()).is_equal(4)
	assert_bool(ship.upgrade("drill")).is_true()
	assert_array(ship.tool_slots).contains(["resonator"])
	var data := ship.snapshot()
	data.tool_slots.append("plasma")
	assert_bool(ship.restore(data)).is_false()
	data = ship.snapshot()
	data.tool_slots[3] = "plasma"
	assert_bool(ship.restore(data)).is_false()

func test_solar_recharge_prevents_empty_battery_soft_lock() -> void:
	var ship := Ship.new()
	ship.resources.clear()
	ship.energy = 0
	assert_bool(ship.recharge()).is_true()
	assert_float(ship.energy).is_equal(15.0)

func test_suit_persists_and_legacy_ship_uses_full_protection() -> void:
	var ship := Ship.new()
	ship.suit_integrity = 42.5
	var data := ship.snapshot()
	var loaded := Ship.new()
	assert_bool(loaded.restore(data)).is_true()
	assert_float(loaded.suit_integrity).is_equal(42.5)
	data.erase("suit_integrity")
	assert_bool(loaded.restore(data)).is_true()
	assert_float(loaded.suit_integrity).is_equal(100.0)
	data.suit_integrity = -1
	assert_bool(loaded.restore(data)).is_false()

func test_lab_unlocks_drone_upgrade_and_portable_cargo_survives_save() -> void:
	var ship := Ship.new()
	assert_bool(ship.upgrade("drill")).is_false()
	ship.lab_research_unlocked = true
	ship.resources.copper = 10
	ship.resources.crystal = 2
	ship.resources.stone = 8
	assert_bool(ship.upgrade("drone")).is_true()
	assert_int(ship.field_cargo.drone_capacity).is_equal(16)
	assert_float(ship.drone_range_metres()).is_equal(20.0)
	ship.field_cargo.collect("soil", 10, true)
	var loaded := Ship.new()
	var data: Dictionary = JSON.parse_string(JSON.stringify(ship.snapshot()))
	assert_bool(loaded.restore(data)).is_true()
	assert_int(loaded.field_cargo.used(loaded.field_cargo.drone)).is_equal(2)
	assert_bool(loaded.lab_research_unlocked).is_true()
