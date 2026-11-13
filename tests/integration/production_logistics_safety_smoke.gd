extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Texts = preload("res://scripts/data/robbie_texts.gd")
var world: Node2D
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, text: String) -> void:
	print(("PASS: " if value else "FAIL: ") + text)
	if not value: failures += 1
func tick(count: int) -> void:
	for index in range(count):
		world.drone._physics_process(1.0 / 60)
		world.outpost.advance(1.0 / 60)
		await physics_frame

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
	world.environment.oil.clear()
	world.environment.acid.clear()
	Fixture.lab_room(world)
	world.set_hatch(true)
	await physics_frame
	await physics_frame
	world.drone._rebuild()
	world.player.position = Vector2(20, 160)
	world.drone.position = world.drone.UNLOAD_POINT
	world.field_cargo.drone = {"iron": 19}
	world.local_store = {"structural_component": 4, "electronic_component": 2}
	var lab: Dictionary = world.outpost.buildings.plan("laboratory", Vector2i(-5, 1))
	await tick(900)
	check(lab.state == "active" and world.local_store.get("iron", 0) == 19, "near-full worker unloads before collecting a two-slot construction load")
	lab.state = "active"
	lab.progress = 1.0
	world.field_cargo.drone.clear()
	world.local_store.clear()
	lab.stock = {"structural_component": 4, "electronic_component": 2}
	for x in range(-5, -1):
		for y in range(5, 8): Fixture.carve(world, Vector2i(x, y))
	for y in range(4, 8): Fixture.carve(world, Vector2i(-1, y))
	for x in range(-5, -1):
		for y in range(1, 4): world.environment.water[Vector2i(x, y)] = 1.0
	await physics_frame
	world.drone._rebuild()
	var pending: Dictionary = world.outpost.buildings.plan("laboratory", Vector2i(-5, 5))
	world.outpost.logistics.reset()
	world.drone.position = world.outpost.logistics._goal_for(lab)
	world.outpost.logistics.target = pending
	world.outpost.logistics.source_identity = ["laboratory", -5, 1]
	world.drone.mission = "loading"
	world.outpost.logistics.advance(1)
	check(world.field_cargo.drone.is_empty() and lab.stock.structural_component == 4, "snapping outside a flooded source never authorizes a remote pickup")
	world.environment.water.clear()
	world.drone.position = world.drone.UNLOAD_POINT
	var source := {"identity": ["laboratory", -5, 1], "stock": lab.stock, "point": world.outpost.logistics._goal_for(lab), "building": lab}
	check(not world.outpost.logistics._load(pending, source) and lab.stock.electronic_component == 2, "loading checks actual distance and line of sight to its laboratory")
	world.outpost.logistics.reset()
	Fixture.workshop(world)
	Fixture.support(world)
	world.outpost.construction.picker.hide()
	world.gear.set_workshop_damage(true)
	world.outpost.fabrication.jobs.append({"id": "structural_component", "station": ["ship"], "level": 1, "elapsed": 0.5, "seconds": 2.0, "batches": 1})
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = world.get_global_transform_with_canvas() * Vector2(-50, -140)
	world._unhandled_input(click)
	check(world.outpost.construction.picker.visible and not world.gear.repair_menu.visible, "actual right click on a damaged workshop opens the paused production computer")
	world.gear.repair_menu.hide()
	if not world.outpost.construction.picker.visible:
		world.outpost.open_station({"kind": "ship"}, Vector2(500, 300))
	world.local_store = {"structural_component": 3, "electronic_component": 1}
	world.outpost.construction.maintenance_button.pressed.emit()
	world.outpost.station_menu.activate(3)
	var workshop_row := {}
	for row: Dictionary in world.outpost.station_menu.rows:
		if row.key == "workshop": workshop_row = row
	check(not workshop_row.is_empty(), "workshop repair remains available through secondary maintenance")
	if not workshop_row.is_empty():
		workshop_row.button.pressed.emit()
		check(not world.gear.workshop_damaged() and world.local_store.structural_component == 0 and world.local_store.electronic_component == 0, "secondary workshop repair pays its existing component cost once")
	var delivery: String = Texts.message("drone_delivery")[2]
	check(delivery.contains("ordinat") and not delivery.contains("preparo i componenti"), "delivery guidance does not promise autonomous recipe selection")
	print("PRODUCTION LOGISTICS SAFETY: %d failures" % failures)
	quit(1 if failures else 0)
