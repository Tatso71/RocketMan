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
	Fixture.starter_tunnel(world)
	world.ladders.erase(Vector2i(0, 1))
	world.player.position = Vector2(20, 80)
	world.field_cargo.drone.clear()
	var energy: float = world.ship_energy()
	check(world.place_ladder_at(Vector2i(0, 1)), "build a free ladder with empty cargo")
	check(world.remove_ladder_at(Vector2i(0, 1)), "remove the ladder for free")
	check(world.ship_energy() == energy and world.field_cargo.used(world.field_cargo.drone) == 0, "ladder cycle changes no cargo or battery")
	check(world.gear.has_method("observe_ground_contact"), "jetpack observes physical floor contacts")
	if world.gear.has_method("observe_ground_contact"):
		world.gear.set_charge(0)
		world.gear.observe_ground_contact(false, false, false)
		check(world.gear.charge() == 0, "no recharge in the air")
		world.gear.observe_ground_contact(true, false, false)
		check(world.gear.charge() == 100, "real landing instantly restores full jetpack")
		world.gear.set_charge(30)
		world.gear.observe_ground_contact(true, false, false)
		check(world.gear.charge() == 30, "held ground state cannot refill repeatedly during takeoff")
		world.gear.observe_ground_contact(false, false, false)
		world.gear.observe_ground_contact(true, false, true)
		check(world.gear.charge() == 30, "ladders do not refill jetpack")
		world.gear.observe_ground_contact(false, false, false)
		world.gear.observe_ground_contact(true, true, false)
		check(world.gear.charge() == 30, "water does not refill jetpack")
		check(world.ship_energy() == energy, "jetpack recharge does not use ship energy")
	print("Ground jetpack smoke: %d failures" % failures)
	quit(1 if failures else 0)
