extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
class MeasuredGraph extends AStar2D:
	var cost_calls := 0
	func _compute_cost(from_id: int, to_id: int) -> float:
		cost_calls += 1
		return get_point_position(from_id).distance_to(get_point_position(to_id))

var world: Node2D
var failures := 0
var max_step := 0.0
var closest_player := INF

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1

func fresh() -> void:
	if is_instance_valid(world):
		world.queue_free()
		await physics_frame
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.drone.graph = MeasuredGraph.new()
	world.environment.water.clear()
	world.environment.oil.clear()
	world.environment.acid.clear()
	world.environment.gas.clear()
	world.gear.drops.clear()
	world.set_hatch(true)
	await physics_frame
	await physics_frame

func tick(count: int) -> void:
	for index in range(count):
		await physics_frame
		var before: Vector2 = world.drone.position
		world.drone._physics_process(1.0 / 60)
		max_step = maxf(max_step, before.distance_to(world.drone.position))
		closest_player = minf(closest_player, world.drone.position.distance_to(world.player.position - Vector2(0, 32)))

func report(label: String) -> void:
	print("TRACE %s: drone=%s torso=%s goal=%s route=%s status=%s" % [label, world.drone.position, world.player.position - Vector2(0, 32), world.drone.resting_goal, world.drone.route, world.drone.status])

func close_to_player() -> bool:
	return world.drone.position.distance_to(world.player.position - Vector2(0, 32)) < 120 and world.drone._route_clear(world.drone.position, world.player.position - Vector2(0, 32))

func run() -> void:
	create_timer(300).timeout.connect(func(): push_error("Drone reliability timeout"); quit(2))
	await fresh()
	for y in range(10):
		Fixture.carve(world, Vector2i(0, y))
	world.drone.position = Vector2(20, -140)
	world.player.position = Vector2(20, 400)
	await tick(540)
	report("single-cell shaft")
	check(close_to_player(), "follows down a single-cell shaft inside signal")
	world.drone.position = Vector2(20, -140)
	world.drone.has_resting_goal = false
	world.player.position = Vector2(20, 40)
	await tick(300)
	report("shallow hatch")
	check(close_to_player() and world.drone_can_collect(), "does not choose a resting point across the hatch floor")

	await fresh()
	for y in range(7):
		Fixture.carve(world, Vector2i(0, y))
	for x in range(-6, 1):
		Fixture.carve(world, Vector2i(x, 6))
	for y in range(6, 11):
		Fixture.carve(world, Vector2i(-6, y))
	world.drone.position = Vector2(20, 20)
	world.player.position = Vector2(-220, 440)
	await tick(840)
	report("single-cell bends")
	check(close_to_player(), "follows through two single-cell right-angle bends")
	world.drone.position = Vector2(-140, 260)
	world.drone.has_resting_goal = false
	world.player.position = Vector2(-220, 320)
	world.player.facing = -1
	closest_player = INF
	await tick(300)
	report("close blind bend")
	check(close_to_player(), "chooses a visible resting point around a nearby blind bend")
	check(closest_player < 42, "personal space is a soft cost, allowing passage past the player in a one-cell shaft")
	world.gear.drops[Vector2i(-6, 10)] = "copper"
	for index in range(360):
		await tick(1)
		world.gear.advance(1.0 / 60)
	check(world.gear.drops.is_empty() and world.field_cargo.drone.get("copper", 0) == 1, "follows and magnetically collects ore beyond the bend exactly once")

	await fresh()
	Fixture.lab_room(world)
	world.drone.position = Vector2(20, -140)
	world.player.position = Vector2(-180, 160)
	await physics_frame
	world.drone._rebuild()
	var calls_before: int = world.drone.graph.cost_calls
	world.drone.follow_goal()
	var selection_calls: int = world.drone.graph.cost_calls - calls_before
	print("PROFILE lab goal selection: %d AStar edge-cost evaluations" % selection_calls)
	check(selection_calls == 0, "goal selection reuses connectivity instead of running redundant AStar searches")
	await tick(420)
	report("narrow lab")
	check(close_to_player(), "enters a narrow laboratory through the hatch")
	world.player.position = Vector2(20, 64)
	await tick(300)
	report("under hatch")
	check(close_to_player() and world.drone.position.y > -70, "follows directly under the hatch instead of resting above the floor")
	world.field_cargo.drone = {"copper": 3}
	var stored: int = world.local_store.get("copper", 0)
	check(world.drone.send_to_ship(), "Y starts a physical cargo delivery")
	world.player.position = Vector2(-180, 160)
	world.set_hatch(false)
	await tick(120)
	check(world.drone.mission == "outbound" and world.field_cargo.drone.get("copper", 0) == 3, "closed hatch blocks delivery without teleporting cargo")
	world.set_hatch(true)
	await tick(600)
	report("delivery return")
	check(world.drone.mission == "follow" and close_to_player(), "delivery resumes through reopened hatch and returns to follow")
	check(world.local_store.get("copper", 0) == stored + 3 and world.field_cargo.used(world.field_cargo.drone) == 0, "delivery deposits cargo exactly once")

	for liquid: String in ["water", "acid", "oil"]:
		await fresh()
		for x in range(7):
			Fixture.carve(world, Vector2i(x, 4))
		Fixture.carve(world, Vector2i(6, 3))
		world.drone.position = Vector2(20, 180)
		world.player.position = Vector2(260, 200)
		var field: Dictionary = world.environment.get(liquid)
		field[Vector2i(3, 4)] = 1.0
		await tick(180)
		check(world.drone.position.x < 110 and not world.environment._wet(world.drone.position), "does not cross a %s-filled one-cell passage" % liquid)
		field.clear()
		await tick(300)
		report(liquid + " drained")
		check(close_to_player(), "recovers after %s passage dries" % liquid)

	await fresh()
	for y in range(4):
		Fixture.carve(world, Vector2i(0, y))
	for x in range(21):
		for y in [2, 3]:
			Fixture.carve(world, Vector2i(x, y))
	world.drone.position = Vector2(20, 100)
	world.player.position = Vector2(820, 160)
	await tick(600)
	report("distant horizontal tunnel")
	check(close_to_player() and world.drone.position.distance_to(Vector2(0, -80)) > 600, "base Robbie follows beyond fifteen metres without an upgrade")
	check(world.drone_can_collect() and world.drone_help_available(), "cargo assistance works far from the ship")
	world.gear.drops[Vector2i(18, 3)] = "copper"
	for index in range(180):
		await tick(1)
		world.gear.advance(1.0 / 60)
	check(world.gear.drops.is_empty() and world.field_cargo.drone.get("copper", 0) == 1, "local magnet collects physical ore beyond the old ship radius")
	check(not world.drone.status.contains("segnale"), "distance never reports a signal limit")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	var distant_position: Vector2 = world.drone.position
	check(world.restore_state(saved) and world.drone.position.distance_to(distant_position) < 1, "save restores Robbie beyond the old ship radius")
	world.player.position = Vector2(340, 160)
	await tick(300)
	check(close_to_player(), "follows back toward the ship normally")
	await fresh()
	for y in range(22): Fixture.carve(world, Vector2i(0, y))
	world.drone.position = Vector2(20, -140)
	world.player.position = Vector2(20, 880)
	await tick(720)
	check(close_to_player() and world.drone_can_collect(), "base Robbie follows deeper than fifteen metres")
	for x in range(19):
		for y in [20, 21]: Fixture.carve(world, Vector2i(x, y))
	world.player.position = Vector2(740, 880)
	await tick(540)
	check(close_to_player() and world.drone_can_collect(), "base Robbie follows a deep diagonal expedition")
	world.field_cargo.drone["copper"] = 1
	check(world.drone.send_to_ship(), "Y delivery starts from the deep distant tunnel")
	await tick(1800)
	check(world.drone.mission == "follow" and close_to_player() and world.local_store.get("copper", 0) == 1, "unloads at the ship and physically returns to the deep expedition")
	check(max_step <= 125.0 / 60 + 0.1, "all following movement is physical without teleportation (max step %.3f)" % max_step)
	print("DRONE FOLLOW RELIABILITY: %d failures" % failures)
	quit(1 if failures else 0)
