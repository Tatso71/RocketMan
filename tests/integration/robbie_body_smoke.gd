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

func frames(count: int) -> void:
	for index in range(count): await physics_frame

func run() -> void:
	create_timer(70).timeout.connect(func(): quit(2))
	for robot in [false, true]:
		world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
		world.variant = "robbie" if robot else "explorer"
		root.add_child(world)
		await frames(3)
		freeze(world)
		world.guide_state.set_muted(true)
		world.guide._update_bubble()
		for x in range(-8, 1):
			Fixture.carve(world, Vector2i(x, 4))
			if x <= -7 or x >= -1: Fixture.carve(world, Vector2i(x, 3))
		world.player.position = Vector2(-300, 200)
		world.player.velocity = Vector2.ZERO
		await frames(2)
		var collider: CollisionShape2D = world.player.get_child(0)
		check(is_equal_approx(collider.shape.height, 32 if robot else 64), "variant collider height: " + world.variant)
		check(world._safe_position(Vector2(20, -400)) == robot, "ceiling save clearance follows actual actor height")
		world.player.set_physics_process(true)
		Input.action_press("move_right")
		await frames(100)
		Input.action_release("move_right")
		world.player.set_physics_process(false)
		check(world.player.position.x > -40 if robot else world.player.position.x < -240, "real one-cell corridor passes Robbie but blocks the human")
		world.player.position = Vector2(-140, 200)
		world.player.velocity = Vector2.ZERO
		check(world._safe_position(world.player.position) == robot, "tight tunnel save validation uses actual body: " + world.variant)
		if robot:
			var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
			check(world.restore_state(saved) and world.player.position.distance_to(Vector2(-140, 200)) < 1, "Robbie restores inside a one-cell tunnel without returning to ship")
			check(world.player_environment().submerged == false, "dry compact body remains safe")
			world.equip_tool(1)
			world.scanner_view.advance(0.01)
			check(world.scanner_view.pulses[0].origin == world.player_center(), "scanner emits from the compact body center")
			world.equip_tool(0)
			world.target_cell = Vector2i(-4, 3)
			for hit in range(3):
				world.mine_timer = 0
				world._mine_target()
			check(world.site.material(Vector2i(-4, 3)).is_empty() and world.beam_time > 0, "mining ray starts inside the compact robot and reaches the corridor ceiling")
		world.environment.water[Vector2i(-4, 4)] = 1.0
		check(world.player_environment().submerged == robot, "water reaches compact robot head but not human head")
		world.environment.water.clear()
		if "--capture" in OS.get_cmdline_user_args() and robot:
			world.camera.position = Vector2(-160, 140)
			world.camera.zoom = Vector2.ONE * 1.6
			for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
				root.size = size
				world.camera.force_update_scroll()
				world._refresh_hud()
				world.queue_redraw()
				world.player.queue_redraw()
				await frames(3)
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png("res://reports/robbie-body-%dp.png" % size.y) == OK, "capture compact robot %dp" % size.y)
		world.queue_free()
		await frames(3)
	print("ROBBIE BODY: %d failures" % failures)
	quit(1 if failures else 0)
