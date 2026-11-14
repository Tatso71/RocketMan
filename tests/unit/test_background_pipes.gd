extends GdUnitTestSuite

const Network = preload("res://scripts/systems/utility_network.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Ship = preload("res://scripts/systems/ship_state.gd")
const EnergyUI = preload("res://scripts/ui/laboratory_energy_ui.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")

func test_energy_legend_covers_every_constructible_module() -> void:
	for id: String in Buildings.CUBE_IDS:
		assert_bool(EnergyUI.SHORT_NAMES.has(id)).is_true()

func test_pipe_guide_rotates_and_neighbouring_cells_stay_connected() -> void:
	var network := Network.new()
	var cell := Vector2i(0, 1)
	network.add("water", cell)
	assert_int(network.water_axes[cell]).is_equal(0)
	network.cycle_water(cell)
	assert_int(network.water_axes[cell]).is_equal(1)
	network.cycle_water(cell)
	assert_int(network.water_axes[cell]).is_equal(0)
	network.add("water", cell + Vector2i.UP)
	network.add("water", cell + Vector2i.RIGHT)
	assert_bool(network.connected("water", cell + Vector2i.UP, cell + Vector2i.RIGHT)).is_true()
	network.remove("water", cell)
	assert_bool(network.water_axes.has(cell)).is_false()
	assert_bool(network.connected("water", cell + Vector2i.UP, cell + Vector2i.RIGHT)).is_false()

func test_aboveground_pipe_guides_round_trip_and_reject_bad_state_atomically() -> void:
	var site := Site.new()
	var network := Network.new()
	network.add("water", Vector2i(-6, -2))
	var original := network.snapshot()
	assert_bool(network.restore(JSON.parse_string(JSON.stringify(original)), site)).is_true()
	network.cycle_water(Vector2i(-6, -2))
	original = network.snapshot()
	var restored := Network.new()
	assert_bool(restored.restore(JSON.parse_string(JSON.stringify(original)), site)).is_true()
	assert_int(restored.water_axes[Vector2i(-6, -2)]).is_equal(1)
	var bad := original.duplicate(true)
	bad.water_axes.append([-6, -2, 2])
	assert_bool(restored.restore(bad, site)).is_false()
	assert_dict(restored.snapshot()).is_equal(original)
	bad = original.duplicate(true)
	bad.cells.append(["water", 0, 0])
	assert_bool(restored.restore(bad, site)).is_false()
	assert_dict(restored.snapshot()).is_equal(original)

func test_ship_water_tanks_are_finite_independent_and_persist() -> void:
	var ship := Ship.new()
	ship.water_tanks.left = 12.5
	ship.water_tanks.right = 35.0
	var restored := Ship.new()
	assert_bool(restored.restore(JSON.parse_string(JSON.stringify(ship.snapshot())))).is_true()
	assert_dict(restored.water_tanks).is_equal(ship.water_tanks)
	for value in [-1.0, 40.1, INF, "water"]:
		var bad := ship.snapshot()
		bad.water_tanks.left = value
		assert_bool(restored.restore(bad)).is_false()
		assert_dict(restored.water_tanks).is_equal(ship.water_tanks)
