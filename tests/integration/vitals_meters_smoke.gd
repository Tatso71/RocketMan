extends SceneTree

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
	for index in range(5): await physics_frame

func capture(viewport: Viewport, name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, "capture " + name)

func same_ink(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.03 and absf(a.g - b.g) < 0.03 and absf(a.b - b.b) < 0.03

func check_fill(viewport: Viewport, meters: Control) -> void:
	var image := viewport.get_texture().get_image()
	var scale_factor := Vector2(image.get_size()) / viewport.get_visible_rect().size
	for bar: ProgressBar in [meters.energy_bar, meters.suit_bar]:
		var rect := bar.get_global_rect()
		var color: Color = bar.get_theme_stylebox("fill").bg_color
		var early := Vector2i((rect.position + Vector2(rect.size.x * 0.06, rect.size.y * 0.5)) * scale_factor)
		var middle := Vector2i((rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5)) * scale_factor)
		var end := Vector2i((rect.position + Vector2(rect.size.x * 0.97, rect.size.y * 0.5)) * scale_factor)
		check(same_ink(image.get_pixelv(early), color), "native bar starts with its assigned color")
		check(same_ink(image.get_pixelv(middle), color) == (bar.value > 50), "native filled length matches actual percentage")
		check(not same_ink(image.get_pixelv(end), color), "partially filled bar retains visible empty track")

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await frames()
	freeze(world)
	check(world.get("vitals_meters") != null and world.rooms.get("vitals_meters") != null, "HUD and rest menu share personal vital meters")
	if world.get("vitals_meters") == null or world.rooms.get("vitals_meters") == null:
		quit(1)
		return
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	world.player.position = Vector2(-70, -200)
	world._set_crew_energy(13)
	world._set_suit(89)
	world._refresh_hud()
	var hud: Control = world.vitals_meters
	var bed: Control = world.rooms.vitals_meters
	check(hud.energy_bar.value == 13 and hud.suit_bar.value == 89, "HUD reads personal energy and suit, not ship battery")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await frames()
		check(hud.get_global_rect().end.y <= world.hazard_label.position.y, "meters leave hazard warnings unobstructed")
		check(world.power_label.get_global_rect().end.y < world.tutorial_ui.panel.position.y, "power and tutorial panels do not overlap")
		for meter: ProgressBar in [hud.energy_bar, hud.suit_bar]:
			check(meter.size.y <= 5, "HUD bars remain thin")
		await capture(root, "vitals-hud-%dp" % size.y)
		check_fill(root, hud)
		world.rooms.open_bed()
		await frames()
		check(bed.visible and bed.energy_bar.value == 13 and bed.suit_bar.value == 89, "rest menu shows the same current values")
		check(hud.energy_bar.get_theme_stylebox("fill").bg_color == bed.energy_bar.get_theme_stylebox("fill").bg_color and hud.suit_bar.get_theme_stylebox("fill").bg_color == bed.suit_bar.get_theme_stylebox("fill").bg_color, "energy and suit keep exactly the same colors at rest")
		check(world.rooms.bed_window.get_visible_rect().encloses(bed.get_global_rect()), "rest meters fit the popup")
		await capture(world.rooms.bed_window, "vitals-rest-%dp" % size.y)
		check_fill(world.rooms.bed_window, bed)
		world.rooms._close_bed()
	world.rooms.open_bed()
	world.rooms.resting = true
	world.rooms._process(1)
	world._refresh_hud()
	check(bed.energy_bar.value == 33 and bed.suit_bar.value == 100 and hud.energy_bar.value == 33 and hud.suit_bar.value == 100, "rest recovery refreshes both meters without changing healing rules")
	world.rooms._close_bed()
	world.queue_free()
	await process_frame
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	world.variant = "robbie"
	root.add_child(world)
	await frames()
	freeze(world)
	world.player.position = Vector2(-70, -200)
	hud = world.vitals_meters
	bed = world.rooms.vitals_meters
	world._refresh_hud()
	check(hud.energy_title.text == "Carica" and hud.suit_title.text == "Scocca", "controlled Robbie uses charge and hull labels")
	world.rooms.open_bed()
	check(not bed.visible and not world.rooms.rest_button.visible, "cryogenic capsules do not imply that Robbie can rest in a bed")
	print("VITALS METERS: %d failures" % failures)
	quit(1 if failures else 0)
