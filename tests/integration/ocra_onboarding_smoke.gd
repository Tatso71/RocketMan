extends SceneTree

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

func frames(count: int = 6) -> void:
	for index in range(count):
		await physics_frame

func walk_to(x: float) -> void:
	for index in range(170):
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
	for index in range(180):
		if absf(world.player.position.y - y) < 4:
			break
		await physics_frame
	Input.action_release(action)
	await frames()

func return_to_workshop() -> void:
	Input.action_press("climb_up")
	for index in range(400):
		if world.player.position.y < -77:
			Input.action_press("move_left")
		if world.player.position.x < -55 and world.player.position.y < -77:
			break
		await physics_frame
	Input.action_release("climb_up")
	Input.action_release("move_left")
	await frames(20)
	for index in range(600):
		if world.drone_can_collect():
			break
		await physics_frame

func mine(cell: Vector2i) -> void:
	for index in range(600):
		if world.drone_can_collect():
			break
		await physics_frame
	for index in range(4):
		if world.site.material(cell).is_empty():
			return
		world.target_cell = cell
		world._mine_target()
		await frames(15)
	check(world.site.material(cell).is_empty(), "mine reachable tutorial cell " + str(cell))
	if not world.site.material(cell).is_empty():
		print("BLOCKED: %s / player %s / %s" % [cell, world.player.position, world.target_blocker(cell)])

func task() -> String:
	world.guide.context()
	return world.guide_state.ocra.current().get("id", "complete")

func screenshot(name: String, viewport: Viewport = null) -> void:
	if not capture:
		return
	world._refresh_hud()
	world.tutorial_ui.refresh()
	await frames(5)
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, name + " screenshot saved")

func layout() -> void:
	var viewport := world.get_viewport().get_visible_rect()
	var panel: Rect2 = world.tutorial_ui.panel.get_global_rect()
	check(viewport.encloses(panel), "objective panel remains inside viewport")
	check(not panel.intersects(world.outpost.cargo_ui.compact.get_global_rect()), "objective and cargo panels do not overlap")
	if world.guide.bubble.visible:
		check(not panel.intersects(world.guide.bubble.get_global_rect()), "Robbie balloon avoids objective panel")

func _run() -> void:
	create_timer(160).timeout.connect(func(): push_error("Ocra onboarding timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	campaign = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	campaign.set_process(false)
	root.get_node("SaveManager").campaign_save_path = "res://reports/ocra-onboarding-save.json"
	campaign.depart()
	campaign._process(10)
	campaign._process(10)
	world = campaign.world
	await frames(15)
	check(task() == "reach_workshop", "first task starts in the cockpit")
	check(world.drone.position.distance_to(world.player.position - Vector2(0, 32)) >= 70, "Robbie starts with personal space in the cabin")
	check(not world.site.material(Vector2i(0, 0)).is_empty() and world.outpost.buildings.structures.is_empty(), "tutorial begins on virgin ground without injected rooms")
	world.guide.request_help()
	layout()
	await screenshot("ocra-01-cockpit-720p")
	await walk_to(100)
	await climb_to(-80)
	await walk_to(20)
	check(world.aboard_workshop() and task() == "open_hatch", "real internal ladder traversal reaches the workshop task")
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	world._unhandled_input(interact)
	check(world.hatch_open and task() == "first_excavation", "opening actual hatch advances the task")
	await climb_to(0)
	await mine(Vector2i(0, 0))
	await mine(Vector2i(-1, 0))
	check(task() == "return_ladder", "two actual mined cells lead to instant ladder objective")
	await climb_to(40)
	for index in range(600):
		if world.drone_can_collect():
			break
		await physics_frame
	check(world.place_ladder() and task() == "laboratory_materials", "character builds first ladder and must gather real resources, not free ship stock")
	check(campaign.model.ship.cargo_used() == 0, "Ocra starts with an empty ship hold")
	for y in range(1, 4):
		await mine(Vector2i(0, y))
		await mine(Vector2i(-1, y))
		if world.field_cargo.available("soil", world.drone_help_available()) < 2:
			await mine(Vector2i(-2, y - 1))
		check(world.place_ladder_at(Vector2i(0, y)), "maintain actual ladder return route at depth " + str(y + 1))
		await climb_to((y + 1) * 40)
	for x in range(-2, -5, -1):
		for y in range(3, 0, -1):
			await mine(Vector2i(x, y))
		await walk_to(x * 40 + 20)
	world.guide.room_poll = 0
	check(world.guide_state.ocra.facts.get("lab_room_ready", false) or task() == "laboratory_materials", "room can be prepared before cube fabrication without artificial task gates")
	await frames(120)
	check(world.drone.position.distance_to(world.player.position - Vector2(0, 32)) >= 60, "Robbie rests outside the player's personal space")
	check(world.drone_help_available(), "Robbie's cargo is always part of the common resource pool")
	await walk_to(-60)
	world.player.facing = -world.player.facing
	var no_overlap := true
	for index in range(100):
		var body := Rect2(world.player.position - Vector2(17, 64), Vector2(34, 64))
		var robot := Rect2(world.drone.position - Vector2(23, 16), Vector2(46, 32))
		no_overlap = no_overlap and not body.intersects(robot)
		await physics_frame
	check(no_overlap, "Robbie changes resting side without crossing the explorer's body")
	await walk_to(-140)
	await frames(70)
	world.guide.request_help()
	layout()
	await screenshot("ocra-03-room-and-spacing-720p")
	for y in range(3, 0, -1):
		await mine(Vector2i(-5, y))
	await walk_to(20)
	for y in range(4, 8):
		await mine(Vector2i(0, y))
		await mine(Vector2i(-1, y))
		check(world.place_ladder_at(Vector2i(0, y)), "build actual ladder while gathering at depth " + str(y + 1))
		await climb_to((y + 1) * 40)
	await mine(Vector2i(1, 7))
	check(world.field_cargo.available("stone", true) >= 6 and world.field_cargo.available("copper", true) >= 4, "virgin Ocra supplies first laboratory ingredients through reachable native mining")
	await return_to_workshop()
	check(world.aboard_workshop(), "climb the actual dug shaft back to the workshop")
	await frames(20)
	world.outpost.open_station({"kind": "ship"}, Vector2(550, 330))
	world.outpost.station_menu.activate(2)
	var ui: Node = world.outpost.construction
	check(ui.picker.visible and not world.outpost.build_mode, "workshop opens physical fabrication table without a red terrain footprint")
	var stone_before: int = world.field_cargo.available("stone", true)
	var copper_before: int = world.field_cargo.available("copper", true)
	ui.craft_button.pressed.emit()
	await screenshot("ocra-02-fabrication-720p", ui.picker)
	ui._cancel_picker()
	world.outpost.advance_fabrication(5.1)
	check(world.outpost.fabrication.cubes.size() == 1 and world.field_cargo.available("lab_cube", true) == 0, "cube materializes on bench rather than in backpack")
	check(stone_before - world.field_cargo.available("stone", true) == 6 and copper_before - world.field_cargo.available("copper", true) == 4, "fabrication charges only actually mined ingredients once")
	check(task() == "carry_laboratory" and world.outpost.use_cube(), "Robbie asks to take ready cube with Space")
	if world.outpost.fabrication.cubes.is_empty():
		quit(1)
		return
	check(task() == "deploy_laboratory", "early excavation is remembered after picking up the cube")
	await walk_to(20)
	await climb_to(140)
	await walk_to(-100)
	await frames(30)
	check(world.outpost.use_cube() and world.outpost.fabrication.carried_id == 0, "physically carry and drop the cube on the excavated room's floor")
	var cube: Dictionary = world.outpost.fabrication.cubes[0]
	var stock_before: Dictionary = campaign.model.ship.resources.duplicate()
	check(world.outpost.activate_cube(cube), "right-click activation starts the paid room's assembly")
	if world.outpost.buildings.structures.is_empty():
		print("DEPLOY GEOMETRY: player=%s cube=%s origin=%s carried=%s" % [world.player.position, cube.position, world.outpost.cube_origin(cube), world.outpost.fabrication.carried_id])
		print("DEPLOY BLOCKER: " + world.outpost.placement_blocker("laboratory", world.outpost.cube_origin(cube)))
		quit(1)
		return
	var lab: Dictionary = world.outpost.buildings.structures.back()
	check(lab.state == "building" and world.outpost.lab_cube_count() == 0, "deployment consumes only one cube and never opens raw funding popup")
	check(campaign.model.ship.resources == stock_before, "no second material payment at deployment")
	world.outpost.advance(2)
	check(campaign.save_campaign() and campaign.load_campaign(), "campaign saves and restores tutorial, physical cube consumption and partial assembly")
	world = campaign.world
	await frames(8)
	lab = world.outpost.buildings.structures.back()
	check(lab.state == "building" and float(lab.progress) >= 0.4, "partial assembly resumes without restarting or refunding its cube")
	world.outpost.advance(5)
	check(world.guide_state.ocra.complete() or task() == "complete", "active first laboratory completes the saved tutorial")
	check(world.outpost.has_lab(), "finished laboratory is functional and powered")
	layout()
	await screenshot("ocra-04-first-laboratory-720p")
	root.size = Vector2i(1920, 1080)
	await frames(10)
	layout()
	await screenshot("ocra-04-first-laboratory-1080p")
	print("OCRA ONBOARDING SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
