extends GdUnitTestSuite

const Fixtures = preload("res://tests/unit/test_water_circuit.gd")
const Circuit = preload("res://scripts/systems/water_circuit.gd")

func context() -> Fixtures.Context:
	var ctx := Fixtures.Context.new()
	auto_free(ctx)
	ctx.hydraulics = Circuit.new()
	ctx.site.removed.clear()
	for kind: String in ["water", "oil", "acid", "gas"]: ctx.environment.get(kind).clear()
	return ctx

func pipe(ctx: Fixtures.Context, cell: Vector2i) -> void:
	ctx.site.removed[cell] = true
	ctx.network.add("water", cell)

func machine(ctx: Fixtures.Context, id: String, port: Vector2i, water: float = 0) -> Dictionary:
	var size: Vector2i = Fixtures.Buildings.SIZES.get(id, Vector2i.ONE)
	var origin := port - Vector2i(0, size.y - 1) if id != "pump" else port
	var b := {"id": id, "origin": origin, "state": "active", "enabled": true, "damaged": false, "drained": 0.0}
	ctx.buildings.structures.append(b)
	ctx.industry.state(b).water = water
	return b

func fixture(pumped: bool = false, target_y: int = 11) -> Fixtures.Context:
	var ctx := context()
	ctx.site.removed[Vector2i(-12, 8)] = true
	ctx.environment.water[Vector2i(-12, 8)] = 1.0
	assert_bool(ctx.hydraulics.place("valve", Vector2i(-11, 8), ctx)).is_true()
	for x in range(-10, -3): pipe(ctx, Vector2i(x, 8))
	for y in range(mini(8, target_y), maxi(8, target_y) + 1): pipe(ctx, Vector2i(-4, y))
	if pumped: machine(ctx, "pump", Vector2i(-8, 8))
	machine(ctx, "water_tank", Vector2i(-4, target_y))
	return ctx

func flow(ctx: Fixtures.Context, first: Vector2i, second: Vector2i) -> float:
	assert_bool(ctx.hydraulics.has_method("flow_between")).is_true()
	if not ctx.hydraulics.has_method("flow_between"): return 0.0
	var result: float = ctx.hydraulics.flow_between(first, second)
	assert_bool(is_finite(result)).is_true()
	return result

func test_passive_elbow_reports_signed_average_and_no_flow_on_unused_branch() -> void:
	var ctx := fixture()
	pipe(ctx, Vector2i(-7, 9))
	ctx.hydraulics.advance(0.5, ctx, 0)
	assert_float(flow(ctx, Vector2i(-11, 8), Vector2i(-10, 8))).is_equal_approx(0.35, 0.00001)
	assert_float(flow(ctx, Vector2i(-5, 8), Vector2i(-4, 8))).is_equal_approx(0.35, 0.00001)
	assert_float(flow(ctx, Vector2i(-4, 8), Vector2i(-4, 9))).is_equal_approx(0.35, 0.00001)
	assert_float(flow(ctx, Vector2i(-4, 9), Vector2i(-4, 8))).is_equal_approx(-0.35, 0.00001)
	assert_float(flow(ctx, Vector2i(-7, 8), Vector2i(-7, 9))).is_equal(0.0)
	assert_float(flow(ctx, Vector2i(-7, 8), Vector2i(-7, 8))).is_equal(0.0)
	assert_float(flow(ctx, Vector2i(-7, 8), Vector2i(-4, 8))).is_equal(0.0)
	assert_float(flow(ctx, Vector2i(-5, 8), Vector2i(-4, 9))).is_equal(0.0)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[0]).water)).is_equal_approx(0.175, 0.00001)

func test_dry_full_closed_and_disconnected_paths_report_zero() -> void:
	for mode: String in ["dry", "full", "closed", "cut"]:
		var ctx := fixture()
		match mode:
			"dry": ctx.environment.water[Vector2i(-12, 8)] = 0.0
			"full": ctx.industry.state(ctx.buildings.structures[0]).water = 32.0
			"closed": ctx.hydraulics.toggle(ctx.hydraulics.valves[0], ctx)
			"cut": ctx.network.remove("water", Vector2i(-6, 8))
		ctx.hydraulics.advance(1, ctx, 1)
		assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal(0.0)
		assert_float(flow(ctx, Vector2i(-4, 9), Vector2i(-4, 10))).is_equal(0.0)

func test_only_successful_route_in_parallel_loop_receives_flow() -> void:
	var ctx := fixture()
	for x in range(-8, -4): pipe(ctx, Vector2i(x, 9))
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(flow(ctx, Vector2i(-8, 8), Vector2i(-7, 8))).is_equal_approx(0.35, 0.00001)
	assert_float(flow(ctx, Vector2i(-8, 8), Vector2i(-8, 9))).is_equal(0.0)
	assert_float(flow(ctx, Vector2i(-7, 9), Vector2i(-6, 9))).is_equal(0.0)

func test_full_receiver_branch_stays_still_while_other_receiver_fills() -> void:
	var ctx := fixture()
	ctx.industry.state(ctx.buildings.structures[0]).water = 32.0
	for y in range(9, 11): pipe(ctx, Vector2i(-7, y))
	var greenhouse := machine(ctx, "greenhouse", Vector2i(-7, 10))
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(0.35, 0.00001)
	assert_float(flow(ctx, Vector2i(-7, 8), Vector2i(-7, 9))).is_equal_approx(0.35, 0.00001)
	assert_float(flow(ctx, Vector2i(-7, 8), Vector2i(-6, 8))).is_equal(0.0)
	assert_float(flow(ctx, Vector2i(-4, 8), Vector2i(-4, 9))).is_equal(0.0)
	assert_float(float(ctx.industry.state(greenhouse).water)).is_equal_approx(0.35, 0.00001)

func test_actual_reverse_transfer_changes_edge_sign_without_changing_query_order() -> void:
	var ctx := fixture(false, 4)
	ctx.environment.water[Vector2i(-12, 8)] = 0.0
	ctx.industry.state(ctx.buildings.structures[0]).water = 1.0
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(-0.35, 0.00001)
	assert_float(flow(ctx, Vector2i(-4, 5), Vector2i(-4, 6))).is_equal_approx(0.35, 0.00001)
	assert_float(float(ctx.environment.water[Vector2i(-12, 8)])).is_equal_approx(0.35, 0.00001)

func test_pump_input_output_include_buffer_delay_in_tick_average() -> void:
	var ctx := fixture(true, 4)
	ctx.hydraulics.advance(1, ctx, 1)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(0.7, 0.00001)
	assert_float(flow(ctx, Vector2i(-8, 8), Vector2i(-7, 8))).is_equal_approx(0.56, 0.00001)
	assert_float(flow(ctx, Vector2i(-4, 8), Vector2i(-4, 7))).is_equal_approx(0.56, 0.00001)
	assert_float(flow(ctx, Vector2i(-7, 8), Vector2i(-8, 8))).is_equal_approx(-0.56, 0.00001)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[1]).water)).is_equal_approx(0.56, 0.00001)

func test_adjacent_pump_handoff_edge_is_counted_once() -> void:
	var ctx := fixture(true, 4)
	machine(ctx, "pump", Vector2i(-7, 8))
	ctx.hydraulics.advance(0.6, ctx, 0.6)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(0.7, 0.00001)
	assert_float(flow(ctx, Vector2i(-8, 8), Vector2i(-7, 8))).is_equal_approx(0.28 / 0.6, 0.00001)
	assert_float(flow(ctx, Vector2i(-7, 8), Vector2i(-6, 8))).is_equal_approx(0.14 / 0.6, 0.00001)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[1]).water)).is_equal_approx(0.14, 0.00001)

func test_stopped_unpowered_and_damaged_pumps_do_not_imply_flow() -> void:
	for mode: String in ["off", "unpowered", "damaged", "no_powered_time"]:
		var ctx := fixture(true, 4)
		var pump: Dictionary = ctx.buildings.structures[0]
		ctx.industry.state(pump).water = 1.0
		match mode:
			"off": pump.enabled = false
			"unpowered": ctx.energy = false
			"damaged": pump.damaged = true
		ctx.hydraulics.advance(1, ctx, 0 if mode == "no_powered_time" else 1)
		assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal(0.0)
		assert_float(flow(ctx, Vector2i(-8, 8), Vector2i(-7, 8))).is_equal(0.0)

func test_passive_bypass_still_reports_real_flow_with_stopped_pump() -> void:
	var ctx := fixture(true)
	ctx.buildings.structures[0].enabled = false
	for x in range(-9, -5): pipe(ctx, Vector2i(x, 9))
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-9, 9))).is_equal_approx(0.35, 0.00001)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal(0.0)

func test_lift_limit_blocks_output_flow_but_keeps_real_pump_intake() -> void:
	var ctx := fixture(true, 1)
	ctx.hydraulics.advance(1, ctx, 1)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(0.7, 0.00001)
	assert_float(flow(ctx, Vector2i(-8, 8), Vector2i(-7, 8))).is_equal(0.0)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[1]).water)).is_equal(0.0)

func test_fractional_power_reports_actual_volume_over_whole_tick() -> void:
	var ctx := fixture(true, 4)
	ctx.hydraulics.advance(1, ctx, 0.5)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(0.35, 0.00001)
	assert_float(flow(ctx, Vector2i(-8, 8), Vector2i(-7, 8))).is_equal_approx(0.28, 0.00001)

func test_full_tick_average_is_not_last_substep_or_previous_tick() -> void:
	var ctx := fixture()
	ctx.industry.state(ctx.buildings.structures[0]).water = 31.99
	ctx.hydraulics.advance(2, ctx, 0)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(0.005, 0.00001)
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal(0.0)

func test_capped_simulation_still_averages_actual_transfer_over_requested_tick() -> void:
	var ctx := fixture()
	ctx.industry.state(ctx.buildings.structures[0]).water = 31.99
	ctx.hydraulics.advance(120, ctx, 0)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(0.01 / 120.0, 0.00000001)
	assert_float(float(ctx.industry.state(ctx.buildings.structures[0]).water)).is_equal_approx(32.0, 0.00001)

func test_valid_tick_clears_flow_after_cut_and_invalid_ticks_are_no_ops() -> void:
	var ctx := fixture()
	ctx.hydraulics.advance(1, ctx, 0)
	for delta: float in [NAN, INF, -1.0, 0.0]: ctx.hydraulics.advance(delta, ctx, 0)
	ctx.hydraulics.advance(1, ctx, NAN)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(0.35, 0.00001)
	ctx.network.remove("water", Vector2i(-6, 8))
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal(0.0)

func test_unchanged_topology_inspection_keeps_flow_and_retopology_clears_it() -> void:
	var ctx := fixture()
	ctx.hydraulics.advance(1, ctx, 0)
	ctx.hydraulics.pumps_for(ctx.buildings.structures[0], ctx)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(0.35, 0.00001)
	ctx.network.remove("water", Vector2i(-6, 8))
	ctx.hydraulics.pumps_for(ctx.buildings.structures[0], ctx)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal(0.0)

func test_remove_toggle_reverse_and_mined_valve_invalidate_flow() -> void:
	for mode: String in ["remove", "toggle", "reverse", "pump_toggle", "mined"]:
		var ctx := fixture(true, 4)
		ctx.hydraulics.advance(1, ctx, 1)
		match mode:
			"remove": ctx.hydraulics.remove(ctx.hydraulics.valves[0], ctx)
			"toggle": ctx.hydraulics.toggle(ctx.hydraulics.valves[0], ctx)
			"reverse": ctx.hydraulics.reverse_pump(ctx.buildings.structures[0], ctx)
			"pump_toggle": ctx.hydraulics.toggle_pump(ctx.buildings.structures[0], ctx)
			"mined":
				ctx.site.removed[Vector2i(-11, 8)] = true
				ctx.hydraulics.synchronize(ctx)
		assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal(0.0)

func test_flow_is_ephemeral_and_successful_restore_clears_it_atomically() -> void:
	var ctx := fixture()
	ctx.hydraulics.advance(1, ctx, 0)
	var saved: Dictionary = ctx.hydraulics.snapshot()
	assert_array(saved.keys()).contains_exactly(["version", "valves", "pumps", "local_ship_water", "cavities", "ship_opened"])
	var before := saved.duplicate(true)
	for index in range(100): flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))
	assert_dict(ctx.hydraulics.snapshot()).is_equal(before)
	assert_bool(ctx.hydraulics.restore({"bad": true}, ctx.site, ctx.buildings)).is_false()
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(0.35, 0.00001)
	assert_bool(ctx.hydraulics.restore(saved, ctx.site, ctx.buildings)).is_true()
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal(0.0)
	ctx.environment.water[Vector2i(-12, 8)] = 1.0
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal_approx(0.35, 0.00001)
	assert_bool(ctx.hydraulics.restore({}, ctx.site, ctx.buildings)).is_true()
	assert_float(flow(ctx, Vector2i(-9, 8), Vector2i(-8, 8))).is_equal(0.0)
