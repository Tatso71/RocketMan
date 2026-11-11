extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0
var world: Node2D

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func tick(count: int) -> void:
	for index in range(count):
		world.outpost.advance_fabrication(1.0 / 60)
		world.drone._physics_process(1.0 / 60)
		world.gear._advance_fragments(1.0 / 60)
		world.outpost.advance(1.0 / 60)
		await physics_frame

func run() -> void:
	check(ResourceLoader.exists("res://scripts/systems/drone_logistics.gd"), "autonomous per-worker logistics controller exists")
	if failures:
		quit(1)
		return
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
	world.environment.oil.clear()
	world.environment.acid.clear()
	world.environment.gas.clear()
	Fixture.lab_room(world)
	for y in range(7): Fixture.carve(world, Vector2i(0, y))
	world.set_hatch(true)
	await physics_frame
	await physics_frame
	world.player.position = Vector2(-120, 160)
	world.drone.position = Vector2(-120, 120)
	world.field_cargo.drone = {"iron": 8, "copper": 3, "crystal": 1}
	check(world.outpost.place("laboratory", Vector2i(-5, 1)), "player can queue first laboratory without prepared components")
	var lab: Dictionary = world.outpost.buildings.structures.back()
	world.player.position = Vector2(20, 260)
	var player_stayed: Vector2 = world.player.position
	for index in range(1500):
		if lab.state == "building": break
		await tick(1)
	check(lab.state == "building", "Robbie physically reaches and starts the paid construction")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	check(world.restore_state(saved), "save/load preserves the in-progress automated construction")
	await physics_frame
	await physics_frame
	lab = world.outpost.buildings.structures[0]
	await tick(1500)
	check(lab.state == "active", "Robbie unloads, converts, delivers and builds while the player stays away")
	check(world.player.position == player_stayed, "autonomous workflow never moves the digging player")
	check(world.outpost.laboratory_unlocked(), "the automatically completed lab unlocks utilities")
	check(world.local_store.get("iron", 0) + world.field_cargo.drone.get("iron", 0) == 0, "structural production really consumes its eight iron")
	check(world.local_store.get("copper", 0) + world.field_cargo.drone.get("copper", 0) == 0, "electronic production really consumes its three copper")
	world.player.position = Vector2(20, 160)
	check(world.outpost.place("lamp", Vector2i(-1, 3)), "a light can be queued after the first laboratory")
	var lamp: Dictionary = world.outpost.buildings.structures.back()
	for entry: Array in [[Vector2i(0, 5), "copper", 3], [Vector2i(0, 6), "crystal", 1]]:
		world.gear.drops[entry[0]] = entry[1]
		world.gear.drop_amounts[entry[0]] = entry[2]
		world.gear._ensure_fragment_group(entry[0])
	world.player.position = player_stayed
	await tick(2400)
	check(lamp.state == "active" and world.outpost.lamp_powered(lamp), "Robbie independently collects fallen ore, converts it and builds a powered light")
	check(world.gear.drops.is_empty(), "all reachable dropped ore is collected without Y")
	lab.state = "planned"
	lab.progress = 0.0
	world.local_store.clear()
	world.local_store.structural_component = 1
	world.field_cargo.drone.clear()
	world.outpost.logistics.reset()
	world.outpost.logistics.advance(0.25)
	check(world.drone.mission == "follow", "incomplete component stock does not cause an endless empty ship shuttle")
	print("AUTO TRACE: ", world.drone.position, " / ", world.drone.mission, " / ", world.drone.status)
	print("AUTONOMOUS ROBBIE: %d failures" % failures)
	quit(1 if failures else 0)
