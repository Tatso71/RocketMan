extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, text: String) -> void:
	if value:
		print("PASS: " + text)
	else:
		failures += 1
		push_error("FAIL: " + text)

func _run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	var world: Node2D = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(4):
		await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.guide_state.set_muted(true)
	Fixture.lab_room(world)
	world.player.position = Vector2(-100, 160)
	Fixture.support(world)
	check(world.outpost.place("laboratory", Vector2i(-5, 1)), "place unpaid supported laboratory plan")
	var site: Dictionary = world.outpost.buildings.structures.back()
	check(site.state == "planned" and not world.outpost.has_lab(), "plan is not a free operational laboratory")
	check(not world.outpost.fund_site(site), "empty cargo cannot assemble")
	world.local_store = {"structural_component": 4, "electronic_component": 2}
	check(not world.outpost.fund_site(site), "ship depot is never a remote assembly resource")
	world.field_cargo.drone = {"structural_component": 4, "electronic_component": 2}
	world.drone.mission = "deliver"
	world.field_cargo.drone_available = false
	check(not world.outpost.fund_site(site) and world.field_cargo.drone.structural_component == 4, "inaccessible Robbie cannot pay from afar")
	Fixture.support(world)
	world.site.removed[Vector2i(-5, 4)] = true
	check(not world.outpost.fund_site(site) and world.field_cargo.drone.structural_component == 4, "lost support prevents charging and assembly")
	world.site.removed.erase(Vector2i(-5, 4))
	world.environment.acid[Vector2i(-4, 2)] = 0.5
	check(not world.outpost.fund_site(site), "newly contaminated plan cannot assemble")
	world.environment.acid.clear()
	world.player.position = Vector2(-100, 31)
	check(world.outpost.placement_blocker("laboratory", site.origin, site).contains("Parete") and not world.outpost.fund_site(site), "real terrain wall blocks a reachable project's assembly ray")
	world.player.position = Vector2(-100, 160)
	Fixture.support(world)
	check(world.outpost.fund_site(site), "carried components fund assembly")
	check(world.field_cargo.used(world.field_cargo.drone) == 0 and site.state == "building", "one-time component payment begins construction")
	check(not world.outpost.fund_site(site), "cannot pay a building twice")
	world.outpost.advance(2.0)
	var saved: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(saved))), "partly assembled structure survives restore")
	world.outpost.advance(4)
	check(world.outpost.buildings.labs().size() == 1, "assembly completes and unlocks devices")
	check(not world.outpost.place("laboratory", Vector2i(-5, 1)), "overlapping structures remain forbidden")
	world.player.position = Vector2(-140, 160)
	Fixture.carve(world, Vector2i(-6, 2))
	check(world.outpost.place("lamp", Vector2i(-6, 2)), "plan a nearby unlocked device without paying")
	var pending: Dictionary = world.outpost.buildings.structures.back()
	var cargo_before: Dictionary = world.field_cargo.snapshot()
	world.player.position = Vector2(-160, 150)
	Fixture.carve(world, Vector2i(-7, 2))
	await physics_frame
	check(world.gear.place_bomb(Vector2i(-7, 2)), "place a real bomb beside an unpaid project")
	if not world.gear.bombs.is_empty():
		world.gear._explode(world.gear.bombs.pop_front())
	check(not pending.get("damaged", false), "an unpaid outline is not a damageable installation")
	# Already-saved damaged outlines must still expose free cancellation.
	pending.damaged = true
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = world.get_global_transform_with_canvas() * world.outpost.buildings.world_rect(pending).get_center()
	world._unhandled_input(click)
	check(world.outpost.assembly.popup.visible and not world.gear.repair_menu.visible, "right-click on an unpaid damaged project opens assembly, not paid repair")
	world.outpost.assembly.popup.hide()
	world.outpost.assembly._choose(1001)
	check(not world.outpost.buildings.structures.has(pending), "unpaid project can be cancelled through its actual menu")
	check(world.field_cargo.snapshot() == cargo_before, "plan cancellation creates no free components")
	print("Component assembly smoke: %d failures" % failures)
	quit(1 if failures else 0)
