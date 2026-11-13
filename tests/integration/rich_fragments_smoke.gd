extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, text: String) -> void:
	print(("PASS: " if value else "FAIL: ") + text)
	if not value: failures += 1
func run() -> void:
	var world: Node2D = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.outpost.logistics.automatic = false
	world.drone.set_physics_process(false)
	world.player.set_physics_process(false)
	var cell := Vector2i(-3, 2)
	Fixture.carve(world, cell)
	world.gear.drops[cell] = "copper"
	world.gear.drop_amounts[cell] = 12
	world.gear._ensure_fragment_group(cell)
	check(world.gear._fragment_group(cell).size() <= 3, "rich ore uses at most three physical bundles")
	world.drone.position = world.Grid.center(cell)
	world.drone.mission = "follow"
	world.field_cargo.drone = {"iron": 19}
	for body in world.gear._fragment_group(cell):
		body.position = world.drone.position
		body.velocity = Vector2.ZERO
		body.age = 1
	world.gear._advance_fragments(1.0 / 60)
	check(world.field_cargo.drone.get("copper", 0) == 1, "one free cargo unit collects exactly one unit from a rich bundle")
	check(world.gear.drop_amounts.get(cell, 0) == 11, "full cargo leaves all eleven residual units on the ground")
	var data: Dictionary = JSON.parse_string(JSON.stringify(world.gear.snapshot()))
	check(world.Gear.valid(data, world.site, world.outpost.buildings), "rich bundle snapshot remains valid after partial pickup")
	world.gear.restore(data, false)
	check(world.gear.drop_amounts.get(cell, 0) == 11 and world.gear._fragment_group(cell).size() <= 3, "rich quantity and bounded bodies survive JSON restore")
	world.field_cargo.drone.clear()
	for body in world.gear._fragment_group(cell):
		body.position = world.drone.position
		body.velocity = Vector2.ZERO
		body.age = 1
	world.gear._advance_fragments(1.0 / 60)
	check(world.field_cargo.drone.get("copper", 0) == 11 and not world.gear.drops.has(cell), "remaining bundles are collected once without loss or duplication")
	print("RICH FRAGMENTS: %d failures" % failures)
	quit(1 if failures else 0)
