extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func volume() -> float:
	var total := 0.0
	for amount in world.environment.water.values(): total += float(amount)
	for b: Dictionary in world.outpost.buildings.structures:
		if b.id in ["pump", "water_tank", "greenhouse"]: total += float(world.outpost.industry.state(b).get("water", 0))
	for amount in world.outpost.hydraulics.local_ship_water.values(): total += float(amount)
	return total

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/robbie_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.guide_state.set_muted(true)
	for kind: String in ["water", "oil", "acid", "gas"]: world.environment.get(kind).clear()
	var outpost: Node2D = world.outpost
	for x in range(-12, -8):
		for y in range(1, 4): Fixture.carve(world, Vector2i(x, y))
	var lab: Dictionary = outpost.buildings.install("laboratory", Vector2i(-12, 1))
	check(outpost.operational(lab), "real laboratory powers hydraulic fixture")
	Fixture.carve(world, Vector2i(-4, 20))
	world.environment.water[Vector2i(-4, 20)] = 1.0
	check(outpost.hydraulics.place("valve", Vector2i(-3, 20), outpost), "real finite reservoir valve placed")
	for x in range(-2, 4):
		Fixture.carve(world, Vector2i(x, 20))
		outpost.network.add("water", Vector2i(x, 20))
	for x in range(3, 5):
		for y in range(19, 21): Fixture.carve(world, Vector2i(x, y))
	Fixture.carve(world, Vector2i(2, 21))
	outpost.network.add("water", Vector2i(2, 21))
	var pump: Dictionary = outpost.buildings.install("pump", Vector2i(0, 20))
	var tank: Dictionary = outpost.buildings.install("water_tank", Vector2i(3, 19))
	check(outpost.device_powered(pump), "inline pump receives real laboratory power")
	var before := volume()
	outpost.advance(0.4)
	var delivered := float(outpost.industry.state(tank).water)
	var output_flow := float(outpost.hydraulics.flow_between(Vector2i(0, 20), Vector2i(1, 20)))
	check(delivered > 0 and is_equal_approx(output_flow, delivered / 0.4), "output edge measures actual delivered units per whole tick")
	check(outpost.hydraulics.flow_between(Vector2i(-1, 20), Vector2i(0, 20)) > 0, "pump intake edge includes actual buffer fill")
	check(is_equal_approx(outpost.hydraulics.flow_between(Vector2i(1, 20), Vector2i(0, 20)), -output_flow), "reverse renderer query negates signed rate")
	check(is_zero_approx(outpost.hydraulics.flow_between(Vector2i(2, 20), Vector2i(2, 21))), "unused dangling branch remains still")
	check(absf(volume() - before) < 0.00001, "meter leaves real world water conservation unchanged")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	check(world.restore_state(saved), "existing real world save schema roundtrips with ephemeral meter")
	outpost = world.outpost
	check(is_zero_approx(outpost.hydraulics.flow_between(Vector2i(0, 20), Vector2i(1, 20))), "load clears the previous tick instead of restoring animation")
	pump = outpost.buildings.structures.filter(func(b: Dictionary): return b.id == "pump")[0]
	tank = outpost.buildings.structures.filter(func(b: Dictionary): return b.id == "water_tank")[0]
	outpost.network.remove("water", Vector2i(2, 20))
	outpost.advance(0.4)
	check(is_zero_approx(outpost.hydraulics.flow_between(Vector2i(0, 20), Vector2i(1, 20))), "cut output branch records no transfer")
	check(outpost.hydraulics.flow_between(Vector2i(-1, 20), Vector2i(0, 20)) > 0, "cut output still allows genuine pump buffer intake")
	pump.enabled = false
	outpost.advance(0.4)
	check(is_zero_approx(outpost.hydraulics.flow_between(Vector2i(-1, 20), Vector2i(0, 20))), "stopped pump clears intake animation on next tick")
	outpost.network.add("water", Vector2i(2, 20))
	pump.enabled = true
	outpost.industry.state(pump).water = 8.0
	outpost.industry.state(tank).water = 32.0
	world.environment.water[Vector2i(-4, 20)] = 1.0
	outpost.advance(0.4)
	check(is_zero_approx(outpost.hydraulics.flow_between(Vector2i(-1, 20), Vector2i(0, 20))) and is_zero_approx(outpost.hydraulics.flow_between(Vector2i(0, 20), Vector2i(1, 20))), "full buffer and receiver do not animate merely powered pipes")
	print("WATER EDGE FLOW: %d failures" % failures)
	quit(1 if failures else 0)
