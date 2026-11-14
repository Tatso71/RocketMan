extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var world: Node2D
var ui: Node2D
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func key_p() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_P
	event.pressed = true
	return event

func button(cell: Vector2i, pressed := true, shift := false, code: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = world.get_global_transform_with_canvas() * Grid.center(cell)
	event.button_index = code
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and code == MOUSE_BUTTON_LEFT else 0
	event.pressed = pressed
	event.shift_pressed = shift
	return event

func motion(cell: Vector2i, shift := false) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = world.get_global_transform_with_canvas() * Grid.center(cell)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.shift_pressed = shift
	return event

func reset_pipes() -> void:
	ui.context_menu.hide()
	ui.menu.hide()
	ui.window.hide()
	if ui.tool_active(): ui.handle_input(button(Vector2i(-8, 3), true, false, MOUSE_BUTTON_RIGHT))
	for cell: Vector2i in world.outpost.network.cells.water.keys():
		world.outpost.network.remove("water", cell)
	ui.handle_input(key_p())

func capture_views() -> void:
	if DisplayServer.get_name() == "headless" or "--capture" not in OS.get_cmdline_user_args(): return
	reset_pipes()
	ui.handle_input(button(Vector2i(-10, 3)))
	ui.handle_input(motion(Vector2i(-6, 3)))
	ui.handle_input(button(Vector2i(-6, 3), false))
	world.camera.position = world.player_center() - Vector2(0, 80)
	world.camera.zoom = Vector2.ONE
	world.camera.force_update_scroll()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		root.content_scale_size = size
		for index in range(4): await process_frame
		for removing in [false, true]:
			var shift := InputEventKey.new()
			shift.keycode = KEY_SHIFT
			shift.physical_keycode = KEY_SHIFT
			shift.pressed = removing
			Input.parse_input_event(shift)
			var hover := motion(Vector2i(-9, 3), removing)
			hover.button_mask = 0
			Input.parse_input_event(hover)
			root.warp_mouse(hover.position)
			world.queue_redraw()
			ui.queue_redraw()
			ui.pipe_renderer.queue_redraw()
			for index in range(4): await process_frame
			ui.queue_redraw()
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var rect := Rect2i(world.get_global_transform_with_canvas() * Grid.to_world(Vector2i(-9, 3)), Vector2i(40, 40))
			var ink := Color("eabf7e") if removing else Color("55b8ff")
			var pixels := 0
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					if image.get_pixel(x, y).is_equal_approx(ink): pixels += 1
			check(pixels > 40, "native cursor preview has the correct placement/removal color at " + str(size))
			check(image.save_png("res://reports/mouse-pipe-%s-%d.png" % ["erase" if removing else "place", size.y]) == OK, "capture native mouse pipe preview")
	var release := InputEventKey.new()
	release.keycode = KEY_SHIFT
	release.physical_keycode = KEY_SHIFT
	Input.parse_input_event(release)

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	ui = world.outpost.industry_ui
	ui.set_process(false)
	for x in range(-11, -4):
		for y in range(1, 7): Fixture.carve(world, Vector2i(x, y))
	world.player.position = Grid.center(Vector2i(-8, 3)) + Vector2(0, world.player.body_size().y / 2)
	world.drone.position = Grid.center(Vector2i(-10, 1))
	for index in range(3): await physics_frame
	var cargo: Dictionary = world.field_cargo.snapshot()
	ui.handle_input(key_p())
	check(ui.mode == "water", "P selects the mouse pipe tool")
	check(world.outpost.network.cells.water.is_empty(), "P does not place anything at the actor's feet")
	reset_pipes()
	ui.handle_input(button(Vector2i(-10, 3)))
	check(world.outpost.network.cells.water.has(Vector2i(-10, 3)), "left click places at the cursor rather than the actor")
	ui.handle_input(motion(Vector2i(-6, 3)))
	for x in range(-10, -5):
		check(world.outpost.network.cells.water.has(Vector2i(x, 3)), "fast sparse mouse motion fills horizontal cell " + str(x))
	ui.handle_input(button(Vector2i(-6, 3), false))
	check(not ui.dragging, "left button release ends the stroke immediately")
	reset_pipes()
	ui.handle_input(button(Vector2i(-10, 2)))
	ui.handle_input(motion(Vector2i(-7, 5)))
	check(world.outpost.network.connected("water", Vector2i(-10, 2), Vector2i(-7, 5)), "diagonal dragging inserts cardinal elbows without gaps")
	ui.handle_input(button(Vector2i(-7, 5), false))
	reset_pipes()
	ui.handle_input(button(Vector2i(-10, 3)))
	ui.handle_input(button(Vector2i(-6, 3), false))
	check(world.outpost.network.connected("water", Vector2i(-10, 3), Vector2i(-6, 3)), "release captures the final segment even without a motion event")
	world.ladders[Vector2i(-8, 3)] = true
	ui.handle_input(button(Vector2i(-8, 3), true, true))
	ui.handle_input(button(Vector2i(-8, 3), false, true))
	check(not world.outpost.network.cells.water.has(Vector2i(-8, 3)) and world.ladders.has(Vector2i(-8, 3)), "Shift click removes only the targeted water pipe, preserving its ladder")
	world.outpost.network.add("water", Vector2i(-8, 3))
	ui.handle_input(button(Vector2i(-8, 3), true, true))
	ui.handle_input(button(Vector2i(-8, 3), false, false))
	check(not world.outpost.network.cells.water.has(Vector2i(-8, 3)), "releasing Shift before the mouse never recreates an erased pipe")
	ui.handle_input(button(Vector2i(-10, 3), true, true))
	ui.handle_input(motion(Vector2i(-6, 3), true))
	ui.handle_input(button(Vector2i(-6, 3), false, true))
	check(world.outpost.network.cells.water.is_empty(), "Shift drag removes every crossed water pipe without gaps")
	check(world.field_cargo.snapshot() == cargo, "all mouse placement and removal remains free")
	reset_pipes()
	var obstacle := Vector2i(-8, 4)
	# Keep the actor's ray away from the obstacle's exact top-left corner.
	world.player.position.x -= 4
	world.site.removed.erase(obstacle)
	world.blocks[obstacle] = world._body(Grid.rect(obstacle), world.terrain)
	for index in range(3): await physics_frame
	ui.handle_input(button(Vector2i(-10, 4)))
	ui.handle_input(motion(Vector2i(-6, 4)))
	check(world.outpost.network.cells.water.has(Vector2i(-9, 4)) and not world.outpost.network.cells.water.has(Vector2i(-7, 4)), "a blocked stroke stops at rock without disconnected pieces beyond it")
	check(not world.site.material(obstacle).is_empty(), "water painting never excavates the obstructing rock")
	ui.handle_input(motion(Vector2i(-9, 3)))
	ui.handle_input(motion(Vector2i(-7, 3)))
	ui.handle_input(motion(Vector2i(-6, 4)))
	check(world.outpost.network.connected("water", Vector2i(-10, 4), Vector2i(-6, 4)), "dragging around the obstacle continues from the last valid cell")
	ui.handle_input(button(Vector2i(-6, 4), false))
	reset_pipes()
	ui.handle_input(button(obstacle))
	ui.handle_input(motion(Vector2i(-6, 3)))
	ui.handle_input(button(Vector2i(-6, 3), false))
	check(world.outpost.network.cells.water.is_empty(), "an invalid initial click cancels the stroke instead of restarting beyond rock")
	Fixture.carve(world, obstacle)
	for index in range(3): await physics_frame
	reset_pipes()
	ui.handle_input(button(Vector2i(-10, 3)))
	world.controls_locked = true
	var paused: Dictionary = world.outpost.network.snapshot()
	ui.handle_input(motion(Vector2i(-6, 3)))
	check(not ui.dragging and world.outpost.network.snapshot() == paused, "blocked controls cancel drag without placing more pipes")
	world.controls_locked = false
	ui.handle_input(motion(Vector2i(-6, 3)))
	check(world.outpost.network.snapshot() == paused, "unblocking controls does not resume a stale stroke")
	reset_pipes()
	ui.handle_input(button(Vector2i(-10, 3)))
	ui.handle_input(button(Vector2i(-10, 3), true, false, MOUSE_BUTTON_RIGHT))
	var before: Dictionary = world.outpost.network.snapshot()
	ui.handle_input(motion(Vector2i(-6, 3)))
	check(ui.mode.is_empty() and not ui.dragging and world.outpost.network.snapshot() == before, "right click exits and cancels the pending stroke")
	# Right click must cancel the tool, not open an earlier repair/bomb handler.
	var bomb := {"cell": Vector2i(-6, 3), "number": 1}
	world.gear.bombs.append(bomb)
	world.gear._add_body(bomb)
	ui._choose_tool(0)
	world._unhandled_input(button(bomb.cell, true, false, MOUSE_BUTTON_RIGHT))
	check(ui.mode.is_empty() and not world.gear.repair_menu.visible, "right-click cancellation wins over bomb interaction")
	world.gear.repair_menu.hide()
	await capture_views()
	print("MOUSE PIPE STROKE: %d failures" % failures)
	quit(1 if failures else 0)
