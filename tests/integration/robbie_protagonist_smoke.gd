extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const State = preload("res://scripts/systems/expedition_state.gd")
const Crew = preload("res://scripts/data/cryo_crew.gd")
var app: Node2D
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

func frames(count: int = 4) -> void:
	for index in range(count):
		await physics_frame

func picture(name: String, viewport: Viewport = null) -> Image:
	world._refresh_hud()
	world.queue_redraw()
	world.player.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	var pixels := target.get_texture().get_image()
	check(pixels.save_png("res://reports/" + name + ".png") == OK, name + " screenshot saved")
	return pixels

func _run() -> void:
	create_timer(70).timeout.connect(func(): push_error("Robbie protagonist timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	await frames()
	app.set_process(false)
	check(app.variant_buttons.size() == 2 and app.variant_buttons[0].text == "Umano" and app.variant_buttons[1].text == "Robbie" and app.variant_buttons[0].button_pressed, "initial menu explicitly offers human and Robbie with the human mode selected")
	app.variant_buttons[1].pressed.emit()
	check(app.model.variant == "robbie" and app.variant_buttons[1].button_pressed and not app.variant_buttons[0].button_pressed, "Robbie button selects the robot as an exclusive protagonist choice")
	app.variant_buttons[0].pressed.emit()
	check(app.model.variant == "explorer" and app.variant_buttons[0].button_pressed, "human button restores the original mode before starting")
	app.variant_buttons[1].pressed.emit()
	check(app.model.variant == "robbie" and app.arrive_immediately(), "selecting Robbie launches the real alternate expedition")
	world = app.world
	await frames()
	world.set_process(false)
	world.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.gear.set_process(false)
	world.guide.set_process(false)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	world.tutorial_ui.set_process(false)
	world.tutorial_ui.panel.hide()
	check(world.is_robbie() and not world.drone.visible and world.drone.collision_layer == 0 and world.drone.collision_mask == 0, "Robbie is the controlled actor with no second visible or collidable companion")
	check(not app.model.choose_variant("explorer"), "variant cannot change midway through a campaign")
	var start: Vector2 = world.player.position
	Input.action_press("move_right")
	await frames(12)
	Input.action_release("move_right")
	world.player.set_physics_process(false)
	check(world.player.position.x > start.x + 15, "the robot responds to normal movement controls")
	world.player.position = Vector2(100, -200)
	world._set_crew_energy(40)
	world._set_suit(55)
	world.rooms.open_bed()
	check(world.rooms.bed_window.visible and not world.rooms.rest_button.visible and world.rooms.status.text.contains("biomedicina") and world.rooms.status.text.contains("chimica") and world.rooms.status.text.contains("Gatto"), "middle floor opens the three cryosleep occupants and their roles instead of a human rest action")
	world.rooms.resting = true
	world.rooms._process(0.5)
	check(world.crew_energy() == 40 and world.suit_integrity() == 55, "cryopods cannot be used as Robbie's bed or wake up their occupants")
	world.rooms._close_bed()
	world._set_crew_energy(15)
	check(world.guide.context() == "robot_charge_low", "low robot charge requests laboratory maintenance rather than a human bed")
	world._set_crew_energy(40)
	world.return_home()
	var supply: float = world.ship_energy()
	world.gear.recharge(1)
	check(world.crew_energy() == 60 and world.suit_integrity() == 65 and is_equal_approx(supply - world.ship_energy(), 0.6), "powered ship laboratory recharges and repairs Robbie using the ship battery")
	world._set_ship_energy(0)
	world.gear.recharge(1)
	check(world.crew_energy() == 60 and world.suit_integrity() == 65, "an empty ship battery cannot grant free robot maintenance")
	world._set_ship_energy(40)
	Fixture.starter_tunnel(world)
	world.set_hatch(true)
	world.player.position = Vector2(20, 140)
	world.drone.position = Vector2(-900, 700)
	await frames()
	world.equip_tool(0)
	world.target_cell = Vector2i(1, 3)
	for hit in range(3):
		if world.site.material(world.target_cell).is_empty():
			break
		world.mine_timer = 0
		world._mine_target()
	check(world.site.material(world.target_cell).is_empty() and world.field_cargo.used(world.field_cargo.drone) == 1 and world.drone_can_collect(), "mined resources enter the protagonist's cargo without waiting for a companion")
	check(not world.drone.send_to_ship() and world.drone.mission == "follow", "Y never sends the controlled character away autonomously")
	world.return_home()
	world.outpost.selected_station = {"kind": "ship"}
	check(world.drone.send_to_ship() and world.field_cargo.used(world.field_cargo.drone) == 0 and world.ship_state.resources.soil == 1, "Y at a laboratory deposits the robot's actual cargo into its local storage")
	world._refresh_hud()
	check(world.hazard_label.text.contains("SCOCCA") and world.hazard_label.text.contains("CARICA ROBBIE"), "HUD identifies robot integrity and charge instead of a human suit")
	var saves: Node = root.get_node("SaveManager")
	saves.campaign_save_path = "res://reports/protagonist-campaign.json"
	check(saves.write_campaign_save(State.new().snapshot()) and app.save_campaign(), "both variants save to isolated report slots")
	check(saves.read_campaign_save().variant == "explorer" and saves.read_campaign_save("robbie").variant == "robbie", "saving Robbie does not overwrite the original campaign slot")
	check(app.load_campaign() and app.world.is_robbie(), "loading the campaign preserves the controlled robot and cryogenic crew")
	world = app.world
	await frames()
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.gear.set_process(false)
	world.guide.set_process(false)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	world.tutorial_ui.set_process(false)
	world.tutorial_ui.panel.hide()
	var incompatible: Dictionary = world.capture_state()
	incompatible.erase("variant")
	check(not world.restore_state(incompatible), "an explorer outpost cannot silently replace the robot variant")
	var lab = load("res://scenes/labs/robbie_text_lab.tscn").instantiate()
	root.add_child(lab)
	lab.select_entry("first_dig")
	var base: String = lab.entries.first_dig.body
	lab.variant_picker.select(1)
	lab.variant_picker.item_selected.emit(1)
	lab.body_edit.text = "Diagnostica di prova"
	lab._changed()
	check(lab.entries.first_dig.body == base and lab.entries.first_dig.robbie.body == "Diagnostica di prova", "text lab edits protagonist diagnostics without replacing explorer copy")
	root.remove_child(lab)
	lab.queue_free()
	if capture:
		world._note("Equipaggio in criosonno / Tutte le capsule stabili")
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			world.player.position = Vector2(100, -200)
			world.camera.position = Vector2(0, -275)
			world.camera.zoom = Vector2.ONE * 0.95
			world.drone.sync_controlled()
			await picture("robbie-ship-%dp" % size.y)
			world.camera.position = Vector2(0, -260)
			world.camera.zoom = Vector2.ONE * 1.45
			var pixels := await picture("robbie-cryo-%dp" % size.y)
			var transform: Transform2D = root.get_final_transform() * world.get_global_transform_with_canvas()
			for index in range(3):
				var rect := Crew.capsule(index)
				var color := pixels.get_pixelv(Vector2i(transform * (rect.position + Vector2(6, 40))))
				check(color.r + color.g + color.b > 1.2, "cryo capsule %d renders visibly at %dp" % [index + 1, size.y])
			world.rooms.open_bed()
			await picture("robbie-crew-status-%dp" % size.y, world.rooms.bed_window)
			world.rooms._close_bed()
		root.remove_child(app)
		app.queue_free()
		app = load("res://scenes/prototype/expedition.tscn").instantiate()
		root.add_child(app)
		current_scene = app
		app.set_process(false)
		app.variant_buttons[1].pressed.emit()
		app._refresh_interface()
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			await frames()
			await RenderingServer.frame_post_draw
			var pixels := root.get_texture().get_image()
			check(pixels.save_png("res://reports/robbie-variant-menu-%dp.png" % size.y) == OK, "variant selection menu screenshot saved")
			check(app.selection_controls.get_global_rect().end.y + 8 <= app.stats_label.get_global_rect().position.y, "variant selection and ship stats do not overlap at %dp" % size.y)
			check(app.variant_controls.get_global_rect().end.x < 980 and app.variant_buttons.all(func(button: Button): return button.size.x >= button.get_combined_minimum_size().x), "protagonist controls fit inside the header before the ship toolbar")
	var sandbox = load("res://scenes/prototype/robbie_home.tscn").instantiate()
	root.add_child(sandbox)
	check(sandbox.is_robbie() and not sandbox.drone.visible, "standalone F6 scene also starts the robot variant")
	root.remove_child(sandbox)
	sandbox.queue_free()
	print("ROBBIE PROTAGONIST SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
