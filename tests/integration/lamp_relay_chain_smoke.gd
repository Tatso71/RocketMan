extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var failures := 0
var world: Node2D

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func frames() -> void:
	for index in range(4): await physics_frame

func stand(cell: Vector2i) -> void:
	world.player.position = Grid.center(cell) + Vector2(0, 20)
	world.drone.position = Grid.center(cell) + Vector2(-20, 0)
	world.field_cargo.drone_available = true
	await frames()

func build_light(cell: Vector2i) -> Dictionary:
	await stand(cell)
	world.field_cargo.drone = {"electronic_component": 1}
	check(world.outpost.place("lamp", cell), "chain plan accepted at %s" % cell)
	var lamp: Dictionary = world.outpost.buildings.structures.back()
	var paid: bool = world.outpost.fund_site(lamp)
	check(paid, "chain assembly consumes one carried electronic component")
	if paid:
		check(world.field_cargo.drone.electronic_component == 0, "relay cable does not add hidden recipe costs")
		world.outpost.advance(world.outpost.Buildings.build_seconds("lamp") + 0.01)
	check(lamp.state == "active" and world.outpost.lamp_powered(lamp), "paid chain light completes and powers up")
	return lamp

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await frames()
	freeze(world)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	world.environment.water.clear()
	world.environment.acid.clear()
	world.environment.oil.clear()
	world.environment.gas.clear()
	for y in range(8, 11):
		for x in range(-4, 0): Fixture.carve(world, Vector2i(x, y))
	# A two-metre-high supported tunnel, extending well outside the root's 8m radius.
	for x in range(0, 24):
		Fixture.carve(world, Vector2i(x, 9))
		Fixture.carve(world, Vector2i(x, 10))
	var outpost: Node2D = world.outpost
	var lab: Dictionary = outpost.buildings.install("laboratory", Vector2i(-4, 8))
	world.guide_state.facts.lab_built = true
	var first := await build_light(Vector2i(4, 10))
	var second := await build_light(Vector2i(11, 10))
	var third := await build_light(Vector2i(18, 10))
	if failures:
		print("CHAIN SETUP BLOCKER: ", outpost.placement_blocker("lamp", Vector2i(18, 10)))
		quit(1)
		return
	check(outpost.buildings.world_rect(lab).get_center().distance_to(Grid.center(second.origin)) > Grid.metres(8), "second light is beyond the laboratory's direct radius")
	check(outpost.lamp_connection(second).parent == first and outpost.lamp_connection(third).parent == second, "automatic cables follow actual lamp-to-lamp parents")
	check(outpost.supplying_lab(third) == lab and is_equal_approx(outpost.power_report(lab).groups.lamp, 0.024), "all three light consumptions belong to the original laboratory exactly once")
	outpost._refresh_light_sources()
	check(outpost.light_at(Grid.center(third.origin)) > 0.99, "deep chained light actually illuminates outside the lab radius")
	first.enabled = false
	check(not outpost.lamp_powered(second) and not outpost.lamp_powered(third), "switching off the first relay disconnects downstream lights")
	check(not outpost.lamp_connection(third).powered, "disconnected downstream cable is shown unpowered")
	first.enabled = true
	check(outpost.lamp_powered(third), "restoring the first relay restores the chain immediately")
	second.damaged = true
	check(not outpost.lamp_powered(third), "damaged relay cannot pass power")
	second.damaged = false
	lab.enabled = false
	check(not outpost.lamp_powered(first) and not outpost.lamp_powered(second) and not outpost.lamp_powered(third), "entire chain stops without an enabled source lab")
	lab.enabled = true
	world._set_ship_energy(0)
	check(not outpost.lamp_powered(third), "a cycle of nearby lamps cannot replace an exhausted source")
	world._set_ship_energy(50)
	check(outpost.lamp_powered(third), "recharging the real source restores power")
	Fixture.carve(world, Vector2i(11, 12))
	Fixture.carve(world, Vector2i(11, 13))
	var alternate: Dictionary = outpost.buildings.install("lamp", Vector2i(11, 13))
	second.enabled = false
	check(outpost.lamp_powered(third) and outpost.lamp_connection(third).parent == alternate, "an active alternate branch reconnects the downstream light")
	outpost.buildings.structures.erase(alternate)
	check(not outpost.lamp_powered(third), "removing the alternate path invalidates cached power immediately")
	second.enabled = true
	await stand(Vector2i(23, 10))
	world.field_cargo.drone = {"electronic_component": 1}
	check(outpost.place("lamp", Vector2i(23, 10)), "funding a downstream construction can use the active chain")
	var pending: Dictionary = outpost.buildings.structures.back()
	check(outpost.lamp_connection(pending).is_empty(), "unpaid plan does not act as a powered cable")
	second.enabled = false
	outpost.assembly.open_site(pending)
	await frames()
	check(outpost.assembly.mount_button.disabled and outpost.assembly.blocker_label.text.contains("luce alimentata"), "popup explains that the plan needs an energized upstream light")
	second.enabled = true
	outpost.assembly.refresh()
	check(not outpost.assembly.mount_button.disabled, "restoring the chain re-enables paid assembly in the open popup")
	outpost.assembly.popup.hide()
	check(outpost.fund_site(pending), "downstream construction uses the same paid recipe")
	second.enabled = false
	var progress: float = pending.progress
	outpost.advance(1)
	check(is_equal_approx(pending.progress, progress), "construction pauses when an intermediate relay loses power")
	second.enabled = true
	outpost.advance(3)
	check(pending.state == "active", "construction resumes when chain power returns")
	await stand(Vector2i(18, 10))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.capture_state()))
	check(world.restore_state(saved), "chain and automatic parents reconstruct from a real JSON restore")
	outpost = world.outpost
	var restored: Dictionary = outpost.buildings.structures.filter(func(item: Dictionary): return item.id == "lamp" and item.origin == Vector2i(18, 10))[0]
	check(outpost.lamp_powered(restored) and outpost.supplying_lab(restored) == outpost.buildings.labs()[0], "restored topology uses restored building dictionaries, not stale cached objects")
	world.camera.position = Vector2(360, 400)
	world.camera.zoom = Vector2.ONE * 0.8
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		world.camera.force_update_scroll()
		world.queue_redraw()
		world._refresh_hud()
		outpost._refresh_light_sources()
		outpost.queue_redraw()
		await frames()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://reports/lamp-relay-%dp.png" % size.y) == OK, "capture chain and red orthogonal cables at %dp" % size.y)
		check(outpost.lamp_query_depth == 0 and outpost.lamp_query_networks.is_empty(), "nested draw/report/cable passes release their snapshots")
	print("LAMP RELAY CHAIN: %d failures" % failures)
	quit(1 if failures else 0)
