extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
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

func frames(count: int = 6) -> void:
	for index in range(count):
		await physics_frame

func freeze() -> void:
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.guide_state.set_muted(true)

func controls_fit(node: Node, bounds: Rect2) -> bool:
	if node is ScrollContainer:
		# Scroll content may be taller, but the viewport and horizontal minimum must fit.
		if not bounds.grow(1).encloses(node.get_global_rect()):
			return false
		for content in node.get_children():
			if content is Container and content.get_combined_minimum_size().x > node.size.x + 1:
				return false
		return true
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and not bounds.grow(1).encloses(child.get_global_rect()):
			print("Overflow: ", child.get_class(), " ", child.get_global_rect(), " / ", bounds)
			return false
		if not controls_fit(child, bounds):
			return false
	return true

func screenshot(name: String, viewport: Viewport = null) -> void:
	if not capture:
		return
	world.outpost.queue_redraw()
	world._refresh_hud()
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png("res://reports/physical-" + name + ".png") == OK, name + " screenshot")

func reload_world() -> void:
	check(campaign.save_campaign() and campaign.load_campaign(), "campaign JSON roundtrip")
	world = campaign.world
	freeze()
	await frames()

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = world.get_global_transform_with_canvas() * point
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	world._unhandled_input(event)

func _run() -> void:
	create_timer(65).timeout.connect(func(): push_error("Physical fabrication timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	campaign = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	campaign.set_process(false)
	root.get_node("SaveManager").campaign_save_path = "res://reports/physical-fabrication-save.json"
	campaign.depart()
	campaign._process(10)
	campaign._process(10)
	world = campaign.world
	await frames()
	check(campaign.model.ship.cargo_used() == 0 and world.field_cargo.free_space(true) == 20, "new ship, player and Robbie have no initial material stock")
	Fixture.workshop(world)
	await frames()
	freeze()
	var outpost: Node2D = world.outpost
	var ui: Node = outpost.construction
	outpost.selected_station = {"kind": "ship"}
	ui.open_picker(Vector2i.ZERO, Vector2(300, 180), true)
	check(ui.picker.visible and ui.craft_button.disabled and not outpost.build_mode, "station recipe opens disabled without an unwanted footprint")
	check(ui.resource_labels.size() == 2 and ui.resource_labels.stone.modulate == Color("ff7e85"), "missing ingredients are individually red")
	var before: Dictionary = world.capture_state()
	ui._start_craft()
	check(outpost.fabrication.jobs.is_empty() and world.field_cargo.snapshot() == before.field_cargo, "invalid create cannot consume partial resources")
	await screenshot("01-missing-recipe-720p", ui.picker)
	world.field_cargo.backpack.clear()
	world.field_cargo.drone = {"stone": 6, "copper": 4, "soil": 10}
	world.inventory.materials = world.field_cargo.drone
	Fixture.support(world)
	ui.refresh()
	check(not ui.craft_button.disabled and ui.resource_labels.stone.modulate == Color("a7e5b4") and ui.resource_labels.copper.modulate == Color("a7e5b4"), "full Robbie cargo is enough when physically nearby")
	check(outpost.fabrication_amount("copper") == 4, "recipe reports the combined copper total")
	await screenshot("02-ready-recipe-720p", ui.picker)
	ui.craft_button.pressed.emit()
	check(outpost.fabrication.jobs.size() == 1 and outpost.lab_cube_count() == 0, "create starts one physical production job, not an inventory item")
	check(world.field_cargo.available("stone", true) == 0 and world.field_cargo.available("copper", true) == 0 and world.field_cargo.available("soil", true) == 10, "start charges both holds once and leaves unrelated materials untouched")
	ui._start_craft()
	check(outpost.fabrication.jobs.size() == 1, "double create cannot queue duplicate jobs")
	outpost.advance_fabrication(2)
	ui.picker.hide()
	await screenshot("03-materializing-720p")
	await reload_world()
	outpost = world.outpost
	ui = outpost.construction
	check(outpost.fabrication.jobs.size() == 1 and is_equal_approx(outpost.fabrication.jobs[0].elapsed, 2), "paid production resumes exactly halfway with the panel closed")
	outpost.advance_fabrication(3.1)
	check(outpost.fabrication.jobs.is_empty() and outpost.fabrication.cubes.size() == 1, "finished fabrication leaves a persistent physical cube on the bench")
	check(world.field_cargo.available("lab_cube", true) == 0, "finished cube is not silently inserted in either inventory")
	check(outpost.fabrication_blocker().contains("Prendi"), "ready output blocks the bench until picked up")
	await reload_world()
	outpost = world.outpost
	ui = outpost.construction
	check(outpost.fabrication.cubes.size() == 1 and outpost.fabrication.carried_id == 0, "ready bench cube survives load")
	var cargo_before: Dictionary = world.field_cargo.snapshot()
	check(outpost.use_cube() and outpost.fabrication.carried_id != 0, "Space action picks up the nearby cube")
	check(world.field_cargo.snapshot() == cargo_before, "hands carry separately, even when raw cargo is full")
	check(world.target_blocker(Vector2i(0, 0)).contains("Posa"), "hands must be freed before mining")
	await screenshot("04-carrying-720p")
	await reload_world()
	outpost = world.outpost
	ui = outpost.construction
	check(outpost.fabrication.carried_id != 0, "carried cube survives save/load")
	Fixture.lab_room(world)
	world.environment.water.clear()
	world.environment.gas.clear()
	world.set_hatch(true)
	world.player.position = Vector2(20, 80)
	world.camera.position = Vector2(-80, 10)
	world.camera.zoom = Vector2.ONE
	await frames()
	check(outpost.use_cube() and outpost.fabrication.carried_id == 0, "Space drops cube before testing full room geometry")
	var cube: Dictionary = outpost.fabrication.cubes[0]
	check(not outpost.activate_cube(cube) and outpost.build_mode and outpost.fabrication.cubes.size() == 1, "invalid activation keeps paid cube and shows fixed red footprint")
	check(world.status_label.text.contains("Spazio"), "invalid activation explains how to move the cube")
	await screenshot("05-invalid-footprint-720p")
	check(outpost.use_cube(), "invalid cube remains recoverable")
	world.player.position = Vector2(-100, 160)
	world.player.set_physics_process(true)
	await frames()
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(1)
	check(outpost.fabrication.carried_id == 0 and absf(world.player.position.y - 160) < 3, "actual contextual Space drops cube without also jumping")
	world.player.set_physics_process(false)
	cube = outpost.fabrication.cubes[0]
	var paid: Dictionary = world.field_cargo.snapshot()
	click(cube.position - Vector2(0, 18))
	check(ui.activation_popup.visible and not outpost.build_mode, "right click on dropped cube offers activation without premature footprint")
	ui.activation_popup.id_pressed.emit(0)
	check(outpost.fabrication.cubes.is_empty() and outpost.buildings.structures.size() == 1, "activation transforms exactly that paid cube into a room")
	check(world.field_cargo.snapshot() == paid, "activation charges no materials a second time")
	outpost.advance(2)
	await reload_world()
	outpost = world.outpost
	ui = outpost.construction
	outpost.advance(4)
	check(outpost.has_lab() and world.guide_state.ocra.complete(), "completed laboratory is powered and completes Ocra tutorial")
	var lab: Dictionary = outpost.buildings.labs()[0]
	check(outpost.recipe_visible("lamp") and outpost.recipe_visible("pump") and outpost.recipe_visible("fan"), "first completed laboratory unlocks all three utility cubes")
	outpost.selected_station = {"kind": "laboratory", "building": lab}
	lab.stock = {"stone": 20, "copper": 20}
	world.field_cargo.backpack.clear()
	world.field_cargo.drone.clear()
	var seconds: float = outpost.fabrication_seconds()
	check(outpost.upgrade_station() and outpost.fabrication_seconds() < seconds, "lab level actually speeds up fabrication")
	ui.open_picker(Vector2i.ZERO, Vector2(300, 180), true)
	ui.craft_button.pressed.emit()
	check(outpost.fabrication.jobs.size() == 1 and outpost.fabrication.jobs[0].station[0] == "laboratory", "underground station fabricates the same physical cubes using only local stock")
	lab.enabled = false
	outpost.advance_fabrication(10)
	ui.refresh()
	check(outpost.fabrication.jobs[0].elapsed == 0, "unpowered field laboratory pauses its paid job")
	check(ui.choice_status.text.contains("pausa"), "paused production clearly names its blocker")
	lab.enabled = true
	outpost.advance_fabrication(seconds)
	check(outpost.fabrication.cubes.size() == 1 and outpost.fabrication.jobs.is_empty(), "powered upgraded field lab finishes physical output")
	ui.picker.hide()
	await screenshot("06-active-laboratory-720p")
	root.size = Vector2i(1920, 1080)
	await screenshot("06-active-laboratory-1080p")
	root.size = Vector2i(1280, 720)
	Fixture.workshop(world)
	await frames()
	outpost.selected_station = {"kind": "ship"}
	campaign.model.ship.resources.stone = 12
	campaign.model.ship.resources.copper = 8
	check(outpost.fabricate_lab_cube(), "second ship-bench production starts independently")
	outpost.advance_fabrication(1)
	world.player.position = Vector2(-60, -320)
	world.drone.position = Vector2(-140, -380)
	world.set_hatch(false)
	check(campaign.request_takeoff(), "takeoff retains ship production without abandoning it on the planet")
	check(campaign.model.ship.fabrication.jobs.size() == 1 and campaign.model.outposts.ochre.fabrication.jobs.is_empty(), "ship job has exactly one owner after takeoff")
	check(campaign.save_campaign() and campaign.load_campaign(), "in-flight factory is saved on ship")
	campaign._process(10)
	check(campaign.model.choose("frost") and campaign.depart(), "travel to unlocked second planet")
	campaign._process(10)
	campaign._process(10)
	world = campaign.world
	freeze()
	check(world.outpost.fabrication.jobs.size() == 1 and campaign.model.ship.fabrication.jobs.is_empty(), "ship job transfers once into the new landing")
	world.outpost.advance_fabrication(5)
	check(world.outpost.fabrication.cubes.size() == 1, "transported job finishes on the ship bench on another planet")
	Fixture.workshop(world)
	await frames()
	ui = world.outpost.construction
	ui.open_picker(Vector2i.ZERO, Vector2(300, 180), true)
	await frames()
	if DisplayServer.get_name() != "headless":
		check(controls_fit(ui.picker, ui.picker.get_visible_rect()), "recipe table fits entirely at 720p")
		check(controls_fit(world.outpost.cargo_ui.compact, world.outpost.cargo_ui.compact.get_global_rect()), "shared totals fit compact cargo panel")
	print("PHYSICAL FABRICATION SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
