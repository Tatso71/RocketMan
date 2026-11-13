extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value: failures += 1
func run() -> void:
	var world: Node2D = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	var cell := Vector2i(-22, 4)
	for x in [-24, -23]:
		for y in range(3, 7): Fixture.carve(world, Vector2i(x, y))
	world.player.position = Vector2(-940, 240)
	world.drone.position = Vector2(-930, 170)
	world.target_cell = cell
	world.camera.position = Vector2(-840, 210)
	world.camera.zoom = Vector2.ONE * 1.7
	await physics_frame
	await physics_frame
	check(world.site.material(cell) == "copper" and world.site.mining_cost(cell) == 10, "exposed pure copper is a solid hard ore block")
	for hit in range(9):
		world.mine_timer = 0
		world._mine_target()
	check(not world.site.material(cell).is_empty() and world.site.damage.get(cell, 0) == 9, "real mining beam needs ten pulses rather than ordinary ore's two")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		world.camera.force_update_scroll()
		world._refresh_hud()
		world.queue_redraw()
		for index in range(5): await physics_frame
		await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		check(not picture.is_invisible() and picture.save_png("res://reports/pure-vein-%dp.png" % size.y) == OK, "capture exposed pure vein and mining progress at %dp" % size.y)
	world.mine_timer = 0
	world._mine_target()
	check(world.site.material(cell).is_empty() and world.gear.drop_amounts.get(cell, 0) == 12, "last real mining pulse yields twelve units")
	check(world.gear._fragment_group(cell).size() == 3, "twelve units appear as three bounded physical bundles")
	world.queue_redraw()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://reports/pure-vein-rich-drop.png") == OK, "capture x12 yield and the new excavated cavity")
	print("PURE VEINS VISUAL: %d failures" % failures)
	quit(1 if failures else 0)
