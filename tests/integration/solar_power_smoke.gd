extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var world: Node2D
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func near(a: float, b: float) -> bool: return absf(a - b) < 0.00001

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
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
	check(outpost.has_method("solar_generation"), "outpost exposes actual solar generation")
	if not outpost.has_method("solar_generation"): quit(1); return
	check(outpost.recipe_visible("solar_panel"), "solar is available before the first field laboratory")
	world.player.position = Vector2(330, 0)
	for index in range(3): await physics_frame
	check(outpost.placement_blocker("solar_panel", Vector2i(8, -1)).is_empty(), "surface blueprint is reachable and valid outside the rocket")
	world.field_cargo.drone = {"structural_component": 2, "electronic_component": 1}
	check(outpost.place("solar_panel", Vector2i(8, -1)), "normal placement creates a paid solar project")
	var panel: Dictionary = outpost.buildings.structures.back()
	check(near(outpost.solar_generation(), 0), "unfunded blueprint generates no electricity")
	check(outpost.fund_site(panel), "ordinary component payment starts solar construction without a field lab")
	check(world.field_cargo.drone.get("structural_component", 0) == 0 and world.field_cargo.drone.get("electronic_component", 0) == 0, "solar construction consumes the required components")
	check(near(outpost.solar_generation(), 0), "unfinished solar panel generates no electricity")
	var before: float = world.ship_energy()
	outpost.advance(5)
	check(panel.state == "active" and world.ship_energy() < before, "solar assembly completes and costs real energy")
	check(near(outpost.solar_generation(), 0.1), "one completed panel produces six kWh per minute")
	world._set_ship_energy(0)
	outpost.advance(10)
	check(near(world.ship_energy(), 1), "sunlight recovers a completely empty battery without a powered lab")
	var second: Dictionary = outpost.buildings.install("solar_panel", Vector2i(-22, -1))
	outpost.advance(10)
	check(near(world.ship_energy(), 3), "multiple distant panels add generation without a ship radius restriction")
	var link: Dictionary = outpost.solar_connection(second)
	check(not link.is_empty() and link.powered, "distant surface panel has an automatic powered ship cable")
	var orthogonal := true
	for index in range(1, link.points.size()):
		var segment: Vector2 = link.points[index] - link.points[index - 1]
		orthogonal = orthogonal and (is_zero_approx(segment.x) or is_zero_approx(segment.y))
	check(orthogonal, "solar cable stays orthogonal")
	second.enabled = false
	panel.damaged = true
	check(near(outpost.solar_generation(), 0), "disabled and damaged panels do not generate")
	panel.damaged = false
	Fixture.carve(world, Vector2i(8, 0))
	check(near(outpost.solar_generation(), 0), "a panel with missing ground support stops generating")
	world.site.removed.erase(Vector2i(8, 0))
	second.enabled = true
	world._set_ship_energy(59.9)
	outpost.advance(10)
	check(near(world.ship_energy(), 60), "surplus cannot exceed the ship battery capacity")
	for x in range(8, 12):
		for y in range(1, 4): Fixture.carve(world, Vector2i(x, y))
	var lab: Dictionary = outpost.buildings.install("laboratory", Vector2i(8, 1))
	second.enabled = false
	world._set_ship_energy(60)
	outpost.advance(10)
	check(near(world.ship_energy(), 60), "simultaneous generation and laboratory consumption cap their net balance")
	world._set_ship_energy(0)
	outpost.advance(10)
	check(near(world.ship_energy(), 0.6) and outpost.operational(lab), "solar powers and recharges the laboratory from zero in the same tick")
	var report: Dictionary = outpost.power_report()
	check(near(report.generation, 0.1) and near(report.net, 0.06), "energy report includes generation, consumption and net surplus")
	for x in range(8, 12):
		for y in range(5, 8): Fixture.carve(world, Vector2i(x, y))
	var greenhouse: Dictionary = outpost.buildings.install("greenhouse", Vector2i(8, 5))
	var crop: Dictionary = outpost.industry.state(greenhouse)
	crop.crop = "potato"
	crop.water = 4.0
	world._set_ship_energy(60)
	report = outpost.power_report()
	check(near(report.network, 0.06) and near(report.net, 0.04) and near(report.groups.greenhouse, 0.02), "solar net balance includes the real ship-powered greenhouse load")
	outpost.advance(10)
	check(near(world.ship_energy(), 60) and near(crop.elapsed, 10), "full battery applies solar and growing greenhouse consumption before capping")
	greenhouse.enabled = false
	check(near(outpost.power_report().network, 0.04), "inactive greenhouse contributes no phantom battery load")
	greenhouse.enabled = true
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	var restored: bool = world.restore_state(saved)
	check(restored, "surface solar panels survive actual world save/load")
	if not restored: print("SAVE BLOCKER: ", world.status_label.text)
	check(near(outpost.solar_generation(), 0.1), "restored panels generate once without duplicated charge")
	world.player.position = Vector2(330, 0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = world.get_global_transform_with_canvas() * Grid.center(Vector2i(8, -1))
	outpost.handle_input(click)
	check(outpost.construction.activation_popup.visible, "right-click on a nearby panel opens its power switch")
	if outpost.construction.activation_popup.visible:
		outpost.construction.activation_popup.id_pressed.emit(2)
		outpost.construction.activation_popup.hide()
		check(near(outpost.solar_generation(), 0.0), "panel switch stops real generation")
		outpost.construction.activation_popup.id_pressed.emit(2)
	outpost.assembly.popup.hide()
	world.player.position = Vector2(50, -80)
	world.camera.position = Vector2(280, -120)
	world.camera.zoom = Vector2.ONE
	world.camera.force_update_scroll()
	world.outpost.energy_ui.refresh()
	world._refresh_hud()
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = viewport_size
			for index in range(4): await process_frame
			world.queue_redraw()
			outpost.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			var screen: Vector2 = world.get_global_transform_with_canvas() * Vector2(350, -30)
			var pixel := Vector2i(root.get_screen_transform() * screen)
			var color := capture.get_pixelv(pixel)
			check(color.b > color.r and color.b > 0.3, "native solar cells render as blue photovoltaic surfaces")
			check(root.get_visible_rect().encloses(outpost.energy_ui.panel.get_global_rect()), "solar energy panel stays inside the viewport")
			capture.save_png("res://reports/solar-%d.png" % viewport_size.y)
	outpost.buildings.install("laboratory", Vector2i(-4, 1))
	outpost.buildings.install("laboratory", Vector2i(0, 5))
	world._set_ship_energy(0)
	outpost.advance(1)
	report = outpost.power_report()
	check(near(world.ship_energy(), 0) and near(report.network, 0.1) and near(report.net, 0), "solar brownout reports actual consumed generation instead of fictitious recharge")
	world._refresh_hud()
	check("Saldo +0.0" in world.power_label.text, "HUD uses the same metered brownout balance")
	world.queue_free()
	await process_frame
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	world.set_hatch(true)
	world.local_store = {"iron": 4, "copper": 3, "crystal": 1}
	world.player.position = Vector2(330, 0)
	for index in range(3): await physics_frame
	check(world.outpost.place("solar_panel", Vector2i(8, -1)), "human can queue a solar blueprint before the tutorial laboratory")
	var automatic: Dictionary = world.outpost.buildings.structures.back()
	for index in range(1400):
		if automatic.state == "active": break
		world.outpost.advance_fabrication(1.0 / 60)
		world.drone._physics_process(1.0 / 60)
		world.outpost.advance(1.0 / 60)
		await physics_frame
	check(automatic.state == "active", "Robbie physically prepares, delivers and assembles the surface solar panel")
	check(world.local_store.get("iron", 0) == 0 and world.local_store.get("copper", 0) == 0 and world.local_store.get("crystal", 0) == 0, "automated solar production consumes real raw materials")
	print("SOLAR POWER: %d failures" % failures)
	quit(1 if failures else 0)
