extends SceneTree

var failures := 0

class CountingOutpost extends "res://scripts/prototype/outpost_controller.gd":
	var safety_checks := 0
	func environment_safe(building: Dictionary) -> bool:
		safety_checks += 1
		return super.environment_safe(building)

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func run() -> void:
	var world: Node2D = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.environment.water.clear()
	world.environment.gas.clear()
	world.environment.oil.clear()
	world.environment.acid.clear()
	var probe := CountingOutpost.new()
	probe.world = world
	var lab: Dictionary = probe.buildings.install("laboratory", Vector2i(-4, 8))
	for index in range(199):
		probe.buildings.install("lamp", Vector2i(-23 + index % 46, 12 + (index / 46) * 2))
	var total: float = probe.network_load()
	print("NETWORK LOAD SAFETY CHECKS: ", probe.safety_checks)
	check(total > 1 and probe.safety_checks < 1000, "network load shares one eligibility snapshot near the 200-structure limit")
	probe.safety_checks = 0
	probe._refresh_light_sources()
	print("LIGHT REFRESH SAFETY CHECKS: ", probe.safety_checks)
	check(probe.light_sources.size() == 200 and probe.safety_checks < 1000, "light refresh uses linear safety checks rather than rebuilding 199 network snapshots")
	probe.safety_checks = 0
	var reports: Dictionary = probe.power_reports()
	print("POWER REPORT SAFETY CHECKS: ", probe.safety_checks)
	check(is_equal_approx(reports.ship.load, total) and probe.safety_checks < 1000, "power reports share the same per-pass topology")
	lab.enabled = false
	check(not probe.lamp_powered(probe.buildings.structures.back()), "ending the batch does not hide same-frame source changes")
	lab.enabled = true
	world._set_ship_energy(1)
	probe.advance(1000)
	print("POST-ADVANCE ENERGY: %.20f / LIGHTS: %d" % [world.ship_energy(), probe.light_sources.size()])
	check(is_zero_approx(world.ship_energy()) and probe.light_sources.is_empty(), "battery exhaustion is reflected by the fresh post-advance light snapshot")
	check(probe.lamp_query_depth == 0 and probe.lamp_query_networks.is_empty(), "nested advance/load/light passes release all query snapshots")
	probe.free()
	print("LAMP RELAY BATCH: %d failures" % failures)
	quit(1 if failures else 0)
