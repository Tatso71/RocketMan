extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0
var capture := false

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, text: String) -> void:
	print(("PASS: " if value else "FAIL: ") + text)
	if not value: failures += 1

func frames() -> void:
	for index in range(5): await physics_frame

func picture(name: String) -> void:
	if not capture: return
	world.camera.force_update_scroll()
	world._refresh_hud()
	world.queue_redraw()
	world.scanner_view.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, "capture " + name)

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await frames()
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.guide_state.set_muted(true)
	Fixture.lab_room(world)
	world.set_hatch(true)
	world.player.position = Vector2(-90, 160)
	world.camera.position = Vector2(-80, 120)
	world.camera.zoom = Vector2.ONE
	await frames()
	world.target_cell = Vector2i(-3, 4)
	world.equip_tool(1)
	var terrain: Array = world.site.snapshot()
	var energy: float = world.ship_energy()
	var personal: float = world.crew_energy()
	var known: Dictionary = world.scanned.duplicate()
	world.mine_timer = 0
	world._mine_target()
	check(world.beam_time == 0 and world.beam_tool == null, "scanner click does not emit extraction beam")
	check(world.site.snapshot() == terrain and world.scanned == known, "scanner click neither mines nor performs point scanning")
	check(world.ship_energy() == energy and world.crew_energy() == personal, "passive scanner click consumes no firing energy")
	world.scanner_view.advance(1.79)
	world.scanner_view.advance(0.1)
	check(not world.scanner_view.revealed.is_empty(), "passive waves still reveal nearby materials")
	await picture("excavation-scanner-720")
	root.size = Vector2i(1920, 1080)
	await picture("excavation-scanner-1080")
	root.size = Vector2i(1280, 720)
	world.equip_tool(0)
	world.message_time = 0
	world._refresh_hud()
	check(not world.status_label.text.contains(world.MATERIAL_NAMES.get(world.site.material(world.target_cell), "not-a-material")), "historical analysis does not identify the aimed rock outside scanner mode")
	world.mine_timer = 0
	world._mine_target()
	check(world.beam_time > 0 and world.beam_tool != null and world.beam_tool.mode == "mine", "mining mode retains its futuristic beam")
	for slot in [1, 2, 3]:
		world.beam_time = 0.2
		world.beam_tool = world.Tools.find("pulse")
		world.equip_tool(slot)
		check(world.beam_time == 0 and world.beam_tool == null, "switching to non-mining slot clears stale beam " + str(slot))
	world.equip_tool(2)
	world.target_cell = Vector2i(-5, 3)
	world.mine_timer = 0
	var ammo: int = world.gear.ammo()
	world._mine_target()
	check(world.gear.ammo() == ammo - 1 and world.beam_time == 0, "bomb mode places a bomb without firing a beam")
	world.equip_tool(3)
	world.mine_timer = 0
	world._mine_target()
	check(world.beam_time == 0 and world.beam_tool == null, "jetpack mode cannot fire")
	world.equip_tool(0)
	world.scanner_view.advance(0.1)
	var removed_before: Array = world.site.snapshot()
	await picture("excavation-irregular-720")
	check(world.site.snapshot() == removed_before, "decorative jagged edges never alter metric terrain")
	var metric_colliders := true
	for cell: Vector2i in world.blocks:
		var body: StaticBody2D = world.blocks[cell]
		metric_colliders = metric_colliders and body.get_child(0).shape is RectangleShape2D and body.get_child(0).shape.size == Vector2(40, 40)
	check(metric_colliders, "all rock colliders remain regular one-metre squares")
	if capture:
		var pixels := root.get_texture().get_image()
		var warm_fringe := 0
		var profile: PackedVector2Array = world.TerrainRenderer.edge_profile(Vector2i(-4, 4), 0, world.site.terrain_seed)
		for index in range(1, profile.size() - 1):
			var point: Vector2 = world.get_global_transform_with_canvas() * (profile[index] + Vector2(0, 0.8))
			var ink := pixels.get_pixelv(Vector2i(point))
			if ink.r > ink.g * 1.1 and ink.r > 0.04: warm_fringe += 1
		check(warm_fringe >= 3, "rock-coloured pixels really extend outside the unchanged collider")
	check(world.environment.gas.is_empty() and not world.site.pockets().any(func(pocket): return pocket.kind == "gas"), "ordinary worlds contain no natural gas pockets")
	print("Excavation readability smoke: %d failures" % failures)
	quit(1 if failures else 0)
