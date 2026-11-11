extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func measure(label: String, action: Callable) -> void:
	for index in range(8): action.call(1.0 / 60)
	var start := Time.get_ticks_usec()
	for index in range(120): action.call(1.0 / 60)
	print("CPU %s: %.3f ms/call (120 calls, rendering excluded)" % [label, (Time.get_ticks_usec() - start) / 120000.0])

func run() -> void:
	var world: Node2D = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	for index in range(4): await physics_frame
	freeze(world)
	world.guide_state.set_muted(true)
	world.return_home()
	measure("world frame/HUD", world._process)
	measure("inventory UI", func(_delta: float): world.outpost.cargo_ui.refresh())
	measure("tutorial UI", func(_delta: float): world.tutorial_ui.refresh())
	measure("environment", world.environment.advance)
	measure("outpost", world.outpost.advance)
	measure("gear/no loose ore", world.gear.advance)
	measure("drone navigation", world.drone._physics_process)
	quit()
