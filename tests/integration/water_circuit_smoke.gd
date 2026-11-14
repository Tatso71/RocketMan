extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var failures := 0
var world: Node2D
var capture := false

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value: failures += 1

func frames() -> void:
	for index in range(4): await physics_frame

func picture(name: String, viewport: Viewport = null) -> void:
	if not capture: return
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png("res://reports/blue-water-" + name + ".png") == OK, "capture " + name)

func stand(cell: Vector2i) -> void:
	world.player.position = Grid.center(cell) + Vector2(0, world.player.body_size().y / 2)
	world.drone.position = world.player.position - Vector2(0, 36)
	world.drone.mission = "follow"
	world.field_cargo.drone_available = true
	await frames()

func click(cell: Vector2i, button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = world.get_global_transform_with_canvas() * Grid.center(cell)
	event.button_index = button
	event.pressed = true
	return event

func volume() -> float:
	var result := 0.0
	for value in world.environment.water.values(): result += float(value)
	for b: Dictionary in world.outpost.buildings.structures:
		if b.id in ["pump", "water_tank", "greenhouse"]: result += float(world.outpost.industry.state(b).get("water", 0))
	for value in world.outpost.hydraulics.local_ship_water.values(): result += float(value)
	return result

func fits(node: Node, bounds: Rect2) -> bool:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and not bounds.grow(1).encloses(child.get_global_rect()):
			print("Overflow: ", child.get_path(), " rect=", child.get_global_rect(), " bounds=", bounds)
			return false
		if not fits(child, bounds): return false
	return true

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
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
	for kind: String in ["water", "oil", "acid", "gas"]: world.environment.get(kind).clear()
	Fixture.carve(world, Vector2i(-6, 5))
	world.environment.water[Vector2i(-6, 5)] = 1.0
	for x in range(-4, 3): Fixture.carve(world, Vector2i(x, 5))
	for y in range(1, 6): Fixture.carve(world, Vector2i(2, y))
	for x in range(2):
		for y in range(2): Fixture.carve(world, Vector2i(x, y))
	await stand(Vector2i(-4, 5))
	var outpost = world.outpost
	var cargo: Dictionary = world.field_cargo.snapshot()
	var terrain: Array = world.site.snapshot()
	outpost.hydraulic_ui.begin("valve")
	check(outpost.handle_input(click(Vector2i(-5, 5), MOUSE_BUTTON_LEFT)), "left click places blue valve on rock")
	outpost.hydraulic_ui.reset()
	var entry: Dictionary = outpost.hydraulics.at(Vector2i(-5, 5))
	check(not entry.is_empty() and entry.get("opened", false), "new valve is immediately ready without extra action")
	check(world.field_cargo.snapshot() == cargo and world.site.snapshot() == terrain, "valve uses no research, cargo or mining")
	if entry.is_empty():
		quit(1)
		return
	for x in range(-4, 3):
		var cell := Vector2i(x, 5)
		await stand(cell)
		check(outpost.place_conduit("water", cell), "free background pipe " + str(cell))
	for y in range(1, 5):
		await stand(Vector2i(2, y))
		check(outpost.place_conduit("water", Vector2i(2, y)), "elbow route " + str(y))
	for x in range(2):
		await stand(Vector2i(x, 1))
		check(outpost.place_conduit("water", Vector2i(x, 1)), "tank port route " + str(x))
	check(world.field_cargo.snapshot() == cargo, "entire water pipe route leaves cargo unchanged")
	outpost.hydraulics.advance(2, outpost, 0)
	check(is_equal_approx(float(world.environment.water[Vector2i(-6, 5)]), 1.0), "dangling pipe never spills or drains source")
	for y in range(3):
		for x in range(-4, 0): Fixture.carve(world, Vector2i(x, y))
	outpost.buildings.install("laboratory", Vector2i(-4, 0))
	world.guide_state.facts.lab_built = true
	var tank: Dictionary = outpost.buildings.install("water_tank", Vector2i(0, 0))
	world.field_cargo.drone = {"structural_component": 20, "electronic_component": 20}
	await stand(Vector2i(-2, 5))
	check(outpost.place("pump", Vector2i(-2, 5)), "one-cell inline pump uses normal assembly plan")
	var pump: Dictionary = outpost.buildings.structures.back()
	check(outpost.fund_site(pump), "pump pays its normal components")
	outpost.advance(4.1)
	check(pump.state == "active" and outpost.device_powered(pump), "lab powers completed inline pump")
	var before := volume()
	outpost.advance(1)
	check(float(outpost.industry.state(tank).water) > 0, "powered pump lifts real water into finite tank")
	check(absf(volume() - before) < 0.00001, "source, pump and tank conserve water")
	check(not world.site.material(Vector2i(-5, 5)).is_empty(), "flow leaves rock valve intact")
	await stand(Vector2i(-4, 5))
	check(outpost.handle_input(click(Vector2i(-5, 5), MOUSE_BUTTON_RIGHT)), "right click opens blue valve controls")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await frames()
		if DisplayServer.get_name() != "headless": check(fits(outpost.hydraulic_ui.window, outpost.hydraulic_ui.window.get_visible_rect()), "valve controls fit " + str(size))
		await picture("valve-" + str(size.y), outpost.hydraulic_ui.window)
	outpost.hydraulic_ui.window.hide()
	await stand(Vector2i(-2, 5))
	outpost.industry_ui.open_machine(pump)
	await frames()
	if DisplayServer.get_name() != "headless": check(fits(outpost.industry_ui.window, outpost.industry_ui.window.get_visible_rect()), "pump controls fit")
	check(outpost.industry_ui.pump_directions.size() == 4, "pump exposes four direction controls")
	outpost.industry_ui._set_pump_direction(Vector2i.LEFT)
	check(outpost.hydraulics.pump_direction(pump) == Vector2i.LEFT, "pump control reverses actual flow direction")
	outpost.industry_ui._set_pump_direction(Vector2i.RIGHT)
	await picture("pump", outpost.industry_ui.window)
	outpost.industry_ui.window.hide()
	check(outpost.hydraulics.at(Vector2i(-6, -3)).get("kind") == "ship", "left booster port is at (-6,-3)")
	check(outpost.hydraulics.at(Vector2i(5, -3)).get("kind") == "ship", "right booster port is at (5,-3)")
	outpost.hydraulics.local_ship_water.left = 12.5
	var saved: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(saved))), "real world v2 circuit and buffer save roundtrip")
	check(is_equal_approx(world.outpost.hydraulics.local_ship_water.left, 12.5), "sandbox ship tank survives reload")
	var bad: Dictionary = world.capture_state().duplicate(true)
	bad.hydraulics.valves[0].cell = [-5.5, 5]
	var unchanged := JSON.stringify(world.capture_state())
	check(not world.restore_state(bad) and JSON.stringify(world.capture_state()) == unchanged, "malformed hydraulic save leaves whole world unchanged")
	root.size = Vector2i(1280, 720)
	await picture("circuit-720")
	print("BLUE WATER CIRCUIT: %d failures" % failures)
	quit(1 if failures else 0)
