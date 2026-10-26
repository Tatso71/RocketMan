extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var campaign: Node2D
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

func layout() -> void:
	var button: Button = campaign.instant_arrival_button
	check(root.get_visible_rect().encloses(button.get_global_rect()), "instant-arrival button stays inside viewport")
	check(button.get_global_rect().end.y < campaign.stats_label.get_global_rect().position.y, "instant-arrival button avoids ship statistics")
	check(not button.get_global_rect().intersects(campaign.depart_button.get_global_rect()), "normal and instant travel controls do not overlap")
	check(button.get_minimum_size().x <= button.size.x, "instant-arrival label fits its button")

func screenshot(name: String) -> void:
	if not capture:
		return
	campaign.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, name + " screenshot")

func _run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Instant arrival timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	campaign = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	campaign.set_process(false)
	root.get_node("SaveManager").campaign_save_path = "res://reports/instant-arrival-save.json"
	await frames()
	check(campaign.instant_arrival_button.visible and campaign.instant_arrival_button.text == "Arriva subito al pianeta", "initial menu contains requested immediate-arrival action")
	check(campaign.planet_list.item_count == 1, "fast travel does not unlock planets ahead of Ocra tutorial")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		campaign.model.ship.lab_research_unlocked = true
		campaign._refresh_interface()
		for index in range(3):
			campaign.select_planet(index)
			await frames()
			layout()
		await screenshot("instant-arrival-menu-%dp" % size.y)
	campaign.model.ship.lab_research_unlocked = false
	campaign.model.selected_planet = "ochre"
	campaign.model.ship.energy = 1
	campaign._refresh_interface()
	check(campaign.instant_arrival_button.disabled and campaign.depart_button.disabled, "both travel controls respect insufficient energy")
	var before: Dictionary = campaign.model.snapshot()
	campaign.instant_arrival_button.pressed.emit()
	check(campaign.model.snapshot() == before and not is_instance_valid(campaign.world), "disabled-route handler cannot consume resources or create a world")
	campaign.model.ship.energy = 60
	campaign._refresh_interface()
	campaign.instant_arrival_button.pressed.emit()
	check(campaign.model.phase == campaign.State.Phase.DIGGING and is_instance_valid(campaign.world), "button immediately opens playable planet without advancing cutscene timers")
	check(not campaign.exterior.visible and not campaign.screen.visible, "flight and vertical landing presentation never remain visible")
	var world: Node2D = campaign.world
	world.controls_locked = true
	check(world.planet_def.planet_id == "ochre" and absf(world.player.position.y + 320) < 2, "immediate arrival still starts the player in Ocra's cockpit")
	check(not world.site.material(Vector2i(0, 0)).is_empty(), "immediate arrival never injects pre-dug terrain")
	check(campaign.model.ship.fuel == 70 and campaign.model.ship.energy == 55 and campaign.model.ship.hull == 97, "immediate arrival applies normal fuel energy and landing wear exactly once")
	var fuel: float = campaign.model.ship.fuel
	check(not campaign.arrive_immediately() and campaign.model.ship.fuel == fuel, "repeated arrival cannot restart play or charge twice")
	check(campaign.save_campaign() and campaign.load_campaign(), "instant-arrival campaign saves and loads normally")
	check(campaign.model.phase == campaign.State.Phase.DIGGING and campaign.model.ship.fuel == fuel, "loading instant arrival does not replay or repay travel")
	world = campaign.world
	world.controls_locked = true
	var cell := Vector2i(0, 0)
	Fixture.carve(world, cell)
	world.field_cargo.collect("copper", 1)
	world.player.position = Vector2(-60, -320)
	world.drone.position = Vector2(-140, -380)
	world.set_hatch(false)
	check(campaign.request_takeoff(), "instant-arrival game retains normal takeoff safety checks")
	campaign._process(10)
	check(campaign.instant_arrival_button.visible, "instant-arrival action returns on later destination menus")
	campaign.instant_arrival_button.pressed.emit()
	check(campaign.model.phase == campaign.State.Phase.DIGGING and campaign.world.site.material(cell).is_empty(), "instant revisit restores the saved planetary terrain")
	check(campaign.world.field_cargo.available("copper", true) == 1, "instant revisit preserves carried cargo without duplication")
	await screenshot("instant-arrival-landed")
	print("INSTANT ARRIVAL SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
