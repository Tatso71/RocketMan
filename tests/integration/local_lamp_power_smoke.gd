extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var failures := 0
var world: Node2D

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func frames() -> void:
	for index in range(4): await physics_frame

func capture(name: String) -> void:
	world.queue_redraw()
	world.outpost.queue_redraw()
	world._refresh_hud()
	world.camera.force_update_scroll()
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, "capture " + name)

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await frames()
	freeze(world)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	world.environment.water.clear()
	world.environment.acid.clear()
	world.environment.oil.clear()
	var outpost: Node2D = world.outpost
	for y in range(8, 11):
		for x in range(-4, 0): Fixture.carve(world, Vector2i(x, y))
	for y in range(11, 14): Fixture.carve(world, Vector2i(0, y))
	for y in range(8): Fixture.carve(world, Vector2i(0, y))
	Fixture.carve(world, Vector2i(1, 13))
	Fixture.carve(world, Vector2i(1, 12))
	var lab: Dictionary = outpost.buildings.install("laboratory", Vector2i(-4, 8))
	check(outpost.has_method("laboratory_connection"), "field laboratory exposes its automatic ship cable")
	world.guide_state.facts.lab_built = true
	world.player.position = Vector2(20, 560)
	world.drone.position = Vector2(20, 500)
	world.field_cargo.drone = {"electronic_component": 2}
	world.field_cargo.drone_available = true
	await frames()
	check(outpost.operational(lab), "local lab is inside ship range and powered")
	check(outpost.place("lamp", Vector2i(0, 13)), "lamp plan fits a supported cell near the field lab")
	var lamp: Dictionary = outpost.buildings.structures.back()
	check(not outpost.safe_link(lamp), "reproduction lamp is beyond direct 15m ship reach")
	check(outpost.funding_blocker(lamp).is_empty(), "local lab permits funding even beyond direct ship reach")
	var funded: bool = outpost.fund_site(lamp)
	check(funded, "lamp consumes its one electronic component through local supply")
	if not funded:
		print("FUNDING BLOCKER: ", outpost.funding_blocker(lamp), " / local cargo: ", world.field_cargo.drone, " / assistance: ", world.drone_help_available())
		quit(1)
		return
	check(world.field_cargo.drone.electronic_component == 1, "automatic cable adds no hidden component surcharge")
	outpost.advance(outpost.Buildings.build_seconds("lamp") + 0.01)
	check(lamp.state == "active" and outpost.lamp_powered(lamp), "lamp unfolds and operates outside direct ship radius")
	check(outpost.consumption_for(lamp) > 0 and outpost.power_report(lab).groups.lamp > 0, "local lab report includes the lamp's real consumption")
	check(outpost.light_at(Grid.center(lamp.origin)) > 0.9, "lamp really illuminates its cell")
	check(outpost.has_method("lamp_connection"), "automatic lamp cable exposes its actual source")
	if not outpost.has_method("lamp_connection"):
		quit(1)
		return
	var ship_link: Dictionary = outpost.laboratory_connection(lab)
	check(ship_link.powered and ship_link.points[0] == Vector2(0, -80), "laboratory cable starts at the ship power outlet")
	var link: Dictionary = outpost.lamp_connection(lamp)
	check(link.lab == lab and link.powered and link.points.size() > 2, "automatic cable uses the actual supplying laboratory")
	var energy: float = world.ship_energy()
	world._set_ship_energy(0)
	check(not outpost.lamp_powered(lamp) and not outpost.lamp_connection(lamp).powered, "empty ship battery disables light and shows a dead cable")
	world._set_ship_energy(energy)
	lab.enabled = false
	check(not outpost.lamp_powered(lamp), "disabled local lab stops lamp power")
	lab.enabled = true
	check(outpost.lamp_powered(lamp), "restored local lab restores the lamp")
	world.player.position = Vector2(60, 560)
	world.drone.position = Vector2(20, 540)
	world.set_hatch(true, false)
	world.camera.position = Vector2(-30, 240)
	world.camera.zoom = Vector2.ONE * 0.8
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await capture("local-lamp-link-%dp" % size.y)
	check(outpost.place("lamp", Vector2i(1, 13)), "second pending lamp fits beside the first")
	var pending: Dictionary = outpost.buildings.structures.back()
	check(outpost.lamp_connection(pending).is_empty(), "unpaid plans do not receive a free automatic cable")
	var view: Node = outpost.assembly
	view.open_site(pending)
	await frames()
	check(view.get("blocker_label") != null, "project popup has a directly visible reason label")
	if view.get("blocker_label") == null:
		quit(1)
		return
	world.field_cargo.drone.clear()
	view.refresh()
	check(view.mount_button.disabled and view.blocker_label.visible and view.blocker_label.text.contains("Mancano"), "missing materials are explained directly in popup")
	world.field_cargo.drone.electronic_component = 1
	world.player.position = Vector2(900, 100)
	view.refresh()
	check(view.mount_button.disabled and view.blocker_label.text.contains("raggiungibile"), "live popup explains reach even with sufficient materials")
	world.player.position = Vector2(60, 560)
	world.drone.position = Vector2(20, 540)
	lab.enabled = false
	view.refresh()
	check(view.mount_button.disabled and view.rows[-1].affordable and not view.blocker_label.text.is_empty(), "unavailable lab is explained despite green ingredient count")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		view.popup.hide()
		root.size = size
		await frames()
		view.open_site(pending)
		await frames()
		check(view.popup.get_visible_rect().encloses(view.blocker_label.get_global_rect()), "reason fits the popup without horizontal overflow")
		await capture("local-lamp-blocker-%dp" % size.y)
	lab.enabled = true
	view.refresh()
	check(not view.mount_button.disabled and view.blocker_label.text == "Pronto al montaggio", "reason changes live when the blocker clears")
	view.popup.hide()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	check(world.restore_state(saved), "deep lamp and automatic connections survive a real JSON world restore")
	var restored: Dictionary = world.outpost.buildings.structures.filter(func(item: Dictionary): return item.id == "lamp" and item.state == "active")[0]
	check(world.outpost.lamp_powered(restored) and not world.outpost.lamp_connection(restored).is_empty(), "loaded lamp reconnects locally without rebuilding or repaying the cable")
	print("LOCAL LAMP POWER: %d failures" % failures)
	quit(1 if failures else 0)
