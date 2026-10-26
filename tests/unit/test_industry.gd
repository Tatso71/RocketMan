extends GdUnitTestSuite

const Catalog = preload("res://scripts/data/industry_catalog.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const Industry = preload("res://scripts/systems/industry_state.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const Ship = preload("res://scripts/systems/ship_state.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")

func test_industry_catalog_is_complete_and_costs_use_runtime_integers() -> void:
	var data := Catalog.load_data()
	assert_int(data.recipes.size()).is_equal(3)
	assert_dict(data.recipes.greenhouse.cost).is_equal({"soil": 4, "stone": 4, "copper_ingot": 2, "glass": 2})
	assert_bool(Cargo.new().can_pay(data.smelting.glass.cost, true, {"stone": 2})).is_true()
	assert_bool(Cargo.new().can_pay(data.conduit_cost, true, {"copper": 1})).is_true()
	assert_int(data.crops.size()).is_equal(4)
	var bad := data.duplicate(true)
	bad.converter.kwh_per_gas = INF
	assert_dict(Catalog.validate(bad)).is_empty()
	bad = data.duplicate(true)
	bad.crops.potato["yield"] = 1.5
	assert_dict(Catalog.validate(bad)).is_empty()

func test_ship_starts_only_with_three_seed_potatoes_not_free_minerals() -> void:
	var ship := Ship.new()
	assert_int(ship.cargo_used()).is_equal(0)
	assert_dict(ship.seed_bank).is_equal({"potato": 3, "ochre_tuber": 0, "verdant_leaf": 0, "frost_berry": 0})
	ship.seed_bank.potato = 0
	ship.seed_bank.verdant_leaf = 2
	var restored := Ship.new()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(ship.snapshot()))
	assert_bool(restored.restore(saved)).is_true()
	assert_dict(restored.seed_bank).is_equal(ship.seed_bank)
	var bad := ship.snapshot()
	bad.seed_bank.potato = -1
	assert_bool(restored.restore(bad)).is_false()
	assert_dict(restored.seed_bank).is_equal(ship.seed_bank)

func test_old_seedless_saves_receive_potatoes_once_but_explicit_empty_bank_stays_empty() -> void:
	var data := Ship.new().snapshot()
	data.erase("seed_bank")
	var ship := Ship.new()
	assert_bool(ship.restore(data)).is_true()
	assert_int(ship.seed_bank.potato).is_equal(3)
	data.seed_bank = {}
	assert_bool(ship.restore(data)).is_true()
	assert_int(ship.seed_bank.potato).is_equal(0)
	assert_bool(ship.restore(ship.snapshot())).is_true()
	assert_int(ship.seed_bank.potato).is_equal(0)

func test_network_connects_cardinal_cells_only_and_separates_media() -> void:
	var network := Network.new()
	network.add("water", Vector2i(0, 0))
	network.add("water", Vector2i(1, 1))
	assert_bool(network.connected("water", Vector2i(0, 0), Vector2i(1, 1))).is_false()
	network.add("gas", Vector2i(1, 0))
	assert_bool(network.connected("water", Vector2i(0, 0), Vector2i(1, 1))).is_false()
	network.add("water", Vector2i(1, 0))
	assert_bool(network.connected("water", Vector2i(0, 0), Vector2i(1, 1))).is_true()
	assert_bool(network.add("water", Vector2i(1, 0))).is_false()
	network.remove("water", Vector2i(1, 0))
	assert_bool(network.connected("water", Vector2i(0, 0), Vector2i(1, 1))).is_false()
	assert_bool(network.cells.gas.has(Vector2i(1, 0))).is_true()

func test_network_snapshot_rejects_solid_duplicate_and_invalid_cells_atomically() -> void:
	var site := Site.new()
	site.removed[Vector2i(0, 0)] = true
	var network := Network.new()
	network.add("gas", Vector2i(0, 0))
	var original := network.snapshot()
	assert_bool(network.restore(JSON.parse_string(JSON.stringify(original)), site)).is_true()
	for bad_entry: Array in [["gas", 0, 0], ["energy", 1, 0], ["water", 0.5, 0], ["oil", 0, 0]]:
		var data := original.duplicate(true)
		data.cells.append(bad_entry)
		assert_bool(network.restore(data, site)).is_false()
		assert_dict(network.snapshot()).is_equal(original)

func test_machine_ports_are_inside_their_metric_footprints() -> void:
	var buildings := Buildings.new()
	for id: String in ["furnace", "gas_converter", "greenhouse", "pump"]:
		var building := buildings.install(id, Vector2i(2, 2))
		for medium: String in Network.KINDS:
			assert_bool(buildings.footprint(id, building.origin).has_point(Network.port(building, medium))).is_true()
	assert_vector(buildings.size_for("furnace")).is_equal(Vector2i(3, 2))
	assert_vector(buildings.size_for("greenhouse")).is_equal(Vector2i(4, 3))

func test_machine_restore_preserves_paid_progress_and_rejects_free_energy() -> void:
	var site := Site.new()
	for y in range(2):
		for x in range(3):
			site.removed[Vector2i(x, y)] = true
	var buildings := Buildings.new()
	var furnace := buildings.install("furnace", Vector2i.ZERO)
	var industry := Industry.new()
	industry.state(furnace).recipe = "glass"
	industry.state(furnace).elapsed = 4.5
	var saved := industry.snapshot()
	assert_bool(Industry.new().restore(JSON.parse_string(JSON.stringify(saved)), buildings, site)).is_true()
	saved.machines[Industry.key(furnace)].elapsed = 10.0
	assert_bool(industry.restore(saved, buildings, site)).is_false()
	assert_float(industry.state(furnace).elapsed).is_equal(4.5)
	buildings.structures.clear()
	var converter := buildings.install("gas_converter", Vector2i.ZERO)
	industry = Industry.new()
	industry.state(converter).energy = 1.0
	assert_bool(Industry.new().restore(industry.snapshot(), buildings, site)).is_false()

func test_planets_offer_different_seeds_never_potatoes_at_start() -> void:
	var species: Array = []
	for seed_value in [0, 11, 23]:
		var pod: Dictionary = Catalog.seed_sites(seed_value)[0]
		species.append(pod.crop)
		assert_bool(pod.crop != "potato").is_true()
	assert_array(species).is_equal(["ochre_tuber", "verdant_leaf", "frost_berry"])
