extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
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

func picture(name: String, viewport: Viewport = null) -> Color:
	if not capture:
		return Color.WHITE
	world._refresh_hud()
	world.queue_redraw()
	world.gear.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	var pixels := target.get_texture().get_image()
	check(pixels.save_png("res://reports/" + name + ".png") == OK, name + " screenshot saved")
	var point: Vector2 = world.get_global_transform_with_canvas() * Grid.center(Vector2i(-3, 4))
	return pixels.get_pixelv(Vector2i(point)) if viewport == null else Color.WHITE

func _run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Light/ammo timeout"); quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames()
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.outpost.set_process(false)
	world.guide.set_process(false)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	Fixture.lab_room(world)
	world.set_hatch(true)
	for depth in [120.0, 400.0, 660.0]:
		world.player.position = Vector2(-100, depth)
		world.equip_tool(0)
		var point: Vector2 = world.player.position - Vector2(0, 32) + Vector2(35, 0)
		var light: float = world._illumination(point)
		for slot in range(4):
			world.equip_tool(slot)
			check(is_finite(world._illumination(point)) and is_equal_approx(world._illumination(point), light) and light > 0.2, "personal light remains independent of slot %d at %.0f m" % [slot + 1, depth / 40])
	world.player.position = Vector2(-100, 160)
	world.camera.position = Vector2(-40, 60)
	world.camera.zoom = Vector2.ONE
	world.equip_tool(0)
	var pulse_color: Color = await picture("light-pulse-720p")
	world.equip_tool(3)
	world.gear.set_charge(0)
	var jet_color: Color = await picture("light-jetpack-empty-720p")
	if capture:
		check(jet_color.r + jet_color.g + jet_color.b > 0.2 and absf(jet_color.r - pulse_color.r) + absf(jet_color.g - pulse_color.g) + absf(jet_color.b - pulse_color.b) < 0.02, "terrain pixels stay lit with the jetpack selected even at zero battery")
	world.gear.set_charge(100)
	check(world.gear.ammo() == 4, "a new expedition has four ready bombs")
	world.equip_tool(2)
	var cargo: Dictionary = world.field_cargo.snapshot()
	for x in range(-5, -1):
		world.player.position = Vector2(Grid.center(Vector2i(x, 3)).x + 80, 120)
		check(world.gear.place_bomb(Vector2i(x, 3)), "place one initial bomb at x=" + str(x))
		await frames(2)
	check(world.gear.ammo() == 0 and world.field_cargo.snapshot() == cargo, "placing all four bombs consumes ammunition, not raw resources")
	check(not world.gear.place_bomb(Vector2i(1, 3)) and world.gear.placement_blocker(Vector2i(1, 3)).contains("esaurite"), "a fifth placement requires laboratory fabrication")
	world.return_home()
	var saved: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(saved))) and world.gear.ammo() == 0 and world.gear.bombs.size() == 4, "loading preserves zero ammunition and every paid placed bomb")
	var invalid: Dictionary = world.capture_state()
	invalid.gear.ammo = 5
	check(not world.restore_state(invalid) and world.gear.ammo() == 0, "invalid ammunition is rejected without refilling the magazine")
	world.local_store = {"stone": 4, "copper": 8}
	world.outpost.selected_station = {"kind": "ship"}
	var ui: Node = world.outpost.construction
	ui.open_picker(Vector2i.ZERO, Vector2.ZERO, true)
	check(ui.recipe_rows.has("bomb") and not ui.recipe_rows.bomb.button.disabled, "ship fabrication panel offers a real bomb recipe before the first field lab")
	ui.recipe_rows.bomb.button.pressed.emit()
	check(world.outpost.fabrication.jobs.size() == 1 and world.outpost.fabrication.jobs[0].id == "bomb" and world.gear.ammo() == 0, "Crea starts timed production rather than granting instant ammunition")
	world.outpost.advance_fabrication(0.75)
	ui.refresh()
	check(ui.craft_bar.visible and ui.craft_bar.value > 0 and ui.craft_bar.value < 100, "bomb production displays bench progress")
	await picture("bomb-fabrication-720p", ui.picker)
	ui.picker.hide()
	check(not world.guide_state.ocra.facts.get("lab_materials_ready", false), "crafting ammunition does not skip the laboratory tutorial")
	saved = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(saved))) and world.outpost.fabrication.jobs[0].elapsed == 0.75, "partial bomb fabrication resumes after save/load")
	world.outpost.advance_fabrication(1.3)
	check(world.gear.ammo() == 1 and world.outpost.fabrication.jobs.is_empty() and world.outpost.fabrication.cubes.is_empty(), "a finished bomb replenishes the magazine without creating a room cube")
	check(world.local_store.stone == 3 and world.local_store.copper == 6, "one crafted bomb costs one stone and two copper exactly once")
	for index in range(3):
		check(world.outpost.fabricate_cube("bomb"), "start another finite bomb recipe")
		world.outpost.advance_fabrication(2.1)
	check(world.gear.ammo() == 4 and world.local_store.stone == 0 and world.local_store.copper == 0, "four completed recipes refill the four-bomb magazine")
	world.local_store = {"stone": 10, "copper": 10}
	check(not world.outpost.fabricate_cube("bomb") and world.local_store.stone == 10 and world.local_store.copper == 10, "a full magazine cannot consume ingredients")
	ui.refresh()
	check(ui.choice_status.text == "Banco pronto" and not ui.craft_button.disabled and ui.recipe_rows.bomb.button.disabled, "full bomb reserves do not make an available laboratory recipe appear blocked")
	Fixture.carve(world, Vector2i(1, 3))
	world.player.position = Vector2(20, 140)
	await frames()
	check(world.gear.place_bomb(Vector2i(1, 3)), "newly manufactured ammunition can actually be placed")
	for x in range(5, 9):
		for y in range(2, 5):
			Fixture.carve(world, Vector2i(x, y))
	var lab: Dictionary = world.outpost.buildings.install("laboratory", Vector2i(5, 2))
	lab.stock = {"stone": 2, "copper": 4}
	world.player.position = Vector2(280, 200)
	world.outpost.selected_station = {"kind": "laboratory", "building": lab}
	await frames()
	check(world.outpost.fabricate_cube("bomb"), "an operational underground lab can fabricate ammunition using its local cache")
	lab.enabled = false
	world.outpost.advance_fabrication(5)
	check(world.gear.ammo() == 3 and world.outpost.fabrication.jobs[0].elapsed == 0, "switched-off lab pauses paid bomb production without loss")
	lab.enabled = true
	world.outpost.advance_fabrication(2.1)
	check(world.gear.ammo() == 4 and lab.stock.stone == 1 and lab.stock.copper == 2, "restored laboratory finishes its paid bomb exactly once")
	root.size = Vector2i(1920, 1080)
	ui.open_picker(Vector2i.ZERO, Vector2.ZERO, true)
	await frames()
	ui.recipe_grid.get_parent().ensure_control_visible(ui.recipe_rows.bomb.button)
	await picture("bomb-fabrication-1080p", ui.picker)
	ui.picker.hide()
	world._refresh_hud()
	check(world.tool_buttons[2].text.contains("4/4"), "hotbar displays the saved bomb supply")
	print("LIGHT AND AMMO SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
