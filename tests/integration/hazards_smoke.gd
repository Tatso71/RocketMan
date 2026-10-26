extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")

var world: Node2D
var failures := 0
var capture := false

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 3) -> void:
	for index in range(count):
		await physics_frame

func fresh_world() -> void:
	if is_instance_valid(world):
		root.remove_child(world)
		world.queue_free()
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	Fixture.workshop(world)
	Fixture.starter_tunnel(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.camera.zoom = Vector2.ONE * 1.2
	world.set_hatch(true)
	await frames()

func pulse(cell: Vector2i, slot: int = 0) -> void:
	world.equip_tool(slot)
	world.target_cell = cell
	world.mine_timer = 0
	world._mine_target()
	await frames()

func excavate(cell: Vector2i) -> void:
	for hit in range(4):
		if world.site.material(cell).is_empty():
			break
		await pulse(cell)
	check(world.site.material(cell).is_empty(), "seal cell %s excavates with material hardness" % cell)

func picture(name: String) -> void:
	if not capture:
		return
	world.beam_time = 0
	world._refresh_hud()
	world.queue_redraw()
	world.player.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if name.contains("indestructible"):
		var red_pixels := 0
		for y in range(0, image.get_height(), 3):
			for x in range(0, image.get_width(), 3):
				var pixel := image.get_pixel(x, y)
				if pixel.r > 0.9 and pixel.g < 0.55 and pixel.b < 0.55:
					red_pixels += 1
		check(red_pixels > 10, "indestructible target outline renders red")
	check(image.save_png("res://reports/" + name + ".png") == OK, name + " screenshot saved")

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1920, 1080)
	create_timer(45).timeout.connect(func(): push_error("Hazard smoke timeout"); quit(2))
	await fresh_world()
	world.player.position = Vector2(-170, 160)
	world.camera.position = Vector2(-210, 100)
	await pulse(Vector2i(-6, 3))
	await pulse(Vector2i(-6, 2))
	await pulse(Vector2i(-7, 2), 1)
	check(world.scanned.has(Vector2i(-7, 2)), "scanner marks gas-side wall before breach")
	check(world.status_label.text.contains("Gas"), "scanner gives explicit gas warning")
	check(world.environment.released.is_empty(), "scanning cannot release a pocket")
	await picture("hazards-gas-scan-1080p")
	await excavate(Vector2i(-7, 2))
	await excavate(Vector2i(-7, 3))
	check(world.environment.released.has("gas_west"), "breaking the seal releases gas once")
	world.player.position = Vector2(-260, 160)
	for index in range(12):
		world._physics_process(0.2)
	check(world.suit_integrity() < 100, "gas exposure degrades suit protection")
	check(world.environment.gas.has(Vector2i(-7, 2)), "gas visibly enters excavated cells")
	world.message_time = 0
	await picture("hazards-gas-breach-1080p")
	var saved: Dictionary = world.capture_state()
	var expected: Dictionary = world.environment.snapshot()
	world.environment.gas.clear()
	var restored: bool = world.restore_state(saved)
	if not restored:
		print("RESTORE BLOCKER: " + world.status_label.text)
	check(restored, "outpost restores breached pocket state")
	check(world.environment.snapshot() == expected, "loading does not refill or duplicate leaked gas")
	var before: Dictionary = world.capture_state()
	var broken: Dictionary = before.duplicate(true)
	broken.hazards.water.append([999, 999, 1.0])
	check(not world.restore_state(broken), "malformed fluid save is rejected")
	check(world.capture_state() == before, "invalid fluid save leaves world unchanged")
	world.player.position = Vector2(-180, 240)
	# Expose a face for the anchor target without invoking a construction feature.
	var floor_cell := Vector2i(-5, 5)
	world.site.removed[floor_cell] = true
	world.terrain.remove_child(world.blocks[floor_cell])
	world.blocks[floor_cell].queue_free()
	world.blocks.erase(floor_cell)
	await frames()
	var anchor := Vector2i(-5, 6)
	check(world.target_blocker(anchor).contains("Indistruttibile"), "anchor target has an explicit red-outline blocker")
	var resources: Dictionary = world.inventory.materials.duplicate()
	await pulse(anchor)
	check(world.site.material(anchor) == "anchor" and world.blocks.has(anchor), "anchor keeps terrain and collision intact")
	check(world.inventory.materials == resources, "indestructible target never credits resources")
	world.camera.position = Vector2(-180, 180)
	world.message_time = 0
	await picture("hazards-indestructible-1080p")
	await fresh_world()
	world.player.position = Vector2(20, 160)
	world.camera.position = Vector2(120, 130)
	await pulse(Vector2i(1, 3))
	await pulse(Vector2i(1, 2))
	await pulse(Vector2i(2, 3), 1)
	check(world.status_label.text.contains("Acqua"), "scanner recognizes sealed water beyond the wall")
	await excavate(Vector2i(2, 3))
	check(world.environment.released.has("water_east"), "water breach triggers an infiltration warning")
	world._physics_process(0.2)
	check(world.environment.water.has(Vector2i(2, 3)), "finite water flows into the new passage")
	world.player.position = Vector2(140, 200)
	var protection: float = world.suit_integrity()
	world._physics_process(0.2)
	check(world.player_environment().submerged, "head can become submerged in reservoir")
	check(world.suit_integrity() < protection, "submersion consumes suit protection")
	Input.action_press("climb_up")
	world.player._physics_process(1.0 / 60)
	Input.action_release("climb_up")
	check(world.player.velocity.y < 0, "up input lets the player swim out of water")
	world.message_time = 0
	await picture("hazards-water-1080p")
	world._set_suit(0)
	world._physics_process(0.2)
	check(world.player.position == Vector2(-60, -80), "failed suit triggers recoverable emergency return")
	check(world.suit_integrity() == 25, "emergency return restores minimum protection")
	world.player.position = Vector2(-60, -200)
	world.rooms.open_bed()
	world.rooms.resting = true
	world.rooms._process(0.2)
	check(world.suit_integrity() > 25, "resting in bedroom restores suit")
	print("HAZARDS SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
