extends SceneTree

var campaign: Node2D
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

func frames(count: int = 5) -> void:
	for i in range(count):
		await physics_frame

func walk_to(x: float) -> void:
	for i in range(200):
		if absf(world.player.position.x - x) < 4:
			break
		var action := "move_right" if world.player.position.x < x else "move_left"
		Input.action_press(action)
		await physics_frame
		Input.action_release(action)
	await frames()

func climb_to(y: float) -> void:
	var action := "climb_up" if world.player.position.y > y else "climb_down"
	Input.action_press(action)
	for i in range(220):
		if absf(world.player.position.y - y) < 4:
			break
		await physics_frame
	Input.action_release(action)
	await frames()

func mine(cell: Vector2i) -> void:
	for hit in range(5):
		if world.site.material(cell).is_empty():
			return
		world.target_cell = cell
		world._mine_target()
		await frames(15)
	check(world.site.material(cell).is_empty(), "reachable mining " + str(cell))
	if not world.site.material(cell).is_empty():
		print("BLOCKER: %s, player %s, %s" % [cell, world.player.position, world.target_blocker(cell)])

func return_to_workshop() -> void:
	Input.action_press("climb_up")
	for i in range(400):
		if world.player.position.y < -77:
			Input.action_press("move_left")
		if world.player.position.x < -55 and world.player.position.y < -77:
			break
		await physics_frame
	Input.action_release("climb_up")
	Input.action_release("move_left")
	await wait_for_cargo()

func wait_for_cargo() -> void:
	for i in range(500):
		if world.drone_help_available() and not world.gear.drops.keys().any(func(cell: Vector2i): return world.gear.fragment_position(cell).distance_to(world.player.position) < 190):
			break
		await physics_frame
	await frames(15)

func picture(name: String, target: Viewport = null) -> void:
	if not capture:
		return
	world._refresh_hud()
	world.guide.context()
	world.tutorial_ui.refresh()
	await frames()
	await RenderingServer.frame_post_draw
	var viewport: Viewport = root if target == null else target
	check(viewport.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, "save " + name)

func _run() -> void:
	create_timer(160).timeout.connect(func(): push_error("Component onboarding timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	for variant in range(2):
		campaign = load("res://scenes/prototype/expedition.tscn").instantiate()
		root.add_child(campaign)
		current_scene = campaign
		campaign.set_process(false)
		campaign.select_variant(variant)
		check(campaign.arrive_immediately(), "new campaign reaches Ocra, variant " + str(variant))
		world = campaign.world
		world.guide_state.set_muted(true)
		await frames(10)
		check(world.outpost.buildings.structures.is_empty() and not world.site.material(Vector2i(0, 0)).is_empty(), "starts with virgin ground and empty ship")
		await walk_to(100)
		await climb_to(-80)
		await walk_to(20)
		check(world.aboard_workshop(), "real ship ladder reaches the operational workshop")
		world.set_hatch(true)
		await climb_to(0)
		await mine(Vector2i(0, 0))
		await mine(Vector2i(-1, 0))
		await climb_to(40)
		check(world.place_ladder_at(Vector2i(0, 0)), "first ladder is free without mined common cargo")
		for y in range(1, 4):
			await mine(Vector2i(0, y))
			await mine(Vector2i(-1, y))
			check(world.place_ladder_at(Vector2i(0, y)), "maintain the actual return shaft")
			await climb_to((y + 1) * 40)
		for x in range(-2, -5, -1):
			for y in range(3, 0, -1):
				await mine(Vector2i(x, y))
			await walk_to(x * 40 + 20)
		await walk_to(20)
		await mine(Vector2i(1, 3))
		await wait_for_cargo()
		var cargo: RefCounted = world.field_cargo
		var ready: bool = cargo.available("iron", true) >= 8 and cargo.available("copper", true) >= 3 and cargo.available("crystal", true) >= 1
		check(ready, "real mining yields the first laboratory resources before any unlock")
		check(cargo.available("soil", true) == 0 and cargo.available("stone", true) == 0, "common rock never enters the expedition cargo")
		if not ready:
			print("CARGO: %s, drops %s, drone %s" % [cargo.snapshot(), world.gear.drops, world.drone.status])
			print("POSITIONS: player %s drone %s fragments %s" % [world.player.position, world.drone.position, world.gear.fragments.values().map(func(body): return body.position)])
			quit(1)
			return
		await return_to_workshop()
		check(world.aboard_workshop(), "actual return route reaches the ship bench")
		check(world.outpost.fabricate_components("structural_component", 2), "order two structural batches from actual ore")
		world.outpost.advance_fabrication(4.1)
		check(world.outpost.fabricate_components("electronic_component", 1), "order electronics from actual ore")
		world.outpost.advance_fabrication(2.1)
		check(world.outpost.collect_fabrication_output() == 6, "retrieve all six compact components in one action")
		check(cargo.available("structural_component", true) == 4 and cargo.available("electronic_component", true) == 2, "first laboratory component set is complete")
		world.outpost.construction.open_picker(Vector2i.ZERO, Vector2.ZERO, true)
		await picture("components-onboarding-production-" + str(variant), world.outpost.construction.picker)
		world.outpost.construction.picker.hide()
		await walk_to(20)
		await climb_to(140)
		await walk_to(-100)
		await wait_for_cargo()
		world.outpost.assembly.open_picker(Vector2i(-2, 3), Vector2(550, 360))
		check(not world.outpost.build_mode, "opening assembly menu alone shows no red footprint")
		world.outpost.assembly._choose(0)
		world.outpost.assembly.popup.hide()
		check(world.outpost.build_mode, "choosing a structure starts its footprint preview")
		check(world.outpost.place_blueprint(Vector2i(-4, 1)), "assemble the real excavated laboratory from carried components")
		check(cargo.available("structural_component", true) == 0 and cargo.available("electronic_component", true) == 0, "assembly consumes components exactly once")
		world.outpost.advance(2)
		var save_manager: Node = root.get_node("SaveManager")
		save_manager.campaign_save_path = "res://reports/components-onboarding-save.json"
		check(campaign.save_campaign() and campaign.load_campaign(), "campaign preserves partial assembly in the isolated test slot")
		world = campaign.world
		await frames(8)
		world.outpost.advance(4)
		world.guide.context()
		check(world.outpost.has_lab() and world.guide_state.ocra.complete(), "first active laboratory completes onboarding and unlocks devices")
		await picture("components-onboarding-lab-" + str(variant) + "-720p")
		root.size = Vector2i(1920, 1080)
		await picture("components-onboarding-lab-" + str(variant) + "-1080p")
		root.size = Vector2i(1280, 720)
		campaign.queue_free()
		await frames(5)
	print("Component onboarding smoke: %d failures" % failures)
	quit(1 if failures else 0)
