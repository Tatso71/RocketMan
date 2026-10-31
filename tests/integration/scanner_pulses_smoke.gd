extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var world: Node2D
var failures := 0
var capture := false

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 4) -> void:
	for index in range(count):
		await physics_frame

func picture(name: String) -> Image:
	world.queue_redraw()
	world.scanner_view.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	check(pixels.save_png("res://reports/" + name + ".png") == OK, name + " screenshot saved")
	return pixels

func changed_pixels(before: Image, after: Image, origin: Vector2, max_radius: float) -> Vector2i:
	var inside := 0
	var outside := 0
	for y in range(60, before.get_height() - 40, 2):
		for x in range(0, before.get_width(), 2):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.08:
				continue
			if origin.distance_to(Vector2(x, y)) <= max_radius + 6:
				inside += 1
			else:
				outside += 1
	return Vector2i(inside, outside)

func _run() -> void:
	create_timer(40).timeout.connect(func(): push_error("Scanner pulses timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames()
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.guide.set_process(false)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	var view: Node2D = world.scanner_view
	view.set_process(false)
	Fixture.lab_room(world)
	world.player.position = Vector2(-100, 160)
	world.camera.position = Vector2(-100, 128)
	world.camera.zoom = Vector2.ONE
	world.show_grid = false
	world.equip_tool(0)
	view.advance(0.2)
	check(view.pulses.is_empty(), "mining mode emits no scanner rings")
	world.equip_tool(1)
	var energy: float = world.ship_energy()
	var crew: float = world.crew_energy()
	var terrain: Array = world.site.snapshot()
	var scans: Dictionary = world.scanned.duplicate()
	var light: float = world._illumination(Grid.center(Vector2i(-3, 4)))
	view.advance(0.2)
	check(view.pulses.size() == 1 and view.pulses[0].origin == world.player.position - Vector2(0, 32), "selecting scanner emits from the explorer torso")
	check(view.pulses[0].max_radius == Grid.metres(4), "initial scanner ring stops at four metres")
	var first: Dictionary = view.pulses[0]
	var radius: float = view.radius_at(first.age, first.max_radius)
	world.player.facing = -1
	view.advance(0.65)
	check(view.pulses.size() == 2 and view.radius_at(first.age, first.max_radius) > radius, "scanner emits repeated expanding rings independently of facing and grid")
	var origin: Vector2 = first.origin
	world.player.position.x += 40
	view.advance(0.65)
	check(first.origin == origin and view.pulses.back().origin.x == world.player.position.x, "emitted waves retain their origin while new waves follow the moving explorer")
	view.advance(0.65)
	check(not view.pulses.has(first) and view.pulses.size() <= 3, "fully faded rings are removed instead of accumulating")
	view.advance(60)
	check(view.pulses.size() <= 3, "a stalled frame cannot create unbounded catch-up rings")
	check(world.ship_energy() == energy and world.crew_energy() == crew and world.site.snapshot() == terrain and world.scanned == scans and world._illumination(Grid.center(Vector2i(-3, 4))) == light, "visual sonar does not consume energy, reveal, excavate or illuminate terrain")
	world.controls_locked = true
	view.advance(0.1)
	check(view.pulses.is_empty(), "locked controls clear the scanner overlay")
	world.controls_locked = false
	view.advance(0.2)
	world.equip_tool(3)
	view.advance(0.1)
	check(view.pulses.is_empty(), "switching to jetpack clears all scanner rings")
	world.equip_tool(1)
	world.player.position = Vector2(20, 80)
	for x in range(1, 4):
		for y in range(1, 3):
			Fixture.carve(world, Vector2i(x, y))
	await frames()
	var scanner: Resource = world.active_tool()
	check(not world.can_reach(Vector2i(4, 2)), "level-I scanner rejects a target beyond four metres")
	scanner.scanner_level = 2
	check(world.can_reach(Vector2i(4, 2)), "level-II scanner targeting uses the same five-metre range as its waves")
	world.target_cell = Vector2i(4, 2)
	world.mine_timer = 0
	world._mine_target()
	check(world.scanned.has(Vector2i(4, 2)) and not world.site.material(Vector2i(4, 2)).is_empty(), "targeted scanning still identifies without destroying a block")
	for level in range(1, 5):
		scanner.scanner_level = level
		view.pulses.clear()
		view.emission_timer = 0
		view.advance(0.2)
		world._refresh_hud()
		check(view.pulses[0].max_radius == Grid.metres(3 + level) and world.metric_label.text.contains("%.1f m" % (3.0 + level)), "level %d rings and HUD share their real scanner range" % level)
	scanner.scanner_level = 1
	world.player.position = Vector2(-100, 160)
	world.target_cell = Vector2i(-3, 4)
	world.beam_time = 0
	world._refresh_hud()
	if capture:
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			view.pulses.clear()
			var baseline := await picture("scanner-baseline-%dp" % size.y)
			view.emission_timer = 0
			view.advance(0.8)
			var visible := await picture("scanner-waves-%dp" % size.y)
			var transform: Transform2D = root.get_final_transform() * world.get_global_transform_with_canvas()
			var changes := changed_pixels(baseline, visible, transform * (world.player.position - Vector2(0, 32)), Grid.metres(4) * transform.get_scale().x)
			check(changes.x > 100 and changes.y == 0, "native %dp pixels show rings only inside the scanner range (%d inside, %d outside)" % [size.y, changes.x, changes.y])
			view.pulses.clear()
			view.pulses.append({"origin": world.player.position - Vector2(0, 32), "age": 1.7, "max_radius": Grid.metres(4), "color": scanner.beam_color})
			await picture("scanner-fade-%dp" % size.y)
			view.advance(0.11)
			check(view.pulses.all(func(pulse: Dictionary): return pulse.age < view.DURATION_SECONDS), "native late-fade ring expires cleanly")
	print("SCANNER PULSES SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
