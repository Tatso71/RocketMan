extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, text: String) -> void:
	print(("PASS: " if value else "FAIL: ") + text)
	if not value: failures += 1

func find_cell(kind: String) -> Vector2i:
	for y in range(1, world.site.DEPTH):
		for x in range(world.site.LEFT + 2, world.site.RIGHT - 2):
			if world.site.material(Vector2i(x, y)) == kind: return Vector2i(x, y)
	return Vector2i(999, 999)

func aim(cell: Vector2i) -> void:
	for x in [-2, -1]:
		for y in [-1, 0, 1]: Fixture.carve(world, cell + Vector2i(x, y))
	world.player.position = world.Grid.center(cell) + Vector2(-60, 28)
	world.camera.position = world.Grid.center(cell) + Vector2(-80, 0)
	world.camera.force_update_scroll()
	world.target_cell = cell
	world.mine_timer = 0
	world._refresh_hud()
	world.queue_redraw()
	for index in range(3): await physics_frame

func run() -> void:
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	check(world.get("mining_feedback") != null, "failed mining has a dedicated visible target message")
	if failures:
		quit(1)
		return
	for kind: String in ["cobalt", "bedrock", "anchor"]:
		var cell := find_cell(kind)
		check(world.site.contains(cell), "find real " + kind + " block")
		await aim(cell)
		var energy: float = world.ship_energy()
		var personal_energy: float = world.crew_energy()
		world._mine_target()
		var expected: String = {"cobalt": "Risonatore", "bedrock": "Plasma", "anchor": "Indistruttibile"}[kind]
		check(world.mining_feedback.visible and world.mining_feedback.message.text.contains(expected), "actual failed click names the rule for " + kind)
		check(world.site.material(cell) == kind and is_equal_approx(world.ship_energy(), energy) and is_equal_approx(world.crew_energy(), personal_energy) and world.beam_time == 0, "refused action spends no energy, emits no beam and removes no block")
		if kind == "bedrock":
			for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
				root.size = size
				for index in range(4): await physics_frame
				check(Rect2(Vector2.ZERO, world.get_viewport_rect().size).encloses(world.mining_feedback.get_global_rect()), "mining message stays within viewport " + str(size) + " / " + str(world.mining_feedback.get_global_rect()))
				check(not world.mining_feedback.get_global_rect().intersects(world.outpost.cargo_ui.compact.get_global_rect()), "mining message avoids the cargo panel")
				if DisplayServer.get_name() != "headless" and "--capture" in OS.get_cmdline_user_args():
					await RenderingServer.frame_post_draw
					check(root.get_texture().get_image().save_png("res://reports/mining-refusal-%d.png" % size.y) == OK, "capture readable refusal")
		world.mining_feedback._process(3.0)
		check(not world.mining_feedback.visible, "refusal expires rather than leaving a permanent popup")
	var viewport_size: Vector2 = world.get_viewport_rect().size
	world.camera.position = world.Grid.center(world.target_cell) + (viewport_size / 2 - Vector2(25, 300)) / world.camera.zoom
	world.camera.force_update_scroll()
	world.mine_timer = 0
	world._mine_target()
	for index in range(3): await physics_frame
	check(not world.mining_feedback.get_global_rect().intersects(world.tutorial_ui.panel.get_global_rect()), "left-edge refusal finds space beside the tutorial instead of hiding behind it")
	world.mining_feedback.show_reason(world.target_cell, "Serve Plasma")
	world.equip_tool(1)
	check(not world.mining_feedback.visible, "changing tools clears the old refusal")
	world.equip_tool(0)
	for kind: String in ["cobalt", "bedrock", "anchor"]:
		var cell := find_cell(kind)
		var bomb_cell := cell + Vector2i.LEFT
		Fixture.carve(world, bomb_cell)
		var body := Node2D.new()
		world.add_child(body)
		world.gear._explode({"cell": bomb_cell, "number": 1, "body": body})
		check(world.site.material(cell).is_empty() if kind == "cobalt" else world.site.material(cell) == kind, "bomb " + ("breaks cobalt" if kind == "cobalt" else "cannot break " + kind))
	print("MINING REFUSAL: %d failures" % failures)
	quit(1 if failures else 0)
