extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0
var world: Node2D

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
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
	Fixture.workshop(world)
	world.local_store = {"iron": 16, "copper": 9, "crystal": 3}
	check(world.outpost.fabricate_components("electronic_component", 3), "start three electronic batches")
	check(world.local_store.copper == 0 and world.local_store.crystal == 0, "pay all batches once at order start")
	world.outpost.advance_fabrication(1.5)
	var saved: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(saved))), "partial production survives JSON/world restore")
	world.outpost.advance_fabrication(4.51)
	check(world.outpost.fabrication.jobs.is_empty() and world.local_store.electronic_component == 6, "produce exactly six components after six seconds")
	check(world.outpost.collect_fabrication_output() == 6 and world.field_cargo.drone.electronic_component == 6, "collect compact production with one action")
	world.outpost.advance_fabrication(20)
	check(world.field_cargo.drone.electronic_component == 6, "completed order cannot produce twice")
	world.field_cargo.drone = {"iron": 4}
	world.local_store = {"copper": 120}
	Fixture.support(world)
	check(world.outpost.fabricate_components("structural_component"), "order from accessible Robbie while depot full")
	world.outpost.advance_fabrication(2.1)
	check(world.outpost.fabrication.buffer_at(["ship"]).get("structural_component", 0) == 2, "full depot preserves output in bench buffer")
	check(world.outpost.collect_fabrication_output() == 2, "collect preserved output without duplication")
	world.field_cargo.drone.clear()
	world.local_store = {"iron": 4}
	world._set_ship_energy(20)
	check(world.outpost.fabricate_components("structural_component"), "start paid work before a power outage")
	world._set_ship_energy(0)
	world.outpost.advance_fabrication(10)
	check(world.outpost.fabrication.jobs[0].elapsed == 0 and world.local_store.iron == 0, "power loss preserves a paid job without free progress")
	world._set_ship_energy(20)
	world.outpost.advance_fabrication(2.1)
	check(world.local_store.structural_component == 2, "restored power finishes the paid order once")
	world.field_cargo.drone = {"copper": 19}
	world.local_store = {"structural_component": 8}
	check(world.outpost.collect_fabrication_output() == 4 and world.local_store.structural_component == 4 and world.field_cargo.used(world.field_cargo.drone) == 20, "partial pickup uses the last compact slot without losing the rest")
	check(world.outpost.collect_fabrication_output() == 0, "a full stack cannot overfill the cargo")
	world.field_cargo.drone.clear()
	world.local_store = {"structural_component": 3, "electronic_component": 3}
	world.gear.set_ammo(0)
	check(world.outpost.fabricate_components("bomb", 3), "order a batch of three bombs")
	world.outpost.advance_fabrication(6.1)
	check(world.gear.ammo() == 3 and world.outpost.fabrication.jobs.is_empty(), "bomb batch yields exactly three ammunition, not a room cube")
	var before: Dictionary = world.local_store.duplicate()
	check(not world.outpost.fabricate_components("bomb", 2) and world.local_store == before, "magazine capacity prevents unaffordable extra batch without charging")
	check(not world.outpost.fabricate_components("structural_component", 0), "zero batches cannot grant free components")
	world.outpost.fabrication.jobs.append({"id": "bomb", "level": 1, "station": ["ship"], "elapsed": 0.0, "seconds": 2.0, "batches": 2})
	world.outpost.advance_fabrication(3)
	check(world.gear.ammo() == 3 and world.outpost.fabrication.jobs.size() == 1, "paid bomb batch waits when the current magazine cannot fit every output")
	world.gear.set_ammo(2)
	world.outpost.advance_fabrication(3)
	check(world.gear.ammo() == 4 and world.outpost.fabrication.jobs.is_empty(), "waiting bomb batch resumes without losing paid ammunition")
	print("Component production smoke: %d failures" % failures)
	quit(1 if failures else 0)
