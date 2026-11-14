extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func stand(cell: Vector2i) -> void:
	world.player.position = world.Grid.center(cell) + Vector2(0, world.player.body_size().y / 2)
	for index in range(3): await physics_frame

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	var cell := Vector2i(-8, 3)
	Fixture.carve(world, cell)
	world.ladders[cell] = true
	await stand(cell)
	var cargo: Dictionary = world.field_cargo.snapshot()
	check(world.outpost.conduit_cost("water").is_empty(), "water pipe has no component cost")
	check(world.outpost.place_conduit("water", cell), "empty-handed explorer places a water pipe in a ladder cell")
	check(world.ladders.has(cell) and world.field_cargo.snapshot() == cargo, "pipe placement preserves ladder and cargo")
	check(not world.outpost.place_conduit("water", cell + Vector2i.RIGHT), "pipe cannot be placed in solid rock")
	check(world.get("ladder_layer") is Node2D, "ladders have a dedicated foreground draw layer")
	if world.get("ladder_layer") is Node2D:
		check(world.ladder_layer.z_index > 1 and world.ladder_layer.z_index < world.player.z_index, "background pipes remain below ladders and player")
	var point := Vector2i(-6, -2)
	await stand(point)
	check(world.outpost.place_conduit("water", point), "water pipe can reach the ship's aboveground booster port")
	var saved: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(saved))), "new pipe layout round trips through real world save API")
	var before: Dictionary = world.capture_state()
	var bad: Dictionary = JSON.parse_string(JSON.stringify(before))
	bad.network.version = 1
	check(not world.restore_state(bad), "obsolete pipe format is rejected without migration")
	check(world.capture_state() == before, "rejected pipe save leaves the current game unchanged")
	print("BACKGROUND PIPE PLACEMENT: %d failures" % failures)
	quit(1 if failures else 0)
