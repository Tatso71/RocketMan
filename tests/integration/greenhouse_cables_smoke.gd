extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var world: Node2D
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func cable(cell: Vector2i) -> void:
	if cell.y >= 0: Fixture.carve(world, cell)
	world.outpost.network.add("energy", cell)

func near(first: float, second: float) -> bool: return absf(first - second) < 0.00001

func run() -> void:
	world = load("res://scenes/prototype/robbie_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	for kind: String in ["water", "gas", "oil", "acid"]: world.environment.get(kind).clear()
	var outpost: Node2D = world.outpost
	check(outpost.has_method("greenhouse_ship_source"), "greenhouse resolves explicit ship and laboratory cable roots")
	if not outpost.has_method("greenhouse_ship_source"): quit(1); return
	var lab_origin := Vector2i(-12, 1)
	for x in range(-12, -8):
		for y in range(1, 4): Fixture.carve(world, Vector2i(x, y))
	var lab: Dictionary = outpost.buildings.install("laboratory", lab_origin)
	var origin := Vector2i(12, 12)
	for x in range(12, 20):
		for y in range(12, 15): Fixture.carve(world, Vector2i(x, y))
	var greenhouse: Dictionary = outpost.buildings.install("greenhouse", origin)
	var crop: Dictionary = outpost.industry.state(greenhouse)
	crop.crop = "potato"
	crop.water = 4.0
	check(outpost.industry.energy_available(greenhouse, outpost) == 0, "remote greenhouse has no magical power before wiring")
	world.player.position = Vector2(220, -40)
	world.field_cargo.drone = {"electronic_component": 2}
	for index in range(3): await physics_frame
	check(outpost.place_conduit("energy", Vector2i(5, -2)), "ship socket accepts paid aboveground cable through real placement API")
	check(world.field_cargo.drone.get("electronic_component", 0) == 1, "aboveground cable costs one real electronic component")
	for y in range(-1, 15): cable(Vector2i(5, y))
	for x in range(6, 13): cable(Vector2i(x, 14))
	check(outpost.greenhouse_ship_source(greenhouse).get("kind") == "ship", "long cardinal cable connects a greenhouse directly to the ship")
	world._set_ship_energy(30)
	outpost.advance(1)
	check(near(crop.elapsed, 1) and crop.water < 4 and near(world.ship_energy(), 29.94), "ship-powered remote growth consumes actual water and shared battery exactly once")
	check(near(outpost.power_report().groups.greenhouse, 0.02), "remote greenhouse demand appears in the ship energy meter")
	outpost.network.remove("energy", Vector2i(5, 6))
	outpost.advance(1)
	check(near(crop.elapsed, 1), "cutting a middle cable pauses paid crop without losing progress")
	cable(Vector2i(5, 6))
	world._set_ship_energy(0)
	outpost.advance(1)
	check(near(crop.elapsed, 1) and outpost.industry.status(greenhouse, outpost) == "Batteria della nave scarica", "connected but empty ship battery pauses growth and reports energy shortage")
	outpost.buildings.install("solar_panel", Vector2i(8, -1))
	outpost.advance(1)
	check(near(crop.elapsed, 2) and near(world.ship_energy(), 0.04), "solar generation recovers and powers the distant wired greenhouse from zero")
	var second: Dictionary = outpost.buildings.install("greenhouse", Vector2i(16, 12))
	var second_crop: Dictionary = outpost.industry.state(second)
	second_crop.crop = "potato"
	second_crop.water = 4.0
	for x in range(13, 17): cable(Vector2i(x, 14))
	world._set_ship_energy(30)
	outpost.advance(1)
	check(near(world.ship_energy(), 30.02) and near(second_crop.elapsed, 1), "two shared-battery greenhouses debit their own real growth without duplicate generation")
	world._set_ship_energy(60)
	outpost.advance(1)
	check(near(world.ship_energy(), 60), "full battery caps after solar and both wired crop debits")
	outpost.network.remove("energy", Vector2i(5, -2))
	check(outpost.greenhouse_ship_source(greenhouse).is_empty(), "cut ship socket disconnects the source despite remaining cable branches")
	cable(Vector2i(-12, 3))
	for y in range(3, 6): cable(Vector2i(-13, y))
	for x in range(-12, 6): cable(Vector2i(x, 5))
	var source: Dictionary = outpost.greenhouse_ship_source(greenhouse)
	check(source.get("kind") == "laboratory" and source.get("lab") == lab, "remote laboratory socket supplies the long cable without a greenhouse distance limit")
	lab.enabled = false
	check(outpost.greenhouse_ship_source(greenhouse).is_empty(), "disabled field laboratory is not an electrical relay")
	lab.enabled = true
	lab.damaged = true
	check(outpost.greenhouse_ship_source(greenhouse).is_empty(), "damaged field laboratory is not an electrical relay")
	lab.damaged = false
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	var restored_world: bool = world.restore_state(saved)
	check(restored_world, "aboveground cable, ship/lab sources and remote crops survive real world save/load")
	if not restored_world: print("SAVE BLOCKER: ", world.status_label.text)
	var restored: Dictionary = outpost.buildings.structures.filter(func(item: Dictionary): return item.id == "greenhouse")[0]
	check(outpost.industry.energy_available(restored, outpost) > 0, "loaded cable network reconstructs actual greenhouse supply")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		cable(Vector2i(5, -2))
		for y in range(-3, 15): outpost.network.add("water", Vector2i(5, y))
		for x in range(6, 17): outpost.network.add("water", Vector2i(x, 14))
		outpost.buildings.install("pump", Vector2i(5, 8))
		outpost.hydraulics.local_ship_water.right = 20.0
		for item: Dictionary in outpost.buildings.structures:
			if item.id == "greenhouse": outpost.industry.state(item).water = 0.5
		outpost.advance(1)
		world.camera.position = Vector2(360, 280)
		world.camera.zoom = Vector2.ONE * 0.75
		world.ambient_time = 1.3
		for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = viewport_size
			world.camera.force_update_scroll()
			world._refresh_hud()
			world.queue_redraw()
			outpost.queue_redraw()
			for index in range(4): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/greenhouse-cables-world-%d.png" % viewport_size.y)
	print("GREENHOUSE CABLES: %d failures" % failures)
	quit(1 if failures else 0)
