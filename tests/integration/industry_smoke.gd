extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const Industry = preload("res://scripts/systems/industry_state.gd")
const Catalog = preload("res://scripts/data/industry_catalog.gd")
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
	world.guide.set_process(false)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	world.tutorial_ui.set_process(false)
	world.tutorial_ui.panel.hide()

func stand(point: Vector2) -> void:
	world.player.position = point
	world.player.velocity = Vector2.ZERO
	world.player.climbing = false
	world.player.set_physics_process(true)
	await frames(6)
	world.player.set_physics_process(false)
	world.drone.position = world.player.position + Vector2(80, -70)
	Fixture.support(world)

func give(stock: Dictionary, clear: bool = true) -> void:
	Fixture.support(world)
	world.field_cargo.drone_available = true
	if clear:
		world.field_cargo.backpack.clear()
		world.field_cargo.drone.clear()
	for id: String in stock:
		check(world.field_cargo.collect(id, int(stock[id]), true), "fixture carries " + id)

func volume(field: Dictionary) -> float:
	var result := 0.0
	for amount in field.values():
		result += float(amount)
	return result

func machine(id: String) -> Dictionary:
	for building: Dictionary in world.outpost.buildings.structures:
		if building.id == id:
			return building
	return {}

func reload_world() -> void:
	check(campaign.save_campaign() and campaign.load_campaign(), "campaign persists pipes, seeds and paid machine jobs")
	world = campaign.world
	freeze()
	await frames(8)

func picture(name: String, viewport: Viewport = null) -> void:
	if not capture:
		return
	world._refresh_hud()
	world.queue_redraw()
	world.outpost.queue_redraw()
	world.outpost.industry_ui.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png("res://reports/industry-" + name + ".png") == OK, name + " screenshot")

func craft_deploy(id: String, origin: Vector2i, supply: bool = true) -> void:
	await stand(Vector2(-80, -80))
	world.outpost.selected_station = {"kind": "ship"}
	if supply:
		give(world.outpost.recipe_definition(id).cost)
	var ui: Node = world.outpost.construction
	ui.open_picker(Vector2i.ZERO, Vector2.ZERO, true)
	check(ui.recipe_rows.has(id) and not ui.recipe_rows[id].button.disabled, id + " has a working fabrication row")
	var before: Dictionary = world.field_cargo.snapshot()
	ui.recipe_rows[id].button.pressed.emit()
	check(world.outpost.fabrication.jobs.size() == 1 and world.outpost.fabrication.jobs[0].id == id, id + " begins paid bench fabrication")
	check(world.field_cargo.snapshot() != before, id + " ingredients paid at order time")
	world.outpost.advance_fabrication(2)
	await picture(id + "-fabricating", ui.picker)
	ui.picker.hide()
	await reload_world()
	world.outpost.advance_fabrication(20)
	check(world.outpost.fabrication.cubes.size() == 1 and world.outpost.fabrication.cubes[0].id == id, id + " ready physical cube retains type after reload")
	await stand(Vector2(-80, -80))
	check(world.outpost.use_cube() and world.outpost.fabrication.carried().id == id, id + " picked up with contextual Space")
	var size: Vector2i = world.outpost.buildings.size_for(id)
	var anchor := origin + Vector2i(size.x / 2, size.y - 1)
	await stand(Vector2(Grid.center(anchor).x, (anchor.y + 1) * 40))
	world.outpost.use_cube()
	check(world.outpost.fabrication.carried_id == 0, id + " physically dropped on floor")
	var cube: Dictionary = world.outpost.fabrication.cubes[0]
	check(world.outpost.cube_origin(cube) == origin and world.outpost.activate_cube(cube), id + " activated at the intended metric footprint")
	world.outpost.advance(1)
	check(machine(id).state == "building", id + " has a real unfolding phase")
	await reload_world()
	world.outpost.advance(8)
	check(machine(id).state == "active", id + " unfolds once after partial save/load")

func lay_line(kind: String, first: int, last: int) -> void:
	give({"copper": last - first + 1})
	for x in range(first, last + 1):
		world.player.position = Vector2(x * 40 + 20, 240)
		var reason: String = world.outpost.conduit_blocker(kind, Vector2i(x, 5))
		check(world.outpost.place_conduit(kind, Vector2i(x, 5)), "%s pipe at %d paid and placed instantly%s" % [kind, x, " / " + reason if not reason.is_empty() else ""])

func _run() -> void:
	create_timer(100).timeout.connect(func(): push_error("Industry smoke timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	campaign = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	campaign.set_process(false)
	root.get_node("SaveManager").campaign_save_path = "res://reports/industry-campaign-native.json" if capture else "res://reports/industry-campaign.json"
	campaign.arrive_immediately()
	world = campaign.world
	freeze()
	await frames()
	check(world.seeds().potato == 3 and world.seeds().ochre_tuber == 0, "only seed potatoes are available initially")
	check(not world.outpost.recipe_visible("furnace") and not world.outpost.recipe_visible("greenhouse"), "industrial cubes are locked until first lab")
	for y in range(3):
		for x in range(-4, 0):
			Fixture.carve(world, Vector2i(x, y))
	for y in range(6):
		Fixture.carve(world, Vector2i(0, y))
	for y in range(4, 6):
		for x in range(-12, 10):
			Fixture.carve(world, Vector2i(x, y))
	for x in range(1, 5):
		Fixture.carve(world, Vector2i(x, 3))
	world.environment.water.clear()
	world.environment.gas.clear()
	world.environment.oil.clear()
	await stand(Vector2(-100, 120))
	give({"stone": 6, "copper": 4})
	check(Fixture.build(world, "laboratory", Vector2i(-4, 0)), "first real lab unlocks the industrial branch")
	await craft_deploy("gas_converter", Vector2i(-7, 4))
	await craft_deploy("furnace", Vector2i(-4, 4))
	await craft_deploy("pump", Vector2i(-10, 4))
	await stand(Vector2(-100, 240))
	give({"copper": 4, "stone": 4})
	check(world.outpost.industry.start_smelting(machine("furnace"), "copper_ingot", world.outpost), "furnace reserves real ore for a paid order")
	world.outpost.advance(2)
	check(world.outpost.industry.state(machine("furnace")).elapsed == 0, "furnace cannot use the ship battery without a converter cable")
	await lay_line("energy", -6, 1)
	await lay_line("gas", -7, 7)
	var cargo_before: Dictionary = world.field_cargo.snapshot()
	check(not world.outpost.place_conduit("gas", Vector2i(7, 5)) and world.field_cargo.snapshot() == cargo_before, "duplicate pipe costs nothing")
	world.environment.gas = {Vector2i(6, 4): 1.0, Vector2i(7, 4): 1.0, Vector2i(6, 5): 1.0, Vector2i(7, 5): 1.0}
	var gas_before := volume(world.environment.gas)
	world.player.position = Vector2(-100, 240)
	world.outpost.advance(2)
	check(world.outpost.industry.state(machine("furnace")).elapsed > 1.9, "piped gas becomes local electrical energy and advances smelting")
	var converter_energy: float = world.outpost.industry.state(machine("gas_converter")).energy
	check(converter_energy >= 0 and world.outpost.industry.state(machine("gas_converter")).produced > converter_energy, "converter generation and furnace consumption are separate finite quantities")
	check(absf((gas_before - volume(world.environment.gas)) * 12 - world.outpost.industry.state(machine("gas_converter")).produced) < 0.001, "generated energy exactly matches consumed finite gas")
	world.player.position = Vector2(-180, 240)
	check(world.outpost.remove_conduit("energy", Vector2i(-5, 5)), "energy cable can be dismantled instantly")
	var elapsed: float = world.outpost.industry.state(machine("furnace")).elapsed
	world.outpost.advance(3)
	check(is_equal_approx(world.outpost.industry.state(machine("furnace")).elapsed, elapsed), "cut cable pauses paid work without losing progress")
	give({"copper": 1})
	check(world.outpost.place_conduit("energy", Vector2i(-5, 5)), "repairing the cable reconnects power")
	await reload_world()
	world.player.position = Vector2(-100, 240)
	world.drone.position = Vector2(-60, 160)
	world.outpost.advance(15)
	check(world.outpost.industry.state(machine("furnace")).output == "copper_ingot", "smelting resumes and produces an actual ingot")
	check(world.outpost.industry.collect(machine("furnace"), world.outpost), "smelted ingot enters physical cargo")
	give({"copper": 2, "stone": 4}, false)
	for recipe: String in ["copper_ingot", "glass", "glass"]:
		check(world.outpost.industry.start_smelting(machine("furnace"), recipe, world.outpost), recipe + " order starts")
		world.outpost.advance(15)
		check(world.outpost.industry.collect(machine("furnace"), world.outpost), recipe + " output collected")
	check(world.field_cargo.available("copper_ingot", true) == 2 and world.field_cargo.available("glass", true) == 2, "real smelting supplies greenhouse processed ingredients")
	give({"soil": 4, "stone": 4}, false)
	await craft_deploy("greenhouse", Vector2i(1, 3), false)
	await stand(Vector2(140, 240))
	check(world.outpost.industry.plant(machine("greenhouse"), "potato", world.outpost), "first crop consumes one of the ship's seed potatoes")
	world.outpost.advance(5)
	check(world.seeds().potato == 2 and world.outpost.industry.state(machine("greenhouse")).elapsed == 0, "no water means no free growth or seed repayment")
	await lay_line("water", -9, 1)
	world.environment.water = {Vector2i(-12, 4): 1.0, Vector2i(-11, 4): 1.0, Vector2i(-12, 5): 1.0, Vector2i(-11, 5): 1.0}
	world.player.position = Vector2(140, 240)
	world.drone.position = Vector2(60, 170)
	world.outpost.advance(20)
	check(world.outpost.industry.state(machine("greenhouse")).elapsed > 19.9, "pumped finite water irrigates crop through actual connected tubes")
	var tank: float = world.outpost.industry.state(machine("pump")).water
	check(absf(tank + volume(world.environment.water) + 20.0 * 2.0 / 45.0 - 4.0) < 0.001, "pump storage, remaining source and irrigation conserve four water volumes")
	world.player.position = Vector2(-180, 240)
	check(world.outpost.remove_conduit("water", Vector2i(-5, 5)), "water tube can be removed without removing gas or energy at that crossing")
	world.outpost.advance(5)
	check(absf(world.outpost.industry.state(machine("greenhouse")).elapsed - 20) < 0.001, "cut water line pauses growth while preserving crop")
	var fuel_before := volume(world.environment.gas)
	world.outpost.advance(2)
	check(absf(volume(world.environment.gas) - fuel_before) < 0.00001, "full converter stops consuming gas when there is no electrical demand")
	give({"copper": 1})
	check(world.outpost.place_conduit("water", Vector2i(-5, 5)), "restored water pipe reconnects irrigation")
	await reload_world()
	world.player.position = Vector2(140, 240)
	world.drone.position = Vector2(60, 170)
	check(world.seeds().potato == 2 and world.outpost.industry.state(machine("greenhouse")).elapsed > 19.9, "crop and global seed count survive halfway save/load")
	world.camera.position = Vector2(-40, 135)
	world.camera.zoom = Vector2.ONE * 0.9
	world.outpost.industry_ui.open_machine(machine("greenhouse"))
	await picture("greenhouse-growing-720p", world.outpost.industry_ui.window)
	var progress_before: float = world.outpost.industry.state(machine("greenhouse")).elapsed
	world.outpost.set_process(true)
	await frames(30)
	check(world.outpost.industry.state(machine("greenhouse")).elapsed > progress_before, "machine menu displays genuinely advancing production while explorer is paused")
	world.outpost.industry_ui.enabled_toggle.set_pressed(false)
	progress_before = world.outpost.industry.state(machine("greenhouse")).elapsed
	await frames(15)
	check(world.outpost.industry.state(machine("greenhouse")).elapsed == progress_before, "power switch pauses growing crop in the actual machine UI")
	world.outpost.industry_ui.enabled_toggle.set_pressed(true)
	world.outpost.set_process(false)
	world.outpost.industry_ui.window.hide()
	world.outpost.advance(30)
	give({"soil": 20})
	check(not world.outpost.industry.collect(machine("greenhouse"), world.outpost) and world.seeds().potato == 2, "full cargo preserves mature crop without duplicating food or seeds")
	give({})
	check(world.outpost.industry.collect(machine("greenhouse"), world.outpost), "harvest fits once cargo has room")
	check(world.field_cargo.available("potato", true) == 3 and world.seeds().potato == 4, "harvest yields three potatoes and two seeds exactly once")
	check(not world.outpost.industry.collect(machine("greenhouse"), world.outpost), "empty greenhouse cannot harvest twice")
	var pod: Dictionary = Catalog.seed_sites(0)[0]
	Fixture.carve(world, pod.cell)
	Fixture.carve(world, pod.cell + Vector2i.UP)
	world.player.position = Grid.to_world(pod.cell) + Vector2(20, 40)
	await frames()
	check(world.outpost.industry.collect_seed(pod, world.outpost) and world.seeds().ochre_tuber == 2, "excavating Ocra's seed capsule discovers a new cultivar")
	check(not world.outpost.industry.collect_seed(pod, world.outpost), "seed discovery cannot repeat")
	await reload_world()
	check(world.seeds().ochre_tuber == 2 and world.outpost.industry.collected_pods.has(pod.id), "planet capsule depletion and portable seeds persist")
	world.player.position = Vector2(20, 240)
	give({"soil": 2})
	check(world.place_ladder_at(Vector2i(0, 5)), "normal ladder is still instant manual construction")
	check(world.remove_ladder_at(Vector2i(0, 5)) and not world.ladders.has(Vector2i(0, 5)), "player can dismantle an underground ladder")
	check(not world.remove_ladder_at(Vector2i(0, -1)), "ship access ladder cannot be destroyed")
	check(world.place_ladder_at(Vector2i(0, 5)) == false, "ladder demolition does not refund free construction materials")
	give({"soil": 2})
	check(world.place_ladder_at(Vector2i(0, 5)), "prepare ladder for actual beam demolition")
	world.target_cell = Vector2i(0, 5)
	world.mine_timer = 0
	world._mine_target()
	check(not world.ladders.has(Vector2i(0, 5)) and world.beam_time > 0, "mining beam can actually break an aimed ladder")
	world.outpost.buildings.install("ladder", Vector2i(0, 5))
	world.ladders[Vector2i(0, 5)] = true
	check(world.remove_ladder_at(Vector2i(0, 5)) and not world.outpost.buildings.structures.any(func(item: Dictionary): return item.id == "ladder"), "legacy paid ladder structures are removed too, so load cannot resurrect them")
	give({"copper": 1})
	world.outpost.industry_ui.menu.id_pressed.emit(0)
	var click := InputEventMouseButton.new()
	click.position = world.get_global_transform_with_canvas() * Grid.center(Vector2i(0, 4))
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	check(world.outpost.handle_input(click) and world.outpost.network.cells.water.has(Vector2i(0, 4)), "pipe-tool menu routes an actual left click into instant placement")
	click.button_index = MOUSE_BUTTON_RIGHT
	check(world.outpost.handle_input(click) and not world.outpost.industry_ui.tool_active(), "right click exits conduit tool without placing a cube")
	var invalid: Dictionary = world.capture_state()
	invalid.network.cells.append(["water", 22, 0])
	check(not world.restore_state(invalid), "invalid pipe saves reject transaction without replacing the current world")
	world.player.position = Vector2(140, 240)
	world.camera.position = Vector2(-40, 135)
	world.camera.zoom = Vector2.ONE * 0.9
	world.outpost.industry_ui.window.hide()
	await picture("connected-outpost-720p")
	root.size = Vector2i(1920, 1080)
	await picture("connected-outpost-1080p")
	world.player.position = Vector2(-100, 240)
	world.outpost.industry_ui.open_machine(machine("furnace"))
	await picture("furnace-menu-1080p", world.outpost.industry_ui.window)
	world.outpost.industry_ui.window.hide()
	world.player.position = Vector2(-80, -80)
	world.outpost.construction.open_picker(Vector2i.ZERO, Vector2.ZERO, true)
	await picture("seven-recipes-1080p", world.outpost.construction.picker)
	var recipe_scroll: ScrollContainer = world.outpost.construction.recipe_grid.get_parent()
	recipe_scroll.scroll_vertical = 1000
	await picture("greenhouse-recipe-bottom-1080p", world.outpost.construction.picker)
	world.outpost.construction.picker.hide()
	world.outpost.cargo_ui.open_inventory()
	give({"potato": 3})
	world._set_crew_energy(70)
	var inventory: CanvasLayer = world.outpost.cargo_ui
	inventory.picker.select(world.field_cargo.ITEM_IDS.find("potato"))
	inventory.refresh()
	inventory.eat_button.pressed.emit()
	check(world.crew_energy() == 90 and world.field_cargo.available("potato", true) == 2, "harvested food restores energy and consumes exactly one carried potato")
	await frames()
	inventory.picker.item_selected.emit(world.field_cargo.ITEM_IDS.find("potato"))
	await frames()
	check(inventory.hold_scrolls[0].scroll_vertical > 0 and inventory.hold_scrolls[0].scroll_vertical == inventory.hold_scrolls[1].scroll_vertical and inventory.hold_scrolls[1].scroll_vertical == inventory.hold_scrolls[2].scroll_vertical, "food selection scrolls all three inventory columns to the same visible resource row")
	await picture("inventory-food-seeds-1080p", world.outpost.cargo_ui.window)
	world.outpost.cargo_ui.window.hide()
	var seeds_before: Dictionary = world.seeds().duplicate()
	check(campaign.save_campaign() and campaign.load_campaign(), "completed economy can be saved normally")
	world = campaign.world
	freeze()
	check(world.seeds() == seeds_before and not world.ladders.has(Vector2i(0, 5)), "demolished ladders stay removed and seeds never reset on load")
	world.player.position = Vector2(-80, -80)
	world.drone.position = Vector2(20, -140)
	world.set_hatch(false, false)
	check(campaign.request_takeoff(), "leave Ocra with plants, machinery and shared seeds saved")
	campaign.model.advance(3)
	campaign._sync_phase()
	check(campaign.model.choose("verdant"), "choose another unlocked seed planet")
	campaign.arrive_immediately()
	world = campaign.world
	freeze()
	check(world.seeds() == seeds_before, "seed bank travels without resetting on new planets")
	var other_pod: Dictionary = Catalog.seed_sites(11)[0]
	Fixture.carve(world, other_pod.cell)
	Fixture.carve(world, other_pod.cell + Vector2i.UP)
	world.player.position = Grid.to_world(other_pod.cell) + Vector2(20, 40)
	await frames()
	check(world.outpost.industry.collect_seed(other_pod, world.outpost) and world.seeds().verdant_leaf == 2, "Viridia supplies a genuinely different cultivar")
	world.player.position = Vector2(-80, -80)
	world.drone.position = Vector2(20, -140)
	world.set_hatch(false, false)
	check(campaign.request_takeoff(), "take the discovered seeds back aboard")
	campaign.model.advance(3)
	campaign._sync_phase()
	check(campaign.model.choose("ochre"), "return to original industrial outpost")
	campaign.arrive_immediately()
	world = campaign.world
	freeze()
	check(world.seeds().verdant_leaf == 2 and world.seeds().potato == seeds_before.potato and world.outpost.industry.collected_pods.has("pod_west"), "old Ocra snapshot restores depleted capsule and pipes without overwriting newer global seeds")
	print("INDUSTRY SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
