extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var failures := 0
var world: Node2D
var capture := false

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value: failures += 1

func frames() -> void:
	for index in range(5): await physics_frame

func picture(name: String, viewport: Viewport = null) -> void:
	if not capture: return
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png("res://reports/water-" + name + ".png") == OK, "capture " + name)

func stand(cell: Vector2i) -> void:
	world.player.position = Grid.center(cell) + Vector2(0, 20)
	Fixture.support(world)
	# This fixture tests plumbing, not companion pathfinding through its test shafts.
	world.drone.position = world.player.position - Vector2(0, 36)
	world.drone.mission = "follow"
	world.field_cargo.drone_available = true

func click(cell: Vector2i, button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = world.get_global_transform_with_canvas() * Grid.center(cell)
	event.button_index = button
	event.pressed = true
	return event

func volume() -> float:
	var result := 0.0
	for value in world.environment.water.values(): result += float(value)
	for pump: Dictionary in world.outpost.buildings.structures:
		if pump.id == "pump": result += float(world.outpost.industry.state(pump).water)
	return result

func fits(node: Node, bounds: Rect2) -> bool:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and not bounds.grow(1).encloses(child.get_global_rect()):
			print("Overflow: ", child, " / ", child.get_global_rect())
			return false
		if not fits(child, bounds): return false
	return true

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await frames()
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.guide_state.set_muted(true)
	for y in range(3):
		for x in range(-4, 0): Fixture.carve(world, Vector2i(x, y))
	world.outpost.buildings.install("laboratory", Vector2i(-4, 0))
	world.guide_state.facts.lab_built = true
	world.environment.water.clear()
	world.environment.oil.clear()
	world.environment.acid.clear()
	world.environment.gas.clear()
	Fixture.carve(world, Vector2i(-6, 5))
	world.environment.water[Vector2i(-6, 5)] = 1.0
	for x in range(-4, 1): Fixture.carve(world, Vector2i(x, 5))
	for x in range(-4, 0): Fixture.carve(world, Vector2i(x, 4))
	for y in range(1, 6): Fixture.carve(world, Vector2i(0, y))
	Fixture.carve(world, Vector2i(1, 1))
	Fixture.carve(world, Vector2i(1, 2))
	Fixture.carve(world, Vector2i(1, 3))
	await frames()
	world.field_cargo.drone = {"structural_component": 60, "electronic_component": 16}
	stand(Vector2i(-4, 5))
	var outpost = world.outpost
	world.camera.position = Vector2(-60, 80)
	world.camera.zoom = Vector2.ONE
	world.camera.force_update_scroll()
	outpost.industry_ui.menu.id_pressed.emit(10)
	var rotate := InputEventKey.new()
	rotate.physical_keycode = KEY_R
	rotate.pressed = true
	check(outpost.handle_input(rotate), "R rotates the selected intake preview")
	outpost.hydraulic_ui.direction = Vector2i.LEFT
	check(outpost.handle_input(click(Vector2i(-4, 5), MOUSE_BUTTON_LEFT)), "actual left click mounts valve instead of mining")
	check(outpost.hydraulics.valves.size() == 1 and not world.site.material(Vector2i(-5, 5)).is_empty(), "valve leaves anchor intact")
	outpost.hydraulic_ui.reset()
	for cell: Vector2i in [Vector2i(-4, 5), Vector2i(-3, 5), Vector2i(-2, 5), Vector2i(-1, 5), Vector2i(0, 5), Vector2i(0, 4), Vector2i(0, 3), Vector2i(0, 2), Vector2i(0, 1)]:
		stand(cell)
		check(outpost.place_conduit("water", cell), "place pipe " + str(cell))
	stand(Vector2i(-2, 5))
	check(outpost.place("pump", Vector2i(-2, 4)), "pump has its normal paid assembly plan")
	var pump: Dictionary = outpost.buildings.structures.back()
	check(outpost.fund_site(pump), "pay carried components for pump")
	outpost.advance(4.1)
	check(pump.state == "active", "pump assembly completes")
	stand(Vector2i(0, 1))
	outpost.industry_ui.menu.id_pressed.emit(11)
	outpost.hydraulic_ui.direction = Vector2i.RIGHT
	check(outpost.handle_input(click(Vector2i(0, 1), MOUSE_BUTTON_LEFT)), "actual click configures capped outlet on paid pipe")
	outpost.hydraulic_ui.reset()
	if outpost.hydraulics.outlets.is_empty() or outpost.hydraulics.valves.is_empty():
		quit(1)
		return
	check(outpost.hydraulics.toggle(outpost.hydraulics.outlets[0], outpost), "open receiving outlet")
	stand(Vector2i(-4, 5))
	check(outpost.handle_input(click(Vector2i(-4, 5), MOUSE_BUTTON_RIGHT)), "right click opens intake control panel")
	check(outpost.hydraulic_ui.window.visible and world.controls_blocked(), "intake panel blocks explorer controls")
	outpost.hydraulic_ui.drill_button.pressed.emit()
	outpost.hydraulic_ui.opened_toggle.set_pressed(true)
	check(outpost.hydraulics.valves[0].drilled and outpost.hydraulics.valves[0].opened, "panel perforates and opens intake")
	var before := volume()
	stand(Vector2i(-4, 5))
	check(outpost.placement_blocker("lamp", Vector2i(-4, 5)).contains("presa"), "construction cannot overlap a mounted valve")
	outpost.advance(0.4)
	check(float(world.environment.water.get(Vector2i(1, 1), 0)) > 0, "powered pump lifts water into actual upper world cell")
	check(absf(before - volume()) < 0.00001, "source, buffer and outlet conserve all water")
	outpost.set_process(true)
	for frame_index in range(30): await physics_frame
	outpost.set_process(false)
	check(float(world.environment.water.get(Vector2i(1, 2), 0)) + float(world.environment.water.get(Vector2i(1, 3), 0)) > 0, "physical water keeps falling while valve controls are open")
	check(absf(before - volume()) < 0.0001, "inspecting controls preserves total water")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await frames()
		check(fits(outpost.hydraulic_ui.window, outpost.hydraulic_ui.window.get_visible_rect()), "valve controls fit " + str(size))
		await picture("valve-" + str(size.y), outpost.hydraulic_ui.window)
	outpost.hydraulic_ui.window.hide()
	stand(Vector2i(-2, 5))
	outpost.industry_ui.open_machine(pump)
	await frames()
	check(fits(outpost.industry_ui.window, outpost.industry_ui.window.get_visible_rect()), "pump direction and flow controls fit")
	await picture("pump-controls", outpost.industry_ui.window)
	outpost.industry_ui.window.hide()
	stand(Vector2i(0, 1))
	check(outpost.handle_input(click(Vector2i(0, 1), MOUSE_BUTTON_RIGHT)), "right click opens terminal role controls")
	outpost.hydraulic_ui.role_picker.item_selected.emit(1)
	check(outpost.hydraulics.outlets[0].role == "intake" and not outpost.hydraulics.outlets[0].opened, "switching terminal to aspiration closes it safely")
	outpost.hydraulic_ui.role_picker.item_selected.emit(0)
	outpost.hydraulic_ui.opened_toggle.set_pressed(true)
	await frames()
	check(fits(outpost.hydraulic_ui.window, outpost.hydraulic_ui.window.get_visible_rect()), "terminal role selector and feedback fit")
	await picture("terminal-controls", outpost.hydraulic_ui.window)
	outpost.hydraulic_ui.window.hide()
	root.size = Vector2i(1280, 720)
	await picture("circuit-720")
	var saved: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(saved))), "world roundtrip preserves sealed circuit and physical water")
	check(world.outpost.hydraulics.valves.size() == 1 and world.outpost.hydraulics.valves[0].opened, "restored valve retains open state")
	var bad := saved.duplicate(true)
	bad.hydraulics.valves[0].direction = [1, 1]
	var state_before := JSON.stringify(world.capture_state())
	check(not world.restore_state(bad) and JSON.stringify(world.capture_state()) == state_before, "invalid circuit is rejected without replacing current world")
	print("Water circuit smoke: %d failures" % failures)
	quit(1 if failures else 0)
