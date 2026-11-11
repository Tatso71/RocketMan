extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0
var world: Node2D

func picture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	world._refresh_hud()
	world.camera.force_update_scroll()
	world.queue_redraw()
	world.gear.queue_redraw()
	await physics_frame
	await physics_frame
	world.queue_redraw()
	world.player.queue_redraw()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, "native capture " + name)

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	Fixture.lab_room(world)
	world.player.position = Vector2(-100, 160)
	world.field_cargo.drone = {"copper": 20}
	world.gear.drops[Vector2i(-4, 1)] = "copper"
	check(world.gear.has_method("fragment_position"), "physical fragment interface exists")
	if not world.gear.has_method("fragment_position"):
		quit(1)
		return
	world.gear.advance(0.016)
	var start: Vector2 = world.gear.fragment_position(Vector2i(-4, 1))
	for i in range(100):
		await physics_frame
		world.gear.advance(1.0 / 60)
	var end: Vector2 = world.gear.fragment_position(Vector2i(-4, 1))
	world.camera.position = Vector2(-100, 80)
	await picture("magnetic-fragment-resting")
	check(end.y > start.y + 30 and end.y < 160, "ore falls and rests on the real floor")
	check(world.gear.fragments[Vector2i(-4, 1)].bounce_count > 0, "falling ore actually bounces on collision")
	var saved: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(saved))), "physical ore roundtrips through JSON")
	check(world.gear.fragment_position(Vector2i(-4, 1)).distance_to(end) < 1, "resting position is preserved")
	var above := saved.duplicate(true)
	above.gear.drops[0].position = [20, -40]
	check(world.Gear.valid(above.gear, world.site, world.outpost.buildings), "a fragment attracted through the open hatch does not invalidate saves")
	world.field_cargo.drone.clear()
	world.player.position = Vector2(20, -320)
	world.drone.position = end + Vector2(65, -10)
	world.drone.mission = "follow"
	for i in range(100):
		await physics_frame
		world.gear.advance(1.0 / 60)
		if i == 12:
			await picture("magnetic-fragment-attraction")
	check(world.field_cargo.drone.get("copper", 0) == 1 and world.gear.drops.is_empty(), "Robbie magnet collects nearby ore even when the human is far away")
	for i in range(10):
		world.gear.advance(1.0 / 60)
	check(world.field_cargo.drone.get("copper", 0) == 1, "magnetic pickup cannot duplicate ore")
	check(world.gear.magnet_range_metres() == 2.0, "base magnet has a two metre radius")
	var invalid := saved.duplicate(true)
	invalid.gear.drops[0].position = [99999, 99999]
	check(not world.restore_state(invalid), "invalid fragment positions are rejected")
	Fixture.carve(world, Vector2i(-6, 3))
	world.drone.position = Vector2(-224, 140)
	world.gear.drops[Vector2i(-8, 3)] = "copper"
	for i in range(90):
		await physics_frame
		world.gear.advance(1.0 / 60)
	check(world.gear.drops.has(Vector2i(-8, 3)) and world.field_cargo.drone.get("copper", 0) == 1, "magnet cannot collect through a solid rock wall")
	world.gear.drops.clear()
	world.gear.advance(1.0 / 60)
	world.player.position = Vector2(-180, 360)
	for y in range(9):
		Fixture.carve(world, Vector2i(0, y))
		if y >= 4:
			Fixture.carve(world, Vector2i(-5, y))
	for x in range(-5, 1):
		Fixture.carve(world, Vector2i(x, 4))
		Fixture.carve(world, Vector2i(x, 5))
	world.set_hatch(true)
	world.drone.position = Vector2(20, 20)
	world.drone.revision = -1
	world.drone.has_resting_goal = false
	await physics_frame
	for i in range(500):
		world.drone._physics_process(1.0 / 60)
		await physics_frame
	check(world.drone.position.distance_to(world.player.position - Vector2(0, 32)) < 120, "Robbie follows through a narrow shaft and two blind tunnel bends")
	print("MAGNETIC FRAGMENTS: %d failures" % failures)
	quit(1 if failures else 0)
