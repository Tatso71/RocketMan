extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
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

func screenshot(name: String, viewport: Viewport = null) -> void:
	if not capture:
		return
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, name + " screenshot saved")

func check_layout() -> void:
	var bubble: Control = world.guide.bubble
	var view := root.get_visible_rect()
	var actor: Vector2 = world.player.get_global_transform_with_canvas() * Vector2(0, -32)
	check(view.encloses(bubble.get_global_rect()), "comic balloon stays inside viewport")
	check(not bubble.get_global_rect().intersects(Rect2(actor - Vector2(20, 40), Vector2(40, 80))), "comic balloon does not cover the explorer")
	check(world.outpost.cargo_ui.compact.get_global_rect().end.x <= view.end.x, "inventory HUD fits viewport width")

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
			print("Overflow: ", child.get_class(), " ", child.get_global_rect(), " bounds ", bounds)
			return false
		if not controls_fit(child, bounds):
			return false
	return true

func _run() -> void:
	create_timer(50).timeout.connect(func(): push_error("Inventory guide smoke timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	Fixture.workshop(world)
	world.local_store = {"soil": 12, "stone": 8, "copper": 6}
	await frames(10)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	var ui: CanvasLayer = world.outpost.cargo_ui
	world.guide.request_help()
	await frames()
	check(world.guide.bubble.visible, "drone has a visible comic balloon")
	check_layout()
	await screenshot("inventory-guide-arrival-720p")
	ui.open_inventory()
	check(ui.window.visible, "inventory opens aboard")
	check(not ui.prepare_button.disabled, "prepare laboratory is available beside ship hold")
	ui.prepare_lab()
	check(world.field_cargo.available("stone", true) == 6 and world.field_cargo.available("copper", true) == 4, "prepare laboratory loads exact stone and copper")
	check(world.field_cargo.backpack.is_empty() and world.field_cargo.used(world.field_cargo.drone) == 10, "recipe is physically carried entirely by Robbie")
	check(world.local_store.stone == 2 and world.local_store.copper == 2, "preparation subtracts materials from local ship stock")
	check(not ui.prepare_blocker().is_empty(), "legacy recipe preparation cannot duplicate already carried materials")
	await frames()
	if DisplayServer.get_name() != "headless":
		check(controls_fit(ui.window, ui.window.get_visible_rect()), "all inventory controls fit inside the window")
	await screenshot("inventory-three-holds", ui.window)
	ui.deposit()
	var copper: int = world.local_store.copper
	world.local_store.copper = 0
	var insufficient: Dictionary = world.local_store.duplicate()
	ui.prepare_lab()
	check(world.local_store == insufficient and world.field_cargo.used(world.field_cargo.backpack) == 0, "missing recipe ingredient prevents partial withdrawal")
	world.local_store.copper = copper
	check(world.field_cargo.used(world.field_cargo.backpack) + world.field_cargo.used(world.field_cargo.drone) == 0, "unload all empties both nearby holds")
	check(world.guide_state.facts.get("deposited", false), "deposit emits a semantic guide milestone")
	world.field_cargo.collect("soil", 20, true)
	ui.refresh()
	var before: Dictionary = world.field_cargo.snapshot()
	var stock: Dictionary = world.local_store.duplicate()
	check(ui.prepare_blocker().contains("Libera"), "full holds explain lack of space for laboratory materials")
	ui.prepare_lab()
	check(world.field_cargo.snapshot() == before and world.local_store == stock, "failed preparation is atomic")
	ui.window.hide()
	world.guide.request_help()
	await frames()
	check(world.guide_state.active_id == "cargo_full", "full holds get an explicit unload tutorial")
	check(world.guide.speech.text.contains("Deposita materiali"), "guide names the actual laboratory context action")
	check_layout()
	await screenshot("inventory-full-cargo-720p")
	root.size = Vector2i(1920, 1080)
	await frames()
	check_layout()
	await screenshot("inventory-full-cargo-1080p")
	ui.open_inventory()
	ui.deposit()
	ui.window.hide()
	Fixture.lab_room(world)
	world.set_hatch(true)
	world.player.position = Vector2(-140, 160)
	world.drone.position = Vector2(-100, 90)
	world.drone.status = "Ti seguo"
	await frames()
	ui.open_inventory()
	ui.refresh()
	check(ui.deposit_button.disabled and ui.withdraw_button.disabled, "remote inventory is inspectable without teleporting stock")
	check(ui.subtitles[2].text == "Nessun deposito vicino", "remote storage is explicitly unavailable")
	ui.window.hide()
	check(world.outpost.place("laboratory", Vector2i(-5, 1)), "cube placement does not require carried resources")
	var site: Dictionary = world.outpost.buildings.structures.back()
	check(world.outpost.funding_blocker(site).contains("6 pietra"), "cube funding identifies missing quantities")
	world.field_cargo.collect("stone", 6, true)
	world.field_cargo.collect("copper", 4, true)
	check(world.outpost.funding_blocker(site).is_empty(), "laboratory cube can overlap the explorer")
	check(world.outpost.fund_site(site), "fund laboratory while standing inside its footprint")
	world.outpost.construction.activation_popup.hide()
	world.outpost.advance(5.1)
	check(world.guide_state.facts.get("lab_built", false), "laboratory completion reaches drone tutorial")
	world.guide_state.dismiss()
	world.guide_state.gap = 0
	world.guide_state.tick(40, "lab_built")
	world.guide.request_help()
	await frames()
	check_layout()
	await screenshot("inventory-laboratory-balloon-1080p")
	world.guide_state.set_muted(true)
	var saved: Dictionary = world.capture_state()
	check(world.restore_state(saved), "standalone outpost restores tutorial progress")
	check(world.guide_state.muted and world.guide_state.facts.get("lab_built", false), "mute preference and milestones survive load")
	world.guide.request_help()
	check(not world.guide_state.active_id.is_empty(), "manual help works while automatic hints are muted")
	world.drone.position = Vector2(900, 0)
	world.drone.status = "Limite segnale"
	world.guide.request_help()
	await frames()
	check_layout()
	check(not world.guide.tail.visible, "offscreen drone uses a radio balloon without a detached tail")
	print("INVENTORY GUIDE SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
