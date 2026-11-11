extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0
var world: Node2D
var label := "current"
var measurements: Array = []
var compare := false

class OreProbeSite extends "res://scripts/systems/dig_site.gd":
	var probe_kind := "stone"
	func material(cell: Vector2i) -> String:
		if cell == Vector2i(-3, 4) and not removed.has(cell):
			return probe_kind
		return super.material(cell)

const PROFILE_SOURCE := """extends "res://scripts/prototype/rocket_home.gd"
var terrain_usec := 0
var light_calls := 0
var reference_renderer: GDScript
func _draw_terrain() -> void:
	light_calls = 0
	var start := Time.get_ticks_usec()
	if reference_renderer != null:
		reference_renderer.draw(self)
	else:
		super._draw_terrain()
	terrain_usec = Time.get_ticks_usec() - start
func _illumination(point: Vector2) -> float:
	light_calls += 1
	return super._illumination(point)
"""

# Frozen pre-optimization submission path, used only by --compare. Geometry,
# lighting, atlas sampling, and chipped edges are the same as the working
# renderer at the start of this task, not the project's legacy visual mode.
const REFERENCE_DRAW := """static func draw(world: Node2D) -> void:
	world.draw_rect(Rect2(-4000, 0, 8000, 3000), DARK)
	var center: Vector2 = world.camera.get_screen_center_position()
	var size: Vector2 = world.get_viewport_rect().size / world.camera.zoom
	var visible := Rect2(center - size * 0.5, size).grow(60)
	var lighting := {}
	var vertices := {}
	var hidden := hidden_pockets(world)
	var exposed_edges: Array = []
	var grid_cells: Array = []
	for y in range(world.site.DEPTH):
		for x in range(world.site.LEFT, world.site.RIGHT):
			var cell := Vector2i(x, y)
			var rect := Grid.rect(cell)
			if not rect.intersects(visible):
				continue
			var kind: String = world.site.material(cell)
			if hidden.has(cell):
				kind = "stone"
			var light: float = world._illumination(rect.get_center())
			var base := Color("a45148").lerp(Color("746b7a"), geology(rect.get_center(), world.site.terrain_seed))
			if kind.is_empty():
				base = Color("41444c")
			if kind.is_empty():
				var corners := PackedVector2Array([rect.position, rect.position + Vector2(40, 0), rect.end, rect.position + Vector2(0, 40)])
				var inks := PackedColorArray()
				for point: Vector2 in corners:
					inks.append(DARK.lerp(base, world._illumination(point) * 0.85))
				world.draw_polygon(corners, inks)
			else:
				var tile_size := Vector2(rock_atlas.get_size()) / 4.0
				for facet: PackedVector2Array in facets_for(cell, world.site.terrain_seed):
					for point: Vector2 in facet:
						if vertices.has(point):
							continue
						var local_light: float = world._illumination(point)
						var blend := geology(point, world.site.terrain_seed)
						var warp := Vector2(field(point, world.site.terrain_seed), field(point + Vector2(931, 207), world.site.terrain_seed)) * 65
						var colors := PackedColorArray()
						var coordinates := PackedVector2Array()
						for layer in range(4):
							var tint := DARK.lerp(Color.WHITE, local_light)
							tint.a = [1.0, 0.28 + field(point + Vector2(310, 0), world.site.terrain_seed) * 0.2, blend, blend * 0.35][layer]
							colors.append(tint)
							coordinates.append((Vector2(layer % 2 * 2, layer / 2) * tile_size + Vector2(8, 8) + warped_uv(point, warp, layer) * (tile_size - Vector2(16, 16))) / Vector2(rock_atlas.get_size()))
						vertices[point] = {"colors": colors, "uvs": coordinates}
					for layer in range(4):
						var inks := PackedColorArray()
						var uvs := PackedVector2Array()
						for point: Vector2 in facet:
							inks.append(vertices[point].colors[layer])
							uvs.append(vertices[point].uvs[layer])
						world.draw_polygon(facet, inks, uvs, rock_atlas)
				if light > 0.08:
					exposed_edges.append({"cell": cell, "base": base, "light": light})
			if world.show_grid and light > 0.15:
				grid_cells.append({"rect": rect, "light": light})
	for entry: Dictionary in exposed_edges:
		_draw_edges(world, entry.cell, entry.base, entry.light, hidden)
	for entry: Dictionary in grid_cells:
		world.draw_rect(entry.rect, Color(0.65, 0.7, 0.73, entry.light * 0.2), false, 1)

"""

func reference_renderer() -> GDScript:
	var source: String = load("res://scripts/ui/terrain_renderer.gd").source_code
	var start := source.find("static func draw(")
	var end := source.find("static func _draw_edges(", start)
	source = source.substr(0, start) + REFERENCE_DRAW + source.substr(end)
	start = source.find("static func hidden_pockets(")
	end = source.find("static func _prepare_cache(", start)
	source = source.substr(0, start) + """static func hidden_pockets(world: Node2D) -> Dictionary:
	var hidden := {}
	for pocket: Dictionary in world.site.pockets():
		if pocket.kind == "water" or world.environment.released.has(pocket.id):
			continue
		for cell: Vector2i in world.site.HazardLayout.cells(pocket):
			hidden[cell] = pocket.kind
	return hidden

""" + source.substr(end)
	var script := GDScript.new()
	script.source_code = source
	check(script.reload() == OK, "compile pre-optimization reference")
	return script

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1

func stats(values: Array) -> Dictionary:
	values.sort()
	var total := 0.0
	for value: float in values:
		total += value
	return {"mean_ms": total / values.size() / 1000.0, "p50_ms": values[values.size() / 2] / 1000.0, "p95_ms": values[int(values.size() * 0.95)] / 1000.0}

func frame() -> void:
	world.queue_redraw()
	await RenderingServer.frame_post_draw
	await process_frame

func pixels(name: String) -> Image:
	await frame()
	var image := root.get_texture().get_image()
	check(image.get_size() == root.size and not image.is_invisible(), "native nonblank pixels " + name)
	var path := "res://reports/terrain-perf-%s-%s.png" % [label, name]
	check(image.save_png(path) == OK, "capture " + name)
	var reference := "res://reports/terrain-perf-baseline-%s.png" % name
	if compare and label != "baseline" and FileAccess.file_exists(reference):
		var before := Image.load_from_file(reference)
		check(image.get_data() == before.get_data(), "exact baseline pixels " + name)
	return image

func image_now() -> Image:
	world.camera.force_update_scroll()
	await frame()
	return root.get_texture().get_image()

func terrain_region(image: Image, rect: Rect2) -> PackedByteArray:
	var transform := world.get_global_transform_with_canvas()
	var region := Rect2i(transform * rect.position, rect.size * world.camera.zoom)
	return image.get_region(region).get_data()

func check_fresh_cache(expected: Image, message: String) -> void:
	world.remove_meta("terrain_geometry")
	world.remove_meta("terrain_pockets")
	var fresh := await image_now()
	check(expected.get_data() == fresh.get_data(), message)

func check_live_changes() -> void:
	world.camera.position = Vector2(-90, 128)
	world.camera.zoom = Vector2.ONE
	var original := await image_now()
	world.player.position += Vector2(200, 140)
	var moved := await image_now()
	var rock_patch := Rect2(-80, 200, 80, 40)
	check(terrain_region(original, rock_patch) != terrain_region(moved, rock_patch), "moving player changes native rock lighting pixels away from sprites")
	await check_fresh_cache(moved, "moving-player lighting matches uncached render")
	world.player.position -= Vector2(200, 140)
	world.outpost.light_sources.append({"point": Vector2(400, 320), "inner": 60.0, "outer": 180.0})
	var lit := await image_now()
	check(original.get_data() != lit.get_data(), "new structure light changes native pixels")
	await check_fresh_cache(lit, "structure illumination matches uncached render")
	world.outpost.light_sources.clear()
	check(original.get_data() == (await image_now()).get_data(), "removed structure light is not retained")
	var cell := Vector2i(-3, 4)
	world.site.removed[cell] = true
	var excavated := await image_now()
	check(original.get_data() != excavated.get_data(), "world edit updates native rock and exposed-edge pixels")
	await check_fresh_cache(excavated, "excavation matches fresh geometry cache")
	world.site.removed.erase(cell)
	check(original.get_data() == (await image_now()).get_data(), "refilling cell restores original native pixels")
	world.environment.released["water_east"] = true
	var breached := await image_now()
	check(original.get_data() == breached.get_data(), "water cavity remains visible before and after breach")
	await check_fresh_cache(breached, "breach matches fresh pocket mask")
	world.environment.released.erase("water_east")
	check(original.get_data() == (await image_now()).get_data(), "resealed reservoir restores camouflage")
	world.camera.position = Vector2(280, 680)
	world.player.position += Vector2(380, 520)
	var concealed_oil := await image_now()
	world.environment.released["oil_east"] = true
	var revealed_oil := await image_now()
	check(concealed_oil.get_data() != revealed_oil.get_data(), "oil reservoir still loses camouflage when breached")
	await check_fresh_cache(revealed_oil, "oil breach matches fresh pocket mask")
	world.environment.released.erase("oil_east")
	check(concealed_oil.get_data() == (await image_now()).get_data(), "resealed oil restores camouflage")
	world.camera.position = Vector2(-90, 128)
	world.player.position -= Vector2(380, 520)
	world.site.terrain_seed = 11
	var reseeded := await image_now()
	check(original.get_data() != reseeded.get_data(), "new seed changes native rock texture")
	await check_fresh_cache(reseeded, "seed change matches fresh geometry cache")
	world.site.terrain_seed = 0
	check(original.get_data() == (await image_now()).get_data(), "original seed restores original native pixels")
	var old_site = world.site
	var probe := OreProbeSite.new()
	probe.restore(old_site.snapshot())
	world.site = probe
	var host := await image_now()
	probe.probe_kind = "iron"
	check(host.get_data() == (await image_now()).get_data(), "hidden iron identity does not alter native rock pixels")
	probe.probe_kind = "crystal"
	check(host.get_data() == (await image_now()).get_data(), "hidden crystal identity does not alter native rock pixels")
	world.site = old_site

func benchmark(name: String) -> void:
	world.camera.force_update_scroll()
	for i in range(20):
		await frame()
	var cpu: Array = []
	var elapsed: Array = []
	var calls: Array = []
	for i in range(60):
		var start := Time.get_ticks_usec()
		await frame()
		elapsed.append(Time.get_ticks_usec() - start)
		cpu.append(world.terrain_usec)
		calls.append(world.light_calls)
	var result := {"label": label, "view": name, "native_size": root.size, "viewport": world.get_viewport_rect().size, "zoom": world.camera.zoom, "samples": cpu.size(), "warmup": 20, "terrain_cpu": stats(cpu), "native_frame": stats(elapsed), "illumination_calls": calls[0], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)}
	measurements.append(result)
	print("TERRAIN_PERF " + JSON.stringify(result))
	await pixels(name)

func paired_benchmark(name: String, reference: GDScript) -> void:
	if compare:
		label = "baseline"
		world.reference_renderer = reference
		await benchmark(name)
		world.reference_renderer = null
		label = "paired"
	await benchmark(name)

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	for child: Node in node.get_children():
		freeze(child)

func run() -> void:
	create_timer(600).timeout.connect(func(): quit(2))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
		if arg == "--compare":
			compare = true
	check(not OS.get_cmdline_args().has("--fixed-fps"), "benchmark uses native non-fixed-fps frames")
	if DisplayServer.get_name() == "headless":
		check(false, "native display required for timings and pixel checks")
		quit(1)
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Compile after autoloads exist; preloading the world from a SceneTree script
	# would resolve SaveManager before Godot registers its singleton.
	var profile := GDScript.new()
	profile.source_code = PROFILE_SOURCE
	if profile.reload() != OK:
		quit(1)
		return
	# rocket_home.tscn is a single Node2D with this script and no overrides.
	world = profile.new()
	world.name = "RocketHome"
	root.add_child(world)
	current_scene = world
	await physics_frame
	freeze(world)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	Fixture.lab_room(world)
	world.set_hatch(true)
	world.player.position = Vector2(-100, 160)
	world.drone.position = Vector2(-150, 160)
	var snapshot: Array = world.site.snapshot()
	var blocks: int = world.blocks.size()
	var reference: GDScript = reference_renderer() if compare else null
	print("TERRAIN_PERF_ENV " + JSON.stringify({"engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "method": RenderingServer.get_current_rendering_method(), "vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps, "scope": "actual home scene; simulation disabled; terrain callback CPU and post-draw wall time; no fixed-fps"}))
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		root.content_scale_size = resolution
		world.camera.position = Vector2(-90, 128)
		world.camera.zoom = Vector2.ONE
		await paired_benchmark("%dx%d-surface" % [resolution.x, resolution.y], reference)
		world.camera.position = Vector2(0, 480)
		world.camera.zoom = Vector2.ONE * 0.65
		await paired_benchmark("%dx%d-overview" % [resolution.x, resolution.y], reference)
	if label != "baseline":
		await check_live_changes()
	check(world.site.snapshot() == snapshot and world.blocks.size() == blocks, "rendering preserves terrain and colliders")
	print("TERRAIN PERFORMANCE: %d failures" % failures)
	var report := FileAccess.open("res://reports/terrain-perf-%s.json" % label, FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify(measurements, "\t"))
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
