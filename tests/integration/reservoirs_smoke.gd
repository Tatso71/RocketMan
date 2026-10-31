extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Field = preload("res://scripts/systems/environment_field.gd")
const Layout = preload("res://scripts/data/hazard_layout.gd")
const Expedition = preload("res://scripts/systems/expedition_state.gd")
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

func volume(field: Dictionary) -> float:
	var result := 0.0
	for amount in field.values():
		result += float(amount)
	return result

func picture(name: String) -> Image:
	world._refresh_hud()
	world.queue_redraw()
	world.reservoir_view.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	check(pixels.save_png("res://reports/" + name + ".png") == OK, name + " screenshot saved")
	return pixels

func _run() -> void:
	create_timer(90).timeout.connect(func(): push_error("Reservoir smoke timeout"); quit(2))
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
	world.tutorial_ui.set_process(false)
	world.tutorial_ui.panel.hide()
	var pristine: Dictionary = world.capture_state()
	check(world.site.layout_version == 2 and world.site.pockets().size() == 7, "new Ocra contains seven sealed areas including acid")
	for pocket: Dictionary in world.site.pockets():
		var all_air := true
		for cell: Vector2i in Layout.cells(pocket):
			all_air = all_air and world.site.material(cell).is_empty() and not world.blocks.has(cell)
		check(all_air, "%s is actual fluid-filled space, not minable blocks" % pocket.id)
	for y in range(10, 17):
		Fixture.carve(world, Vector2i(-22, y))
		if y != 12:
			Fixture.carve(world, Vector2i(-21, y))
	world.player.position = Vector2(-860, 480)
	world.drone.range_metres = 50
	Fixture.support(world)
	await frames()
	var seal := Vector2i(-21, 12)
	world.equip_tool(1)
	world.target_cell = seal
	world.mine_timer = 0
	world._mine_target()
	check(world.scanned.has(seal) and world.status_label.text.contains("Acido") and world.environment.released.is_empty(), "scanner identifies the acid area beyond its solid wall without releasing it")
	if capture:
		world.camera.position = Vector2(-790, 530)
		world.camera.zoom = Vector2.ONE * 1.35
		world.outpost.light_sources = [{"point": Vector2(-790, 530), "inner": 180.0, "outer": 260.0}]
		world.beam_time = 0
		await picture("reservoir-acid-sealed-720p")
	world.equip_tool(0)
	for hit in range(3):
		if world.site.material(seal).is_empty():
			break
		world.mine_timer = 0
		world._mine_target()
	check(world.site.material(seal).is_empty() and world.environment.released.has("acid_west"), "normal beam mining breaches the reservoir boundary, not its liquid interior")
	var acid_before := volume(world.environment.acid)
	for step in range(60):
		world.environment.advance(0.2)
	check(float(world.environment.acid.get(Vector2i(-22, 16), 0)) > 0 and not world.environment.acid.has(Vector2i(-23, 16)), "acid exits the breach, descends into connected galleries and stops at rock")
	check(absf(volume(world.environment.acid) - acid_before) < 0.0001, "a leaking reservoir never creates an infinite acid source")
	if capture:
		world.beam_time = 0
		for child: Node in world.gear.get_children():
			if child is CPUParticles2D:
				child.hide()
		await picture("reservoir-acid-breach-720p")
	world.player.position = Vector2(-740, 560)
	var integrity: float = world.suit_integrity()
	world._physics_process(0.1)
	world.drone._physics_process(0.1)
	world._refresh_hud()
	check(world.player_environment().acid and world.suit_integrity() < integrity and world.hazard_label.text.contains("ACIDO"), "acid contact produces real corrosion damage and an explicit HUD warning")
	check(world.guide.context() == "acid_danger" and world.drone.water_alarm, "Robbie warns about acid and refuses to follow into the liquid")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	var expected := JSON.stringify(world.environment.snapshot())
	var restored: bool = world.restore_state(saved)
	if not restored:
		print("RESTORE BLOCKER: " + world.status_label.text)
	check(restored and JSON.stringify(world.environment.snapshot()) == expected, "save/load preserves escaped liquid without refilling the original basin")
	var campaign := Expedition.new()
	campaign.outposts.ochre = saved
	check(Expedition.new().restore(JSON.parse_string(JSON.stringify(campaign.snapshot()))), "campaign validator accepts layout two and version-three fluid saves")
	var invalid: Dictionary = world.capture_state()
	invalid.hazards.acid.append([0, 0, 5])
	var before_invalid: Dictionary = world.environment.snapshot()
	check(not world.restore_state(invalid) and world.environment.snapshot() == before_invalid, "corrupt acid data is rejected transactionally by the playable world")
	var legacy: Dictionary = pristine.duplicate(true)
	legacy.layout_version = 1
	legacy.removed = Site.new(0, 1).snapshot()
	legacy.hazards = Field.new(Site.new(0, 1)).snapshot()
	legacy.hazards.version = 2
	legacy.hazards.erase("acid")
	check(world.restore_state(legacy) and world.site.pockets().size() == 6 and world.environment.acid.is_empty(), "an existing layout-one outpost keeps its smaller reservoirs and has no injected acid")
	check(world.restore_state(pristine), "restore fresh reservoirs for visual inspection")
	if capture:
		world.camera.zoom = Vector2.ONE * 1.35
		world.target_cell = Vector2i.ZERO
		world.beam_time = 0
		for pocket: Dictionary in world.site.pockets():
			if pocket.id not in ["water_deep", "gas_deep", "oil_west", "acid_west"]:
				continue
			check(world.restore_state(pristine), "restore untouched basin before its inspection capture")
			world.drone.water_alarm = false
			world.drone.status = "Ti seguo"
			world.drone.range_metres = 15
			for x in range(pocket.origin.x - 2, pocket.origin.x):
				for y in range(pocket.origin.y - 2, pocket.origin.y):
					Fixture.carve(world, Vector2i(x, y))
			var center := Grid.to_world(pocket.origin) + Vector2(pocket.size) * Grid.CELL_SIZE * 0.5
			world.camera.position = center
			world.player.position = Grid.to_world(pocket.origin) - Vector2(60, 0)
			world.outpost.light_sources = [{"point": center, "inner": 220.0, "outer": 300.0}]
			for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
				root.size = size
				var pixels := await picture("reservoir-%s-%dp" % [pocket.kind, size.y])
				var cells := Layout.cells(pocket)
				var adjacent := Vector2i.ZERO
				for cell: Vector2i in cells:
					if cell + Vector2i.RIGHT in cells:
						adjacent = cell
						break
				var transform: Transform2D = root.get_final_transform() * world.get_global_transform_with_canvas()
				var edge := Grid.to_world(adjacent) + Vector2(40, 20)
				var left := pixels.get_pixelv(Vector2i(transform * (edge - Vector2(2, 0))))
				var right := pixels.get_pixelv(Vector2i(transform * (edge + Vector2(2, 0))))
				check(absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b) < 0.06, "%s at %dp has continuous fill across internal metre cells" % [pocket.kind, size.y])
				var distinct: bool = {"water": left.b > left.r + 0.1, "acid": left.g > left.r + 0.05 and left.g > left.b + 0.1, "gas": left.r > left.b + 0.12, "oil": left.b > left.g + 0.025}[pocket.kind]
				check(distinct, "%s at %dp renders its actual substance color, not blank terrain" % [pocket.kind, size.y])
	print("RESERVOIRS SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
