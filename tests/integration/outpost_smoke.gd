extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var campaign: Node2D
var world: Node2D
var failures := 0
var capture := false

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 4) -> void:
	for index in range(count):
		await physics_frame

func screenshot(name: String, viewport: Viewport = null) -> void:
	if not capture:
		return
	world._refresh_hud()
	world.queue_redraw()
	world.outpost.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, name + " screenshot saved")

func _run() -> void:
	create_timer(60).timeout.connect(func(): push_error("Outpost smoke timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1920, 1080)
	campaign = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	campaign.set_process(false)
	root.get_node("SaveManager").campaign_save_path = "res://reports/outpost-test-save.json"
	campaign.depart()
	campaign._process(10)
	campaign._process(10)
	world = campaign.world
	Fixture.workshop(world)
	await frames(10)
	check(not world.site.material(Vector2i(0, 0)).is_empty(), "arrival has intact ground directly below the ship")
	check(not world.site.material(Vector2i(-5, 3)).is_empty(), "no starter gallery has been excavated")
	check(not world.ladders.has(Vector2i(0, 0)), "no underground ladder or equipment is preinstalled")
	check(world.outpost.buildings.structures.is_empty(), "no laboratory or lights are prebuilt")
	check(world.drone_help_available(), "support drone starts aboard within helping distance")
	await screenshot("outpost-virgin-arrival-1080p")
	check(not world.outpost.craft_lamp(), "lights cannot be fabricated before building a lab")
	check(world.field_cargo.withdraw(campaign.model.ship.resources, "stone", 6, world.drone_help_available()), "load laboratory stone physically from ship")
	check(world.field_cargo.withdraw(campaign.model.ship.resources, "copper", 4, world.drone_help_available()), "drone carries recipe overflow beyond backpack capacity")
	check(world.field_cargo.used(world.field_cargo.backpack) == 8 and world.field_cargo.used(world.field_cargo.drone) == 2, "backpack and drone have distinct bounded holds")
	check(not world.outpost.place("laboratory", Vector2i(-5, 1)), "lab cannot install through untouched rock")
	world.player.position = Vector2(20, -80)
	world.set_hatch(true)
	Input.action_press("climb_down")
	await frames(65)
	Input.action_release("climb_down")
	check(absf(world.player.position.y) < 3, "player reaches the virgin surface through ship collar")
	await frames(30)
	var ship_soil: int = campaign.model.ship.resources.soil
	world.target_cell = Vector2i(0, 0)
	world.mine_timer = 0
	world._mine_target()
	await frames()
	check(world.site.material(Vector2i(0, 0)).is_empty(), "player digs the actual first block")
	check(campaign.model.ship.resources.soil == ship_soil, "mining never teleports resources into ship hold")
	world.player.set_physics_process(false)
	Fixture.lab_room(world)
	world.player.position = Vector2(-20, 160)
	await frames(150)
	check(world.drone_help_available(), "drone follows through an opened hatch and carved passage")
	check(world.drone.position.y > 0, "drone physically enters the underground rather than teleporting cargo")
	check(world.outpost.placement_blocker("laboratory", Vector2i(-5, 1)).is_empty(), "clear supported dry laboratory footprint is valid")
	world.outpost.set_process(false)
	world.outpost.build_mode = true
	world.outpost.blueprint = "laboratory"
	world.outpost.origin = Vector2i(-5, 1)
	world.mouse_aim = false
	world.outpost._process(0)
	await screenshot("outpost-laboratory-preview-1080p")
	world.outpost.set_process(true)
	check(Fixture.build(world, "laboratory", Vector2i(-5, 1)), "carried materials fund and complete first laboratory cube")
	check(campaign.model.ship.lab_research_unlocked, "first lab unlocks research-dependent ship upgrades")
	check(not world.outpost.craft_lamp(), "lab cannot draw missing copper remotely from ship")
	world.return_home()
	await frames(150)
	check(world.drone.aboard(), "drone can return aboard through the hatch")
	check(world.field_cargo.withdraw(campaign.model.ship.resources, "soil", 2, world.drone_help_available()), "prepare carried lamp material at ship")
	check(world.field_cargo.withdraw(campaign.model.ship.resources, "copper", 2, world.drone_help_available()), "prepare carried copper for two portable lights")
	world.player.position = Vector2(-20, 160)
	await frames(150)
	check(world.outpost.craft_lamp(), "nearby laboratory fabricates first portable light")
	check(world.outpost.craft_lamp(), "nearby laboratory fabricates second portable light")
	Fixture.carve(world, Vector2i(-6, 2))
	Fixture.carve(world, Vector2i(-6, 3))
	world.player.position = Vector2(-160, 160)
	await frames(90)
	check(Fixture.build(world, "lamp", Vector2i(-6, 3)), "first lamp cube unfolds in an empty supported gallery cell")
	Fixture.carve(world, Vector2i(1, 2))
	Fixture.carve(world, Vector2i(1, 3))
	world.player.position = Vector2(20, 160)
	await frames(90)
	check(Fixture.build(world, "lamp", Vector2i(1, 3)), "second crafted lamp cube can be left in another gallery")
	check(world.outpost.light_at(Vector2(-320, 140)) > 0.1, "installed lamp remains lit away from explorer")
	check(world.outpost.mining_blocker(Vector2i(-4, 4)).contains("portante"), "laboratory support cannot accidentally be mined away")
	world.player.position = Vector2(-160, 160)
	await frames(90)
	var lab: Dictionary = world.outpost.nearby_lab()
	check(not lab.is_empty(), "laboratory provides a local physical cargo deposit")
	world.field_cargo.deposit(lab.stock, 32, world.drone_help_available())
	check(int(lab.stock.get("soil", 0)) > 0, "laboratory stores material unloaded from nearby drone")
	world.set_process(false)
	world.camera.zoom = Vector2.ONE * 0.9
	world.camera.position = Vector2(-80, 5)
	world.target_cell = Vector2i(-6, 3)
	await screenshot("outpost-laboratory-lights-1080p")
	root.size = Vector2i(1280, 720)
	await frames()
	await screenshot("outpost-laboratory-lights-720p")
	root.size = Vector2i(1920, 1080)
	await frames()
	world.outpost.open_cargo()
	await frames()
	await screenshot("outpost-laboratory-cargo", world.outpost.cargo_window)
	world.outpost.cargo_window.hide()
	check(campaign.save_campaign(), "laboratory, lights and separate cargo can be saved")
	var cargo: Dictionary = campaign.model.ship.field_cargo.snapshot()
	check(campaign.load_campaign(), "outpost campaign can be restored")
	world = campaign.world
	await frames()
	check(world.outpost.buildings.structures.size() == 3, "restored planet retains laboratory and both lights")
	check(campaign.model.ship.field_cargo.snapshot() == cargo, "restore does not duplicate portable cargo")
	check(int(world.outpost.buildings.labs()[0].stock.get("soil", 0)) > 0, "local lab cache persists independently of ship")
	# An explored long tunnel tests the radio boundary, not procedural generation.
	for x in range(0, 19):
		Fixture.carve(world, Vector2i(x, 2))
		Fixture.carve(world, Vector2i(x, 3))
	world.player.set_physics_process(false)
	world.player.position = Vector2(740, 160)
	await frames(150)
	check(not world.drone_help_available(), "drone cannot assist an explorer beyond its signal range")
	check(world.drone.position.distance_to(Vector2(0, -80)) <= 601, "drone remains inside the fifteen-metre ship radius")
	check(world.drone.status == "Limite segnale", "drone reports waiting at radio limit")
	world.field_cargo.backpack.clear()
	world.field_cargo.collect("soil", 8, false)
	world.field_cargo.drone.clear()
	world.target_cell = Vector2i(19, 3)
	check(world.target_blocker(world.target_cell).contains("Carico pieno"), "remote drone capacity cannot bypass full backpack")
	print("OUTPOST SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
