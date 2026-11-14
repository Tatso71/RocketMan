extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var world: Node2D
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func prepare_pipe(cell: Vector2i) -> void:
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2): Fixture.carve(world, Vector2i(x, y))
	for offset in [-1, 0, 1]: world.outpost.network.add("water", cell + Vector2i(offset, 0))
	world.player.position = Grid.center(cell) + Vector2(-40, world.player.body_size().y / 2)
	for index in range(3): await physics_frame

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/robbie_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	for kind: String in ["water", "gas", "oil", "acid"]: world.environment.get(kind).clear()
	var outpost: Node2D = world.outpost
	var lab_origin := Vector2i(-12, 1)
	for x in range(-12, -8):
		for y in range(1, 4): Fixture.carve(world, Vector2i(x, y))
	var lab: Dictionary = outpost.buildings.install("laboratory", lab_origin)
	check(outpost.operational(lab), "fixture laboratory is active and genuinely powered")
	var near := Vector2i(-1, 1)
	await prepare_pipe(near)
	check(outpost.buildings.world_rect(lab).get_center().distance_to(Grid.center(near)) > Grid.metres(9), "reproduce a straight pipe over nine metres from the laboratory")
	check(outpost.placement_blocker("pump", near).is_empty(), "pump blueprint can be placed beyond the old eight-metre laboratory radius")
	var far := Vector2i(0, 20)
	await prepare_pipe(far)
	check(outpost.placement_blocker("pump", far).is_empty(), "pump can also be placed deep underground beyond the old ship-link radius")
	world.field_cargo.drone = {"structural_component": 2, "electronic_component": 2}
	var placed: bool = outpost.place("pump", far)
	check(placed, "real placement API accepts the distant pump")
	var pump: Dictionary = outpost.buildings.structures.back() if placed else outpost.buildings.plan("pump", far)
	var paid: bool = outpost.fund_site(pump)
	check(paid, "distant assembly accepts real carried components without a hidden radius gate")
	var before: float = world.ship_energy()
	if paid: outpost.advance(outpost.Buildings.build_seconds("pump") + 0.1)
	check(pump.state == "active" and world.ship_energy() < before, "paid distant construction completes and consumes actual ship energy")
	if not paid:
		pump.state = "active"
		pump.progress = 1.0
	check(outpost.device_powered(pump) and outpost.supplying_lab(pump) == lab, "distant pump remains powered by an operational laboratory without proximity limits")
	var source := far + Vector2i(-4, 0)
	var valve_cell := source + Vector2i.RIGHT
	Fixture.carve(world, source)
	world.environment.water[source] = 1.0
	check(outpost.hydraulics.place("valve", valve_cell, outpost), "mount source valve for the distant pump circuit")
	for x in [-2, 2, 3]:
		Fixture.carve(world, far + Vector2i(x, 0))
		outpost.network.add("water", far + Vector2i(x, 0))
	var tank_origin := far + Vector2i(3, -1)
	for x in range(tank_origin.x, tank_origin.x + 2):
		for y in range(tank_origin.y, tank_origin.y + 2): Fixture.carve(world, Vector2i(x, y))
	var tank: Dictionary = outpost.buildings.install("water_tank", tank_origin)
	before = world.ship_energy()
	outpost.advance(1.0)
	check(float(outpost.industry.state(tank).water) > 0, "distant powered pump actually transfers water into its connected container")
	check(world.ship_energy() < before and outpost.consumption_for(pump) > 0, "removing distance limits does not grant free energy")
	world._set_ship_energy(0)
	check(not outpost.device_powered(pump), "empty ship battery still stops the pump")
	world._set_ship_energy(30)
	pump.enabled = false
	check(not outpost.device_powered(pump), "pump switch still disables distant operation")
	pump.enabled = true
	pump.damaged = true
	check(not outpost.device_powered(pump), "damage still disables distant operation")
	pump.damaged = false
	check(outpost.supplying_lab({"id": "fan", "origin": far}).is_empty(), "unrelated fan radius rules are not silently changed")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	check(world.restore_state(saved), "distant pump and finite water circuit survive real save/load validation")
	print("REMOTE PUMP POWER: %d failures" % failures)
	quit(1 if failures else 0)
