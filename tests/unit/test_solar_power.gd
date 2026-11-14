extends GdUnitTestSuite

const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Field = preload("res://scripts/systems/environment_field.gd")
const Ship = preload("res://scripts/systems/ship_state.gd")

func test_emergency_recharge_stays_free_and_capped() -> void:
	var ship := Ship.new()
	ship.energy = 0
	ship.resources.clear()
	assert_bool(ship.recharge()).is_true()
	assert_float(ship.energy).is_equal(15.0)
	assert_dict(ship.resources).is_empty()
	ship.energy = 59
	assert_bool(ship.recharge()).is_true()
	assert_float(ship.energy).is_equal(60.0)

func test_solar_panel_is_a_paid_two_cell_blueprint() -> void:
	assert_bool("solar_panel" in Buildings.CUBE_IDS).is_true()
	assert_vector(Buildings.new().size_for("solar_panel")).is_equal(Vector2i(2, 1))
	assert_dict(Buildings.cost_for("solar_panel")).is_equal({"structural_component": 2, "electronic_component": 1})

func test_surface_placement_does_not_relax_underground_modules() -> void:
	var buildings := Buildings.new()
	var site := Site.new()
	var field := Field.new(site)
	assert_str(buildings.blocker("solar_panel", Vector2i(8, -1), site, field)).is_empty()
	assert_str(buildings.blocker("solar_panel", Vector2i(8, 1), site, field)).is_not_empty()
	assert_str(buildings.blocker("solar_panel", Vector2i(0, -1), site, field)).is_not_empty()
	assert_str(buildings.blocker("solar_panel", Vector2i(23, -1), site, field)).is_not_empty()
	assert_str(buildings.blocker("laboratory", Vector2i(8, -3), site, field)).is_not_empty()
	assert_str(buildings.blocker("solar_panel", Vector2i(8, -2), site, field)).is_not_empty()
	buildings.install("solar_panel", Vector2i(8, -1))
	assert_str(buildings.blocker("solar_panel", Vector2i(9, -1), site, field)).is_not_empty()

func test_surface_panel_roundtrip_rejects_invalid_placement() -> void:
	var buildings := Buildings.new()
	var site := Site.new()
	buildings.install("solar_panel", Vector2i(-22, -1))
	var snapshot := buildings.snapshot()
	assert_bool(Buildings.new().restore(snapshot, site)).is_true()
	snapshot[0].origin = [0, -1]
	assert_bool(Buildings.new().restore(snapshot, site)).is_false()
