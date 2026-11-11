extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0
var capture := false

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, text: String) -> void:
	if value:
		print("PASS: " + text)
	else:
		failures += 1
		push_error("FAIL: " + text)

func picture(name: String, target: Viewport = null) -> void:
	if not capture:
		return
	world._refresh_hud()
	world.queue_redraw()
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var viewport: Viewport = root if target == null else target
	var pixels := viewport.get_texture().get_image()
	check(pixels.save_png("res://reports/" + name + ".png") == OK, "save " + name)
	check(pixels.get_size().x >= 900 and not pixels.is_invisible(), "rendered viewport is nonblank")

func _run() -> void:
	create_timer(80).timeout.connect(func(): quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(6):
		await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	Fixture.lab_room(world)
	world.set_hatch(true)
	world.player.position = Vector2(-100, 160)
	Fixture.support(world)
	world.camera.position = Vector2(-20, 20)
	world.camera.zoom = Vector2.ONE * 1.3
	var removed: Array = world.site.snapshot()
	var blocks: int = world.blocks.size()
	world.organic_terrain = false
	await picture("components-terrain-before-720p")
	world.organic_terrain = true
	await picture("components-terrain-after-720p")
	check(world.site.snapshot() == removed and world.blocks.size() == blocks, "visual change preserves all metric terrain and collisions")
	check(not world.show_grid, "metric overlay is hidden by default")
	world.outpost.place("laboratory", Vector2i(-5, 1))
	await picture("components-pending-plan-720p")
	world.field_cargo.drone = {"structural_component": 4, "electronic_component": 2}
	Fixture.support(world)
	check(world.outpost.fund_site(world.outpost.buildings.structures.back()), "preview funds real construction with carried components")
	world.outpost.advance(2.5)
	await picture("components-building-720p")
	root.size = Vector2i(1920, 1080)
	await picture("components-terrain-after-1080p")
	world.return_home()
	world.local_store = {"iron": 16, "copper": 9, "crystal": 3}
	Fixture.support(world)
	world.outpost.construction.open_picker(Vector2i.ZERO, Vector2.ZERO, true)
	var ui: Node = world.outpost.construction
	ui.recipe_rows.structural_component.quantity.value = 2
	ui.refresh()
	check(ui.recipe_rows.structural_component.resources.iron.text.contains("8"), "batch UI shows multiplied ingredient costs")
	check(not ui.recipe_rows.structural_component.button.disabled, "available components recipe can be ordered")
	await picture("components-production-1080p", ui.picker)
	root.size = Vector2i(1280, 720)
	await picture("components-production-720p", ui.picker)
	ui.picker.hide()
	print("Organic terrain smoke: %d failures" % failures)
	quit(1 if failures else 0)
