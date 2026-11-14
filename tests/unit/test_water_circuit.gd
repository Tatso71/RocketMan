extends GdUnitTestSuite

const MODEL := "res://scripts/systems/water_circuit.gd"
const Site = preload("res://scripts/systems/dig_site.gd")
const Field = preload("res://scripts/systems/environment_field.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const Industry = preload("res://scripts/systems/industry_state.gd")

class Ship extends RefCounted:
	var water_tanks := {"left": 0.0, "right": 0.0}

class Context extends Node2D:
	var world: Node2D = self
	var site := Site.new()
	var environment := Field.new(site)
	var network := Network.new()
	var buildings := Buildings.new()
	var industry := Industry.new()
	var hydraulics: RefCounted
	var energy := true
	var reachable := true
	func laboratory_unlocked() -> bool: return false
	func reachable_cell(_cell: Vector2i) -> bool: return reachable
	func device_powered(b: Dictionary) -> bool: return energy and Buildings.is_active(b) and b.get("enabled", true)
	func site_reachable(_b: Dictionary) -> bool: return reachable
	func _note(_text: String) -> void: pass
	func guide_event(_id: String) -> void: pass

class CampaignContext extends Context:
	var ship_state := Ship.new()

func context(campaign: bool = false) -> Context:
	var ctx: Context = CampaignContext.new() if campaign else Context.new()
	auto_free(ctx)
	ctx.hydraulics = load(MODEL).new()
	ctx.site.removed.clear()
	for kind: String in ["water", "oil", "acid", "gas"]: ctx.environment.get(kind).clear()
	return ctx

func pipe(ctx: Context, cell: Vector2i) -> void:
	ctx.site.removed[cell] = true
	ctx.network.add("water", cell)

func machine(ctx: Context, id: String, port: Vector2i, water: float = 0) -> Dictionary:
	var size: Vector2i = Buildings.SIZES.get(id, Vector2i.ONE)
	var origin := port - Vector2i(0, size.y - 1) if id != "pump" else port
	var b := {"id": id, "origin": origin, "state": "active", "enabled": true, "damaged": false, "drained": 0.0}
	ctx.buildings.structures.append(b)
	ctx.industry.state(b).water = water
	return b

func valve(ctx: Context, cell: Vector2i, water_cell: Vector2i, volume: float = 1) -> Dictionary:
	ctx.site.removed[water_cell] = true
	ctx.environment.water[water_cell] = volume
	if not ctx.hydraulics.place("valve", cell, ctx): return {}
	var entry: Dictionary = ctx.hydraulics.at(cell)
	return entry

func stored(ctx: Context) -> float:
	var result := 0.0
	for value in ctx.environment.water.values(): result += float(value)
	for b: Dictionary in ctx.buildings.structures:
		if b.id in ["pump", "water_tank", "greenhouse"]: result += float(ctx.industry.state(b).get("water", 0))
	var ship = ctx.world.get("ship_state")
	var tanks: Dictionary = ship.water_tanks if ship != null else ctx.hydraulics.local_ship_water
	return result + float(tanks.left) + float(tanks.right)

func fixture(pumped: bool = false, height: int = 4) -> Context:
	var ctx := context()
	valve(ctx, Vector2i(-11, 8), Vector2i(-12, 8))
	for x in range(-10, -3): pipe(ctx, Vector2i(x, 8))
	var target_y := 8 - height if pumped else 11
	for y in range(mini(8, target_y), maxi(8, target_y) + 1): pipe(ctx, Vector2i(-4, y))
	if pumped: machine(ctx, "pump", Vector2i(-8, 8))
	machine(ctx, "water_tank", Vector2i(-4, target_y))
	return ctx

func test_blue_valve_api_replaces_the_old_contract() -> void:
	var ctx := context()
	assert_bool(ctx.hydraulics.has_method("ship_ports")).is_true()
	assert_bool(ctx.hydraulics.has_method("pump_direction")).is_true()
	assert_int(ctx.hydraulics.snapshot().version).is_equal(2)

func test_valve_uses_actual_orthogonal_water_without_reach_unlock_cost_or_mining() -> void:
	for direction: Vector2i in Network.OFFSETS:
		var ctx := context()
		ctx.reachable = false
		var cell := Vector2i(-15, 10)
		var water_cell := cell + direction
		ctx.site.removed[water_cell] = true
		ctx.environment.water[water_cell] = 0.4
		var before := ctx.site.snapshot()
		assert_str(ctx.hydraulics.placement_blocker("valve", cell, ctx)).is_empty()
		assert_bool(ctx.hydraulics.place("valve", cell, ctx)).is_true()
		assert_array(ctx.site.snapshot()).is_equal(before)
		assert_float(float(ctx.environment.water[water_cell])).is_equal(0.4)
		assert_dict(ctx.hydraulics.at(cell)).is_equal({"kind": "valve", "cell": cell, "opened": true, "total": 0.0})
		assert_bool(ctx.hydraulics.place("valve", cell, ctx)).is_false()

func test_valve_rejects_dry_diagonal_other_liquid_and_empty_cell() -> void:
	var ctx := context()
	var cell := Vector2i(-15, 10)
	ctx.environment.water[cell + Vector2i.ONE] = 1.0
	ctx.environment.oil[cell + Vector2i.RIGHT] = 1.0
	assert_bool(ctx.hydraulics.place("valve", cell, ctx)).is_false()
	ctx.environment.water[cell + Vector2i.RIGHT] = 1.0
	ctx.site.removed[cell] = true
	assert_bool(ctx.hydraulics.place("valve", cell, ctx)).is_false()

func test_gravity_through_elbow_fills_finite_tank_and_conserves() -> void:
	var ctx := fixture()
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[0]).water)).is_equal_approx(0.35, 0.00001)
	assert_float(stored(ctx)).is_equal_approx(1.0, 0.00001)

func test_closed_disconnected_dangling_and_full_paths_do_not_delete_water() -> void:
	for mode: String in ["closed", "disconnected", "dangling", "full"]:
		var ctx := fixture()
		match mode:
			"closed": ctx.hydraulics.valves[0].opened = false
			"disconnected": ctx.network.remove("water", Vector2i(-6, 8))
			"dangling": ctx.buildings.structures.clear()
			"full": ctx.industry.state(ctx.buildings.structures[0]).water = 32.0
		var before := stored(ctx)
		ctx.hydraulics.advance(60, ctx, 60)
		assert_float(float(ctx.environment.water[Vector2i(-12, 8)])).is_equal(1.0)
		assert_float(stored(ctx)).is_equal_approx(before, 0.00001)

func test_passive_flow_cannot_climb_or_cross_a_high_detour() -> void:
	var ctx := fixture(true)
	ctx.buildings.structures.remove_at(0)
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[0]).water)).is_equal(0.0)
	var lower := fixture()
	lower.network.remove("water", Vector2i(-7, 8))
	for x in range(-8, -5): pipe(lower, Vector2i(x, 6))
	for y in range(6, 9):
		pipe(lower, Vector2i(-8, y))
		pipe(lower, Vector2i(-6, y))
	lower.hydraulics.advance(1, lower, 0)
	assert_float(float(lower.industry.state(lower.buildings.structures[0]).water)).is_equal(0.0)

func test_inline_pump_requires_power_and_separates_both_sides() -> void:
	var ctx := fixture(true)
	var pump: Dictionary = ctx.buildings.structures[0]
	var tank: Dictionary = ctx.buildings.structures[1]
	ctx.energy = false
	ctx.hydraulics.advance(1, ctx, 1)
	assert_float(float(ctx.industry.state(tank).water)).is_equal(0.0)
	ctx.energy = true
	ctx.hydraulics.advance(1, ctx, 1)
	assert_float(float(ctx.industry.state(tank).water)).is_greater(0.0)
	assert_float(float(ctx.industry.state(tank).water)).is_less_equal(0.700001)
	assert_float(stored(ctx)).is_equal_approx(1.0, 0.00001)
	assert_vector(ctx.hydraulics.pump_ports(pump).input).is_equal(Vector2i(-9, 8))
	assert_vector(ctx.hydraulics.pump_ports(pump).output).is_equal(Vector2i(-7, 8))

func test_pump_lift_limit_and_buffer_capacity() -> void:
	var ctx := fixture(true, 7)
	var pump: Dictionary = ctx.buildings.structures[0]
	ctx.industry.state(pump).water = 7.99
	ctx.hydraulics.advance(2, ctx, 2)
	assert_float(float(ctx.industry.state(pump).water)).is_equal_approx(8.0, 0.00001)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[1]).water)).is_equal(0.0)
	assert_float(stored(ctx)).is_equal_approx(8.99, 0.00001)

func test_pump_cannot_draw_from_source_on_output_side() -> void:
	var ctx := fixture(true)
	ctx.hydraulics.valves.clear()
	ctx.environment.water.clear()
	valve(ctx, Vector2i(-3, 8), Vector2i(-2, 8))
	ctx.hydraulics.advance(3, ctx, 3)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[0]).water)).is_equal(0.0)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[1]).water)).is_equal(0.0)

func test_vertical_direction_inference_reversal_and_perpendicular_rejection() -> void:
	var ctx := context()
	for y in range(7, 10): pipe(ctx, Vector2i(-15, y))
	var pump := machine(ctx, "pump", Vector2i(-15, 8))
	assert_str(ctx.hydraulics.pump_placement_blocker(pump.origin, ctx)).is_empty()
	ctx.hydraulics.synchronize(ctx)
	assert_int(absi(ctx.hydraulics.pump_direction(pump).y)).is_equal(1)
	assert_bool(ctx.hydraulics.set_pump_direction(pump, Vector2i.UP, ctx)).is_true()
	assert_vector(ctx.hydraulics.pump_ports(pump).input).is_equal(Vector2i(-15, 9))
	assert_bool(ctx.hydraulics.reverse_pump(pump, ctx)).is_true()
	assert_vector(ctx.hydraulics.pump_ports(pump).output).is_equal(Vector2i(-15, 9))
	assert_bool(ctx.hydraulics.set_pump_direction(pump, Vector2i.RIGHT, ctx)).is_false()

func test_pump_placement_rejects_isolated_elbow_junction_but_accepts_end() -> void:
	var ctx := context()
	var origin := Vector2i(-15, 10)
	assert_str(ctx.hydraulics.pump_placement_blocker(origin, ctx)).is_not_empty()
	pipe(ctx, origin)
	assert_str(ctx.hydraulics.pump_placement_blocker(origin, ctx)).is_not_empty()
	pipe(ctx, origin + Vector2i.LEFT)
	assert_str(ctx.hydraulics.pump_placement_blocker(origin, ctx)).is_empty()
	pipe(ctx, origin + Vector2i.DOWN)
	assert_str(ctx.hydraulics.pump_placement_blocker(origin, ctx)).is_not_empty()
	ctx.network.remove("water", origin + Vector2i.DOWN)
	pipe(ctx, origin + Vector2i.RIGHT)
	assert_str(ctx.hydraulics.pump_placement_blocker(origin, ctx)).is_empty()
	pipe(ctx, origin + Vector2i.UP)
	assert_str(ctx.hydraulics.pump_placement_blocker(origin, ctx)).is_not_empty()

func test_multiple_branches_share_finite_source_and_fill_bounds() -> void:
	var ctx := fixture(true)
	var tank: Dictionary = ctx.buildings.structures[1]
	ctx.industry.state(tank).water = 31.99
	pipe(ctx, Vector2i(-5, 7))
	pipe(ctx, Vector2i(-5, 6))
	var greenhouse := machine(ctx, "greenhouse", Vector2i(-5, 6), 3.99)
	var before := stored(ctx)
	for index in range(100): ctx.hydraulics.advance(0.01, ctx, 0.01)
	assert_float(stored(ctx)).is_equal_approx(before, 0.00001)
	assert_float(float(ctx.industry.state(tank).water)).is_less_equal(32.0)
	assert_float(float(ctx.industry.state(greenhouse).water)).is_less_equal(4.0)

func test_greenhouse_consumes_own_buffer_even_when_disconnected() -> void:
	var ctx := context()
	var greenhouse := machine(ctx, "greenhouse", Vector2i(-10, 8), 0.4)
	machine(ctx, "pump", Vector2i(-8, 8), 8)
	assert_float(ctx.hydraulics.deliverable(greenhouse, ctx)).is_equal_approx(0.4, 0.00001)
	assert_float(ctx.hydraulics.withdraw(greenhouse, 0.3, ctx)).is_equal_approx(0.3, 0.00001)
	assert_float(ctx.hydraulics.withdraw(greenhouse, 0.3, ctx)).is_equal_approx(0.1, 0.00001)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[1]).water)).is_equal(8.0)
	assert_float(ctx.hydraulics.withdraw(greenhouse, NAN, ctx)).is_equal(0.0)

func test_ship_ports_use_independent_campaign_or_sandbox_tanks() -> void:
	for campaign: bool in [false, true]:
		var ctx := context(campaign)
		assert_int(ctx.hydraulics.ship_ports().size()).is_equal(2)
		assert_dict(ctx.hydraulics.at(Vector2i(-6, -3))).is_equal({"kind": "ship", "cell": Vector2i(-6, -3), "opened": true, "total": 0.0, "id": "left"})
		assert_str(ctx.hydraulics.at(Vector2i(5, -3)).id).is_equal("right")
		var tanks: Dictionary = ctx.get("ship_state").water_tanks if campaign else ctx.hydraulics.local_ship_water
		tanks.left = 40.0
		for y in range(-3, 2): pipe(ctx, Vector2i(-7, y))
		var tank := machine(ctx, "water_tank", Vector2i(-7, 1))
		ctx.hydraulics.advance(1, ctx, 0)
		assert_float(float(ctx.industry.state(tank).water)).is_equal_approx(0.35, 0.00001)
		assert_float(float(tanks.left)).is_equal_approx(39.65, 0.00001)
		assert_float(float(tanks.right)).is_equal(0.0)
		assert_float(stored(ctx)).is_equal_approx(40.0, 0.00001)

func test_mined_support_and_invalid_steps() -> void:
	var ctx := fixture()
	ctx.site.removed[Vector2i(-11, 8)] = true
	ctx.hydraulics.synchronize(ctx)
	assert_array(ctx.hydraulics.valves).is_empty()
	var before := stored(ctx)
	for delta: float in [NAN, INF, -1.0, 0.0]: ctx.hydraulics.advance(delta, ctx, 1)
	ctx.hydraulics.advance(1, ctx, NAN)
	assert_float(stored(ctx)).is_equal(before)

func test_v2_roundtrip_and_strict_atomic_validation() -> void:
	var ctx := fixture(true)
	ctx.hydraulics.set_pump_direction(ctx.buildings.structures[0], Vector2i.LEFT, ctx)
	ctx.hydraulics.local_ship_water.left = 12.5
	var saved: Dictionary = ctx.hydraulics.snapshot()
	var copy: RefCounted = load(MODEL).new()
	assert_bool(copy.restore(JSON.parse_string(JSON.stringify(saved)), ctx.site, ctx.buildings)).is_true()
	assert_dict(copy.snapshot()).is_equal(saved)
	for issue: String in ["duplicate", "empty", "fractional", "opened", "total", "unknown", "direction", "orphan", "tank", "extra"]:
		var bad := saved.duplicate(true)
		match issue:
			"duplicate": bad.valves.append(bad.valves[0].duplicate(true))
			"empty": bad.valves[0].cell = [-12, 8]
			"fractional": bad.valves[0].cell = [-11.5, 8]
			"opened": bad.valves[0].opened = 1
			"total": bad.valves[0].total = NAN
			"unknown": bad.valves[0].drilled = true
			"direction": bad.pumps["-8:8"] = [1, 1]
			"orphan": bad.pumps["20:20"] = [1, 0]
			"tank": bad.local_ship_water.left = 40.01
			"extra": bad.outlets = []
		assert_bool(copy.restore(bad, ctx.site, ctx.buildings)).is_false()
		assert_dict(copy.snapshot()).is_equal(saved)

func test_only_empty_payload_accepted_and_all_v1_payloads_rejected_atomically() -> void:
	var ctx := context()
	assert_bool(ctx.hydraulics.restore({}, ctx.site, ctx.buildings)).is_true()
	var saved: Dictionary = ctx.hydraulics.snapshot()
	assert_bool(ctx.hydraulics.restore({"version": 1, "valves": [], "outlets": [], "pumps": {}}, ctx.site, ctx.buildings)).is_false()
	assert_bool(ctx.hydraulics.restore({"version": 1, "valves": [{"kind": "valve"}], "outlets": [], "pumps": {}}, ctx.site, ctx.buildings)).is_false()
	assert_dict(ctx.hydraulics.snapshot()).is_equal(saved)

func test_valve_receives_only_into_known_cavity_and_survives_empty_roundtrip() -> void:
	var ctx := context()
	var entry := valve(ctx, Vector2i(-11, 8), Vector2i(-12, 8), 0.1)
	ctx.environment.water[Vector2i(-12, 8)] = 0.0
	# A second adjacent empty cell is a dry tunnel, not a water destination.
	pipe(ctx, Vector2i(-10, 8))
	ctx.site.removed[Vector2i(-11, 9)] = true
	for y in range(4, 9): pipe(ctx, Vector2i(-10, y))
	var tank := machine(ctx, "water_tank", Vector2i(-10, 4), 1.0)
	var saved: Dictionary = ctx.hydraulics.snapshot()
	assert_bool(ctx.hydraulics.restore(JSON.parse_string(JSON.stringify(saved)), ctx.site, ctx.buildings)).is_true()
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(float(ctx.environment.water.get(Vector2i(-12, 8), 0))).is_equal_approx(0.35, 0.00001)
	assert_float(float(ctx.environment.water.get(Vector2i(-11, 9), 0))).is_equal(0.0)
	assert_float(float(ctx.industry.state(tank).water)).is_equal_approx(0.65, 0.00001)
	assert_bool(ctx.hydraulics.at(entry.cell).opened).is_true()

func test_multiple_pumps_cannot_multiply_source_or_output_budget() -> void:
	var ctx := fixture(true)
	# Both pumps draw from the same input trunk, but have independent output branches.
	for y in range(8, 12): pipe(ctx, Vector2i(-9, y))
	for x in range(-9, -3): pipe(ctx, Vector2i(x, 11))
	var other := machine(ctx, "pump", Vector2i(-8, 11))
	var other_tank := machine(ctx, "water_tank", Vector2i(-4, 11))
	ctx.hydraulics.advance(1, ctx, 1)
	assert_float(stored(ctx)).is_equal_approx(1.0, 0.00001)
	assert_float(float(ctx.environment.water[Vector2i(-12, 8)])).is_greater_equal(0.299999)
	assert_float(float(ctx.industry.state(other).water)).is_less_equal(0.700001)
	assert_float(float(ctx.industry.state(other_tank).water)).is_less_equal(0.700001)

func test_planned_pump_is_not_a_barrier_or_endpoint_and_planned_tank_cannot_fill() -> void:
	var ctx := fixture()
	var pump := machine(ctx, "pump", Vector2i(-8, 8))
	pump.state = "planned"
	ctx.hydraulics.advance(1, ctx, 1)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[0]).water)).is_equal_approx(0.35, 0.00001)
	assert_float(float(ctx.industry.state(pump).water)).is_equal(0.0)
	ctx.buildings.structures[0].state = "planned"
	var before := stored(ctx)
	ctx.hydraulics.advance(1, ctx, 1)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[0]).water)).is_equal_approx(0.35, 0.00001)
	assert_float(stored(ctx)).is_equal_approx(before, 0.00001)

func test_ship_port_can_close_reopen_and_roundtrip_without_removal() -> void:
	var ctx := context()
	var entry: Dictionary = ctx.hydraulics.at(Vector2i(-6, -3))
	ctx.hydraulics.local_ship_water.left = 1.0
	for y in range(-3, 2): pipe(ctx, Vector2i(-7, y))
	var tank := machine(ctx, "water_tank", Vector2i(-7, 1))
	assert_bool(ctx.hydraulics.toggle(entry, ctx)).is_true()
	var saved: Dictionary = ctx.hydraulics.snapshot()
	assert_bool(ctx.hydraulics.restore(saved, ctx.site, ctx.buildings)).is_true()
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(float(ctx.industry.state(tank).water)).is_equal(0.0)
	assert_bool(ctx.hydraulics.remove(ctx.hydraulics.at(entry.cell), ctx)).is_false()
	assert_bool(ctx.hydraulics.toggle(ctx.hydraulics.at(entry.cell), ctx)).is_true()
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(float(ctx.industry.state(tank).water)).is_equal_approx(0.35, 0.00001)

func test_catalog_capacity_changes_bound_actual_pump_tank_and_irrigation_fill() -> void:
	var catalog = load("res://scripts/data/industry_catalog.gd")
	var original: Dictionary = catalog.load_data().duplicate(true)
	catalog.cached.pump_capacity = 0.4
	catalog.cached.water_tank_capacity = 0.2
	catalog.cached.greenhouse_capacity = 0.1
	var pumped := fixture(true, 7)
	pumped.industry.state(pumped.buildings.structures[0]).water = 0.39
	pumped.hydraulics.advance(1, pumped, 1)
	var pump_water: float = pumped.industry.state(pumped.buildings.structures[0]).water
	var pump_capacity: float = pumped.hydraulics.capacity()
	var passive := fixture()
	passive.hydraulics.advance(1, passive, 0)
	var tank_water: float = passive.industry.state(passive.buildings.structures[0]).water
	var irrigation := fixture()
	irrigation.buildings.structures.clear()
	var greenhouse := machine(irrigation, "greenhouse", Vector2i(-4, 11))
	irrigation.hydraulics.advance(1, irrigation, 0)
	var greenhouse_water: float = irrigation.industry.state(greenhouse).water
	catalog.cached = original
	assert_float(pump_capacity).is_equal_approx(0.4, 0.00001)
	assert_float(pump_water).is_equal_approx(0.4, 0.00001)
	assert_float(tank_water).is_equal_approx(0.2, 0.00001)
	assert_float(greenhouse_water).is_equal_approx(0.1, 0.00001)

func test_pumped_cavity_fill_cannot_overshoot_the_six_metre_head() -> void:
	var ctx := fixture(true, 6)
	ctx.buildings.structures.pop_back()
	ctx.network.remove("water", Vector2i(-4, 2))
	ctx.site.removed.erase(Vector2i(-4, 2))
	valve(ctx, Vector2i(-4, 2), Vector2i(-3, 2), 0.1)
	ctx.industry.state(ctx.buildings.structures[0]).water = 8.0
	var before := stored(ctx)
	ctx.hydraulics.advance(2, ctx, 2)
	# Pump head 8.5 - 6 = 2.5; this cavity's bottom is 3, so at most 0.5 fits.
	assert_float(float(ctx.environment.water[Vector2i(-3, 2)])).is_equal_approx(0.5, 0.00001)
	assert_float(stored(ctx)).is_equal_approx(before, 0.00001)

func test_adjacent_aligned_pumps_fill_second_buffer_then_deliver_without_loss() -> void:
	var ctx := fixture(true)
	var tank: Dictionary = ctx.buildings.structures[1]
	var second := machine(ctx, "pump", Vector2i(-7, 8))
	assert_str(ctx.hydraulics.pump_placement_blocker(Vector2i(-8, 8), ctx)).is_empty()
	assert_str(ctx.hydraulics.pump_placement_blocker(Vector2i(-7, 8), ctx)).is_empty()
	ctx.hydraulics.advance(0.4, ctx, 0.4)
	assert_float(float(ctx.industry.state(second).water)).is_greater(0.0)
	assert_float(stored(ctx)).is_equal_approx(1.0, 0.00001)
	ctx.hydraulics.advance(1, ctx, 1)
	assert_float(float(ctx.industry.state(tank).water)).is_greater(0.0)
	assert_float(float(ctx.industry.state(tank).water)).is_less_equal(0.700001)
	assert_float(stored(ctx)).is_equal_approx(1.0, 0.00001)

func test_adjacent_pumps_cannot_handoff_when_either_is_reversed_off_or_unpowered() -> void:
	for mode: String in ["first_reverse", "second_reverse", "first_off", "second_off", "unpowered"]:
		var ctx := fixture(true)
		var first: Dictionary = ctx.buildings.structures[0]
		var tank: Dictionary = ctx.buildings.structures[1]
		var second := machine(ctx, "pump", Vector2i(-7, 8))
		ctx.industry.state(first).water = 0.5
		match mode:
			"first_reverse": assert_bool(ctx.hydraulics.reverse_pump(first, ctx)).is_true()
			"second_reverse": assert_bool(ctx.hydraulics.reverse_pump(second, ctx)).is_true()
			"first_off": first.enabled = false
			"second_off": second.enabled = false
			"unpowered": ctx.energy = false
		ctx.hydraulics.advance(2, ctx, 2)
		assert_float(float(ctx.industry.state(second).water)).is_equal(0.0)
		assert_float(float(ctx.industry.state(tank).water)).is_equal(0.0)
		assert_float(stored(ctx)).is_equal_approx(1.5, 0.00001)
