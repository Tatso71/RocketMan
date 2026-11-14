extends SceneTree

const Renderer = preload("res://scripts/ui/terrain_renderer.gd")
const Surface = preload("res://scripts/ui/vein_surface.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Geology = preload("res://scripts/data/ocra_geology.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var failures := 0

class TerrainView extends Node2D:
	var site = Site.new()
	var environment = preload("res://scripts/systems/environment_field.gd").new(site)
	var camera := Camera2D.new()
	var show_grid := false
	var light_level := 1.0
	var light_cutoff := INF
	var profile_mode := ""
	var profile_batch := {}
	var samples: Array = []
	func _ready() -> void:
		add_child(camera)
	func _illumination(point: Vector2) -> float:
		return light_level if point.x < light_cutoff else 0.0
	func _draw() -> void:
		var started := Time.get_ticks_usec()
		if profile_mode == "ore":
			Renderer._draw_veins(self, profile_batch, {})
		else:
			Renderer.draw(self)
		if not profile_mode.is_empty(): samples.append((Time.get_ticks_usec() - started) / 1000.0)

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value: failures += 1

func picture(view: TerrainView) -> Image:
	view.camera.force_update_scroll()
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func host_picture(view: TerrainView) -> Image:
	var identity: Dictionary = view.site._pure_vein_cells
	view.site._pure_vein_cells = {}
	var result := await picture(view)
	view.site._pure_vein_cells = identity
	return result

func aim(view: TerrainView, vein: Dictionary, size: Vector2i) -> void:
	root.size = size
	root.content_scale_size = size
	view.camera.position = Grid.to_world(vein.origin) + Vector2(vein.size) * 20
	view.camera.zoom = Vector2.ONE * 2.5 * size.y / 720.0

func expose(view: TerrainView, vein: Dictionary) -> void:
	var cells: Array = Site.HazardLayout.cells(vein)
	for cell: Vector2i in cells:
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor := cell + offset
			if not cells.has(neighbor) and not view.site.indestructible(neighbor):
				view.site.removed[neighbor] = true

func check_pixels(view: TerrainView, art: Image, host: Image, label: String) -> void:
	var inverse := view.get_global_transform_with_canvas().affine_inverse()
	var eligible_cells := {}
	for cell: Vector2i in view.site._pure_vein_cells:
		if not view.site.material(cell).is_empty() and view.site.exposed(cell) and view._illumination(Grid.center(cell)) > 0.08:
			eligible_cells[cell] = true
	var changed := 0
	var leaked := 0
	var retained_rock := 0
	for y in range(0, art.get_height(), 2):
		for x in range(0, art.get_width(), 2):
			var point: Vector2 = inverse * Vector2(x + 0.5, y + 0.5)
			var cell := Grid.to_cell(point)
			var eligible := eligible_cells.has(cell)
			if art.get_pixel(x, y) != host.get_pixel(x, y):
				changed += 1
				# Raster edge rounding can land within one pixel of the metric boundary.
				if not eligible:
					var local := point - Grid.to_world(cell)
					if local.x > 0.5 and local.y > 0.5 and local.x < 39.5 and local.y < 39.5:
						leaked += 1
			elif eligible:
				retained_rock += 1
	check(changed > 200, label + " nonblank mineral pixels differ from the rock atlas")
	check(leaked == 0, label + " no mineral pixels in buried, air, destroyed or unlit cells (%d)" % leaked)
	check(retained_rock > changed, label + " host rock remains dominant (%d rock / %d changed samples)" % [retained_rock, changed])

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native raster required: --rendering-method gl_compatibility --fixed-fps 60")
		quit(1)
		return
	var view := TerrainView.new()
	root.add_child(view)
	await process_frame
	for vein: Dictionary in Geology.pure_veins(0):
		view.site = Site.new()
		view.environment = preload("res://scripts/systems/environment_field.gd").new(view.site)
		aim(view, vein, Vector2i(1280, 720))
		var buried := await picture(view)
		var buried_host := await host_picture(view)
		check(buried.get_data() == buried_host.get_data(), vein.kind + " buried identity is exactly host rock")
		expose(view, vein)
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			aim(view, vein, size)
			var art := await picture(view)
			var host := await host_picture(view)
			check(art.get_size() == size, "native raster size %s" % size)
			check_pixels(view, art, host, "%s %dp" % [vein.kind, size.y])
			check(art.save_png("res://reports/vein-surface-%s-%dp.png" % [vein.kind, size.y]) == OK, "save new capture without overwriting baseline")
		view.light_level = 0
		var dark := await picture(view)
		var dark_host := await host_picture(view)
		check(dark.get_data() == dark_host.get_data(), vein.kind + " no glow in total darkness")
		check(dark.get_pixel(dark.get_width() / 2, dark.get_height() / 2).get_luminance() < 0.03, "darkness raster is actually dark")
		view.light_level = 1
		view.light_cutoff = view.camera.position.x
		var half_lit := await picture(view)
		var half_host := await host_picture(view)
		check_pixels(view, half_lit, half_host, vein.kind + " moving light gate")
		view.light_cutoff = INF
		var cells: Array = Site.HazardLayout.cells(vein)
		var first: Vector2i = cells[0]
		check(view.site.mine(first, 10) == vein.kind, "excavate a decorated %s block" % vein.kind)
		var excavated := await picture(view)
		var excavated_host := await host_picture(view)
		check_pixels(view, excavated, excavated_host, vein.kind + " after excavation")
		check(not view.get_meta("vein_geometry").batch.cells.has(first), "destroyed cell is absent on the very next draw")
	await benchmark(view)
	view.queue_free()
	await process_frame
	await gameplay_captures()
	print("VEIN SURFACE VISUAL: %d failures" % failures)
	quit(1 if failures else 0)

func benchmark(view: TerrainView) -> void:
	var vein: Dictionary = Geology.pure_veins(0)[0]
	view.site = Site.new()
	view.environment = preload("res://scripts/systems/environment_field.gd").new(view.site)
	expose(view, vein)
	aim(view, vein, Vector2i(1280, 720))
	var candidates: Array = Site.HazardLayout.cells(vein)
	var lit := func(_point: Vector2) -> float: return 1.0
	var cache := {}
	var started := Time.get_ticks_usec()
	var batch := Renderer.cached_vein_batch(cache, view.site, candidates, lit)
	var cold_ms := (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	for index in range(200): Renderer.cached_vein_batch(cache, view.site, candidates, lit)
	var warm_ms := (Time.get_ticks_usec() - started) / 200000.0
	check(batch.points.size() < 10000, "visible overlay stays below 10000 vertices in the copper fixture")
	check(is_same(batch, Renderer.cached_vein_batch(cache, view.site, candidates, lit)), "warmed selection reuses batch identity")
	var measurements := {"cold_geometry_ms": cold_ms, "warm_geometry_ms": warm_ms, "vertices": batch.points.size(), "triangles": batch.indices.size() / 3, "additional_submissions": 1}
	view.profile_batch = batch
	for mode: String in ["host", "full", "ore"]:
		var identity: Dictionary = view.site._pure_vein_cells
		if mode == "host": view.site._pure_vein_cells = {}
		view.profile_mode = mode
		for index in range(10):
			view.queue_redraw()
			await process_frame
		view.samples.clear()
		for index in range(40):
			view.queue_redraw()
			await process_frame
		view.samples.sort()
		measurements[mode + "_cpu_median_ms"] = view.samples[view.samples.size() / 2]
		measurements[mode + "_cpu_p95_ms"] = view.samples[floori((view.samples.size() - 1) * 0.95)]
		view.site._pure_vein_cells = identity
	view.profile_mode = ""
	print("WARMED CPU ONLY (draw commands and lighting; NOT GPU/frame timing): ", JSON.stringify(measurements))
	var report := FileAccess.open("res://reports/vein-surface-cpu.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(measurements, "\t"))

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	for child: Node in node.get_children(): freeze(child)

func gameplay_captures() -> void:
	var world: Node2D = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	freeze(world)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	for x in [-24, -23]:
		for y in range(3, 7):
			preload("res://tests/fixtures/dig_site_fixture.gd").carve(world, Vector2i(x, y))
	world.player.position = Vector2(-940, 240)
	world.drone.position = Vector2(-930, 170)
	world.target_cell = Vector2i(-22, 4)
	world.camera.position = Vector2(-840, 210)
	world.camera.zoom = Vector2.ONE * 1.7
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		root.content_scale_size = Vector2i(1280, 720)
		world.camera.force_update_scroll()
		world._refresh_hud()
		for index in range(3):
			world.queue_redraw()
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(image.get_size() == size and image.save_png("res://reports/vein-surface-gameplay-%dp.png" % size.y) == OK, "capture real gameplay with personal light at %dp" % size.y)
	world.queue_free()
	await process_frame
