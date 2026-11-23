extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var world: Node2D
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func plane(item: CanvasItem) -> int:
	var parent := item.get_parent()
	return item.z_index + (plane(parent) if item.z_as_relative and parent is CanvasItem else 0)

func frame() -> Image:
	world.queue_redraw()
	world.outpost.queue_redraw()
	world.outpost.industry_ui.queue_redraw()
	world.outpost.industry_ui.pipe_renderer.queue_redraw()
	for index in range(2): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	world = load("res://scenes/prototype/robbie_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	for kind: String in ["water", "gas", "oil", "acid"]: world.environment.get(kind).clear()
	var outpost: Node2D = world.outpost
	var pipes: Node2D = outpost.industry_ui.pipe_renderer
	check(plane(pipes) < plane(outpost), "main installation artwork is above every manual utility line")
	check(plane(pipes) < plane(outpost.industry_ui), "industrial artwork is above every manual utility line")
	check(plane(pipes) < plane(world.ladder_layer), "ladders remain above utility lines")
	check(plane(pipes) < plane(world.player) and plane(pipes) < plane(world.drone), "characters remain above utility lines")
	check(plane(outpost.hydraulic_ui) == 8, "valve and hydraulic preview plane retains its original depth")
	for child in outpost.get_children():
		if child is Node2D and child.get_script() == outpost.CubeView:
			check(plane(child) == 7, "physical cube plane retains its original depth")
	var samples := {
		"laboratory": Vector2(60, 100), "lamp": Vector2(20, 8),
		"pump": Vector2(20, 20), "fan": Vector2(20, 60),
		"furnace": Vector2(20, 60), "gas_converter": Vector2(20, 60),
		"greenhouse": Vector2(60, 60), "water_tank": Vector2(20, 60),
		"solar_panel": Vector2(20, 12)
	}
	for x in range(-4, 0):
		for y in range(0, 4): Fixture.carve(world, Vector2i(x, y))
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		for id: String in outpost.Buildings.CUBE_IDS:
			outpost.buildings.structures.clear()
			for kind: String in outpost.Network.KINDS: outpost.network.cells[kind].clear()
			outpost.network.water_axes.clear()
			var origin := Vector2i(8, -1) if id == "solar_panel" else Vector2i(-4, 1)
			outpost.buildings.install(id, origin)
			world.camera.position = Grid.to_world(origin) + Vector2(80, 60)
			world.camera.zoom = Vector2.ONE
			world.camera.force_update_scroll()
			var reference := await frame()
			var local: Vector2 = samples[id]
			var cell := origin + Grid.to_cell(local)
			for kind: String in outpost.Network.KINDS:
				outpost.network.add(kind, cell)
				outpost.network.add(kind, cell + Vector2i.UP)
			var wired := await frame()
			var screen: Vector2 = world.get_global_transform_with_canvas() * (Grid.to_world(origin) + local)
			var pixel := Vector2i(root.get_screen_transform() * screen)
			check(wired.get_pixelv(pixel).is_equal_approx(reference.get_pixelv(pixel)), "%s keeps its opaque foreground pixel over crossing pipes/cables at %dp" % [id, viewport_size.y])
			if id == "pump" and "--capture" in OS.get_cmdline_user_args():
				wired.save_png("res://reports/installation-layers-%d.png" % viewport_size.y)
	print("INSTALLATION LAYERS: %d failures" % failures)
	quit(1 if failures else 0)
