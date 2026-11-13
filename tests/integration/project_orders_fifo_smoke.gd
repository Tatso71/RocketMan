extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, text: String) -> void:
	print(("PASS: " if value else "FAIL: ") + text)
	if not value: failures += 1

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	world.environment.water.clear()
	world.environment.gas.clear()
	world.environment.oil.clear()
	world.environment.acid.clear()
	Fixture.lab_room(world)
	for y in range(7): Fixture.carve(world, Vector2i(0, y))
	for x in range(1, 10):
		for y in range(1, 4): Fixture.carve(world, Vector2i(x, y))
	world.outpost.buildings.install("laboratory", Vector2i(6, 1))
	world.set_hatch(true)
	await physics_frame
	await physics_frame
	world.drone._rebuild()
	world.drone.position = world.drone.UNLOAD_POINT
	world.field_cargo.drone = {"electronic_component": 1}
	world.local_store = {"iron": 8, "copper": 3, "crystal": 1}
	world.player.position = Vector2(20, 260)
	var first: Dictionary = world.outpost.buildings.plan("laboratory", Vector2i(-5, 1))
	var second: Dictionary = world.outpost.buildings.plan("lamp", Vector2i(1, 3))
	first.damaged = true
	world.outpost.logistics.advance(1)
	check(second.state == "planned" and world.drone.mission != "delivering", "an affordable later light never overtakes a blocked first project")
	check(world.outpost.logistics.project_status(second).contains("precedente"), "later project explains it is waiting for the previous one")
	world.player.position = Vector2(60, 160)
	Fixture.support(world)
	check(not world.outpost.fund_site(second) and second.state == "planned", "manual mount cannot bypass the project's FIFO position")
	second.state = "building"
	second.progress = 0.0
	second.automatic = false
	world.outpost.advance(1)
	check(second.progress == 0.0 and world.outpost.consumption_for(second) == 0.0, "a previously paid later project neither progresses nor draws assembly power ahead of the head")
	second.state = "planned"
	second.progress = 0.0
	world.field_cargo.drone = {"electronic_component": 1}
	world.drone.position = world.drone.UNLOAD_POINT
	world.player.position = Vector2(20, 260)
	first.damaged = false
	world.drone.mission = "outbound"
	world.outpost.logistics.advance(1)
	check(world.outpost.fabrication.jobs.size() == 2, "placing a project automatically queues only its missing structural and electronic batches")
	var paid_energy: float = world.ship_energy()
	for index in range(10): world.outpost.logistics.advance(1)
	check(world.outpost.fabrication.jobs.size() == 2 and is_equal_approx(world.ship_energy(), paid_energy), "repeated dispatch reuses ready and already paid components without duplicate orders")
	check(world.local_store.get("iron", 0) == 0 and world.local_store.get("copper", 0) == 0, "worker orders consume actual ship minerals while the player stays underground")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	check(world.restore_state(saved), "project FIFO and paid component orders survive JSON restore / " + world.status_label.text)
	first = world.outpost.buildings.structures[1]
	second = world.outpost.buildings.structures[2]
	var overtaken := false
	for index in range(2400):
		world.outpost.advance_fabrication(1.0 / 60)
		world.drone._physics_process(1.0 / 60)
		world.outpost.advance(1.0 / 60)
		if second.state != "planned" and first.state != "active": overtaken = true
		await physics_frame
		if second.state == "active": break
	check(first.state == "active" and second.state == "active" and not overtaken, "Robbie manufactures and constructs the first lab before serving the next light")
	check(world.player.position == Vector2(20, 260), "project orders never move the player back to the computer")
	Fixture.carve(world, Vector2i(-6, 2))
	var blocked: Dictionary = world.outpost.buildings.plan("laboratory", Vector2i(-5, 5))
	blocked.damaged = true
	var next: Dictionary = world.outpost.buildings.plan("lamp", Vector2i(-6, 2))
	world.field_cargo.drone = {"electronic_component": 1}
	world.outpost.logistics.reset()
	world.drone._rebuild()
	check(world.outpost.logistics._plan().is_empty(), "blocked head holds the queue even when the later project is affordable")
	world.outpost.buildings.structures.erase(blocked)
	check(world.outpost.logistics._plan() == next, "removing the blocked head advances to the next project")
	world.drone.position = Vector2(20, 260)
	world.local_store = {"iron": 4}
	var before_energy: float = world.ship_energy()
	check(not world.outpost.fabricate_components("structural_component", 1, {"kind": "ship"}, true) and world.local_store.iron == 4 and is_equal_approx(world.ship_energy(), before_energy), "worker cannot reserve ship minerals remotely")
	world.variant = "robbie"
	check(not world.outpost.logistics.enabled(), "controlled Robbie stays manual")
	print("PROJECT ORDERS FIFO: %d failures" % failures)
	quit(1 if failures else 0)
