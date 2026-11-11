extends GdUnitTestSuite

const MODEL := "res://scripts/systems/water_circuit.gd"
const Site = preload("res://scripts/systems/dig_site.gd")
const Field = preload("res://scripts/systems/environment_field.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const Industry = preload("res://scripts/systems/industry_state.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const Tools = preload("res://scripts/data/digital_tool_catalog.gd")

class Context extends Node2D:
	var world: Node2D = self
	var site := Site.new()
	var environment := Field.new(site)
	var network := Network.new()
	var buildings := Buildings.new()
	var industry := Industry.new()
	var field_cargo := Cargo.new()
	var hydraulics: RefCounted
	var energy := 60.0
	var tool_id := "pulse"
	func _init() -> void:
		field_cargo.enable_drone_only(200)
		field_cargo.drone = {"structural_component": 100, "electronic_component": 100}
	func laboratory_unlocked() -> bool: return true
	func reachable_cell(cell: Vector2i, _reach: float = 3) -> bool: return site.contains(cell) and site.material(cell).is_empty()
	func drone_help_available() -> bool: return true
	func device_powered(building: Dictionary) -> bool: return Buildings.is_active(building) and building.get("enabled", true) and energy > 0
	func environment_safe(_building: Dictionary) -> bool: return true
	func site_reachable(_building: Dictionary) -> bool: return true
	func active_tool() -> Resource: return Tools.find(tool_id)
	func _note(_text: String) -> void: pass
	func guide_event(_id: String) -> void: pass

func context() -> Context:
	var result := Context.new()
	auto_free(result)
	result.hydraulics = load(MODEL).new()
	return result

func carve(ctx: Context, cell: Vector2i) -> void:
	ctx.site.removed[cell] = true

func pipe(ctx: Context, cell: Vector2i) -> void:
	carve(ctx, cell)
	ctx.network.add("water", cell)

func amount(field: Dictionary) -> float:
	var total := 0.0
	for value in field.values(): total += float(value)
	return total

func gravity_fixture() -> Context:
	var ctx := context()
	carve(ctx, Vector2i(1, 3))
	ctx.hydraulics.place("valve", Vector2i(1, 3), Vector2i.RIGHT, ctx)
	for y in range(3, 7): pipe(ctx, Vector2i(1, y))
	carve(ctx, Vector2i(0, 6))
	ctx.hydraulics.place("outlet", Vector2i(1, 6), Vector2i.LEFT, ctx)
	ctx.hydraulics.drill(ctx.hydraulics.valves[0], ctx)
	ctx.hydraulics.toggle(ctx.hydraulics.valves[0], ctx)
	ctx.hydraulics.toggle(ctx.hydraulics.outlets[0], ctx)
	return ctx

func test_sealed_water_circuit_model_exists() -> void:
	assert_bool(FileAccess.file_exists(MODEL)).is_true()

func test_all_four_faces_can_be_tapped_without_breaching_or_mining() -> void:
	if not FileAccess.file_exists(MODEL): return
	for face: Array in [[Vector2i(1, 3), Vector2i.RIGHT], [Vector2i(6, 3), Vector2i.LEFT], [Vector2i(3, 1), Vector2i.DOWN], [Vector2i(3, 6), Vector2i.UP]]:
		var ctx := context()
		carve(ctx, face[0])
		var anchor: Vector2i = face[0] + face[1]
		var before := ctx.site.snapshot()
		assert_bool(ctx.hydraulics.place("valve", face[0], face[1], ctx)).is_true()
		assert_bool(ctx.hydraulics.valves[0].opened).is_false()
		assert_bool(ctx.hydraulics.drill(ctx.hydraulics.valves[0], ctx)).is_true()
		assert_array(ctx.site.snapshot()).is_equal(before)
		assert_bool(ctx.site.material(anchor).is_empty()).is_false()
		ctx.environment.detect_breaches()
		assert_bool(ctx.environment.released.has("water_east")).is_false()

func test_gravity_outlet_transfers_real_water_without_deleting_or_duplicating() -> void:
	if not FileAccess.file_exists(MODEL): return
	var ctx := gravity_fixture()
	var before := amount(ctx.environment.water)
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(float(ctx.environment.water.get(Vector2i(0, 6), 0))).is_greater(0)
	assert_float(amount(ctx.environment.water)).is_equal_approx(before, 0.00001)
	assert_bool(ctx.environment.released.has("water_east")).is_false()
	ctx.hydraulics.toggle(ctx.hydraulics.valves[0], ctx)
	var frozen: Dictionary = ctx.environment.water.duplicate()
	ctx.hydraulics.advance(1, ctx, 0)
	assert_dict(ctx.environment.water).is_equal(frozen)

func test_disconnected_full_and_contaminated_outlets_stop_without_loss() -> void:
	if not FileAccess.file_exists(MODEL): return
	var ctx := gravity_fixture()
	ctx.environment.oil[Vector2i(0, 6)] = 1.0
	var before: Dictionary = ctx.environment.water.duplicate()
	ctx.hydraulics.advance(1, ctx, 0)
	assert_dict(ctx.environment.water).is_equal(before)
	ctx.environment.oil.clear()
	ctx.network.remove("water", Vector2i(1, 4))
	ctx.hydraulics.advance(1, ctx, 0)
	assert_dict(ctx.environment.water).is_equal(before)
	ctx.network.remove("water", Vector2i(1, 3))
	ctx.hydraulics.advance(1, ctx, 0)
	assert_bool(ctx.hydraulics.valves[0].opened).is_false()

func test_gravity_cannot_lift_or_cross_a_high_pipe_route() -> void:
	if not FileAccess.file_exists(MODEL): return
	var ctx := gravity_fixture()
	ctx.hydraulics.outlets.clear()
	for y in range(1, 4): pipe(ctx, Vector2i(1, y))
	carve(ctx, Vector2i(0, 1))
	ctx.hydraulics.place("outlet", Vector2i(1, 1), Vector2i.LEFT, ctx)
	ctx.hydraulics.toggle(ctx.hydraulics.outlets[0], ctx)
	var before: Dictionary = ctx.environment.water.duplicate()
	ctx.hydraulics.advance(2, ctx, 0)
	assert_dict(ctx.environment.water).is_equal(before)

func pump_fixture() -> Context:
	var ctx := context()
	ctx.environment.water.clear()
	var source := Vector2i(-6, 5)
	carve(ctx, source)
	ctx.environment.water[source] = 1.0
	carve(ctx, Vector2i(-4, 5))
	ctx.hydraulics.place("valve", Vector2i(-4, 5), Vector2i.LEFT, ctx)
	for x in range(-4, 1): pipe(ctx, Vector2i(x, 5))
	for y in range(1, 6): pipe(ctx, Vector2i(0, y))
	for x in range(-2, 0): carve(ctx, Vector2i(x, 4))
	ctx.buildings.install("pump", Vector2i(-2, 4))
	carve(ctx, Vector2i(1, 1))
	ctx.hydraulics.place("outlet", Vector2i(0, 1), Vector2i.RIGHT, ctx)
	ctx.hydraulics.drill(ctx.hydraulics.valves[0], ctx)
	ctx.hydraulics.toggle(ctx.hydraulics.valves[0], ctx)
	ctx.hydraulics.toggle(ctx.hydraulics.outlets[0], ctx)
	return ctx

func test_pump_separates_ports_and_requires_energy_to_lift() -> void:
	if not FileAccess.file_exists(MODEL): return
	var ctx := pump_fixture()
	var before := amount(ctx.environment.water)
	ctx.energy = 0
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(float(ctx.environment.water.get(Vector2i(1, 1), 0))).is_equal(0.0)
	ctx.energy = 60
	ctx.hydraulics.advance(1, ctx, 1)
	assert_float(float(ctx.environment.water.get(Vector2i(1, 1), 0))).is_greater(0)
	var stored: float = ctx.industry.state(ctx.buildings.structures[0]).water
	assert_float(amount(ctx.environment.water) + stored).is_equal_approx(before, 0.00001)
	assert_bool(ctx.hydraulics.reverse_pump(ctx.buildings.structures[0], ctx)).is_true()
	assert_vector(ctx.hydraulics.pump_ports(ctx.buildings.structures[0]).input).is_equal(Vector2i(-1, 5))

func test_multiple_outlets_and_tiny_steps_conserve_finite_volume() -> void:
	if not FileAccess.file_exists(MODEL): return
	var ctx := gravity_fixture()
	pipe(ctx, Vector2i(2, 6))
	carve(ctx, Vector2i(3, 6))
	ctx.hydraulics.place("outlet", Vector2i(2, 6), Vector2i.RIGHT, ctx)
	ctx.hydraulics.toggle(ctx.hydraulics.outlets[1], ctx)
	var total := amount(ctx.environment.water)
	for index in range(100): ctx.hydraulics.advance(0.01, ctx, 0)
	assert_float(amount(ctx.environment.water)).is_equal_approx(total, 0.00001)
	var before: Dictionary = ctx.environment.water.duplicate()
	ctx.hydraulics.advance(NAN, ctx, 0)
	ctx.hydraulics.advance(-1, ctx, 0)
	assert_dict(ctx.environment.water).is_equal(before)

func test_restore_is_strict_transactional_and_preserves_controls() -> void:
	if not FileAccess.file_exists(MODEL): return
	var ctx := gravity_fixture()
	ctx.hydraulics.advance(0.2, ctx, 0)
	var saved: Dictionary = ctx.hydraulics.snapshot()
	var copy = load(MODEL).new()
	assert_bool(copy.restore(JSON.parse_string(JSON.stringify(saved)), ctx.site, ctx.buildings)).is_true()
	assert_str(JSON.stringify(copy.snapshot())).is_equal(JSON.stringify(saved))
	for property: String in ["opened", "direction", "total"]:
		var bad := saved.duplicate(true)
		bad.valves[0][property] = {"opened": 1, "direction": [0.5, 1], "total": -1}[property]
		assert_bool(copy.restore(bad, ctx.site, ctx.buildings)).is_false()
		assert_str(JSON.stringify(copy.snapshot())).is_equal(JSON.stringify(saved))

func test_stopped_pump_is_a_real_barrier_even_for_downhill_gravity() -> void:
	var ctx := pump_fixture()
	ctx.hydraulics.outlets.clear()
	pipe(ctx, Vector2i(0, 6))
	carve(ctx, Vector2i(1, 6))
	ctx.hydraulics.place("outlet", Vector2i(0, 6), Vector2i.RIGHT, ctx)
	ctx.hydraulics.toggle(ctx.hydraulics.outlets[0], ctx)
	ctx.energy = 0
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(float(ctx.environment.water.get(Vector2i(1, 6), 0))).is_equal(0.0)
	assert_float(float(ctx.environment.water.get(Vector2i(-6, 5), 0))).is_equal(1.0)

func test_unpaid_pump_plan_does_not_interrupt_existing_gravity_pipe() -> void:
	var ctx := pump_fixture()
	ctx.hydraulics.outlets.clear()
	pipe(ctx, Vector2i(0, 6))
	carve(ctx, Vector2i(1, 6))
	ctx.hydraulics.place("outlet", Vector2i(0, 6), Vector2i.RIGHT, ctx)
	ctx.hydraulics.toggle(ctx.hydraulics.outlets[0], ctx)
	ctx.buildings.structures[0].state = "planned"
	ctx.energy = 0
	ctx.hydraulics.advance(1, ctx, 0)
	assert_float(float(ctx.environment.water.get(Vector2i(1, 6), 0))).is_greater(0.0)

func test_full_pump_buffer_and_high_discharge_preserve_water() -> void:
	var ctx := pump_fixture()
	var pump: Dictionary = ctx.buildings.structures[0]
	pump.origin = Vector2i(-2, 10)
	for y in range(5, 12):
		pipe(ctx, Vector2i(-3, y))
		pipe(ctx, Vector2i(0, y))
	pipe(ctx, Vector2i(-2, 11))
	pipe(ctx, Vector2i(-1, 11))
	ctx.industry.state(pump).water = 7.99
	var before := amount(ctx.environment.water) + 7.99
	ctx.hydraulics.advance(1, ctx, 1)
	assert_float(float(ctx.environment.water.get(Vector2i(1, 1), 0))).is_equal(0.0)
	assert_float(float(ctx.industry.state(pump).water)).is_equal_approx(8.0, 0.00001)
	assert_float(amount(ctx.environment.water) + float(ctx.industry.state(pump).water)).is_equal_approx(before, 0.00001)

func test_gravity_rejects_high_detour_even_when_outlet_is_lower() -> void:
	var ctx := gravity_fixture()
	ctx.network.cells.water.clear()
	for y in range(1, 4): pipe(ctx, Vector2i(1, y))
	for x in range(1, 5): pipe(ctx, Vector2i(x, 1))
	for y in range(1, 7): pipe(ctx, Vector2i(4, y))
	for x in range(1, 5): pipe(ctx, Vector2i(x, 6))
	var before: Dictionary = ctx.environment.water.duplicate()
	ctx.hydraulics.advance(1, ctx, 0)
	assert_dict(ctx.environment.water).is_equal(before)

func test_broken_anchor_releases_falda_and_invalid_restore_is_atomic() -> void:
	var ctx := gravity_fixture()
	carve(ctx, Vector2i(2, 3))
	ctx.hydraulics.synchronize(ctx)
	assert_array(ctx.hydraulics.valves).is_empty()
	ctx.environment.detect_breaches()
	assert_bool(ctx.environment.released.has("water_east")).is_true()
	var fresh := gravity_fixture()
	var original: Dictionary = fresh.hydraulics.snapshot()
	for issue: String in ["duplicate", "solid", "nan", "pump"]:
		var bad := original.duplicate(true)
		match issue:
			"duplicate": bad.valves.append(bad.valves[0].duplicate(true))
			"solid": bad.outlets[0].cell = [20, 20]
			"nan": bad.valves[0].total = NAN
			"pump": bad.pumps["0:0"] = true
		assert_bool(fresh.hydraulics.restore(bad, fresh.site, fresh.buildings)).is_false()
		assert_dict(fresh.hydraulics.snapshot()).is_equal(original)

func test_open_pool_intake_requires_explicit_terminal_role_and_conserves_volume() -> void:
	var ctx := pump_fixture()
	ctx.hydraulics.valves.clear()
	ctx.environment.water.clear()
	carve(ctx, Vector2i(-5, 5))
	ctx.environment.water[Vector2i(-5, 5)] = 1.0
	ctx.hydraulics.place("outlet", Vector2i(-4, 5), Vector2i.LEFT, ctx)
	var intake: Dictionary = ctx.hydraulics.outlets[1]
	assert_bool(ctx.hydraulics.has_method("set_role")).is_true()
	if not ctx.hydraulics.has_method("set_role"): return
	assert_bool(ctx.hydraulics.set_role(intake, "intake", ctx)).is_true()
	assert_bool(intake.opened).is_false()
	ctx.hydraulics.toggle(intake, ctx)
	ctx.hydraulics.advance(0.5, ctx, 0.5)
	assert_float(float(ctx.environment.water.get(Vector2i(1, 1), 0))).is_greater(0)
	assert_float(amount(ctx.environment.water) + float(ctx.industry.state(ctx.buildings.structures[0]).water)).is_equal_approx(1.0, 0.00001)

func test_outlets_and_multiple_receivers_share_one_pump_delivery_budget() -> void:
	var ctx := pump_fixture()
	var pump: Dictionary = ctx.buildings.structures[0]
	var receiver := {"id": "greenhouse", "origin": Vector2i(0, -1)}
	ctx.hydraulics.valves[0].opened = false
	ctx.industry.state(pump).water = 8.0
	assert_bool(ctx.hydraulics.has_method("deliverable")).is_true()
	if not ctx.hydraulics.has_method("deliverable"): return
	ctx.hydraulics.advance(1, ctx, 1)
	assert_float(ctx.hydraulics.deliverable(receiver, ctx)).is_equal_approx(0.0, 0.00001)
	ctx.hydraulics.outlets[0].opened = false
	ctx.hydraulics.advance(1, ctx, 1)
	var first: float = ctx.hydraulics.withdraw(receiver, 0.6, ctx)
	var second: float = ctx.hydraulics.withdraw(receiver, 0.6, ctx)
	assert_float(first + second).is_equal_approx(0.7, 0.00001)

func test_device_limit_rejects_placement_before_paying() -> void:
	var ctx := context()
	carve(ctx, Vector2i(1, 3))
	for index in range(200): ctx.hydraulics.outlets.append({"cell": Vector2i(-20, 0)})
	var before: Dictionary = ctx.field_cargo.snapshot()
	assert_bool(ctx.hydraulics.place("valve", Vector2i(1, 3), Vector2i.RIGHT, ctx)).is_false()
	assert_dict(ctx.field_cargo.snapshot()).is_equal(before)
