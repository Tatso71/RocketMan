extends SceneTree

var failures := 0
var capture := false

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value:
		failures += 1

func frames() -> void:
	for index in range(5):
		await physics_frame

func picture(world, name: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var rect: Rect2 = world.guide.speech.rich_text.get_global_rect()
	var pixel_scale := Vector2(image.get_size()) / root.get_visible_rect().size
	rect = Rect2(rect.position * pixel_scale, rect.size * pixel_scale)
	var copper_pixels := 0
	for y in range(maxi(0, int(rect.position.y)), mini(image.get_height(), int(rect.end.y))):
		for x in range(maxi(0, int(rect.position.x)), mini(image.get_width(), int(rect.end.x))):
			var color := image.get_pixel(x, y)
			if color.r > 0.65 and color.r > color.g * 1.12 and color.g > color.b * 1.18:
				copper_pixels += 1
	check(copper_pixels > 25, "copper-colored inline icon pixels are visible")
	check(image.save_png("res://reports/material-speech-" + name + ".png") == OK, "capture " + name)

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	var world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await frames()
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide.set_process(false)
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await frames()
		for variant: String in ["explorer", "robbie"]:
			world.variant = variant
			world.guide_state.variant = variant
			for id: String in ["ocra/laboratory_materials", "ocra/laboratory_cube", "ocra/carry_laboratory", "ocra/deploy_laboratory"]:
				world.guide_state.offer(id, true)
				world.guide.current_id = ""
				world.guide.replay_text = ""
				world.guide.replay_id = ""
				world.guide.replay_title = ""
				world.guide._update_bubble()
				await frames()
				world.guide._update_bubble()
				var speech = world.guide.speech
				var rich: RichTextLabel = speech.rich_text
				var source: String = world.guide_state.message(id)[2]
				var rendered := rich.get_parsed_text()
				check(speech.text == source and world.guide.last_message_text == source, "plain source preserved: " + variant + " / " + id)
				check(rich.get_total_character_count() > source.length(), "inline icons added: " + id)
				check(rich.size.x <= 304 and rich.get_content_height() <= rich.size.y + 1, "wrapped material speech fits its content track")
				check(root.get_visible_rect().encloses(world.guide.bubble.get_global_rect()), "balloon fits " + str(viewport_size))
				if id == "ocra/laboratory_materials":
					await picture(world, variant + "-" + str(viewport_size.y))
				world.guide_state.variant = "robbie" if variant == "explorer" else "explorer"
				for repeat_index in range(3):
					world.guide.repeat_last()
				check(speech.text == source and world.guide.replay_text == source, "replay retains original plain source")
				check(rich.get_parsed_text() == rendered, "repeat does not duplicate inline icons")
				world.guide_state.variant = variant
	world.queue_free()
	await frames()
	print("MATERIAL SPEECH: %d failures" % failures)
	quit(1 if failures else 0)
