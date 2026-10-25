extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
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

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = world.get_global_transform_with_canvas() * point
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	world._unhandled_input(event)

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

func freeze() -> void:
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)

func _run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Creator cube timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	campaign = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	campaign.set_process(false)
	root.get_node("SaveManager").campaign_save_path = "res://reports/creator-cube-save.json"
	campaign.depart()
	campaign._process(10)
	campaign._process(10)
	world = campaign.world
	await frames()
	freeze()
	check(absf(world.player.position.y + 320) < 2 and world.rooms.available("cabin"), "landing leaves the pilot in the top cabin")
	await screenshot("cube-cockpit-arrival-720p")
	click(Vector2(-60, -370))
	check(world.rooms.popup.visible, "illuminated cockpit opens navigation actions")
	world.rooms._cabin_action(1)
	check(campaign.ship_menu.visible and campaign.Modules.all()[campaign.module_picker.selected].module_id == "battery", "cockpit opens ship battery management")
	check(campaign.upgrade_button.disabled, "battery upgrade requires real scarce resources")
	campaign._close_ship_menu()
	world.player.position = Vector2(-60, -200)
	world._set_suit(40)
	world._set_crew_energy(20)
	await screenshot("cube-bedroom-highlight-720p")
	click(Vector2(-80, -240))
	check(world.rooms.bed_window.visible and world.rooms.available("bedroom"), "bedroom highlights and opens rest panel")
	var battery: float = world.ship_energy()
	world.rooms.rest_button.pressed.emit()
	world.rooms._process(1)
	check(world.crew_energy() >= 40 and world.suit_integrity() >= 60, "bed restores personal energy and suit integrity")
	check(is_equal_approx(world.ship_energy(), battery), "bed does not generate ship battery energy")
	await screenshot("cube-bed-rest", world.rooms.bed_window)
	world.rooms._close_bed()
	Fixture.workshop(world)
	Fixture.lab_room(world)
	world.set_hatch(true)
	world.player.position = Vector2(-140, 160)
	world.drone.position = Vector2(-100, 90)
	world.camera.position = Vector2(-80, 10)
	world.camera.zoom = Vector2.ONE * 0.9
	await frames()
	check(not world.outpost.place("laboratory", Vector2i(8, 1)), "solid terrain still rejects cube placement")
	click(Vector2(-199, 41))
	var ui: Node = world.outpost.construction
	check(not ui.picker.visible and not world.outpost.build_mode, "right click on empty ground no longer creates free cube plans or unwanted outlines")
	world.outpost.place("laboratory", Vector2i(-5, 1))
	await frames()
	var site: Dictionary = world.outpost.buildings.structures[0]
	check(site.state == "planned" and world.outpost.buildings.labs().is_empty(), "placed cube reserves its footprint without activating a laboratory")
	check(world.outpost.funding_blocker(site).contains("Mancano"), "legacy unfunded cube reports exact missing materials")
	var cargo: Dictionary = world.field_cargo.snapshot()
	world.outpost.fund_site(site)
	check(site.state == "planned" and world.field_cargo.snapshot() == cargo, "insufficient funding cannot consume partial materials")
	Fixture.workshop(world)
	campaign.model.ship.resources = {"stone": 6, "copper": 4}
	await frames()
	check(world.field_cargo.withdraw(campaign.model.ship.resources, "stone", 6, true), "physically load laboratory stone in workshop")
	check(world.field_cargo.withdraw(campaign.model.ship.resources, "copper", 4, true), "physically load laboratory copper in workshop")
	world.player.position = Vector2(-140, 160)
	world.drone.position = Vector2(-100, 90)
	await frames()
	check(world.outpost.funding_blocker(site).is_empty(), "old saves can still fund an existing plan")
	world.outpost.fund_site(site)
	check(site.state == "building", "legacy transfer starts timed unfolding")
	check(world.field_cargo.used(world.field_cargo.backpack) + world.field_cargo.used(world.field_cargo.drone) == 0, "raw materials transfer exactly once from physical holds")
	check(not world.outpost.fund_site(site), "construction cannot charge the same materials twice")
	check(not world.outpost.has_lab(), "unfinished laboratory provides no services")
	world.outpost.advance(2)
	check(site.progress > 0.3 and site.progress < 0.5, "construction has real elapsed-time progress")
	world.ambient_time = 0
	await screenshot("cube-unfolding-720p")
	check(campaign.save_campaign() and campaign.load_campaign(), "half-built creator cube survives campaign save/load")
	world = campaign.world
	await frames()
	freeze()
	site = world.outpost.buildings.structures[0]
	check(site.state == "building" and site.progress > 0.3, "restored cube remains paid and unfinished")
	check(world.crew_energy() >= 40, "personal energy persists with ship state")
	world.outpost.advance(4)
	check(site.state == "active" and site.progress == 1 and world.outpost.has_lab(), "full progress bar activates the laboratory")
	check(campaign.model.ship.lab_research_unlocked, "research unlock occurs only on actual completion")
	world.camera.position = Vector2(-80, 10)
	world.camera.zoom = Vector2.ONE * 0.9
	var before: float = world.ship_energy()
	world.outpost.advance(10)
	check(is_equal_approx(before - world.ship_energy(), 0.4), "active laboratory continuously draws energy from ship battery")
	world.outpost.open_station({"kind": "laboratory", "building": site}, Vector2(700, 450))
	world.outpost.station_menu.activate(5)
	before = world.ship_energy()
	world.outpost.advance(10)
	check(is_equal_approx(before, world.ship_energy()) and not world.outpost.operational(site), "switching a lab off stops both services and consumption")
	world.outpost.open_station({"kind": "laboratory", "building": site}, Vector2(700, 450))
	world.outpost.station_menu.activate(5)
	world._set_ship_energy(0.01)
	world.outpost.advance(1)
	check(world.ship_energy() == 0 and not world.outpost.has_lab(), "empty ship battery shuts down laboratories without becoming negative")
	check(world.outpost.light_at(world.outpost.buildings.world_rect(site).get_center()) == 0, "unpowered lab cannot keep lighting the galleries")
	check(world.outpost.station_available({"kind": "laboratory", "building": site}), "unpowered station still permits access to its switch and physical cache")
	await screenshot("cube-laboratory-no-power-720p")
	world._set_ship_energy(10)
	world.player.position = Vector2(-160, 160)
	world.drone.position = Vector2(-120, 90)
	Fixture.carve(world, Vector2i(-6, 2))
	Fixture.carve(world, Vector2i(-6, 3))
	site.stock = {"soil": 1, "copper": 1}
	await frames()
	check(world.outpost.place("lamp", Vector2i(-6, 3)), "lights also start as creator cubes")
	var lamp: Dictionary = world.outpost.buildings.structures.back()
	check(world.outpost.fund_site(lamp), "lamp cube consumes raw soil and copper from nearby physical cache")
	world.outpost.advance(3)
	check(lamp.state == "active" and world.outpost.lamp_powered(lamp), "lamp unfolds into its lit final structure")
	check(is_equal_approx(world.outpost.network_load(), 0.048), "network includes both laboratory and lamp draw")
	Fixture.carve(world, Vector2i(0, 4))
	Fixture.carve(world, Vector2i(0, 5))
	Fixture.carve(world, Vector2i(1, 5))
	Fixture.carve(world, Vector2i(2, 5))
	world.player.position = Vector2(22, 240)
	world.drone.position = Vector2(20, 185)
	await frames()
	check(world.outpost.place("lamp", Vector2i(1, 5)) and world.outpost.place("lamp", Vector2i(2, 5)), "two adjacent pending light cubes can coexist")
	var first: Dictionary = world.outpost.buildings.structures[-2]
	var second: Dictionary = world.outpost.buildings.structures[-1]
	await frames()
	var cube_ui: Node = world.outpost.construction
	check(not cube_ui.is_open(), "old pending plans do not trap the player with automatic prompts")
	cube_ui.open_site(first)
	check(cube_ui.activation_popup.visible, "existing plans retain an explicit compatibility action")
	cube_ui.activation_popup.hide()
	world.outpost.buildings.structures.erase(first)
	world.outpost.buildings.structures.erase(second)
	check(not world.outpost.buildings.structures.has(first) and not world.outpost.buildings.structures.has(second), "unfunded cubes can be removed without creating active structures")
	world.player.position = Vector2(-160, 160)
	world.drone.position = Vector2(-120, 90)
	root.size = Vector2i(1920, 1080)
	await screenshot("cube-active-outpost-1080p")
	var saved_battery: float = world.ship_energy()
	world._set_ship_energy(0)
	Fixture.carve(world, Vector2i(12, 9))
	Fixture.carve(world, Vector2i(12, 10))
	world.player.position = Vector2(500, 440)
	var count: int = world.outpost.buildings.structures.size()
	check(not world.place_ladder(), "manual ladder rejects insufficient soil without creating a cube")
	world.field_cargo.collect("soil", 2, false)
	check(world.place_ladder() and world.ladders.has(Vector2i(12, 10)), "player builds emergency ladder instantly without drone or battery")
	check(world.outpost.buildings.structures.size() == count and not world.outpost.construction.is_open(), "manual ladder has no cube, popup or construction timer")
	check(world.ship_energy() == 0, "instant manual ladder uses no electricity")
	world._set_ship_energy(saved_battery)
	world.player.position = Vector2(-60, -320)
	world.drone.position = Vector2(0, -365)
	world.set_hatch(false)
	campaign.model.ship.resources.copper = 5
	campaign.model.ship.resources.crystal = 2
	world.rooms._cabin_action(1)
	before = world.ship_energy()
	campaign.upgrade_button.pressed.emit()
	check(campaign.model.ship.energy_capacity() == 100 and is_equal_approx(before, world.ship_energy()), "scarce materials expand battery capacity without refilling it")
	campaign._close_ship_menu()
	world.rooms._cabin_action(2)
	await frames()
	check(campaign.model.phase == 4, "top cabin launches ship after normal safety checks")
	print("CREATOR CUBE SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
