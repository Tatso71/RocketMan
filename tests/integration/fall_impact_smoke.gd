extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0
var world: Node2D

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func drop(height: float, initial_speed: float = 0.0) -> void:
	world.player.reset_animation()
	world.player.position = Vector2(-340, 400 - height)
	world.player.velocity = Vector2(0, initial_speed)
	world.player.climbing = false
	world._set_crew_energy(100)
	world.player.set_physics_process(true)
	for index in range(120):
		await physics_frame
		if index > 2 and world.player.is_on_floor(): break
	world.player.set_physics_process(false)
	check(world.player.is_on_floor(), "actual falling body reaches solid ground")

func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	for variant in ["explorer", "robbie"]:
		world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
		world.variant = variant
		root.add_child(world)
		await physics_frame
		freeze(world)
		world.guide_state.set_muted(true)
		world.guide._update_bubble()
		for y in range(10):
			for x in range(-10, -6): Fixture.carve(world, Vector2i(x, y))
		await physics_frame
		await drop(50)
		check(world.crew_energy() == 100 and world.player.impact_flash == 0, "short drops do not penalize " + variant)
		await drop(320)
		check(world.crew_energy() < 80 and world.player.impact_flash > 0, "hard landing consumes significant personal energy: " + variant)
		check(world.ship_energy() == 60 and world.suit_integrity() == 100, "landing affects personal energy, not ship power or suit")
		var energy: float = world.crew_energy()
		check(world.player.self_modulate.r > world.player.self_modulate.g * 2, "impact immediately flashes red")
		world.player.set_physics_process(true)
		for index in range(65): await physics_frame
		world.player.set_physics_process(false)
		check(is_equal_approx(world.crew_energy(), energy), "ground contact charges impact only once")
		check(world.player.impact_flash == 0 and world.player.self_modulate == Color.WHITE, "temporary flash returns to normal")
		await drop(12, 120)
		check(world.crew_energy() == 100, "low-speed final approach remains safe after braking")
		world.queue_free()
		await process_frame
	print("FALL IMPACT: %d failures" % failures)
	quit(1 if failures else 0)
