extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var failures := 0
var world: Node2D

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func walk_to(x: float) -> void:
	for index in range(120):
		if absf(world.player.position.x - x) < 4:
			break
		var action := "move_right" if world.player.position.x < x else "move_left"
		Input.action_press(action)
		await physics_frame
		Input.action_release(action)
	await frames(30)

func _run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Hatch smoke timeout"); quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	check(not world.site.material(Vector2i(0, 0)).is_empty(), "arrival still has virgin ground under the hatch")
	var shape: CollisionShape2D = world.hatch.get_child(0)
	check(shape.shape.size.x == Grid.CELL_SIZE, "hatch opening is exactly one metre wide")
	check(world.hatch.position.x == Grid.center(Vector2i(0, -2)).x, "hatch is centred on the access ladder")
	# Only the test excavates this one-cell shaft and installs return ladders.
	for y in range(4):
		Fixture.carve(world, Vector2i(0, y))
		world.ladders[Vector2i(0, y)] = true
	world.return_home()
	world.player.position.x = 20
	await frames(8)
	Input.action_press("climb_down")
	await frames(40)
	Input.action_release("climb_down")
	check(absf(world.player.position.y + 80) < 1, "closed hatch still supports the player and blocks descent")
	world.set_hatch(true)
	await frames(4)
	check(world.on_ladder(Vector2(20, -82)), "ladder grip extends above the workshop floor for a safe exit")
	world.player.position = Vector2(-20, -80)
	world.player.velocity = Vector2.ZERO
	world.player.climbing = false
	await frames(60)
	check(absf(world.player.position.y + 80) < 1, "no unsupported strip remains left of the access ladder")
	check(not world._safe_position(Vector2(-20, -79)), "save validation rejects positions inside the restored floor strip")
	check(world._safe_position(Vector2(20, -20)), "save validation accepts positions in the narrower open collar")
	for exit_x in [-60.0, 70.0]:
		world.return_home()
		await walk_to(20)
		Input.action_press("climb_down")
		await frames(105)
		Input.action_release("climb_down")
		check(world.player.position.y > 140, "open hatch allows descent through the one-cell shaft")
		Input.action_press("climb_up")
		for index in range(160):
			if world.player.position.y < -81:
				break
			await physics_frame
		Input.action_release("climb_up")
		check(world.player.position.y < -80, "access ladder lifts the feet clear of the workshop floor")
		await walk_to(exit_x)
		await frames(60)
		check(absf(world.player.position.x - exit_x) < 4 and absf(world.player.position.y + 80) < 1 and world.player.is_on_floor(), "player exits and stays on the workshop floor at x=" + str(exit_x))
	world.player.position = Vector2(20, -30)
	world.player.velocity = Vector2.ZERO
	world.set_hatch(false)
	check(world.hatch_open, "hatch cannot close on someone climbing through it")
	world.return_home()
	world.set_hatch(false)
	await frames(4)
	check(not world.hatch_open and not shape.disabled, "unoccupied hatch closes with its narrower collision restored")
	world.set_hatch(true)
	await frames(4)
	var legacy: Dictionary = world.capture_state()
	legacy.player = [-20, -40]
	check(world.restore_state(legacy), "old wider-hatch save remains compatible")
	check(world.player.position == Vector2(-60, -80) and world.site.material(Vector2i(0, 0)).is_empty() and world.ladders.has(Vector2i(0, 3)), "old position inside the new floor returns safely home without losing excavation or ladders")
	if "--capture" in OS.get_cmdline_user_args():
		for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			await frames(12)
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://reports/hatch-%dp.png" % size.y) == OK, "hatch screenshot saved at " + str(size))
	print("HATCH SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
