extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
var campaign: Node2D
var world: Node2D
var failures := 0
var capture := false

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 5) -> void:
	for index in range(count):
		await physics_frame

func freeze() -> void:
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.guide_state.set_muted(true)

func total(field: Dictionary) -> float:
	var amount := 0.0
	for value in field.values():
		amount += float(value)
	return amount

func reload_world() -> void:
	check(campaign.save_campaign() and campaign.load_campaign(), "utility campaign JSON roundtrip")
	world = campaign.world
	freeze()
	await stand(world.player.position)

func stand(point: Vector2) -> void:
	world.player.position = point
	world.player.velocity = Vector2.ZERO
	world.player.climbing = false
	world.player.set_physics_process(true)
	await frames()
	world.player.set_physics_process(false)

func controls_fit(node: Node, bounds: Rect2) -> bool:
	if node is ScrollContainer:
		# Scroll content may be taller, but the viewport and horizontal minimum must fit.
		if not bounds.grow(1).encloses(node.get_global_rect()):
			return false
		for content in node.get_children():
			if content is Container and content.get_combined_minimum_size().x > node.size.x + 1:
				return false
		return true
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and not bounds.grow(1).encloses(child.get_global_rect()):
			print("Overflow: ", child.get_class(), " ", child.get_global_rect(), " / ", bounds)
			return false
		if not controls_fit(child, bounds):
			return false
	return true

func screenshot(name: String, viewport: Viewport = null) -> void:
	if not capture:
		return
	world._refresh_hud()
	world.outpost.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png("res://reports/utility-" + name + ".png") == OK, name + " screenshot")

func make_and_deploy(id: String, feet: Vector2) -> void:
	await stand(Vector2(-120, 160))
	world.camera.position = Vector2(-100, 25)
	world.camera.zoom = Vector2.ONE * 0.9
	world.outpost.selected_station = {"kind": "laboratory", "building": world.outpost.buildings.labs()[0]}
	await frames()
	var ui: Node = world.outpost.construction
	ui.open_picker(Vector2i.ZERO, Vector2(330, 160), true)
	check(ui.recipe_rows.has(id) and not ui.recipe_rows[id].button.disabled, id + " recipe is creatable at field bench")
	var before := {}
	for resource: String in world.outpost.recipe_definition(id).cost:
		before[resource] = world.outpost.fabrication_amount(resource)
	ui.recipe_rows[id].button.pressed.emit()
	check(world.outpost.fabrication.jobs.size() == 1 and world.outpost.fabrication.jobs[0].id == id, id + " button starts correct paid cube job")
	for resource: String in before:
		check(before[resource] - world.outpost.fabrication_amount(resource) == world.outpost.recipe_definition(id).cost[resource], id + " charges exactly one " + resource + " payment")
	var seconds: float = world.outpost.fabrication.jobs[0].seconds
	world.outpost.advance_fabrication(seconds * 0.5)
	ui.picker.hide()
	await screenshot(id + "-materializing-720p")
	await reload_world()
	world.camera.position = Vector2(-100, 25)
	world.camera.zoom = Vector2.ONE * 0.9
	check(world.outpost.fabrication.jobs[0].id == id and is_equal_approx(world.outpost.fabrication.jobs[0].elapsed, seconds * 0.5), id + " retains type and progress halfway through fabrication")
	world.outpost.advance_fabrication(seconds)
	check(world.outpost.fabrication.cubes.size() == 1 and world.outpost.fabrication.cubes[0].id == id, id + " materializes the correct physical cube")
	check(world.outpost.lab_cube_count() == 0, id + " is never mistaken for a laboratory cube")
	await screenshot(id + "-ready-cube-720p")
	check(world.outpost.use_cube() and world.outpost.fabrication.carried().id == id, id + " pickup uses the shared Space workflow")
	if id == "pump":
		world.outpost.use_cube()
		var bad: Dictionary = world.outpost.fabrication.cubes[0]
		check(not world.outpost.activate_cube(bad) and world.outpost.build_mode, "overlapping pump activation keeps cube with red footprint")
		check(world.outpost.use_cube() and world.outpost.fabrication.carried().id == "pump", "invalid pump cube can be recovered with Space")
	await stand(feet)
	world.outpost.use_cube()
	check(world.outpost.fabrication.carried_id == 0, id + " can be dropped before activation")
	var cube: Dictionary = world.outpost.fabrication.cubes[0]
	var cargo: Dictionary = world.field_cargo.snapshot()
	world.outpost.construction.open_cube(cube, Vector2(430, 230))
	check(world.outpost.construction.activation_popup.get_item_text(1).to_lower().contains(Buildings.NAMES[id].to_lower()), id + " activation popup names the right object")
	world.outpost.construction.activation_popup.id_pressed.emit(0)
	check(world.outpost.fabrication.cubes.is_empty() and world.outpost.buildings.structures.back().id == id, id + " activates into the correct structure without a free blueprint")
	check(world.field_cargo.snapshot() == cargo, id + " deployment never pays raw resources twice")
	var unfolding: Dictionary = world.outpost.buildings.structures.back()
	var duration: float = world.outpost.recipe_definition(id).deployment_seconds
	var gas_before := total(world.environment.gas)
	world.outpost.advance(duration * 0.5)
	check(unfolding.state == "building" and unfolding.progress > 0 and unfolding.progress < 1, id + " unfolds over time")
	await reload_world()
	check(world.outpost.buildings.structures.back().id == id and world.outpost.buildings.structures.back().state == "building", id + " half-unfolded structure survives save/load")
	world.outpost.advance(duration)
	check(world.outpost.buildings.structures.back().state == "active", id + " completes unfolding")
	if id == "fan":
		check(is_equal_approx(total(world.environment.gas), gas_before), "fan does not vent retroactively on completion frame")

func _run() -> void:
	create_timer(70).timeout.connect(func(): push_error("Utility cubes timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	campaign = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	campaign.set_process(false)
	root.get_node("SaveManager").campaign_save_path = "res://reports/utility-cubes-save.json"
	campaign.depart()
	campaign._process(10)
	campaign._process(10)
	world = campaign.world
	Fixture.workshop(world)
	await frames()
	freeze()
	world.field_cargo.drone = {"stone": 6, "copper": 4}
	world.inventory.materials = world.field_cargo.drone
	Fixture.support(world)
	world.outpost.selected_station = {"kind": "ship"}
	var ui: Node = world.outpost.construction
	ui.open_picker(Vector2i.ZERO, Vector2(330, 160), true)
	check(ui.recipe_rows.keys() == ["laboratory", "bomb"], "only laboratory and ammunition recipes are visible before the first laboratory")
	var cargo: Dictionary = world.field_cargo.snapshot()
	for id: String in Buildings.DEVICE_IDS:
		check(not world.outpost.fabricate_cube(id), id + " cannot be fabricated by bypassing the locked UI")
	check(world.field_cargo.snapshot() == cargo, "locked device requests never consume resources")
	ui.craft_button.pressed.emit()
	ui.picker.hide()
	world.outpost.advance_fabrication(6)
	check(world.outpost.use_cube(), "fabricate and pick up the first laboratory cube")
	Fixture.lab_room(world)
	world.set_hatch(true)
	world.player.position = Vector2(-100, 160)
	world.outpost.use_cube()
	check(world.outpost.activate_cube(world.outpost.fabrication.cubes[0]), "deploy actual first laboratory cube")
	check(not world.outpost.recipe_visible("fan"), "an unfinished first laboratory does not unlock devices")
	world.outpost.advance(6)
	check(world.outpost.has_lab() and world.outpost.recipe_visible("fan"), "only completed laboratory unlocks utility recipes")
	for y in range(2, 4):
		for x in [-8, -7, -6, 1, 2]:
			Fixture.carve(world, Vector2i(x, y))
	world.environment.water.clear()
	world.player.position = Vector2(-120, 160)
	Fixture.support(world)
	world.field_cargo.drone = {"soil": 1, "copper": 1}
	world.inventory.materials = world.field_cargo.drone
	world.outpost.selected_station = {"kind": "laboratory", "building": world.outpost.buildings.labs()[0]}
	ui.open_picker(Vector2i.ZERO, Vector2(330, 160), true)
	check(ui.recipe_rows.size() == 8 and not ui.recipe_rows.lamp.button.disabled and ui.recipe_rows.pump.button.disabled, "recipe rows independently reflect affordability after unlock")
	check(ui.recipe_rows.lamp.resources.copper.modulate == Color("a7e5b4") and ui.recipe_rows.pump.resources.stone.modulate == Color("ff7e85"), "per-device ingredient colors use nearby Robbie's cargo")
	await frames()
	if DisplayServer.get_name() != "headless":
		check(controls_fit(ui.picker, ui.picker.get_visible_rect()), "all four recipe rows fit at 720p")
	await screenshot("four-recipes-720p", ui.picker)
	ui.picker.hide()
	world.camera.position = Vector2(-100, 30)
	world.camera.zoom = Vector2.ONE * 0.9
	await make_and_deploy("lamp", Vector2(-220, 160))
	check(world.outpost.light_at(Vector2(-220, 140)) > 0.99, "new lamp illuminates its surroundings")
	world.outpost.buildings.labs()[0].stock = {"stone": 8, "copper": 10}
	await make_and_deploy("pump", Vector2(100, 160))
	await make_and_deploy("fan", Vector2(-260, 160))
	world.environment.water = {Vector2i(1, 3): 1.0, Vector2i(2, 3): 1.0}
	world.environment.gas = {Vector2i(-8, 2): 1.0, Vector2i(-8, 3): 1.0, Vector2i(-7, 3): 1.0}
	Fixture.carve(world, Vector2i(-6, 5))
	world.environment.gas[Vector2i(-6, 5)] = 0.5
	var water_before := total(world.environment.water)
	var gas_before := total(world.environment.gas)
	var load: float = world.outpost.network_load()
	check(is_equal_approx(load, 0.098), "lab and all three devices contribute to ship battery demand")
	var report: Dictionary = world.outpost.power_report(world.outpost.buildings.labs()[0])
	check(is_equal_approx(report.load, load) and report.counts.lamp == 1 and report.counts.pump == 1 and report.counts.fan == 1, "laboratory meter includes each attached utility exactly once")
	check(is_equal_approx(report.groups.lamp, 0.008) and is_equal_approx(report.groups.pump, 0.03) and is_equal_approx(report.groups.fan, 0.02), "meter segments expose actual per-device consumption")
	for y in range(5, 8):
		for x in range(1, 5):
			Fixture.carve(world, Vector2i(x, y))
	var second_lab: Dictionary = world.outpost.buildings.install("laboratory", Vector2i(1, 5))
	var first_report: Dictionary = world.outpost.power_report(world.outpost.buildings.labs()[0])
	var second_report: Dictionary = world.outpost.power_report(second_lab)
	check(first_report.counts.pump == 0 and second_report.counts.pump == 1, "overlapping laboratory ranges assign each powered device to its nearest supplier")
	check(is_equal_approx(float(first_report.load) + float(second_report.load), world.outpost.network_load()), "multiple lab meters never double-count shared network draw")
	second_lab.enabled = false
	check(is_equal_approx(world.outpost.power_report(world.outpost.buildings.labs()[0]).load, load), "meter follows a device supplied by another operational laboratory")
	world.outpost.buildings.structures.erase(second_lab)
	world.outpost.advance(1)
	check(is_equal_approx(water_before - total(world.environment.water), 0.7), "new cube-built pump removes finite water at declared rate")
	check(is_equal_approx(gas_before - total(world.environment.gas), 0.35), "new cube-built fan removes finite gas at declared rate")
	check(world.environment.gas[Vector2i(-6, 5)] == 0.5, "fan cannot pull gas through a solid floor")
	var lab: Dictionary = world.outpost.buildings.labs()[0]
	var fan: Dictionary = world.outpost.buildings.structures.filter(func(item: Dictionary): return item.id == "fan")[0]
	check(world.outpost.device_powered(fan), "fan remains powered inside the gas it is removing")
	world.outpost.construction.open_device(fan, Vector2(430, 230))
	world.outpost.construction.activation_popup.id_pressed.emit(2)
	gas_before = total(world.environment.gas)
	world.outpost.advance(1)
	check(not fan.enabled and is_equal_approx(gas_before, total(world.environment.gas)), "right-click power switch stops the fan and its effect")
	fan.enabled = true
	lab.enabled = false
	water_before = total(world.environment.water)
	gas_before = total(world.environment.gas)
	var energy: float = world.ship_energy()
	world.outpost.advance(5)
	check(world.ship_energy() == energy and is_equal_approx(water_before, total(world.environment.water)) and is_equal_approx(gas_before, total(world.environment.gas)), "disabled lab stops utilities, drainage and network consumption")
	check(world.outpost.light_at(Vector2(-220, 140)) == 0, "lamp loses illumination without lab power")
	lab.enabled = true
	world._set_ship_energy(0.007)
	water_before = total(world.environment.water)
	gas_before = total(world.environment.gas)
	world.outpost.advance(1)
	check(world.ship_energy() == 0, "utility network clamps consumption at zero battery")
	check(is_equal_approx(water_before - total(world.environment.water), 0.7 * 0.007 / load) and is_equal_approx(gas_before - total(world.environment.gas), 0.35 * 0.007 / load), "both environmental effects are bounded by actual powered runtime")
	world._set_ship_energy(30)
	world.player.position = Vector2(-120, 160)
	world.camera.position = Vector2(-100, 25)
	world.camera.zoom = Vector2.ONE * 0.9
	await reload_world()
	check(world.outpost.buildings.structures.filter(func(item: Dictionary): return item.id in Buildings.DEVICE_IDS).size() == 3, "all utility types persist as deployed structures")
	check(world.outpost.buildings.structures.any(func(item: Dictionary): return item.id == "fan" and item.drained > 0), "fan filtration statistics persist")
	world.camera.position = Vector2(-100, 25)
	world.camera.zoom = Vector2.ONE * 0.9
	world.outpost.energy_ui.refresh()
	check(is_equal_approx(world.outpost.energy_ui.battery.value, world.ship_energy()) and world.outpost.energy_ui.battery.max_value == 60, "laboratory charge bar reads the real shared ship battery")
	campaign.model.ship.modules.battery = 2
	world.outpost.energy_ui.refresh()
	check(world.outpost.energy_ui.battery.max_value == 100, "charge bar expands with the ship battery upgrade")
	campaign.model.ship.modules.battery = 1
	world.outpost.energy_ui.refresh()
	await frames()
	check(root.get_visible_rect().encloses(world.outpost.energy_ui.panel.get_global_rect()), "energy panel remains inside the 720p viewport")
	check(not world.outpost.energy_ui.panel.get_global_rect().intersects(world.outpost.cargo_ui.compact.get_global_rect()), "energy and cargo panels do not overlap")
	if DisplayServer.get_name() != "headless":
		check(controls_fit(world.outpost.energy_ui.panel, world.outpost.energy_ui.panel.get_global_rect()), "energy labels and bars fit their 720p panel")
	await screenshot("active-devices-720p")
	if capture and DisplayServer.get_name() != "headless":
		var rendered_fan: Dictionary = world.outpost.buildings.structures.filter(func(item: Dictionary): return item.id == "fan")[0]
		var rect: Rect2 = world.outpost.buildings.world_rect(rendered_fan)
		var transform: Transform2D = world.get_global_transform_with_canvas()
		var region := Rect2i(Vector2i(transform * rect.position), Vector2i((transform * rect.end) - (transform * rect.position)))
		var before: Image = root.get_texture().get_image().get_region(region)
		world.ambient_time += 0.12
		world.outpost.queue_redraw()
		await frames()
		await RenderingServer.frame_post_draw
		var after: Image = root.get_texture().get_image().get_region(region)
		var changed := 0
		for y in range(before.get_height()):
			for x in range(before.get_width()):
				if before.get_pixel(x, y) != after.get_pixel(x, y):
					changed += 1
		check(changed > 20, "powered fan rotor visibly animates in native rendering")
	root.size = Vector2i(1920, 1080)
	world.outpost.energy_ui.refresh()
	await frames()
	check(root.get_visible_rect().encloses(world.outpost.energy_ui.panel.get_global_rect()), "energy panel remains inside the 1080p viewport")
	await screenshot("active-devices-1080p")
	world.outpost.selected_station = {"kind": "laboratory", "building": world.outpost.buildings.labs()[0]}
	ui = world.outpost.construction
	ui.open_picker(Vector2i.ZERO, Vector2(330, 160), true)
	await frames()
	if DisplayServer.get_name() != "headless":
		check(controls_fit(ui.picker, ui.picker.get_visible_rect()), "all four recipe rows fit at 1080p")
	await screenshot("four-recipes-1080p", ui.picker)
	ui.picker.hide()
	Fixture.workshop(world)
	world.outpost.selected_station = {"kind": "ship"}
	campaign.model.ship.resources = {"soil": 1, "stone": 2, "copper": 4}
	check(world.outpost.fabricate_cube("lamp"), "ship laboratory also exposes unlocked utility recipes")
	world.outpost.advance_fabrication(5)
	world.outpost.use_cube()
	check(world.outpost.fabrication.carried().id == "lamp", "carry a lamp aboard for travel")
	check(world.outpost.fabricate_cube("fan"), "fabricate another type while carrying an earlier cube")
	world.outpost.advance_fabrication(5)
	world.player.position = Vector2(-60, -320)
	world.drone.position = Vector2(-140, -380)
	world.set_hatch(false)
	check(campaign.request_takeoff(), "utilities travel aboard under normal safety checks")
	check(campaign.model.ship.fabrication.carried().id == "lamp" and campaign.model.ship.fabrication.cubes.any(func(cube: Dictionary): return cube.id == "fan"), "ship factory retains both carried and ready utility types")
	check(campaign.save_campaign() and campaign.load_campaign(), "utility types survive an in-flight campaign save")
	campaign._process(10)
	campaign.model.choose("frost")
	campaign.depart()
	campaign._process(10)
	campaign._process(10)
	world = campaign.world
	freeze()
	check(world.outpost.fabrication.carried().id == "lamp" and world.outpost.fabrication.output_at(["ship"]).id == "fan", "landing imports utility types once without converting them into labs")
	print("UTILITY CUBES SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
