extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func run() -> void:
	var world: Node2D = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	for index in range(3): await physics_frame
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.drone.status = "Percorso ostruito"
	check(not world.guide_state.ocra.complete(), "path warning test runs during unfinished Ocra tutorial")
	check(world.guide.context() == "path_blocked", "an actual blocked path has priority over tutorial hints")
	world.drone.status = "Ti seguo"
	check(world.guide.context().begins_with("ocra/"), "tutorial resumes once the path is clear")
	world.variant = "robbie"
	world.drone.status = "Percorso ostruito"
	check(world.guide.context() != "path_blocked", "controlled Robbie has no companion path warning")
	print("MINING GUIDANCE: %d failures" % failures)
	quit(1 if failures else 0)
