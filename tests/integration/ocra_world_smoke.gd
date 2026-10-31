extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Field = preload("res://scripts/systems/environment_field.gd")
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

func picture(name: String) -> void:
	if not capture:
		return
	if is_instance_valid(world) and not world.is_queued_for_deletion():
		world._refresh_hud()
		world.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, name + " screenshot")

func _run() -> void:
	create_timer(75).timeout.connect(func(): push_error("Ocra world timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames()
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.guide.set_process(false)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	world.tutorial_ui.set_process(false)
	world.tutorial_ui.panel.hide()
	var pristine: Dictionary = world.capture_state()
	check(pristine.layout_version == 2 and pristine.hazards.oil.size() > 12 and pristine.hazards.acid.size() == 12, "fresh Ocra uses irregular reservoirs and finite acid/oil volumes")
	check(world.site.material(Vector2i(0, 0)) != "", "no predug hatch shaft")
	check(world.restore_state(JSON.parse_string(JSON.stringify(pristine))), "new terrain and all four fluids restore after JSON")
	var legacy := pristine.duplicate(true)
	legacy.erase("layout_version")
	legacy.removed = Site.new(0, 0).snapshot()
	legacy.hazards = Field.new(Site.new(0, 0)).snapshot()
	legacy.hazards.version = 1
	legacy.hazards.erase("oil")
	check(world.restore_state(legacy) and world.site.layout_version == 0 and world.environment.oil.is_empty(), "old saves retain old terrain without injecting new cavities or massifs")
	check(world.restore_state(pristine), "return to current layout without campaign writes")
	world.set_hatch(true)
	for y in range(10):
		for x in [-1, 0]:
			Fixture.carve(world, Vector2i(x, y))
	for y in range(7, 10):
		for x in range(-8, 0):
			Fixture.carve(world, Vector2i(x, y))
	world.player.position = Vector2(-300, 400)
	world.drone.position = Vector2(20, -140)
	world.drone.velocity = Vector2.ZERO
	world.drone.revision = -1
	world.drone.has_resting_goal = false
	await frames()
	world.environment.water[Vector2i(0, 6)] = 1.0
	check(not world.drone._route_clear(Vector2(20, 220), Vector2(20, 300)), "path lookahead cannot shortcut through water between dry endpoints")
	world.environment.water.erase(Vector2i(0, 6))
	var previous: Vector2 = world.drone.position
	var previous_step := Vector2.ZERO
	var reversals := 0
	var max_step := 0.0
	var in_open_cells := true
	for index in range(520):
		await physics_frame
		var point: Vector2 = world.drone.position
		var step := point - previous
		max_step = maxf(max_step, step.length())
		if step.length() > 0.4 and previous_step.length() > 0.4 and step.normalized().dot(previous_step.normalized()) < -0.5:
			reversals += 1
		in_open_cells = in_open_cells and world.drone._free(world.Grid.to_cell(point))
		previous_step = step
		previous = point
	check(world.drone.position.distance_to(world.player.position - Vector2(0, 32)) < 145, "Robbie reaches explorer through shaft and ninety-degree bend")
	check(in_open_cells and max_step <= 2.2 and reversals < 8, "movement stays in air with bounded per-frame travel and no replan oscillation")
	for index in range(240):
		if world.drone.velocity.length() < 0.5:
			break
		await physics_frame
	var resting: Vector2 = world.drone.position
	var previous_goal: Vector2 = world.drone.resting_goal
	world.player.facing = -world.player.facing
	await frames(120)
	print("DRONE REST: %s -> %s; goal %s -> %s" % [resting, world.drone.position, previous_goal, world.drone.resting_goal])
	check(world.drone.position.distance_to(resting) < 8, "turning in place does not make Robbie orbit or snap to another side")
	world.player.position = Vector2(-100, -80)
	await frames(550)
	check(world.drone.position.y < -80, "Robbie returns through the actual hatch without getting trapped")
	world.player.position = Vector2(900, 800)
	await frames(35)
	check(world.drone.signal_connected() and world.drone.status == "Limite segnale", "radio limit remains enforced")
	world.player.position = Vector2(140, 200)
	var before_alarm: Vector2 = world.drone.position
	await frames(10)
	check(world.drone.water_alarm and world.drone.position.distance_to(before_alarm) < 0.1, "Robbie stays out of water and flashes alarm")
	world.drone.set_physics_process(false)
	world.player.position = Vector2(20, 120)
	var shallow: float = world._illumination(world.player.position - Vector2(0, 32) + Vector2(80, 0))
	world.player.position = Vector2(20, 660)
	var deep: float = world._illumination(world.player.position - Vector2(0, 32) + Vector2(80, 0))
	check(shallow > 0.85 and deep < 0.15, "same two-metre distance becomes dark at depth, independent of digging reach")
	world.player.position = Vector2(-300, 400)
	world.drone.position = Vector2(-220, 300)
	world.drone.water_alarm = false
	world.drone.status = "Ti seguo"
	world.camera.position = Vector2(-120, 360)
	world.camera.zoom = Vector2.ONE
	world._refresh_hud()
	world.queue_redraw()
	await picture("ocra-tunnel-unlit-720p")
	world.field_cargo.backpack.clear()
	world.field_cargo.drone = {"stone": 6, "copper": 5, "soil": 1}
	world.player.position = Vector2(-260, 400)
	Fixture.support(world)
	check(Fixture.build(world, "laboratory", Vector2i(-6, 7)), "field laboratory can be built in a real dry supported gallery")
	check(Fixture.build(world, "lamp", Vector2i(-8, 9)), "lamp works from the first laboratory")
	world.outpost._refresh_light_sources()
	var lamp_point: Vector2 = world.Grid.center(Vector2i(-8, 9))
	world.player.position = Vector2(20, 40)
	var lamp: Dictionary = world.outpost.buildings.structures.back()
	var illuminated: float = world._illumination(lamp_point)
	lamp.enabled = false
	world.outpost._refresh_light_sources()
	var unlit: float = world._illumination(lamp_point)
	lamp.enabled = true
	world.outpost._refresh_light_sources()
	check(illuminated > 0.95 and illuminated > unlit + 0.05, "installed powered lamp lights a gallery after explorer leaves")
	world.queue_redraw()
	world.outpost.queue_redraw()
	await picture("ocra-tunnel-lit-720p")
	root.size = Vector2i(1920, 1080)
	await picture("ocra-tunnel-lit-1080p")
	var oil_cell := Vector2i(6, 17)
	world.player.position = world.Grid.to_world(oil_cell) + Vector2(20, 40)
	check(world.player_environment().oil and world.guide.context() == "oil_danger", "oil contact has distinct exposure and Robbie warning")
	check(not world.outpost.Buildings.environment_safe("pump", 0, 0, 1), "water pump cannot be deployed into petroleum as if it were water")
	for y in range(15, 18):
		for x in range(4, 6):
			Fixture.carve(world, Vector2i(x, y))
	world.player.position = Vector2(220, 720)
	world.camera.position = Vector2(240, 660)
	world.target_cell = Vector2i(5, 17)
	world.scanned[world.target_cell] = "bedrock"
	await picture("ocra-oil-pocket-1080p")
	world.guide_state.set_muted(false)
	world.guide.event("gas_leak")
	check(world.guide_state.active_id == "gas_leak", "a breached gas pocket raises a real Robbie event")
	world.guide_state.tick(50, "tools")
	world.guide.event("gas_leak")
	check(world.guide_state.active_id == "gas_leak", "opening a second pocket can warn again instead of remaining latched forever")
	world.queue_free()
	await frames()
	var lab: Control = load("res://scenes/labs/robbie_text_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	root.size = Vector2i(1280, 720)
	await frames()
	check(lab.entries.size() >= 42 and lab.filtered.size() == lab.entries.size(), "F6 dialogue lab lists all balloons, contextual variants and tutorial steps")
	lab.select_entry("ocra/laboratory_materials")
	lab.body_edit.text = "Robbie: una prova modificabile senza rifare il tutorial."
	lab._changed()
	check(lab.dirty and lab.preview_body.text == lab.body_edit.text and lab.entries[lab.selected].body == lab.body_edit.text, "editing immediately updates the balloon preview and marks unsaved changes")
	lab.reload_entries()
	check(not lab.dirty and lab.body_edit.text != "Robbie: una prova modificabile senza rifare il tutorial.", "reload restores catalog without changing real project text")
	lab.search.text = "petrolio"
	lab.search.text_changed.emit("petrolio")
	await frames()
	check(lab.filtered.has("oil_danger") and lab.filtered.has("oil_leak"), "dialogue search finds petroleum warnings")
	lab.select_entry("oil_danger")
	await picture("robbie-text-lab-720p")
	root.size = Vector2i(1920, 1080)
	await picture("robbie-text-lab-1080p")
	print("OCRA WORLD SMOKE: %d failures; drone reversals=%d, max step=%.3f" % [failures, reversals, max_step])
	quit(0 if failures == 0 else 1)
