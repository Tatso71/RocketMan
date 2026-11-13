extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	world.environment.water.clear()
	world.environment.gas.clear()
	Fixture.lab_room(world)
	world.set_hatch(true)
	await physics_frame
	await physics_frame
	world.drone._rebuild()
	world.drone.position = world.drone.UNLOAD_POINT
	world.drone.mission = "outbound"
	world.field_cargo.drone = {"iron": 8, "copper": 3, "crystal": 1}
	world.outpost.logistics.advance(1)
	check(world.outpost.fabrication.jobs.is_empty() and world.local_store.get("iron", 0) == 8, "unloading raw ore never chooses a production recipe")
	world.outpost.fabrication.jobs.clear()
	world.field_cargo.drone.clear()
	world.local_store = {"iron": 8, "copper": 3, "crystal": 1}
	Fixture.workshop(world)
	var energy: float = world.ship_energy()
	check(world.outpost.fabricate_components("structural_component"), "submit first structural order")
	check(world.outpost.fabricate_components("structural_component"), "queue second structural order while station is busy")
	check(world.outpost.fabricate_components("electronic_component"), "queue electronic order after structural orders")
	check(world.local_store.get("iron", 0) == 0 and world.local_store.get("copper", 0) == 0 and is_equal_approx(world.ship_energy(), energy - 0.03), "explicit orders reserve all ingredients and energy exactly once")
	var pending: Dictionary = world.outpost.buildings.plan("laboratory", Vector2i(-5, 1))
	var pending_status: String = world.outpost.logistics.project_status(pending)
	check(pending_status.contains("ordinati") and not pending_status.contains("Ordinali"), "project distinguishes paid queued semilavorati from ingredients still to order")
	world.outpost.buildings.structures.erase(pending)
	world.gear.set_workshop_damage(true)
	check(world.outpost.station_at(Vector2(-50, -140)).get("kind") == "ship" and world.outpost.open_station({"kind": "ship"}, Vector2(500, 300)), "damaged ship laboratory still exposes the computer and its pause reason")
	check(world.outpost.component_blocker("structural_component").contains("Ripara"), "damaged laboratory blocks new orders with an actual repair reason")
	world.outpost.construction.picker.hide()
	world.gear.set_workshop_damage(false)
	var before: Dictionary = world.local_store.duplicate()
	check(not world.outpost.fabricate_components("structural_component") and world.local_store == before, "unaffordable queued order leaves stock unchanged")
	world.outpost.advance_fabrication(1)
	check(world.outpost.fabrication.jobs.size() == 3 and world.outpost.fabrication.jobs[0].elapsed == 1.0 and world.outpost.fabrication.jobs[1].elapsed == 0.0, "only the head order advances per station")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	var reserved_energy: float = world.ship_energy()
	check(world.restore_state(saved), "world JSON round trip preserves the entire paid queue")
	check(is_equal_approx(world.ship_energy(), reserved_energy), "restoring queued work never charges again")
	world._set_ship_energy(0)
	world.outpost.advance_fabrication(10)
	check(not world.outpost.fabrication.jobs.is_empty() and world.outpost.fabrication.jobs[0].elapsed == 1.0, "power loss pauses the queue without discarding paid work")
	world._set_ship_energy(60)
	world.outpost.advance_fabrication(1.1)
	check(world.local_store.get("structural_component", 0) == 2 and world.outpost.fabrication.jobs.size() == 2 and world.outpost.fabrication.jobs[0].elapsed == 0.0, "finishing the head does not give its time slice to the next order")
	world.outpost.advance_fabrication(2.1)
	world.outpost.advance_fabrication(2.1)
	check(world.local_store.get("structural_component", 0) == 4 and world.local_store.get("electronic_component", 0) == 2 and world.outpost.fabrication.jobs.is_empty(), "three ordered batches produce exactly the first lab components")
	world.outpost.advance_fabrication(20)
	check(world.local_store.get("structural_component", 0) == 4, "a finished order never produces twice")
	world.local_store = {"iron": 4}
	check(world.outpost.fabricate_components("structural_component"), "ship accepts another paid order")
	var lab: Dictionary = world.outpost.buildings.install("laboratory", Vector2i(-5, 1))
	lab.stock = {"iron": 4}
	world.player.position = Vector2(-120, 160)
	world.outpost.selected_station = {"kind": "laboratory", "building": lab}
	check(world.outpost.fabricate_components("structural_component"), "a separate underground laboratory accepts an independent paid order")
	world.outpost.advance_fabrication(1)
	check(world.outpost.fabrication.jobs.size() == 2 and world.outpost.fabrication.jobs.all(func(job: Dictionary): return job.elapsed == 1.0), "independent laboratory heads advance concurrently")
	world.outpost.advance_fabrication(1.1)
	check(world.outpost.fabrication.jobs.is_empty() and lab.stock.get("structural_component", 0) == 2, "local ordered output stays in its actual laboratory stock")
	lab.stock = {"electronic_component": 1}
	world.local_store.clear()
	world.field_cargo.drone.clear()
	world.player.position = Vector2(20, 260)
	world.drone.position = world.drone.UNLOAD_POINT
	world.drone._rebuild()
	var light: Dictionary = world.outpost.buildings.plan("lamp", Vector2i(-1, 3))
	for index in range(900):
		world.drone._physics_process(1.0 / 60)
		world.outpost.advance(1.0 / 60)
		await physics_frame
	check(light.state == "active" and lab.stock.get("electronic_component", 0) == 0, "Robbie physically retrieves local laboratory output and builds without manual transfers")
	world.outpost.fabrication.jobs.clear()
	world.outpost.fabrication.outputs.clear()
	world.local_store = {"copper": 120}
	world.field_cargo.drone = {"iron": 4}
	Fixture.workshop(world)
	Fixture.support(world)
	world.outpost.fabrication.add_output(["ship"], "structural_component", 320)
	check(world.outpost.fabricate_components("structural_component"), "full output does not prevent reserving a later explicit order")
	world.outpost.advance_fabrication(3)
	check(world.outpost.fabrication.jobs.size() == 1 and world.outpost.fabrication.jobs[0].elapsed == 0.0 and world.outpost.fabrication.buffer_at(["ship"]).structural_component == 320, "full bench pauses paid work without overflow or lost output")
	check(world.outpost.fabrication.restore(JSON.parse_string(JSON.stringify(world.outpost.fabrication.snapshot()))), "full output and paused order remain valid save data")
	world.outpost.fabrication.buffer_at(["ship"]).structural_component -= 2
	world.outpost.advance_fabrication(3)
	check(world.outpost.fabrication.jobs.is_empty() and world.outpost.fabrication.buffer_at(["ship"]).structural_component == 320, "freeing output space resumes the paid order exactly once")
	print("PRODUCTION ORDERS: %d failures" % failures)
	quit(1 if failures else 0)
