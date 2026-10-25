extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var campaign: Node2D
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

func frames(count: int = 5) -> void:
	for index in range(count):
		await physics_frame

func click(point: Vector2, button: MouseButton = MOUSE_BUTTON_RIGHT) -> void:
	var event := InputEventMouseButton.new()
	event.position = world.get_global_transform_with_canvas() * point
	event.button_index = button
	event.pressed = true
	world._unhandled_input(event)

func screenshot(name: String, viewport: Viewport = null) -> void:
	if not capture:
		return
	if is_instance_valid(world):
		world._refresh_hud()
		world.queue_redraw()
		world.outpost.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, name + " screenshot saved")

func water_total() -> float:
	var result := 0.0
	for volume in world.environment.water.values():
		result += float(volume)
	return result

func _run() -> void:
	create_timer(50).timeout.connect(func(): push_error("Robbie tutorial timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	campaign = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	campaign.set_process(false)
	root.get_node("SaveManager").campaign_save_path = "res://reports/robbie-tutorial-save.json"
	check(campaign.planet_list.item_count == 1 and not campaign.model.choose("frost"), "only Ocra is visible and reachable before the tutorial")
	await screenshot("robbie-first-planet-720p")
	campaign.depart()
	campaign._process(10)
	campaign._process(10)
	world = campaign.world
	await frames()
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide.set_process(false)
	Fixture.workshop(world)
	world.observe_tutorial()
	world.set_hatch(true)
	world.player.position = Vector2(20, 0)
	world.drone.position = Vector2(20, -40)
	world.guide_state.dismiss()
	world.guide_state.gap = 0
	world.target_cell = Vector2i(0, 0)
	world.mine_timer = 0
	await frames()
	world._mine_target()
	world.guide._process(0.01)
	check(world.guide_state.active_id == "ocra/first_excavation", "first excavated block updates the authored Ocra task")
	check(world.guide.context() == "ocra/first_excavation", "one mined block does not skip the two-cell objective")
	world.guide_state.tick(25, "ocra/first_excavation")
	world.guide_state.tick(3, "ocra/first_excavation")
	check(world.guide_state.offer("ocra/first_excavation"), "Robbie repeats unfinished authored advice instead of saying it only once")
	world.target_cell = Vector2i(-1, 0)
	world.mine_timer = 0
	world._mine_target()
	check(world.place_ladder_at(Vector2i(0, 0)), "instant ladder advances the real early task")
	var original_cargo: Dictionary = world.field_cargo.snapshot()
	world.field_cargo.collect("stone", 6, true)
	world.field_cargo.collect("copper", 4, true)
	check(world.guide.context() == "ocra/laboratory_room", "shared raw ingredients advance the collection goal before room fabrication")
	world.field_cargo.restore(original_cargo)
	Fixture.lab_room(world)
	world.player.position = Vector2(-140, 160)
	world.drone.position = Vector2(-100, 90)
	world.camera.position = Vector2(-80, 10)
	world.camera.zoom = Vector2.ONE * 0.9
	world.guide.room_poll = 0
	await frames()
	world.guide.context()
	check(world.guide_state.ocra.facts.get("lab_room_ready", false), "cleared room is recognized without skipping cube fabrication")
	world.guide.request_help()
	check(world.guide.speech.text.contains("Costruisci"), "Robbie directs player to physical station fabrication")
	await screenshot("robbie-room-ready-720p")
	world.guide_state.dismiss()
	world.guide._update_bubble()
	var ui: Node = world.outpost.construction
	click(Vector2(260, 60))
	check(not ui.picker.visible and not world.outpost.build_mode, "right click on terrain never opens a recipe or a red footprint")
	check(not world.outpost.recipe_visible("lamp") and not world.outpost.recipe_visible("pump"), "future devices are not currently offered")
	var count: int = world.outpost.buildings.structures.size()
	check(not world.outpost.deploy_lab_cube(Vector2i(6, 1)) and world.outpost.buildings.structures.size() == count, "activation cannot invent an uncarried or unplaced cube")
	check(world.outpost.placement_origin("laboratory", Vector2i(-3, 3)) == Vector2i(-5, 1), "cube anchor expands footprint upward from floor instead of into terrain")
	click(Vector2(-100, 140), MOUSE_BUTTON_LEFT)
	check(world.outpost.buildings.structures.is_empty(), "new placement cannot create a free laboratory without a carried cube")
	check(world.outpost.place("laboratory", Vector2i(-5, 1)), "legacy raw-funded plan remains supported for existing saves")
	await frames()
	var lab: Dictionary = world.outpost.buildings.structures.back()
	check(lab.origin == Vector2i(-5, 1) and lab.state == "planned", "legacy laboratory reservation keeps its original funding stage")
	ui.activation_popup.hide()
	Fixture.workshop(world)
	campaign.model.ship.resources = {"stone": 6, "copper": 6}
	await frames()
	world.outpost.cargo_ui.deposit()
	check(world.field_cargo.withdraw(campaign.model.ship.resources, "stone", 6, true), "carry laboratory stone from the ship")
	check(world.field_cargo.withdraw(campaign.model.ship.resources, "copper", 6, true), "carry copper split between explorer and Robbie")
	world.player.position = Vector2(-140, 160)
	world.drone.position = Vector2(-100, 90)
	await frames()
	check(world.field_cargo.backpack.stone == 6 and world.field_cargo.backpack.copper == 2 and world.field_cargo.drone.copper == 4, "reproduce screenshot with materials distributed across both holds")
	check(world.outpost.funding_blocker(lab).is_empty(), "split explorer/drone resources are correctly combined")
	world.outpost.fund_site(lab)
	world.outpost.advance(5.1)
	campaign._refresh_interface()
	check(lab.state == "active" and campaign.planet_list.item_count == 3, "completed first laboratory reveals the two later planets")
	ui.open_picker(Vector2i(-3, 3), Vector2(640, 400), true)
	check(ui.picker.visible and ui.resource_labels.size() == 2, "underground laboratory exposes the same fabrication panel")
	await screenshot("robbie-laboratory-recipe", ui.picker)
	ui.picker.hide()
	lab.enabled = false
	check(not world.outpost.recipe_visible("lamp") and not world.outpost.recipe_visible("pump"), "future device recipes remain deferred")
	lab.enabled = true
	for y in range(2, 4):
		for x in range(1, 3):
			Fixture.carve(world, Vector2i(x, y))
	Fixture.carve(world, Vector2i(6, 4))
	world.environment.water.clear()
	world.environment.water[Vector2i(2, 3)] = 1.0
	world.environment.water[Vector2i(3, 3)] = 1.0
	world.environment.water[Vector2i(3, 4)] = 1.0
	world.environment.water[Vector2i(6, 4)] = 1.0
	lab.stock = {"stone": 3, "copper": 2}
	world.player.position = Vector2(-18, 160)
	world.drone.position = Vector2(-10, 65)
	await frames()
	check(world.outpost.place("pump", Vector2i(1, 2)), "pump cube can be placed partly underwater on solid support")
	var pump: Dictionary = world.outpost.buildings.structures.back()
	check(world.outpost.fund_site(pump), "pump consumes raw materials from backpack and nearby laboratory cache")
	ui.activation_popup.hide()
	var volume := water_total()
	world.outpost.advance(4.1)
	check(pump.state == "active" and is_equal_approx(water_total(), volume), "unfinished pump never drains retroactively during construction")
	var battery: float = world.ship_energy()
	world.outpost.advance(3)
	check(is_equal_approx(volume - water_total(), 2.1) and is_equal_approx(pump.drained, 2.1), "active pump removes finite water at its declared rate")
	check(world.ship_energy() < battery and world.environment.water.get(Vector2i(6, 4), 0) == 1, "pump uses battery and does not reach disconnected distant water")
	await screenshot("robbie-pump-draining-720p")
	lab.enabled = false
	volume = water_total()
	world.outpost.advance(5)
	check(is_equal_approx(volume, water_total()), "pump stops when its laboratory loses power")
	lab.enabled = true
	world._set_ship_energy(0.007)
	world.outpost.advance(1)
	check(world.ship_energy() == 0 and volume - water_total() <= 0.071, "pump drainage is clamped to actual remaining battery runtime")
	world.environment.water[Vector2i(0, 2)] = 1.0
	world.environment.water[Vector2i(0, 3)] = 1.0
	world.player.position = Vector2(20, 160)
	world.drone.position = Vector2(20, 40)
	var drone_position: Vector2 = world.drone.position
	world.drone._physics_process(0.2)
	check(world.drone.water_alarm and world.drone.position == drone_position and world.drone.velocity == Vector2.ZERO, "submerged explorer makes Robbie stop outside the water")
	var integrity: float = world.suit_integrity()
	world.environment.accumulator = 0
	world._physics_process(0.02)
	check(world.suit_integrity() < integrity, "underwater alarm corresponds to real player damage")
	world.guide_state.dismiss()
	world.guide_state.gap = 0
	world.guide._process(0.01)
	check(world.guide_state.active_id == "water_danger" and world.guide.speech.text.contains("perdendo integrita"), "Robbie explicitly warns that immersion is causing damage")
	world.drone.clock = 0.1
	world.drone.queue_redraw()
	await screenshot("robbie-water-red-alarm-720p")
	root.size = Vector2i(1920, 1080)
	await screenshot("robbie-water-red-alarm-1080p")
	world.environment.water.clear()
	world.drone._physics_process(0.02)
	check(not world.drone.water_alarm, "Robbie resumes normal behavior when player is no longer submerged")
	world._set_ship_energy(20)
	world.player.position = Vector2(-140, 160)
	world.drone.position = Vector2(-100, 90)
	check(campaign.save_campaign() and campaign.load_campaign(), "pump and tutorial progress survive campaign JSON roundtrip")
	world = campaign.world
	await frames()
	check(world.outpost.buildings.structures.any(func(item: Dictionary): return item.id == "pump" and item.drained > 2), "restored pump preserves drainage statistics")
	check(campaign.model.available_planets().size() == 3, "planet unlock persists with completed laboratory")
	print("ROBBIE TUTORIAL SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
