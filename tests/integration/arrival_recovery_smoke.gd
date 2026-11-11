extends SceneTree

var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func campaign() -> Node2D:
	var result: Node2D = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(result)
	result.set_process(false)
	return result

func run() -> void:
	var app := campaign()
	check(app.arrive_immediately(), "valid initial arrival succeeds")
	var bad: Dictionary = app.world.capture_state()
	if [-1, 1] not in bad.removed: bad.removed.append([-1, 1])
	bad.gear = {"drops": [{"cell": [-1, 1], "material": "copper", "position": [-99999, 0], "velocity": [0, 0]}]}
	var payload: Dictionary = app.model.snapshot()
	payload.phase = app.State.Phase.SELECT
	payload.outposts.ochre = bad
	var state: RefCounted = app.State.new()
	var before: Dictionary = state.snapshot()
	check(not state.restore(JSON.parse_string(JSON.stringify(payload))), "inactive outpost with invalid fragment geometry is rejected on campaign load")
	check(state.snapshot() == before, "rejected campaign keeps its previous state unchanged")
	app.queue_free()
	await physics_frame
	for instant: bool in [true, false]:
		app = campaign()
		app.model.outposts.ochre = bad.duplicate(true)
		var ship_before: Dictionary = app.model.ship.snapshot()
		if instant:
			check(not app.arrive_immediately(), "failed instant arrival reports failure")
		else:
			check(app.depart(), "normal flight can start")
			app._process(10)
			app._process(10)
		check(app.model.phase == app.State.Phase.SELECT and app.screen.visible and not is_instance_valid(app.world), "failed arrival returns to a usable selection screen")
		check(app.model.ship.snapshot() == ship_before, "failed arrival rolls back travel costs and landing damage")
		check(not app.feedback.is_empty(), "failed arrival explains the invalid outpost")
		app.model.outposts.clear()
		check(app.arrive_immediately() and is_instance_valid(app.world), "correcting the outpost allows a fresh arrival")
		app.queue_free()
		await physics_frame
	print("ARRIVAL RECOVERY: %d failures" % failures)
	quit(1 if failures else 0)
