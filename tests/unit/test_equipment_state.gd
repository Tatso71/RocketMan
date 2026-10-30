extends GdUnitTestSuite

const Cargo = preload("res://scripts/systems/field_cargo.gd")
const Ship = preload("res://scripts/systems/ship_state.gd")
const Gear = preload("res://scripts/prototype/expedition_gear.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")

func test_legacy_backpack_merges_into_drone_without_losing_items() -> void:
	var cargo := Cargo.new()
	cargo.enable_drone_only()
	var drone: Dictionary = cargo.drone
	assert_bool(cargo.restore({"backpack": {"soil": 8}, "drone": {"copper": 12}})).is_true()
	assert_dict(cargo.backpack).is_empty()
	assert_int(drone.soil).is_equal(8)
	assert_int(drone.copper).is_equal(12)
	assert_int(cargo.free_space(true)).is_equal(0)
	assert_bool(cargo.collect("stone", 1, true)).is_false()

func test_delivery_disables_remote_collection_and_payment_but_not_local_cache() -> void:
	var cargo := Cargo.new()
	cargo.enable_drone_only()
	assert_bool(cargo.collect("stone", 6, true)).is_true()
	cargo.drone_available = false
	assert_bool(cargo.collect("copper", 1, true)).is_false()
	assert_bool(cargo.pay({"stone": 1}, true)).is_false()
	var cache := {"stone": 2}
	assert_bool(cargo.pay({"stone": 2}, true, cache)).is_true()
	assert_int(cargo.drone.stone).is_equal(6)
	var stock := {}
	assert_int(cargo.unload_drone(stock, 3)).is_equal(3)
	assert_int(cargo.drone.stone).is_equal(3)
	assert_int(stock.stone).is_equal(3)

func test_four_equipment_slots_and_jetpack_survive_ship_roundtrip() -> void:
	var ship := Ship.new()
	ship.jetpack_charge = 37
	ship.workshop_damaged = true
	assert_array(ship.tool_slots).is_equal(["pulse", "scanner", "bomb", "jetpack"])
	var loaded := Ship.new()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(ship.snapshot()))
	assert_bool(loaded.restore(saved)).is_true()
	assert_float(loaded.jetpack_charge).is_equal(37.0)
	assert_bool(loaded.workshop_damaged).is_true()
	var invalid := ship.snapshot()
	invalid.jetpack_charge = INF
	assert_bool(loaded.restore(invalid)).is_false()
	assert_float(loaded.jetpack_charge).is_equal(37.0)

func test_old_empty_slots_migrate_without_removing_mining_upgrades() -> void:
	var ship := Ship.new()
	var data := ship.snapshot()
	data.tool_slots = ["pulse", "scanner", "", ""]
	data.erase("jetpack_charge")
	data.erase("workshop_damaged")
	assert_bool(ship.restore(data)).is_true()
	assert_array(ship.tool_slots).is_equal(["pulse", "scanner", "bomb", "jetpack"])
	assert_float(ship.jetpack_charge).is_equal(100.0)

func test_bomb_save_requires_ordered_unique_cells_and_bounded_charge() -> void:
	var site := Site.new()
	site.removed[Vector2i(0, 1)] = true
	site.removed[Vector2i(1, 1)] = true
	var buildings := Buildings.new()
	var data := {"bombs": [{"cell": [0, 1], "number": 1}, {"cell": [1, 1], "number": 2}], "next_number": 3, "drops": [], "charge": 50}
	assert_bool(Gear.valid(data, site, buildings)).is_true()
	data.bombs[1].number = 1
	assert_bool(Gear.valid(data, site, buildings)).is_false()
	data.bombs[1].number = 2
	data.bombs[1].cell = [0, 1]
	assert_bool(Gear.valid(data, site, buildings)).is_false()
	data.bombs[1].cell = [1, 1]
	data.charge = -1
	assert_bool(Gear.valid(data, site, buildings)).is_false()

func test_damaged_installations_disable_services_without_losing_stock() -> void:
	var site := Site.new()
	for x in range(-4, 0):
		for y in range(3):
			site.removed[Vector2i(x, y)] = true
	var buildings := Buildings.new()
	var lab := buildings.install("laboratory", Vector2i(-4, 0))
	lab.stock.copper = 4
	lab.damaged = true
	assert_bool(Buildings.is_active(lab)).is_false()
	assert_dict(Buildings.repair_cost(lab)).is_equal({"stone": 3, "copper": 2})
	var loaded := Buildings.new()
	assert_bool(loaded.restore(JSON.parse_string(JSON.stringify(buildings.snapshot())), site)).is_true()
	assert_bool(loaded.structures[0].damaged).is_true()
	assert_int(loaded.structures[0].stock.copper).is_equal(4)

func test_empty_bomb_supply_persists_and_invalid_counts_are_transactional() -> void:
	var ship := Ship.new()
	assert_int(ship.bomb_ammo).is_equal(4)
	ship.bomb_ammo = 0
	var loaded := Ship.new()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(ship.snapshot()))
	assert_bool(loaded.restore(saved)).is_true()
	assert_int(loaded.bomb_ammo).is_equal(0)
	for amount in [-1, 5, 1.5, INF, "4"]:
		var bad := saved.duplicate(true)
		bad.bomb_ammo = amount
		assert_bool(loaded.restore(bad)).is_false()
		assert_int(loaded.bomb_ammo).is_equal(0)
	saved.erase("bomb_ammo")
	assert_bool(loaded.restore(saved)).is_true()
	assert_int(loaded.bomb_ammo).is_equal(4)

func test_bomb_bench_job_roundtrips_but_never_becomes_a_room_cube() -> void:
	var ship := Ship.new()
	ship.bomb_ammo = 0
	ship.fabrication.jobs.append({"id": "bomb", "level": 1, "station": ["ship"], "elapsed": 0.75, "seconds": 2.0})
	var loaded := Ship.new()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(ship.snapshot()))
	assert_bool(loaded.restore(saved)).is_true()
	assert_int(loaded.bomb_ammo).is_equal(0)
	assert_float(loaded.fabrication.jobs[0].elapsed).is_equal(0.75)
	assert_dict(loaded.fabrication.add_cube(Vector2(-80, -80), ["ship"], "bomb")).is_empty()
