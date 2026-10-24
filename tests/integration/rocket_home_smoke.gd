extends SceneTree

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
	for frame in range(count):
		await physics_frame

func walk_to(x: float) -> void:
	for frame in range(150):
		if absf(world.player.position.x - x) < 4:
			break
		var action := "move_right" if world.player.position.x < x else "move_left"
		Input.action_press(action)
		await physics_frame
		Input.action_release(action)
	await frames(15)

func climb(action: String, count: int) -> void:
	Input.action_press(action)
	await frames(count)
	Input.action_release(action)

func _run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Smoke test timeout"); quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(8)
	check(absf(world.player.position.y + 80) < 2, "player rests on workshop floor")
	await walk_to(100)
	await climb("climb_up", 55)
	await walk_to(40)
	check(absf(world.player.position.y + 200) < 3, "living floor is reachable by internal ladder")
	await walk_to(100)
	await climb("climb_up", 55)
	await walk_to(40)
	check(absf(world.player.position.y + 320) < 3, "cockpit floor is reachable and can be exited")
	world.return_home()
	world.player.position.x = 20
	await frames(3)
	await climb("climb_down", 15)
	check(world.player.position.y < -76, "closed hatch blocks descent")
	world.set_hatch(true)
	await frames(3)
	await climb("climb_down", 100)
	check(world.player.position.y > 145, "open hatch allows descent into two-metre shaft")
	await walk_to(-170)
	check(absf(world.player.position.y - 160) < 3, "player fits in two-metre-high starter tunnel")
	world.target_cell = Vector2i(-6, 3)
	check(world.can_reach(world.target_cell), "adjacent exposed tunnel block is in reach")
	world.mine_timer = 0
	world._mine_target()
	check(world.site.material(Vector2i(-6, 3)).is_empty(), "mining removes one cell")
	check(not world.blocks.has(Vector2i(-6, 3)), "mining removes corresponding physics body")
	check(world.inventory.get_amount("soil") == 1, "resource credited exactly once")
	world.mine_timer = 0
	world._mine_target()
	check(world.inventory.get_amount("soil") == 1, "empty cell cannot duplicate resources")
	check(not world.can_reach(Vector2i(-8, 3)), "ray blocks mining through intact cells")
	check(not world.can_reach(Vector2i(20, 0)), "distant block is out of reach")
	check(not world.place_ladder(), "ladder placement requires resources")
	world.inventory.add_material("soil", 3)
	check(world.place_ladder(), "one-cell ladder is placed in empty tunnel space")
	check(world.inventory.get_amount("soil") == 2, "ladder costs two soil units")
	# Redirect the public save API to a test-only file; never touch the player's outpost.
	var store := root.get_node("SaveManager")
	store.rocket_save_path = "res://reports/rocket-test-save.json"
	check(world.save_run(), "save writes isolated prototype data")
	world.inventory.add_material("crystal", 99)
	world.set_hatch(false)
	check(world.load_run(), "saved outpost loads")
	await frames(5)
	check(world.inventory.get_amount("crystal") == 0, "load restores inventory")
	check(world.hatch_open, "load restores hatch state")
	check(world.site.material(Vector2i(-6, 3)).is_empty(), "load restores dug geometry")
	check(not world.blocks.has(Vector2i(-6, 3)), "loaded geometry matches physics")
	check(world.ladders.has(Vector2i(-5, 3)), "load restores constructed ladder")
	await walk_to(20)
	await climb("climb_up", 105)
	check(world.player.position.y < -75, "shaft ladder allows return into rocket")
	world.return_home()
	await frames(30)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(not image.is_empty(), "rendered viewport is nonblank")
		check(image.save_png("res://reports/rocket-home-desktop.png") == OK, "desktop screenshot saved")
		root.size = Vector2i(960, 720)
		await frames(15)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://reports/rocket-home-compact.png") == OK, "compact screenshot saved")
	print("ROCKET HOME SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
