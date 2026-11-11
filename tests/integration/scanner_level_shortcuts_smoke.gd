extends SceneTree

var world: Node2D
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value: failures += 1

func press(key: Key, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	event.shift_pressed = shift
	world._unhandled_input(event)

func run() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	var base: Resource = world.Tools.find("scanner")
	var original_level: int = base.scanner_level
	world.equip_tool(0)
	press(KEY_PLUS)
	check(base.scanner_level == original_level, "shortcut does nothing outside scanner mode")
	world.equip_tool(1)
	press(KEY_PLUS)
	check(world.active_tool().scanner_level == 2, "plus raises the current scanner level")
	check(world.active_tool().effective_reach_metres() == 5.0, "plus actually increases detection radius")
	check(base.scanner_level == original_level, "debug shortcut does not mutate the shared tool catalog")
	press(KEY_KP_ADD)
	press(KEY_EQUAL, true)
	press(KEY_PLUS)
	check(world.active_tool().scanner_level == 4, "main keyboard and keypad clamp at level IV")
	check(world.metric_label.text.contains("IV") and world.tool_buttons[1].text.contains("IV"), "current level is visible in HUD and scanner slot")
	world.scanner_view.advance(1.8)
	check(world.scanner_view.pulses.size() > 0, "test contains an old active wave")
	press(KEY_KP_SUBTRACT)
	check(world.active_tool().scanner_level == 3 and world.scanner_view.pulses.is_empty() and world.scanner_view.revealed.is_empty(), "lowering level clears stale long-range waves and traces")
	for index in range(5): press(KEY_MINUS)
	check(world.active_tool().scanner_level == 1, "minus clamps at level I")
	world.outpost.cargo_window.show()
	press(KEY_PLUS)
	check(world.active_tool().scanner_level == 1, "open menus prevent scanner shortcuts")
	world.outpost.cargo_window.hide()
	world.equip_tool(0)
	press(KEY_PLUS)
	world.equip_tool(1)
	check(world.active_tool().scanner_level == 1, "non-scanner tools cannot modify the override")
	print("SCANNER LEVEL SHORTCUTS: %d failures" % failures)
	quit(1 if failures else 0)
