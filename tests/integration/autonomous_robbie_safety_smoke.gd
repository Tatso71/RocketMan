extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, text: String) -> void:
	print(("PASS: " if value else "FAIL: ") + text)
	if not value: failures += 1
func tick(count: int) -> void:
	for index in range(count):
		await physics_frame
		world.drone._physics_process(1.0 / 60)
		world.outpost.advance_fabrication(1.0 / 60)
func run() -> void:
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.environment.water.clear()
	world.environment.oil.clear()
	world.environment.acid.clear()
	world.environment.gas.clear()
	Fixture.lab_room(world)
	world.set_hatch(true)
	await physics_frame
	await physics_frame
	world.drone._rebuild()
	world.drone.position = world.drone.UNLOAD_POINT
	world.drone.mission = "outbound"
	world.field_cargo.drone = {"iron": 8, "copper": 3, "crystal": 1}
	world.gear.set_workshop_damage(true)
	var energy: float = world.ship_energy()
	world.outpost.logistics.advance(1)
	check(world.outpost.fabrication.jobs.is_empty() and world.local_store.get("iron", 0) == 8 and world.ship_energy() == energy, "damaged workshop keeps delivered materials without consuming production energy")
	check(world.outpost.logistics.status.contains("danneggiata"), "workshop damage is reported instead of causing empty trips")
	world.gear.set_workshop_damage(false)
	world.outpost.logistics.advance(1)
	check(world.outpost.fabrication.jobs.is_empty(), "repair never starts an unordered conversion")
	Fixture.workshop(world)
	check(world.outpost.fabricate_components("structural_component"), "player explicitly reserves conversion after workshop repair")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	var paid_energy: float = world.ship_energy()
	check(world.restore_state(saved), "paid production order survives a JSON load")
	await physics_frame
	await physics_frame
	world.drone._rebuild()
	world.drone.position = world.drone.UNLOAD_POINT
	world.drone.mission = "outbound"
	world.outpost.logistics.advance(0.25)
	check(world.outpost.fabrication.jobs.size() == 1 and is_equal_approx(world.ship_energy(), paid_energy), "reloading a paid job never reserves or charges it twice")
	world._set_ship_energy(0)
	world.outpost.advance_fabrication(10)
	check(world.outpost.fabrication.jobs.size() == 1 and world.outpost.fabrication.jobs[0].elapsed == 0.0, "empty battery pauses paid production without losing it")
	world.outpost.fabrication.jobs.clear()
	world._set_ship_energy(60)
	world.local_store.clear()
	world.field_cargo.drone = {"structural_component": 4, "electronic_component": 2}
	var plan: Dictionary = world.outpost.buildings.plan("laboratory", Vector2i(-5, 1))
	world.outpost.logistics.target = plan
	world.outpost.logistics.destination = Vector2(-120, 100)
	world.drone.mission = "delivering"
	world.outpost.buildings.structures.erase(plan)
	world.outpost.logistics.advance(1)
	check(world.field_cargo.drone.get("structural_component", 0) == 4 and world.field_cargo.drone.get("electronic_component", 0) == 2, "cancelled delivery retains all components instead of consuming them")
	world.field_cargo.drone = {"iron": 20}
	world.outpost.logistics.reset()
	world.drone.position = Vector2(20, 100)
	world.player.position = Vector2(-120, 160)
	world.set_hatch(false, false)
	await physics_frame
	await physics_frame
	world.drone.revision = -1
	await tick(360)
	check(world.drone.position.y > -72 and world.local_store.get("iron", 0) == 0 and world.field_cargo.drone.get("iron", 0) == 20, "closed hatch blocks actual transport and preserves cargo")
	world.set_hatch(true)
	await tick(1200)
	check(world.local_store.get("iron", 0) > 0, "opening the hatch lets automatic delivery resume physically")
	world.variant = "robbie"
	check(not world.outpost.logistics.enabled(), "player-controlled Robbie keeps manual logistics as requested")
	world.variant = "explorer"
	world.field_cargo.drone = {"structural_component": 4, "electronic_component": 2}
	plan = world.outpost.buildings.plan("laboratory", Vector2i(-5, 1))
	world.outpost.logistics.reset()
	world.drone._rebuild()
	var point: Vector2 = world.outpost.logistics._goal_for(plan)
	world.drone.position = world.drone.graph.get_point_position(world.drone.graph.get_closest_point(point))
	world.outpost.logistics.target = plan
	world.outpost.logistics.destination = point + Vector2(200, 200)
	world.drone.mission = "delivering"
	world.outpost.logistics.advance(1)
	check(plan.state == "building", "delivery refreshes its waypoint and funds a multi-cell lab from a graph cell center")
	plan.damaged = true
	plan.state = "building"
	plan.automatic = true
	for x in range(1, 6):
		for y in range(1, 4): Fixture.carve(world, Vector2i(x, y))
	world.outpost.buildings.install("laboratory", Vector2i(2, 1))
	var light: Dictionary = world.outpost.buildings.plan("lamp", Vector2i(-1, 3))
	world.field_cargo.drone = {"electronic_component": 1}
	world.drone._rebuild()
	world.outpost.logistics.reset()
	world.outpost.logistics.advance(1)
	check(world.outpost.logistics.target.is_empty() and world.drone.mission != "delivering" and light.state == "planned", "a damaged first project blocks later projects instead of being skipped")
	world.outpost.buildings.structures.clear()
	world.outpost.fabrication.jobs.clear()
	world.outpost.fabrication.outputs.clear()
	world.local_store = {"stone": 120}
	world.field_cargo.drone = {"silica": 10}
	world.drone.position = world.drone.UNLOAD_POINT
	world.outpost.logistics.reset()
	world.drone.mission = "outbound"
	world.outpost.logistics.advance(1)
	check(world.drone.mission == "outbound" and world.field_cargo.drone.silica == 10, "a full depot parks a partial undeliverable load without repeated empty shuttles")
	plan = world.outpost.buildings.plan("laboratory", Vector2i(-5, 1))
	plan.state = "building"
	plan.automatic = true
	plan.progress = 0.4
	world.outpost.logistics.advance(1)
	check(world.drone.mission == "building" and world.outpost.logistics.target == plan, "residual cargo does not prevent resuming an already paid reachable construction")
	world.outpost.buildings.structures.clear()
	world.field_cargo.drone.clear()
	world.outpost.logistics.reset()
	world.drone.mission = "returning"
	world.player.position = Vector2(20, 120)
	world.set_hatch(false, false)
	await physics_frame
	await physics_frame
	world.drone._rebuild()
	world.gear.drops[Vector2i(0, 0)] = "iron"
	world.gear._ensure_fragment_group(Vector2i(0, 0))
	world.gear.fragments[Vector2i(0, 0)].position = Vector2(-60, -140)
	world.outpost.logistics.advance(1)
	check(world.drone.mission == "collecting", "returning to an unreachable player does not block reachable collection work")
	print("AUTONOMOUS ROBBIE SAFETY: %d failures" % failures)
	quit(1 if failures else 0)
