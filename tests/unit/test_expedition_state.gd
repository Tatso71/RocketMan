extends GdUnitTestSuite

const State = preload("res://scripts/systems/expedition_state.gd")
const Planets = preload("res://scripts/data/planet_catalog.gd")
const DigSite = preload("res://scripts/systems/dig_site.gd")

func test_cycle_transitions_and_one_time_costs() -> void:
	var state := State.new()
	assert_bool(state.choose("verdant")).is_true()
	assert_bool(state.depart()).is_true()
	var fuel := state.ship.fuel
	assert_bool(state.depart()).is_false()
	assert_float(state.ship.fuel).is_equal(fuel)
	assert_bool(state.choose("frost")).is_false()
	state.advance(10)
	assert_int(state.phase).is_equal(State.Phase.LANDING)
	var hull := state.ship.hull
	state.advance(10)
	assert_int(state.phase).is_equal(State.Phase.DIGGING)
	assert_float(state.ship.hull).is_less(hull)
	var landed_hull := state.ship.hull
	state.advance(100)
	assert_float(state.ship.hull).is_equal(landed_hull)
	assert_bool(state.takeoff()).is_true()
	assert_bool(state.takeoff()).is_false()
	state.advance(10)
	assert_int(state.phase).is_equal(State.Phase.SELECT)

func test_unaffordable_or_invalid_routes_leave_state_unchanged() -> void:
	var state := State.new()
	assert_bool(state.choose("missing")).is_false()
	state.ship.fuel = 1
	var before := state.snapshot()
	assert_bool(state.depart()).is_false()
	assert_dict(state.snapshot()).is_equal(before)
	assert_bool(state.takeoff()).is_false()

func test_midflight_save_resumes_without_paying_twice() -> void:
	var state := State.new()
	state.depart()
	state.advance(1)
	var fuel := state.ship.fuel
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.snapshot()))
	var loaded := State.new()
	assert_bool(loaded.restore(data)).is_true()
	assert_int(loaded.phase).is_equal(State.Phase.FLIGHT)
	assert_float(loaded.ship.fuel).is_equal(fuel)
	assert_bool(is_equal_approx(loaded.progress, state.progress)).is_true()
	loaded.advance(10)
	assert_float(loaded.ship.fuel).is_equal(fuel)

func test_outpost_snapshots_are_independent_and_planets_have_distinct_terrain() -> void:
	var state := State.new()
	var ocra := DigSite.new(Planets.find("ochre").terrain_seed)
	var brina := DigSite.new(Planets.find("frost").terrain_seed)
	assert_str(ocra.material(Vector2i(0, 4))).is_not_equal(brina.material(Vector2i(0, 4)))
	state.outposts.ochre = {"removed": ocra.snapshot()}
	var data := state.snapshot()
	state.outposts.ochre.removed.clear()
	assert_int(data.outposts.ochre.removed.size()).is_greater(0)

func test_invalid_phase_and_unknown_planet_do_not_mutate_state() -> void:
	var state := State.new()
	var data := state.snapshot()
	data.phase = 99
	assert_bool(state.restore(data)).is_false()
	assert_int(state.phase).is_equal(State.Phase.SELECT)
	data = state.snapshot()
	data.selected_planet = "missing"
	assert_bool(state.restore(data)).is_false()
	data = state.snapshot()
	data.progress = NAN
	assert_bool(state.restore(data)).is_false()
