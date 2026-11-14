extends GdUnitTestSuite

const Industry = preload("res://scripts/systems/industry_state.gd")
const Catalog = preload("res://scripts/data/industry_catalog.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const Icons = preload("res://scripts/data/item_icon_catalog.gd")

class TestWorld extends RefCounted:
	var energy := 2.0
	func ship_energy() -> float: return energy
	func _set_ship_energy(value: float) -> void: energy = value

class Irrigation extends RefCounted:
	var limit := INF
	func withdraw(building: Dictionary, requested: float, outpost: Node2D) -> float:
		var storage: Dictionary = outpost.industry.state(building)
		var taken := minf(limit, minf(requested, float(storage.water)))
		storage.water -= taken
		return taken

class TestOutpost extends Node2D:
	const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
	var buildings := Buildings.new()
	var industry := Industry.new()
	var world := TestWorld.new()
	var network := Network.new()
	var hydraulics := Irrigation.new()
	var lab := {"id": "laboratory", "origin": Vector2i.ZERO}
	var safe := true
	func supplying_lab(_building: Dictionary) -> Dictionary:
		return lab if safe and world.energy > 0 else {}
	func environment_safe(_building: Dictionary) -> bool: return safe

func test_water_container_catalog_and_building_contract() -> void:
	var buildings := Buildings.new()
	assert_bool("water_tank" in Catalog.MACHINE_IDS).is_true()
	assert_bool("water_tank" in Buildings.CUBE_IDS).is_true()
	assert_bool("water_tank" in Buildings.INDUSTRIAL_IDS).is_true()
	assert_vector(buildings.size_for("water_tank")).is_equal(Vector2i(2, 2))
	assert_dict(Buildings.cost_for("water_tank")).is_equal({"structural_component": 2, "electronic_component": 1})
	assert_float(Buildings.power_draw({"id": "water_tank", "state": "active"})).is_zero()
	assert_float(Buildings.power_draw({"id": "water_tank", "state": "building"})).is_equal(0.06)
	assert_float(float(Catalog.load_data().get("water_tank_capacity", -1))).is_equal(32.0)
	assert_float(float(Catalog.load_data().get("greenhouse_capacity", -1))).is_equal(4.0)
	assert_dict(Catalog.load_data().conduit_cost).is_equal({"water": {}, "gas": {"structural_component": 1}, "energy": {"electronic_component": 1}})

func test_water_buffers_start_empty_and_crop_state_is_retained() -> void:
	assert_dict(Industry.defaults("water_tank")).is_equal({"water": 0.0})
	assert_dict(Industry.defaults("greenhouse")).is_equal({"crop": "", "elapsed": 0.0, "water": 0.0})
	assert_dict(Industry.defaults("pump")).is_equal({"water": 0.0})

func test_new_module_has_a_shared_icon_and_repair_alias() -> void:
	assert_str(Icons.path("water_tank")).is_equal("res://assets/ui/items/water_tank.svg")
	assert_str(Icons.path("repaired_water_tank")).is_equal(Icons.path("water_tank"))
	assert_bool(FileAccess.file_exists(Icons.path("water_tank"))).is_true()
	assert_str(Icons.catalog().icons.valve.name).is_equal("Valvola blu")

func test_catalog_rejects_invalid_capacities_and_water_pipe_charges() -> void:
	var data := Catalog.load_data()
	for property: String in ["pump_capacity", "water_tank_capacity", "greenhouse_capacity"]:
		for invalid in [0, -1, INF, NAN, true, "4"]:
			var bad := data.duplicate(true)
			bad[property] = invalid
			assert_dict(Catalog.validate(bad)).is_empty()
	var paid_water := data.duplicate(true)
	paid_water.conduit_cost.water = {"structural_component": 1}
	assert_dict(Catalog.validate(paid_water)).is_empty()

func test_storage_restore_is_strict_finite_bounded_and_atomic() -> void:
	var site := Site.new()
	var buildings := Buildings.new()
	for id: String in ["water_tank", "greenhouse", "pump"]:
		var building := buildings.install(id, Vector2i(buildings.structures.size() * 6, 0))
		var industry := Industry.new()
		var capacity: float = {"water_tank": 32.0, "greenhouse": 4.0, "pump": 8.0}[id]
		industry.state(building)["water"] = capacity
		if id == "greenhouse":
			industry.state(building).crop = "potato"
			industry.state(building).elapsed = 12.5
		var saved := industry.snapshot()
		assert_bool(industry.restore(JSON.parse_string(JSON.stringify(saved)), buildings, site)).is_true()
		for invalid in [-1, capacity + 0.001, INF, NAN, "2", true]:
			var bad := saved.duplicate(true)
			bad.machines[Industry.key(building)].water = invalid
			assert_bool(industry.restore(bad, buildings, site)).is_false()
			assert_dict(industry.snapshot()).is_equal(saved)
		var missing := saved.duplicate(true)
		missing.machines[Industry.key(building)].erase("water")
		assert_bool(industry.restore(missing, buildings, site)).is_false()
		var extra := saved.duplicate(true)
		extra.machines[Industry.key(building)].legacy_water = 1
		assert_bool(industry.restore(extra, buildings, site)).is_false()
		building.state = "planned"
		assert_bool(industry.restore(saved, buildings, site)).is_false()
		building.state = "active"

func test_pump_requires_one_empty_cell_but_not_a_floor() -> void:
	var site := Site.new()
	site.removed[Vector2i.ZERO] = true
	site.removed[Vector2i.DOWN] = true
	var buildings := Buildings.new()
	var outpost := auto_free(TestOutpost.new()) as TestOutpost
	assert_vector(buildings.size_for("pump")).is_equal(Vector2i.ONE)
	assert_vector(Buildings.PUMP_SIZE).is_equal(Vector2i.ONE)
	assert_str(buildings.blocker("pump", Vector2i.ZERO, site, EmptyField.new())).is_empty()
	assert_str(buildings.blocker("lamp", Vector2i.ZERO, site, EmptyField.new())).is_not_empty()
	buildings.install("laboratory", Vector2i(-8, 0))
	for y in range(3):
		for x in range(-8, -4): site.removed[Vector2i(x, y)] = true
	buildings.install("pump", Vector2i.ZERO)
	assert_bool(Buildings.new().restore(buildings.snapshot(), site)).is_true()
	assert_bool(outpost.industry.healthy(outpost.buildings.install("water_tank", Vector2i.ZERO), outpost)).is_true()

class EmptyField extends RefCounted:
	var water := {}
	var gas := {}
	var oil := {}
	var acid := {}

func test_container_status_reports_capacity_and_health() -> void:
	var outpost := auto_free(TestOutpost.new()) as TestOutpost
	var tank := outpost.buildings.install("water_tank", Vector2i.ZERO)
	outpost.industry.state(tank)["water"] = 12.5
	assert_str(outpost.industry.status(tank, outpost)).contains("12.50 / 32")
	tank.damaged = true
	assert_bool(outpost.industry.healthy(tank, outpost)).is_false()
	tank.damaged = false
	tank.enabled = false
	assert_bool(outpost.industry.healthy(tank, outpost)).is_false()

func test_greenhouse_uses_local_lab_energy_and_its_own_water_buffer() -> void:
	var outpost := auto_free(TestOutpost.new()) as TestOutpost
	var greenhouse := outpost.buildings.install("greenhouse", Vector2i.ZERO)
	var storage: Dictionary = outpost.industry.state(greenhouse)
	storage.crop = "potato"
	storage["water"] = 2.0
	assert_float(outpost.industry.water_available(greenhouse, outpost)).is_equal(2.0)
	outpost.industry.advance(1.0, outpost, [greenhouse])
	assert_float(storage.elapsed).is_equal_approx(1.0, 0.000001)
	assert_float(storage.water).is_equal_approx(2.0 - 2.0 / 45.0, 0.000001)
	assert_float(outpost.world.energy).is_equal_approx(1.98, 0.000001)
	assert_bool(outpost.industry.call("is_irrigating", greenhouse)).is_true()
	storage.water = 0.0
	outpost.industry.advance(1.0, outpost, [greenhouse])
	assert_float(storage.elapsed).is_equal_approx(1.0, 0.000001)
	assert_float(outpost.world.energy).is_equal_approx(1.98, 0.000001)
	assert_bool(outpost.industry.call("is_irrigating", greenhouse)).is_false()

func test_greenhouse_only_advances_by_actual_withdrawal() -> void:
	var outpost := auto_free(TestOutpost.new()) as TestOutpost
	var greenhouse := outpost.buildings.install("greenhouse", Vector2i.ZERO)
	var storage: Dictionary = outpost.industry.state(greenhouse)
	storage.crop = "potato"
	storage["water"] = 2.0
	outpost.hydraulics.limit = 0.001
	outpost.industry.advance(0.25, outpost, [greenhouse])
	assert_float(storage.elapsed).is_equal_approx(0.0225, 0.000001)
	assert_float(outpost.world.energy).is_equal_approx(2.0 - 0.0225 * 0.02, 0.000001)
	outpost.hydraulics.limit = 0.0
	outpost.industry.advance(0.25, outpost, [greenhouse])
	assert_float(storage.elapsed).is_equal_approx(0.0225, 0.000001)
	assert_bool(outpost.industry.call("is_irrigating", greenhouse)).is_false()

func test_greenhouse_converter_fallback_and_no_free_energy() -> void:
	var outpost := auto_free(TestOutpost.new()) as TestOutpost
	outpost.lab = {}
	var greenhouse := outpost.buildings.install("greenhouse", Vector2i.ZERO)
	var storage: Dictionary = outpost.industry.state(greenhouse)
	storage.crop = "potato"
	storage["water"] = 2.0
	outpost.industry.advance(1.0, outpost, [greenhouse])
	assert_float(storage.elapsed).is_zero()
	assert_float(storage.water).is_equal(2.0)
	var converter := outpost.buildings.install("gas_converter", Vector2i(4, 0))
	for x in range(0, 6): outpost.network.add("energy", Vector2i(x, 2))
	outpost.network.add("energy", Network.port(converter, "energy"))
	outpost.industry.state(converter).energy = 0.01
	outpost.industry.advance(1.0, outpost, [greenhouse])
	assert_float(storage.elapsed).is_equal_approx(0.5, 0.000001)
	assert_float(outpost.industry.state(converter).energy).is_zero()
	assert_float(outpost.world.energy).is_equal(2.0)

func test_greenhouse_stops_when_disabled_unsafe_or_mature() -> void:
	var outpost := auto_free(TestOutpost.new()) as TestOutpost
	var greenhouse := outpost.buildings.install("greenhouse", Vector2i.ZERO)
	var storage: Dictionary = outpost.industry.state(greenhouse)
	storage.crop = "potato"
	storage["water"] = 4.0
	greenhouse.enabled = false
	outpost.industry.advance(1.0, outpost, [greenhouse])
	assert_float(storage.elapsed).is_zero()
	greenhouse.enabled = true
	outpost.safe = false
	outpost.industry.advance(1.0, outpost, [greenhouse])
	assert_float(storage.elapsed).is_zero()
	outpost.safe = true
	storage.elapsed = 45.0
	outpost.industry.advance(1.0, outpost, [greenhouse])
	assert_float(storage.water).is_equal(4.0)
	assert_float(outpost.world.energy).is_equal(2.0)
