extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
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

func frames(count: int = 5) -> void:
	for index in range(count):
		await physics_frame

func click(point: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.position = world.get_global_transform_with_canvas() * point
	event.button_index = button
	event.pressed = true
	world._unhandled_input(event)

func controls_fit(node: Node, bounds: Rect2) -> bool:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and not bounds.grow(1).encloses(child.get_global_rect()):
			print("Overflow: ", child.get_class(), " ", child.get_global_rect(), " bounds ", bounds)
			return false
		if not controls_fit(child, bounds):
			return false
	return true

func screenshot(name: String, viewport: Viewport = null) -> void:
	if not capture:
		return
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, name + " screenshot saved")

func _run() -> void:
	create_timer(50).timeout.connect(func(): push_error("Workstation smoke timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	campaign = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	campaign.set_process(false)
	root.get_node("SaveManager").campaign_save_path = "res://reports/workstation-test-save.json"
	campaign.depart()
	campaign._process(10)
	campaign._process(10)
	world = campaign.world
	Fixture.workshop(world)
	campaign.model.ship.resources = {"soil": 12, "stone": 12, "copper": 12, "crystal": 0}
	await frames()
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	var menu: Node = world.outpost.station_menu
	var ui: CanvasLayer = world.outpost.cargo_ui
	check(not menu.is_open() and not world.controls_blocked(), "workstation windows start closed")
	check(world.outpost.station_at(Vector2(-50, -140)).get("kind") == "ship", "ship laboratory is interactable from workshop")
	await screenshot("workstation-ship-highlight-720p")
	world.field_cargo.collect("soil", 4, true)
	click(Vector2(-50, -140), MOUSE_BUTTON_RIGHT)
	check(menu.popup.visible and world.controls_blocked(), "right click opens and pauses at the ship laboratory")
	check(menu.popup.item_count == 6, "context popup has a title and all five actions")
	await screenshot("workstation-context-actions", menu.popup)
	var soil: int = campaign.model.ship.resources.soil
	menu.activate(0)
	check(campaign.model.ship.resources.soil == soil + 4 and world.field_cargo.used(world.field_cargo.backpack) == 0, "deposit action unloads to the selected ship station")
	click(Vector2(-50, -140), MOUSE_BUTTON_RIGHT)
	menu.activate(1)
	check(ui.window.visible, "withdraw action opens the local material inventory")
	ui.picker.select(1)
	ui.amount.value = 2
	ui.withdraw_button.pressed.emit()
	check(world.field_cargo.available("stone", true) == 2, "withdraw control transfers real local materials")
	ui.window.hide()
	click(Vector2(-50, -140), MOUSE_BUTTON_RIGHT)
	menu.activate(2)
	await frames()
	var construction: Node = world.outpost.construction
	check(construction.picker.visible and construction.resource_labels.size() == 2, "construction action opens the laboratory recipe table")
	if DisplayServer.get_name() != "headless":
		check(controls_fit(construction.picker, construction.picker.get_visible_rect()), "construction tree fits at 720p")
	await screenshot("workstation-construction", construction.picker)
	construction._cancel_picker()
	ui.open_inventory()
	ui.prepare_lab()
	check(world.field_cargo.available("stone", true) == 6 and world.field_cargo.available("copper", true) == 4, "construction menu prepares exact laboratory supplies")
	ui.window.hide()
	campaign.model.ship.hull = 50
	world._set_suit(50)
	click(Vector2(-50, -140), MOUSE_BUTTON_RIGHT)
	menu.activate(3)
	menu.rows[0].button.pressed.emit()
	check(world.suit_integrity() == 100, "ship laboratory repairs suit through its action button")
	menu.rows[1].button.pressed.emit()
	check(campaign.model.ship.hull == 75, "ship laboratory repair restores hull")
	menu.window.hide()
	click(Vector2(-50, -140), MOUSE_BUTTON_RIGHT)
	menu.activate(4)
	check(menu.rows[0].button.disabled, "ship tool-station upgrade respects laboratory research gate")
	campaign.model.ship.lab_research_unlocked = true
	campaign.model.ship.resources.stone = 20
	campaign.model.ship.resources.copper = 20
	menu.refresh()
	menu.rows[0].button.pressed.emit()
	check(campaign.model.ship.laboratory_level == 2 and world.outpost.fabrication_seconds() < 5, "ship laboratory upgrade reduces actual production time")
	menu.window.hide()
	world.guide_state.offer("first_dig", true)
	world.guide._update_bubble()
	var message: String = world.guide.speech.text
	world.guide_state.dismiss()
	world.guide_state.facts.mined = true
	var removed: Array = world.site.snapshot()
	click(world.drone.position, MOUSE_BUTTON_LEFT)
	check(world.guide_state.active_id == "first_dig" and world.guide.speech.text == message, "clicking drone repeats exact last message, not new context")
	check(not world.mouse_mining and world.site.snapshot() == removed, "drone click cannot start mining")
	world.camera.zoom = Vector2.ONE * 1.4
	await frames()
	world.guide_state.dismiss()
	click(world.drone.position, MOUSE_BUTTON_LEFT)
	check(world.guide.speech.text == message, "drone hit testing follows camera zoom")
	world.guide_state.dismiss()
	Fixture.lab_room(world)
	world.field_cargo.backpack = {"stone": 6, "copper": 2}
	world.field_cargo.drone = {"copper": 2}
	world.set_hatch(true)
	world.player.position = Vector2(-140, 160)
	world.drone.position = Vector2(-100, 90)
	await frames()
	check(Fixture.build(world, "laboratory", Vector2i(-5, 1)), "field laboratory cube unfolds around the explorer")
	var lab: Dictionary = world.outpost.buildings.labs()[0]
	lab.stock = {"stone": 12, "copper": 12, "soil": 8}
	world.set_process(false)
	world.camera.zoom = Vector2.ONE * 0.9
	world.camera.position = Vector2(-80, 10)
	await frames()
	await screenshot("workstation-field-highlight-720p")
	click(Vector2(-120, 100), MOUSE_BUTTON_RIGHT)
	check(menu.popup.visible and world.outpost.selected_station.get("kind") == "laboratory", "right click on built laboratory opens the same actions")
	menu.activate(4)
	var ship_stock: Dictionary = campaign.model.ship.resources.duplicate()
	menu.rows[0].button.pressed.emit()
	check(lab.level == 2 and ui.storage_capacity() == 48, "field upgrade expands actual local storage")
	check(Buildings.light_range(lab) == 10, "field upgrade extends actual lamp link range")
	check(campaign.model.ship.resources == ship_stock, "field upgrade never charges remote ship storage")
	var saved_stock: Dictionary = lab.stock.duplicate()
	lab.stock.clear()
	check(not world.outpost.upgrade_station() and lab.level == 2 and lab.stock.is_empty(), "unaffordable upgrade is atomic")
	lab.stock.merge(saved_stock)
	await screenshot("workstation-field-upgrade", menu.window)
	if DisplayServer.get_name() != "headless":
		check(controls_fit(menu.window, menu.window.get_visible_rect()), "upgrade controls fit inside their window")
	menu.window.hide()
	world._set_suit(40)
	click(Vector2(-120, 100), MOUSE_BUTTON_RIGHT)
	menu.activate(3)
	var copper: int = lab.stock.copper
	menu.rows[0].button.pressed.emit()
	check(world.suit_integrity() == 100 and lab.stock.copper == copper - 1, "field suit repair consumes local supplies")
	check(menu.rows[1].button.disabled, "underground lab cannot remotely repair ship hull")
	menu.window.hide()
	click(Vector2(-120, 100), MOUSE_BUTTON_RIGHT)
	menu.activate(2)
	check(construction.picker.visible and not world.outpost.recipe_visible("lamp") and not world.outpost.build_mode, "field station opens fabrication; future devices cannot create free plans")
	construction.picker.hide()
	world.outpost.build_mode = false
	# Keep the multi-station fixture dry; fluid behavior has a separate smoke test.
	world.environment.water.clear()
	world.environment.gas.clear()
	Fixture.carve(world, Vector2i(6, 2))
	Fixture.carve(world, Vector2i(6, 3))
	world.outpost.buildings.install("lamp", Vector2i(6, 3))
	world.outpost._refresh_light_sources()
	check(world.outpost.light_at(Vector2(260, 140)) > 0.99, "upgraded laboratory powers a lamp more than eight metres away")
	lab.level = 1
	world.outpost._refresh_light_sources()
	check(world.outpost.light_at(Vector2(260, 140)) < 0.01, "same distant lamp is outside base laboratory range")
	lab.level = 2
	for y in range(4, 8):
		Fixture.carve(world, Vector2i(-1, y))
		Fixture.carve(world, Vector2i(0, y))
	for y in range(5, 8):
		for x in range(1, 5):
			Fixture.carve(world, Vector2i(x, y))
	var second: Dictionary = world.outpost.buildings.install("laboratory", Vector2i(1, 5))
	second.stock = {"stone": 5}
	world.player.position = Vector2(0, 200)
	world.drone.position = Vector2(20, 170)
	world.field_cargo.backpack.clear()
	world.field_cargo.drone.clear()
	world.field_cargo.collect("soil", 2, false)
	await frames()
	click(Vector2(120, 260), MOUSE_BUTTON_RIGHT)
	menu.activate(0)
	check(second.stock.get("soil", 0) == 2, "clicked laboratory wins when two depots are in reach")
	check(not lab.stock.get("soil", 0) == 2, "deposit does not switch to the first nearby laboratory")
	Fixture.carve(world, Vector2i(-7, 2))
	Fixture.carve(world, Vector2i(-7, 3))
	world.player.position = Vector2(-254, 160)
	await frames()
	check(not world.outpost.station_available({"kind": "laboratory", "building": lab}), "solid wall blocks interaction despite short distance")
	click(Vector2(-120, 100), MOUSE_BUTTON_RIGHT)
	check(not menu.is_open(), "cannot open a laboratory through a wall")
	world.player.position = Vector2(-140, 160)
	world.drone.position = Vector2(-100, 90)
	world.camera.position = Vector2(-80, 10)
	await frames()
	root.size = Vector2i(1920, 1080)
	await frames()
	await screenshot("workstation-field-highlight-1080p")
	check(campaign.save_campaign() and campaign.load_campaign(), "campaign saves and restores laboratory upgrades")
	world = campaign.world
	await frames()
	check(world.outpost.buildings.labs()[0].level == 2 and Buildings.cache_capacity(world.outpost.buildings.labs()[0]) == 48, "upgraded local capacity survives campaign JSON roundtrip")
	print("WORKSTATION SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
