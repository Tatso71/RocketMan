extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0
var max_step := 0.0
var blocked_steps := 0
var initial_removed := {}

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1

func fresh(side: int) -> void:
	if is_instance_valid(world):
		world.queue_free()
		await physics_frame
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	initial_removed = world.site.removed.duplicate()
	# Only this separate two-metre surface shaft is excavated, never the hatch.
	for x in ([-8, -7] if side < 0 else [6, 7]):
		for y in range(3):
			Fixture.carve(world, Vector2i(x, y))
	world.player.position = Vector2(side * 280, 120)
	world.player.facing = side
	await physics_frame
	await physics_frame

func measure(before: Vector2) -> void:
	max_step = maxf(max_step, before.distance_to(world.drone.position))
	if not world.drone._clear(before, world.drone.position):
		blocked_steps += 1

func tick(count: int) -> void:
	for index in range(count):
		await physics_frame
		var before: Vector2 = world.drone.position
		world.drone._physics_process(1.0 / 60)
		measure(before)

func close_to_player() -> bool:
	var torso: Vector2 = world.player.position - Vector2(0, 32)
	return world.drone.position.y > 0 and world.drone.position.distance_to(torso) < 120 and world.drone._route_clear(world.drone.position, torso)

func untouched_ground(side: int) -> bool:
	for y in range(3):
		for x in range(-4, 4):
			if world.site.material(Vector2i(x, y)).is_empty():
				return false
	for cell: Vector2i in world.site.removed:
		if not initial_removed.has(cell) and (cell.y < 0 or cell.y > 2 or cell.x not in ([-8, -7] if side < 0 else [6, 7])):
			return false
	return true

func physical_probe(side: int) -> void:
	await fresh(side)
	world.drone.position = Vector2(20, -100)
	world.set_hatch(true)
	await physics_frame
	await physics_frame
	var waypoints := [Vector2(20, -20), Vector2(side * 280, -20), Vector2(side * 280, 20)]
	for goal: Vector2 in waypoints:
		check(world.drone._clear(world.drone.position, goal), "circle sweep admits physical air leg to %s" % goal)
		for index in range(240):
			if world.drone.position.distance_to(goal) < 2:
				break
			await physics_frame
			var before: Vector2 = world.drone.position
			world.drone.velocity = (goal - before).normalized() * minf(125, before.distance_to(goal) * 4)
			world.drone.move_and_slide()
			measure(before)
		check(world.drone.position.distance_to(goal) < 2, "real body traverses collar and overground leg to %s" % goal)
	check(untouched_ground(side), "physical probe never excavates below the rocket")

func follow_case(side: int, start: Vector2) -> void:
	await fresh(side)
	var label := "%s from %s" % ["left" if side < 0 else "right", start]
	world.drone.position = start
	world.drone.velocity = Vector2.ZERO
	world.set_hatch(false)
	await tick(180)
	check(world.drone.position.y < -80, label + ": closed hatch contains Robbie inside hull")
	check(not world.drone._clear(Vector2(20, -100), Vector2(20, -20)), label + ": closed hatch blocks the actual collar sweep")
	world.set_hatch(true)
	await physics_frame
	await physics_frame
	world.drone._rebuild()
	check(not world.drone.graph.has_point(world.drone._id(Vector2i(-5, -4))) and not world.drone.graph.has_point(world.drone._id(Vector2i(4, -4))), label + ": graph excludes aerial circles overlapping either hull wall")
	var source: int = world.drone.graph.get_closest_point(world.drone.position)
	var destination: int = world.drone.graph.get_closest_point(Vector2(side * 280, 20))
	check(not world.drone.graph.get_id_path(source, destination).is_empty(), label + ": open air graph connects ship to separate shaft")
	check(not world.drone._clear(Vector2(-140, -140), Vector2(-220, -140)) and not world.drone._clear(Vector2(140, -140), Vector2(220, -140)), label + ": hull walls still block lateral shortcuts")
	await tick(720)
	print("TRACE %s: position=%s goal=%s status=%s" % [label, world.drone.position, world.drone.resting_goal, world.drone.status])
	check(close_to_player() and world.drone_can_collect(), label + ": exits below ship and follows into separate surface shaft")
	if close_to_player():
		world.field_cargo.drone = {"copper": 3}
		var stored: int = world.local_store.get("copper", 0)
		check(world.drone.send_to_ship(), label + ": Y starts delivery from separate shaft")
		world.set_hatch(false)
		await tick(360)
		check(world.drone.mission == "outbound" and world.drone.position.y > -72 and world.field_cargo.drone.get("copper", 0) == 3 and world.local_store.get("copper", 0) == stored, label + ": closed hatch blocks return without moving cargo")
		world.set_hatch(true)
		await tick(960)
		check(world.drone.mission == "follow" and close_to_player(), label + ": unloads and physically returns through overground entrance")
		check(world.local_store.get("copper", 0) == stored + 3 and world.field_cargo.used(world.field_cargo.drone) == 0, label + ": deposits exactly once")
	check(untouched_ground(side), label + ": all rocket soil and other terrain remain untouched")

func run() -> void:
	create_timer(300).timeout.connect(func(): push_error("Drone ship exit timeout"); quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	world.variant = "robbie"
	root.add_child(world)
	world.player.position = Vector2(100, 200)
	world.drone.sync_controlled()
	check(world.drone.position == Vector2(100, 184), "controlled cargo surrogate follows the compact robot center, not the human offset")
	for side in [-1, 1]:
		await physical_probe(side)
		for start: Vector2 in [Vector2(-60, -100), Vector2(-140, -380)]:
			await follow_case(side, start)
	check(max_step <= 125.0 / 60 + 0.1, "all movement stays physical at normal speed (max step %.3f)" % max_step)
	check(blocked_steps == 0, "no movement crosses hull, floor, hatch or terrain")
	print("DRONE SHIP EXIT: %d failures" % failures)
	quit(1 if failures else 0)
