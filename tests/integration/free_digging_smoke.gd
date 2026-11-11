extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, text: String) -> void:
	if value:
		print("PASS: " + text)
	else:
		failures += 1
		push_error("FAIL: " + text)

func _run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	var world: Node2D = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(4):
		await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.guide_state.set_muted(true)
	world.field_cargo.drone = {"copper": 20}
	world.drone.position = Vector2(5000, 5000)
	world.field_cargo.drone_available = false
	var mined := 0
	for x in range(-20, 20):
		world.player.position = Vector2(x * 40 + 20, -4)
		world.target_cell = Vector2i(x, 0)
		world.mine_timer = 0
		world._mine_target()
		await physics_frame
		if world.site.material(Vector2i(x, 0)).is_empty():
			mined += 1
	check(mined == 40, "forty common cells excavated with full cargo and absent Robbie")
	check(world.field_cargo.drone == {"copper": 20} and world.gear.drops.is_empty(), "common ground never generates cargo or loose clutter")
	world.player.position = Vector2(-140, -4)
	world.target_cell = Vector2i(-4, 1)
	for i in range(3):
		world.mine_timer = 0
		world._mine_target()
		await physics_frame
	check(world.gear.drops.get(Vector2i(-4, 1)) == "copper", "valuable ore remains on the ground when cargo cannot collect")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	check(world.restore_state(saved), "loose ore survives a world save/load")
	world.field_cargo.drone.clear()
	world.player.position = Vector2(-140, 40)
	Fixture.support(world)
	world.drone.position = Vector2(-120, 25)
	for tick in range(90):
		await physics_frame
		world.gear.advance(1.0 / 60)
	check(world.gear.drops.is_empty() and world.field_cargo.drone.get("copper", 0) == 1, "Robbie collects preserved ore exactly once")
	world.gear.advance(0.01)
	check(world.field_cargo.drone.get("copper", 0) == 1, "ore is not duplicated on later ticks")
	print("Free digging smoke: %d failures" % failures)
	quit(1 if failures else 0)
