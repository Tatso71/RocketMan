extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")

var failures := 0
var campaign: Node2D
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
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	var image := target.get_texture().get_image()
	var colors := {}
	for y in range(0, image.get_height(), 30):
		for x in range(0, image.get_width(), 30):
			colors[image.get_pixel(x, y).to_html()] = true
	check(colors.size() > 8, name + " viewport contains rendered content")
	check(image.save_png("res://reports/" + name + ".png") == OK, name + " screenshot saved")

func step(delta: float) -> void:
	campaign._process(delta)

func land() -> void:
	step(10)
	step(10)
	await frames()

func _run() -> void:
	create_timer(50).timeout.connect(func(): push_error("Expedition smoke timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1920, 1080)
	campaign = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	campaign.set_process(false)
	root.get_node("SaveManager").campaign_save_path = "res://reports/campaign-test-save.json"
	await frames()
	check(campaign.model.phase == 0, "campaign starts at planet selection")
	check(campaign.planet_list.item_count == 3, "three destinations are selectable")
	check(campaign.depart_button.get_global_rect().end.y < campaign.stats_label.get_global_rect().position.y, "navigation controls do not overlap ship statistics")
	await screenshot("expedition-selection-1080p")
	campaign.open_ship_menu()
	await frames()
	await screenshot("expedition-ship-modules", campaign.ship_menu)
	campaign.module_picker.select(2)
	campaign._upgrade()
	check(campaign.model.ship.cargo_capacity() == 200, "cargo expansion can be installed")
	campaign._close_ship_menu()
	check(campaign.depart(), "route begins from navigation screen")
	step(1)
	check(campaign.model.phase == 1 and campaign.exterior.visible, "flight displays opaque rocket with pilot")
	await screenshot("expedition-flight-1080p")
	check(campaign.save_campaign(), "campaign can be saved in flight")
	var fuel: float = campaign.model.ship.fuel
	check(campaign.load_campaign(), "midflight campaign can be loaded")
	check(is_equal_approx(fuel, campaign.model.ship.fuel), "loading does not charge travel twice")
	step(10)
	step(2)
	check(campaign.model.phase == 2 and campaign.exterior.legs_deployed, "vertical landing deploys legs")
	await screenshot("expedition-landing-1080p")
	step(10)
	await frames()
	check(campaign.model.phase == 3 and is_instance_valid(campaign.world), "landing enters playable cutaway")
	var world: Node2D = campaign.world
	Fixture.starter_tunnel(world)
	world.player.set_physics_process(false)
	world.set_hatch(true)
	await frames()
	check(not campaign.request_takeoff(), "open hatch prevents launch")
	world.player.position = Vector2(-170, 160)
	check(not campaign.request_takeoff(), "player cannot launch from underground")
	world.target_cell = Vector2i(-6, 3)
	world.mine_timer = 0
	var soil: int = world.field_cargo.used(world.field_cargo.backpack)
	world._mine_target()
	check(world.site.material(world.target_cell).is_empty(), "digital beam destroys reachable soil")
	check(world.field_cargo.used(world.field_cargo.backpack) == soil + 1, "mined resources enter the physical backpack")
	check(world.beam_time > 0, "successful pulse starts beam effect")
	world.target_cell = Vector2i(-6, 2)
	world.equip_tool(1)
	world.mine_timer = 0
	world._mine_target()
	check(world.scanned.has(world.target_cell), "scanner records cell composition without mining")
	check(not world.site.material(world.target_cell).is_empty(), "scanner leaves terrain intact")
	check(not world.equip_tool(3), "locked empty equipment slot cannot be selected")
	world.equip_tool(0)
	var cargo: Dictionary = world.field_cargo.snapshot()
	world.field_cargo.backpack.soil = 8
	world.field_cargo.drone.soil = world.field_cargo.drone_capacity
	world.mine_timer = 0
	world._mine_target()
	check(world.target_blocker(world.target_cell).contains("Carico pieno"), "full portable cargo marks target unavailable")
	check(not world.site.material(world.target_cell).is_empty(), "full hold does not destroy or lose a block")
	world.field_cargo.restore(cargo)
	check(not world.target_blocker(Vector2i(20, 0)).is_empty(), "distant target has a blocking reason")
	check(world._illumination(Vector2(700, 700)) < 0.01, "distant underground cells are dark")
	check(world._illumination(world.player.position - Vector2(0, 32)) > 0.99, "working radius is illuminated around explorer")
	var original_position: Vector2 = world.player.position
	for y in [13, 14]:
		var cell := Vector2i(0, y)
		world.site.removed[cell] = true
		world.terrain.remove_child(world.blocks[cell])
		world.blocks[cell].queue_free()
		world.blocks.erase(cell)
	world.player.position = Vector2(20, 600)
	await frames()
	check(world.target_blocker(Vector2i(0, 15)).contains("incompatibile"), "reachable but tool-incompatible rock is marked unavailable")
	world.player.position = original_position
	campaign.open_ship_menu()
	check(world.controls_blocked(), "ship window pauses mining and traversal")
	check(not campaign._can_service(), "remote upgrades are blocked outside workshop")
	campaign._close_ship_menu()
	await frames(25)
	world.set_process(false)
	world.target_cell = Vector2i(-6, 2)
	world.player.facing = -1
	world.message_time = 0
	world._refresh_hud()
	world.beam_time = 1
	world.beam_tool = world.active_tool()
	world.beam_target = world.Grid.center(world.target_cell)
	world.queue_redraw()
	world.player.queue_redraw()
	await frames()
	await screenshot("expedition-dark-digging-1080p")
	root.size = Vector2i(1280, 720)
	await frames()
	world.beam_time = 0
	world.target_cell = Vector2i(-8, 3)
	world._refresh_hud()
	world.queue_redraw()
	await frames()
	await screenshot("expedition-dark-digging-720p")
	world.return_home()
	world.drone.position = Vector2(20, -140)
	world.set_hatch(false)
	await frames()
	check(campaign.request_takeoff(), "closed ship can take off with astronaut aboard")
	step(10)
	check(campaign.model.phase == 0, "takeoff returns to planet selection")
	check(root.canvas_transform == Transform2D.IDENTITY, "camera resets when leaving dig site")
	campaign.select_planet(1)
	campaign.depart()
	await land()
	check(not campaign.world.site.material(Vector2i(-6, 3)).is_empty(), "second planet has independent excavation")
	check(campaign.world.site.terrain_seed == 11, "planet config drives deterministic material distribution")
	check(campaign.model.ship.cargo_capacity() == 200, "ship upgrades persist across planets")
	campaign.world.return_home()
	campaign.world.drone.position = Vector2(20, -140)
	campaign.world.set_hatch(false)
	check(campaign.request_takeoff(), "second planet can be left")
	step(10)
	campaign.select_planet(0)
	campaign.depart()
	await land()
	check(campaign.world.site.material(Vector2i(-6, 3)).is_empty(), "returning to planet restores previous tunnel")
	check(campaign.world.scanned.has(Vector2i(-6, 2)), "returning restores scan records")
	check(campaign.save_campaign(), "landed multi-planet campaign saves")
	campaign.model.ship.resources.crystal = 50
	check(campaign.load_campaign(), "multi-planet campaign restores")
	check(campaign.model.ship.resources.crystal == 0, "cargo is not duplicated from per-planet snapshots")
	var previous: Node2D = campaign.world
	root.get_node("SaveManager").write_campaign_save({"version": 999})
	check(not campaign.load_campaign() and campaign.world == previous, "invalid save leaves running world unchanged")
	print("EXPEDITION SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
