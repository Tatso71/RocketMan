extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
var world: Node2D
var failures := 0
var capture := false
var growing_greenhouse: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value:
		failures += 1

func frames() -> void:
	for index in range(5):
		await process_frame

func stand(cell: Vector2i) -> void:
	world.player.position = Grid.center(cell) + Vector2(0, world.player.body_size().y / 2)
	world.drone.position = world.player.position - Vector2(0, 36)
	world.drone.mission = "follow"
	world.queue_redraw()
	world.outpost.queue_redraw()
	await frames()

func key(code: Key, shifted := false, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.shift_pressed = shifted
	event.echo = echo
	return event

func click(cell: Vector2i, button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = world.get_global_transform_with_canvas() * Grid.center(cell)
	event.button_index = button
	event.pressed = true
	return event

func fits(node: Node, bounds: Rect2) -> bool:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree():
			if not bounds.grow(1).encloses(child.get_global_rect()):
				print("Overflow: ", child, " / ", child.get_global_rect())
				return false
		if not fits(child, bounds):
			return false
	return true

func picture(name: String, viewport: Viewport = null) -> void:
	if not capture:
		return
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	var image := target.get_texture().get_image()
	if target == root:
		check(image.get_size() == root.size, "native raster dimensions " + name)
	var colors := {}
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			colors[image.get_pixel(x, y).to_rgba32()] = true
	check(colors.size() > 8, "nonblank rendered view " + name)
	check(image.save_png("res://reports/hydraulics-ui-" + name + ".png") == OK, "capture " + name)

func render_image() -> Image:
	await frames()
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func ladder_pixels(cell: Vector2i) -> void:
	if not capture:
		return
	var renderer: Node2D = world.outpost.industry_ui.pipe_renderer
	var ladders: Node2D = world.ladder_layer
	renderer.hide()
	ladders.hide()
	var background := await render_image()
	renderer.show()
	var pipes := await render_image()
	renderer.hide()
	ladders.show()
	var ladder := await render_image()
	renderer.show()
	var combined := await render_image()
	var center := Vector2i(world.get_global_transform_with_canvas() * Grid.center(cell))
	var crossings := 0
	var covered := 0
	for y in range(center.y - 18, center.y + 19):
		for x in range(center.x - 18, center.x + 19):
			if x < 0 or y < 0 or x >= background.get_width() or y >= background.get_height():
				continue
			if pipes.get_pixel(x, y) != background.get_pixel(x, y) and ladder.get_pixel(x, y) != background.get_pixel(x, y):
				crossings += 1
				if combined.get_pixel(x, y) == ladder.get_pixel(x, y):
					covered += 1
	check(crossings > 3 and covered == crossings, "ladder pixels cover the pipe at every overlapping crossing")

func advance_greenhouse() -> void:
	if not growing_greenhouse.is_empty():
		world.outpost.industry.advance(1.0 / 60.0, world.outpost, [growing_greenhouse])
		world.ambient_time += 1.0 / 60.0
		world.outpost._refresh_light_sources()
		world.queue_redraw()
		world.outpost.queue_redraw()

func pipe_pixels(cell: Vector2i) -> void:
	if not capture:
		return
	var renderer: Node2D = world.outpost.industry_ui.pipe_renderer
	renderer.hide()
	await frames()
	await RenderingServer.frame_post_draw
	var without := root.get_texture().get_image()
	renderer.show()
	await frames()
	await RenderingServer.frame_post_draw
	var with_pipes := root.get_texture().get_image()
	var center := Vector2i(world.get_global_transform_with_canvas() * Grid.center(cell))
	var changed := 0
	for y in range(center.y - 12, center.y + 13):
		for x in range(center.x - 12, center.x + 13):
			if x >= 0 and y >= 0 and x < without.get_width() and y < without.get_height():
				if without.get_pixel(x, y) != with_pipes.get_pixel(x, y):
					changed += 1
	check(changed > 12, "pipe pixels remain visible above opaque world background")

func blue_fixture_pixels(rock: Vector2i, source: Vector2i) -> void:
	if not capture:
		return
	var image := await render_image()
	for cell: Vector2i in [rock, source]:
		var center := Vector2i(world.get_global_transform_with_canvas() * Grid.center(cell))
		var blue := 0
		for y in range(center.y - 15, center.y + 16):
			for x in range(center.x - 15, center.x + 16):
				var color := image.get_pixel(x, y)
				if color.b > 0.35 and color.b > color.r * 1.3:
					blue += 1
		check(blue > 150, "illuminated blue valve / sealed water pocket has visible pixel coverage " + str(cell))

func distant_ship_port_pixels(rock: Vector2i) -> void:
	var valve_ui: Node2D = world.outpost.hydraulic_ui
	await stand(Vector2i(0, 20))
	check(not valve_ui._visible_cell(rock), "distant underground player does not reveal the rock valve")
	for entry: Dictionary in world.outpost.hydraulics.ship_ports():
		check(world._illumination(Grid.center(entry.cell)) <= 0.1, "ship port regression is outside the player's light " + str(entry.cell))
		check(valve_ui._visible_cell(entry.cell), "ambient-lit ship port remains visible at a distance " + str(entry.cell))
	if not capture:
		return
	valve_ui.hide()
	var background := await render_image()
	valve_ui.show()
	var devices := await render_image()
	for cell: Vector2i in [Vector2i(-6, -3), Vector2i(5, -3), rock]:
		var center := Vector2i(world.get_global_transform_with_canvas() * Grid.center(cell))
		var changed := 0
		var bright_blue := 0
		for y in range(center.y - 16, center.y + 17):
			for x in range(center.x - 16, center.x + 17):
				var color := devices.get_pixel(x, y)
				if color != background.get_pixel(x, y):
					changed += 1
					if color.b > 0.9 and color.b > color.r * 2:
						bright_blue += 1
		if cell == rock:
			check(changed == 0, "dark rock valve adds no visible pixels when the player is distant")
		else:
			check(changed > 500 and bright_blue > 300, "distant ship port renders full-brightness blue pixels " + str(cell))

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
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
	var outpost: Node2D = world.outpost
	var ui: Node2D = outpost.industry_ui
	var valve_ui: Node2D = outpost.hydraulic_ui
	world.environment.water.clear()
	world.environment.oil.clear()
	world.environment.acid.clear()
	world.environment.gas.clear()
	for y in range(1, 7):
		for x in range(-8, 5):
			Fixture.carve(world, Vector2i(x, y))
	var cell := Vector2i(-7, 3)
	world.ladders[cell] = true
	await stand(cell)
	var cargo: Dictionary = world.field_cargo.snapshot()
	check(outpost.handle_input(key(KEY_P)), "P is consumed by the conduit UI")
	check(ui.mode == "water" and not outpost.network.cells.water.has(cell), "P selects pipes without placing at the actor body cell")
	check(outpost.handle_input(key(KEY_P)) and not outpost.network.cells.water.has(cell), "repeated P keeps the pipe tool selected without placing anything")
	ui.handle_input(key(KEY_P, false, true))
	check(not outpost.network.cells.water.has(cell), "key echo does not place a pipe")
	check(outpost.handle_input(click(cell, MOUSE_BUTTON_LEFT)) and outpost.network.cells.water.has(cell), "mouse click places the free pipe over a ladder")
	check(world.ladders.has(cell) and cargo == world.field_cargo.snapshot(), "free mouse placement preserves ladder and cargo")
	var erase := click(cell, MOUSE_BUTTON_LEFT)
	erase.shift_pressed = true
	check(outpost.handle_input(erase) and not outpost.network.cells.water.has(cell), "Shift click removes only the targeted water pipe")
	check(world.ladders.has(cell), "Shift click does not remove the overlapping ladder")
	check(ui.pipe_renderer.get_parent() == ui and ui.pipe_renderer.z_index == 1 and ui.z_index == 0, "only the separate pipe renderer occupies z1")
	check(world.ladder_layer.z_index > ui.pipe_renderer.z_index and world.player.z_index > world.ladder_layer.z_index, "pipes render behind ladders and actors")
	check(outpost.handle_input(key(KEY_T)), "T opens the concise installation menu")
	check(not ui.menu.is_item_disabled(ui.menu.get_item_index(10)), "blue valve is selectable without a laboratory")
	var labels: Array[String] = []
	for index in range(ui.menu.item_count):
		labels.append(ui.menu.get_item_text(index))
	check(labels.slice(0, 5) == ["Valvola blu", "Tubo acqua (gratuito / P)", "Pompa", "Serra", "Contenitore acqua"], "five primary menu items match the new hydraulic workflow")
	check(not labels.any(func(label: String): return label.contains("Terminale") or label.contains("Perfora")), "obsolete outlet and drilling tools are absent")
	ui.menu.hide()
	var utilities: PopupMenu = ui.menu.get_node("Utilities")
	utilities.id_pressed.emit(1)
	check(ui.mode == "gas", "gas pipe remains available in the secondary menu")
	utilities.id_pressed.emit(2)
	check(ui.mode == "energy", "energy cable remains available in the secondary menu")
	utilities.id_pressed.emit(3)
	check(ui.mode == "remove", "secondary removal tool is preserved")
	for id: int in [12, 13, 14]:
		ui.menu.id_pressed.emit(id)
		check(outpost.build_mode and outpost.blueprint == ui.BUILD_TOOLS[id], "T selects normal construction blueprint " + str(id))
	outpost.build_mode = false
	ui.mode = ""
	# Keep the rock cell intact and put real water against its western face.
	var rock := Vector2i(-9, 3)
	var source := rock + Vector2i.LEFT
	Fixture.carve(world, source)
	world.environment.water[source] = 1.0
	await stand(Vector2i(-8, 3))
	ui.menu.id_pressed.emit(10)
	check(valve_ui.mode == "valve" and not outpost.build_mode, "blue valve enters the orientation-free placement tool")
	check(not valve_ui.handle_input(key(KEY_R)), "R is not an orientation command")
	check(outpost.handle_input(click(rock, MOUSE_BUTTON_LEFT)), "left click handles rock-mounted valve placement")
	var valve: Dictionary = outpost.hydraulics.at(rock)
	check(not valve.is_empty() and not world.site.material(rock).is_empty(), "blue valve overlays existing rock without excavation")
	if valve.is_empty():
		quit(1)
		return
	check(valve_ui._visible_cell(rock), "illuminated rock does not hide its valve")
	valve_ui.reset()
	check(outpost.handle_input(click(rock, MOUSE_BUTTON_RIGHT)) and valve_ui.window.visible, "right click opens rock valve status and open/close controls")
	valve_ui.opened_toggle.set_pressed(true)
	check(valve.opened, "valve opens directly without drilling")
	valve_ui.opened_toggle.set_pressed(false)
	check(not valve.opened, "valve closes directly")
	valve_ui.window.hide()
	outpost.network.add("water", Vector2i(-8, 3))
	outpost.network.add("water", Vector2i(-7, 3))
	outpost.network.add("water", Vector2i(-7, 2))
	check(ui.pipe_connections(Vector2i(-8, 3), "water").has(Vector2i.LEFT), "pipe autojoins the neighboring rock valve")
	check(ui.pipe_connections(Vector2i(-7, 3), "water").size() == 2, "perpendicular neighbors form an automatic elbow")
	outpost.network.add("water", Vector2i(-6, 3))
	outpost.network.add("water", Vector2i(-7, 4))
	check(ui.pipe_connections(Vector2i(-7, 3), "water").size() == 4, "all four adjacent pipes join automatically")
	ui.menu.id_pressed.emit(0)
	check(outpost.handle_input(click(Vector2i(-8, 2), MOUSE_BUTTON_LEFT)) and outpost.network.cells.water.has(Vector2i(-8, 2)), "optional mouse water placement remains available")
	ui.mode = ""
	ui.dragging = false
	for ship_cell: Vector2i in [Vector2i(-6, -3), Vector2i(5, -3)]:
		await stand(ship_cell + Vector2i.DOWN)
		check(not outpost.hydraulics.at(ship_cell).is_empty(), "ship blue port is returned by at " + str(ship_cell))
		check(outpost.handle_input(click(ship_cell, MOUSE_BUTTON_RIGHT)) and valve_ui.window.visible, "ship port opens on right click " + str(ship_cell))
		check(not valve_ui.remove_button.visible and valve_ui.remove_button.disabled and valve_ui.details.text.contains("40"), "permanent ship port reports finite capacity without dismantle control")
		valve_ui.opened_toggle.set_pressed(false)
		check(not outpost.hydraulics.at(ship_cell).opened, "permanent ship valve can close")
		valve_ui.opened_toggle.set_pressed(true)
		check(outpost.hydraulics.at(ship_cell).opened, "permanent ship valve can open")
		valve_ui.window.hide()
	var pump_cell := Vector2i(-4, 3)
	outpost.network.add("water", pump_cell)
	outpost.network.add("water", pump_cell + Vector2i.LEFT)
	outpost.network.add("water", pump_cell + Vector2i.RIGHT)
	var pump: Dictionary = outpost.buildings.install("pump", pump_cell)
	var tank: Dictionary = outpost.buildings.install("water_tank", Vector2i(-2, 3))
	var greenhouse: Dictionary = outpost.buildings.install("greenhouse", Vector2i(1, 3))
	var converter: Dictionary = outpost.buildings.install("gas_converter", Vector2i(1, 1))
	outpost.industry.state(tank).water = 16.0
	outpost.industry.state(greenhouse).water = 2.0
	await stand(pump_cell)
	check(outpost.handle_input(click(pump_cell, MOUSE_BUTTON_RIGHT)) and ui.window.visible, "right click opens the one-cell pump")
	check(ui.pump_directions.size() == 4, "pump offers four compact direction controls")
	for index in range(4):
		for offset: Vector2i in Network.OFFSETS:
			outpost.network.remove("water", pump_cell + offset)
		outpost.network.add("water", pump_cell + ui.DIRECTIONS[index])
		outpost.network.add("water", pump_cell - ui.DIRECTIONS[index])
		ui.pump_directions[index].pressed.emit()
		check(outpost.hydraulics.pump_direction(pump) == ui.DIRECTIONS[index], "pump control sets direction " + str(index))
	ui.pump_directions[0].pressed.emit()
	check(outpost.hydraulics.pump_direction(pump) == Vector2i.LEFT and not ui.feedback.text.is_empty(), "pump rejects a turn across its existing straight run")
	ui.enabled_toggle.set_pressed(false)
	check(not pump.enabled, "pump power toggle switches off")
	ui.enabled_toggle.set_pressed(true)
	check(pump.enabled, "pump power toggle switches on")
	var ports: Dictionary = outpost.hydraulics.pump_ports(pump)
	check(ports.input != pump_cell and ports.output != pump_cell, "pump indicators use external input and output cells")
	ui.window.hide()
	# Animate only the industry's actual water-consuming growth step.
	var storage: Dictionary = outpost.industry.state(greenhouse)
	storage.crop = "potato"
	storage.elapsed = 0.0
	check(not ui._irrigating(greenhouse), "idle watered greenhouse has no rain")
	outpost.industry.state(converter).energy = 8.0
	for port_cell: Vector2i in [Vector2i(2, 2), Vector2i(2, 3), Vector2i(1, 3), Vector2i(1, 4), Vector2i(1, 5)]:
		outpost.network.add("energy", port_cell)
	outpost.industry.advance(0.1, outpost, [greenhouse])
	check(ui._irrigating(greenhouse) and float(storage.water) < 2 and float(storage.elapsed) > 0, "actual water-consuming growth enables irrigation animation")
	storage.water = 0.0
	outpost.industry.advance(0.1, outpost, [greenhouse])
	check(not ui._irrigating(greenhouse), "rain stops when irrigation buffer is empty")
	storage.water = 2.0
	storage.elapsed = 20.0
	growing_greenhouse = greenhouse
	process_frame.connect(advance_greenhouse)
	world.camera.position = Vector2(0, 40)
	world.camera.zoom = Vector2.ONE
	world.camera.force_update_scroll()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		root.content_scale_size = size
		ui.open_tools()
		await frames()
		check(ui.menu.size.x <= 400 and ui.menu.size.y <= 350, "T menu stays compact at " + str(size))
		await picture("tools-" + str(size.y), ui.menu)
		ui.menu.hide()
		await stand(Vector2i(-8, 3))
		outpost.handle_input(click(rock, MOUSE_BUTTON_RIGHT))
		await frames()
		if DisplayServer.get_name() != "headless":
			check(fits(valve_ui.window, valve_ui.window.get_visible_rect()), "valve panel fits " + str(size))
		await picture("valve-" + str(size.y), valve_ui.window)
		valve_ui.window.hide()
		for building: Dictionary in [pump, tank, greenhouse]:
			await stand(building.origin)
			ui.open_machine(building)
			await frames()
			if DisplayServer.get_name() != "headless":
				check(ui.window.visible and fits(ui.window, ui.window.get_visible_rect()), str(building.id) + " controls fit " + str(size))
			if building.id == "water_tank":
				check(is_equal_approx(ui.progress.value, 50) and ui.reserves.text.contains("32"), "tank panel reports half of its finite 32-unit capacity")
			if building.id == "greenhouse":
				check(ui.reserves.text.contains("/ 4 u") and ui.reserves.text.contains("Porta acqua"), "greenhouse panel identifies local irrigation buffer and port")
			await picture(str(building.id) + "-" + str(size.y), ui.window)
			ui.window.hide()
		await stand(Vector2i(-8, 3))
		await pipe_pixels(Vector2i(-7, 2))
		await ladder_pixels(Vector2i(-7, 3))
		await blue_fixture_pixels(rock, source)
		check(ui._irrigating(greenhouse) and float(storage.water) < 2.0, "native world view shows rain driven by real irrigation consumption")
		await picture("world-" + str(size.y))
		await distant_ship_port_pixels(rock)
	process_frame.disconnect(advance_greenhouse)
	print("HYDRAULICS UI: %d failures" % failures)
	quit(1 if failures else 0)
