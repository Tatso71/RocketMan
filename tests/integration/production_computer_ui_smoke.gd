extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value:
		failures += 1

func frames(count: int = 4) -> void:
	for index in range(count):
		await physics_frame

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = world.get_global_transform_with_canvas() * point
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	world._unhandled_input(event)

func setup(variant: String) -> void:
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	world.variant = variant
	root.add_child(world)
	await frames()
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.guide.set_process(false)
	world.guide_state.set_muted(true)
	Fixture.workshop(world)
	Fixture.support(world)
	world.field_cargo.backpack.clear()
	world.field_cargo.drone.clear()
	world.local_store = {"iron": 16, "copper": 9, "crystal": 3}

func controls_fit(node: Node, bounds: Rect2) -> bool:
	if node is ScrollContainer:
		if not bounds.grow(1).encloses(node.get_global_rect()):
			return false
		for content in node.get_children():
			if content is Container and content.get_combined_minimum_size().x > node.size.x + 1:
				print("Horizontal overflow: ", content.get_combined_minimum_size(), " / ", node.size)
				return false
		return true
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and not bounds.grow(1).encloses(child.get_global_rect()):
			print("Overflow: ", child.get_class(), " ", child.get_global_rect(), " / ", bounds)
			return false
		if not controls_fit(child, bounds):
			return false
	return true

func layout(view: Node, size: Vector2i) -> void:
	view.picker.hide()
	root.size = size
	await frames()
	world.outpost.station_menu.open(Vector2(500, 300))
	await frames()
	var bounds: Rect2 = root.get_screen_transform() * root.get_visible_rect()
	var panel: Rect2 = view.picker.get_screen_transform() * view.picker.get_visible_rect()
	check(bounds.grow(1).encloses(panel), "computer fits native viewport " + str(size))
	check(controls_fit(view.picker, view.picker.get_visible_rect()), "computer controls and scroll widths fit " + str(size))
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(view.picker.get_texture().get_image().save_png("res://reports/production-computer-ui-%s-%d.png" % [view.current_station.kind, size.y]) == OK, "save bounded computer screenshot")

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	root.size = Vector2i(1280, 720)
	await setup("explorer")
	var outpost: Node = world.outpost
	var view: Node = outpost.construction
	var menu: Node = outpost.station_menu
	click(Vector2(-50, -140))
	await frames()
	check(view.picker.visible and not menu.popup.visible and world.controls_blocked(), "right click opens the computer directly and blocks world input")
	if not view.picker.visible:
		menu.popup.hide()
		view.open_picker(Vector2i.ZERO, Vector2(500, 300), true)
	var structural: Dictionary = view.recipe_rows.structural_component
	structural.quantity.value = 2
	view.refresh()
	check(structural.resources.iron.text.contains("16 / 8"), "quantity shows actual owned / needed iron")
	check(structural.duration.text == "4.0 s" and structural.energy.text == "0.02 kWh", "quantity scales existing recipe time and energy")
	check(not structural.button.disabled, "affordable explicit order is enabled")
	check(structural.title.get_theme_color("font_color") * structural.title.modulate == Color("a7e5b4"), "affordable recipe name is green, not multiplied by its item tint")
	structural.button.pressed.emit()
	check(outpost.fabrication.jobs.size() == 1 and world.local_store.iron == 8, "actual order button reserves two paid batches once")
	var electronic: Dictionary = view.recipe_rows.electronic_component
	check(not electronic.button.disabled, "second recipe remains orderable while station is busy")
	electronic.button.pressed.emit()
	check(outpost.fabrication.jobs.size() == 2 and world.local_store.copper == 6 and world.local_store.crystal == 2, "second button appends a real paid order")
	check(not view.collect_button.visible, "human companion needs no manual withdrawal command")
	if outpost.fabrication.jobs.size() == 2:
		outpost.advance_fabrication(1)
		view.refresh()
		check(outpost.fabrication.jobs[0].elapsed == 1 and outpost.fabrication.jobs[1].elapsed == 0, "only FIFO head progresses in core")
		check(is_equal_approx(view.craft_bar.value, 25), "computer progress belongs to first queued order")
		var queue: Variant = view.get("queue_rows")
		check(queue is Array and queue.size() == 2, "computer displays both paid FIFO orders")
		if queue is Array and queue.size() == 2:
			check(queue[0].status.text.contains("corso") and queue[1].status.text.contains("coda") and queue[1].bar.value == 0, "queue distinguishes active head from zero-progress waiting order")
		world._set_ship_energy(0)
		outpost.advance_fabrication(1)
		view.refresh()
		check(view.picker.visible and view.choice_status.text.contains("batteria") and is_equal_approx(view.craft_bar.value, 25), "paused paid head remains visible with concrete power reason")
		world._set_ship_energy(60)
		world.gear.set_workshop_damage(true)
		view.refresh()
		check(view.picker.visible and view.choice_status.text.contains("ripara"), "damaged workshop keeps the paused head visible")
		world.gear.set_workshop_damage(false)
	world.local_store.structural_component = 3
	outpost.fabrication.add_output(["ship"], "electronic_component", 2)
	outpost.logistics.status = "Percorso di Robbie ostruito"
	view.refresh()
	var stocks: Variant = view.get("stock_labels")
	check(stocks is Dictionary and stocks.has("structural_component") and stocks.structural_component.ship.text == "3", "ready ship stock uses existing inventory")
	check(stocks is Dictionary and stocks.has("electronic_component") and stocks.electronic_component.buffer.text == "2", "ready bench output remains visible separately")
	var robot: Variant = view.get("robot_status")
	check(robot is Label and robot.text.contains("Percorso di Robbie ostruito"), "computer shows current robot task or blocker")
	world.local_store.iron = 0
	view.refresh()
	check(structural.button.disabled and not structural.button.tooltip_text.is_empty(), "unaffordable order exposes actual blocker")
	check(structural.title.get_theme_color("font_color") * structural.title.modulate == Color("829396"), "unaffordable recipe name is neutral gray")
	check(structural.has("reason") and structural.reason.text == structural.button.tooltip_text, "failure reason is visible beside the disabled order")
	var more: Variant = view.get("maintenance_button")
	check(more is Button, "computer exposes secondary station actions")
	if more is Button:
		more.pressed.emit()
		await frames()
		check(not view.picker.visible and menu.popup.visible and outpost.selected_station.kind == "ship", "maintenance command closes computer and preserves selected station")
		var has_production := false
		for index in range(menu.popup.item_count):
			has_production = has_production or menu.popup.get_item_id(index) == 2
		check(not has_production, "secondary actions do not loop back to production")
		menu.activate(3)
		check(menu.window.visible and menu.rows.size() == 2, "secondary maintenance still reaches existing repairs")
		menu.window.hide()
	menu.popup.hide()
	# Fill through the actual controls: a long queue must stay bounded.
	outpost.fabrication.jobs.clear()
	outpost.fabrication.outputs.clear()
	world.local_store = {"iron": 100}
	outpost.station_menu.open(Vector2(500, 300))
	structural.quantity.value = 1
	for index in range(18):
		structural.button.pressed.emit()
	check(outpost.fabrication.jobs.size() == 18, "repeated emitted order buttons populate a real queue")
	var scroll: Variant = view.get("queue_scroll")
	check(scroll is ScrollContainer, "long queue has a bounded scrolling viewport")
	if DisplayServer.get_name() != "headless":
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			await layout(view, size)
		if scroll is ScrollContainer:
			check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "populated queue scrolls without growing the window")
	view.picker.hide()
	Fixture.lab_room(world)
	world.set_hatch(true)
	world.player.position = Vector2(-140, 160)
	Fixture.support(world)
	world.field_cargo.drone = {"structural_component": 4, "electronic_component": 2}
	check(Fixture.build(world, "laboratory", Vector2i(-5, 1)), "create reachable underground station fixture")
	var lab: Dictionary = outpost.buildings.labs()[0]
	lab.stock = {"iron": 8, "structural_component": 2}
	world.field_cargo.drone.clear()
	await frames()
	click(Vector2(-120, 100))
	view.refresh()
	structural = view.recipe_rows.structural_component
	check(view.picker.visible and outpost.selected_station.get("kind") == "laboratory", "underground right click opens selected local computer")
	check(structural.resources.iron.text == "Ferro  8 / 4", "local ingredients exclude remote ship minerals")
	check(view.recipe_rows.has("refined_electronics") and view.recipe_rows.has("structural_alloy"), "active laboratory exposes existing advanced recipes")
	var ship_before: Dictionary = world.local_store.duplicate()
	structural.button.pressed.emit()
	check(lab.stock.iron == 4 and world.local_store == ship_before, "local order pays only selected station without touching remote stock")
	stocks = view.get("stock_labels")
	check(stocks is Dictionary and stocks.structural_component.local.text == "2", "computer distinguishes local ready stock")
	lab.enabled = false
	view.refresh()
	check(view.picker.visible and view.choice_status.text.contains("accendi") and structural.button.disabled, "disabled local station keeps paid job and concrete pause status visible")
	if DisplayServer.get_name() != "headless":
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			await layout(view, size)
	view.maintenance_button.pressed.emit()
	await frames()
	check(menu.popup.visible and outpost.selected_station.building == lab, "local maintenance preserves the selected underground station")
	menu.activate(5)
	check(lab.enabled, "secondary local action toggles the actual selected laboratory")
	view.picker.hide()
	world.player.position = Vector2(20, 160)
	check(outpost.place("lamp", Vector2i(-1, 3)), "create a project needing ordered semilavorati")
	world.drone._rebuild()
	world.field_cargo.drone.clear()
	world.local_store.clear()
	outpost.fabrication.outputs.clear()
	world.player.position = Vector2(-140, 160)
	click(Vector2(-120, 100))
	view.refresh()
	check(view.robot_status.text.contains("Preparo") and view.robot_status.text.contains("elettronici"), "robot status includes concrete project semilavorati preparation")
	var pinned: Dictionary = outpost.selected_station
	world.player.position = Vector2(50, -80)
	view.refresh()
	check(not view.picker.visible and outpost.selected_station == pinned, "leaving selected station closes computer instead of silently switching")
	var jobs_before: Array = outpost.fabrication.jobs.duplicate(true)
	ship_before = world.local_store.duplicate()
	structural = view.recipe_rows.structural_component
	structural.button.pressed.emit()
	check(outpost.fabrication.jobs == jobs_before and world.local_store == ship_before, "stale order button cannot redirect payment to the nearby ship")
	world.free()
	await setup("robbie")
	view = world.outpost.construction
	click(Vector2(-50, -140))
	view.refresh()
	check(view.collect_button.visible and not world.outpost.logistics.enabled(), "controlled Robbie retains manual collect without autonomous logistics")
	world.local_store = {"structural_component": 2}
	world.field_cargo.drone = {"iron": 20}
	view.refresh()
	check(view.collect_button.disabled and view.collect_button.tooltip_text.contains("pieno"), "manual collection exposes full cargo blocker")
	world.field_cargo.drone.clear()
	view.refresh()
	view.collect_button.pressed.emit()
	check(world.field_cargo.drone.get("structural_component", 0) == 2, "controlled Robbie collect button transfers actual ready output")
	world.free()
	print("PRODUCTION COMPUTER UI: %d failures" % failures)
	quit(1 if failures else 0)
