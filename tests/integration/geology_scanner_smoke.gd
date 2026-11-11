extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0
var world: Node2D

class ProbeSite extends "res://scripts/systems/dig_site.gd":
	var probe_kind := "soil"
	func material(cell: Vector2i) -> String:
		return probe_kind if cell == Vector2i(-3, 4) else super.material(cell)

func picture(name: String) -> Image:
	world.camera.force_update_scroll()
	world.queue_redraw()
	world.scanner_view.queue_redraw()
	await physics_frame
	await physics_frame
	world.queue_redraw()
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	check(pixels.save_png("res://reports/" + name + ".png") == OK, "capture " + name)
	return pixels

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.scanner_view.set_process(false)
	world.guide_state.set_muted(true)
	world.guide.set_process(false)
	world.guide._update_bubble()
	Fixture.lab_room(world)
	world.player.position = Vector2(-90, 160)
	var view = world.scanner_view
	check(view.has_method("reveal_strength"), "scanner has temporary geological reveals")
	check(world.TerrainRenderer.has_method("surface_uv"), "rock texture uses continuous world coordinates")
	if not view.has_method("reveal_strength") or not world.TerrainRenderer.has_method("surface_uv"):
		quit(1)
		return
	var uv0: Vector2 = world.TerrainRenderer.surface_uv(Vector2(0, 140), 0, 0)
	var uv1: Vector2 = world.TerrainRenderer.surface_uv(Vector2(40, 140), 0, 0)
	check(uv0.distance_to(uv1) > 0.01, "adjacent cells do not restart the same rock image")
	var left: Vector2 = world.TerrainRenderer.surface_uv(Vector2(39.999, 140), 0, 0)
	var right: Vector2 = world.TerrainRenderer.surface_uv(Vector2(40.001, 140), 0, 0)
	check(left.distance_to(right) < 0.001, "UVs are continuous across a cell boundary")
	var before: Array = world.site.snapshot()
	var ore := Vector2i(1, 3)
	var capture := "--capture" in OS.get_cmdline_user_args()
	var unscanned_image: Image
	world.camera.position = Vector2(-90, 128)
	world.camera.zoom = Vector2.ONE
	world.equip_tool(0)
	if capture:
		unscanned_image = await picture("geology-normal-720p")
	world.equip_tool(1)
	view.advance(0.01)
	check(view.reveal_strength(ore) == 0, "ore is not revealed before the wave reaches it")
	view.advance(1.79)
	check(view.reveal_strength(ore) > 0 and world.scanned.has(ore), "actual wavefront reveals reachable-radius ore and records discovery")
	check(view.reveal_strength(Vector2i(18, 18)) == 0, "scanner cannot reveal the entire planet")
	if capture:
		await picture("geology-scanned-720p")
		root.size = Vector2i(1920, 1080)
		await picture("geology-scanned-1080p")
	var saved: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(saved))), "analyses survive a real JSON world restore")
	check(world.scanned.has(ore) and view.reveal_strength(ore) == 0, "restore keeps discoveries but not active radiography")
	view.advance(1.8)
	view.advance(1.8)
	check(view.reveal_strength(ore) > 0, "a new wave can reveal a previously discovered cell again")
	view.pulses.clear()
	view.emission_timer = 0
	view.advance(0.01)
	world.player.position = Vector2(4000, 4000)
	view.advance(10)
	check(view.reveal_strength(ore) == 0 and world.scanned.has(ore), "old traces expire after leaving scanner range")
	world.player.position = Vector2(-90, 160)
	var discoveries: Dictionary = world.scanned.duplicate()
	world.equip_tool(0)
	view.advance(0.1)
	check(view.reveal_strength(ore) == 0 and world.scanned == discoveries, "switching tools hides ore but retains knowledge")
	if capture:
		root.size = Vector2i(1280, 720)
		world.camera.position = Vector2(-90, 128)
		world.camera.zoom = Vector2.ONE
		var hidden_again := await picture("geology-known-but-hidden-720p")
		check(unscanned_image.get_region(Rect2i(510, 235, 410, 300)).get_data() == hidden_again.get_region(Rect2i(510, 235, 410, 300)).get_data(), "known deposits leave no permanent symbol or terrain-color leak")
		var old_site = world.site
		var old_planet = world.planet_def
		var probe := ProbeSite.new()
		probe.restore(old_site.snapshot())
		world.site = probe
		world.planet_def = load("res://scripts/data/planet_catalog.gd").find("verdant")
		world.organic_terrain = false
		var host := await picture("geology-legacy-host")
		probe.probe_kind = "iron"
		var buried := await picture("geology-legacy-buried")
		var point: Vector2 = world.get_global_transform_with_canvas() * world.Grid.center(Vector2i(-3, 4))
		var region := Rect2i(Vector2i(point) - Vector2i(12, 12), Vector2i(24, 24))
		check(host.get_region(region).get_data() == buried.get_region(region).get_data(), "legacy planetary terrain cannot leak ore through a soil-only tint")
		world.site = old_site
		world.planet_def = old_planet
		world.organic_terrain = true
	var invalid := saved.duplicate(true)
	invalid.scan_findings[0].kind = "unknown"
	var unchanged: Dictionary = world.capture_state()
	check(not world.restore_state(invalid) and world.capture_state() == unchanged, "malformed discoveries cannot partially replace the live world")
	check(world.site.snapshot() == before, "rendering and scanning do not excavate terrain")
	world.site.removed[ore] = true
	world.remove_mined_block(ore, "crystal")
	check(world.scanned.has(ore), "mining and blast cleanup retain historical analyses")
	check(not world.TerrainRenderer.hidden_pockets(world).has(Vector2i(3, 3)) and not world.environment.released.has("water_east"), "an unopened water reservoir is visible without breaching its rock seal")
	Fixture.carve(world, Vector2i(2, 3))
	world.environment.detect_breaches()
	check(not world.TerrainRenderer.hidden_pockets(world).has(Vector2i(3, 3)), "breaching a reservoir exposes its real fluids normally")
	print("GEOLOGY SCANNER: %d failures" % failures)
	quit(1 if failures else 0)
