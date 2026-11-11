extends SceneTree

const Grid = preload("res://scripts/world/world_grid.gd")
const Reservoir = preload("res://scripts/ui/reservoir_view.gd")
const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const YieldPopup = preload("res://scripts/ui/mining_yield_popup.gd")
var failures := 0
var world: Node2D

class FluidStage extends Node2D:
	const TerrainRenderer = preload("res://scripts/ui/terrain_renderer.gd")
	var site := preload("res://scripts/systems/dig_site.gd").new()
	var environment := preload("res://scripts/systems/environment_field.gd").new(site)
	var player := Node2D.new()
	var ambient_time := 0.0
	var light := 1.0
	func _init() -> void: add_child(player)
	func _illumination(_point: Vector2) -> float: return light

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func pixels(viewport: Viewport) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func water_pixels() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 240)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := FluidStage.new()
	viewport.add_child(stage)
	var camera := Camera2D.new()
	camera.position = Vector2(-480, 480)
	stage.add_child(camera)
	var view := Reservoir.new()
	view.world = stage
	stage.add_child(view)
	view.set_process(false)
	var first := await pixels(viewport)
	var transform := stage.get_global_transform_with_canvas()
	for pocket: Dictionary in stage.site.pockets():
		if pocket.id != "water_deep": continue
		for cell: Vector2i in stage.site.HazardLayout.cells(pocket):
			var point: Vector2i = Vector2i(transform * Grid.center(cell))
			var color := first.get_pixelv(point)
			check(color.b > color.r * 1.5 and color.a > 0.5, "sealed irregular water mask contains physical blue liquid at %s" % cell)
	var corner: Vector2i = Vector2i(transform * Grid.center(Vector2i(-15, 10)))
	check(first.get_pixelv(corner).a == 0, "rock notch is not painted as water")
	stage.ambient_time = 0.7
	view.queue_redraw()
	var second := await pixels(viewport)
	var inner: Rect2i = Rect2i(Vector2i(transform * Vector2(-548, 448)), Vector2i(16, 24))
	check(first.get_region(inner).get_data() != second.get_region(inner).get_data(), "bubbles animate inside the liquid, independently of its surface")
	check(stage.environment.released.is_empty(), "drawing the pocket does not breach its rock walls")
	check(second.save_png("res://reports/water-bubbles-detail.png") == OK, "capture irregular water and animated bubbles detail")
	stage.light = 0
	view.queue_redraw()
	var dark := await pixels(viewport)
	var dark_color := dark.get_pixelv(Vector2i(transform * Vector2(-500, 460)))
	check(dark_color.b < 0.06 and dark_color.r < 0.06, "water remains dark outside illumination")
	viewport.queue_free()
	await process_frame

func yield_feedback() -> void:
	for amount in [1, 2, 3]:
		var chosen_seed := 0
		for value in range(1000):
			seed(value)
			if world.gear.yield_for_roll(randi_range(0, 99)) == amount:
				chosen_seed = value
				break
		var cell := Vector2i(-4 + amount, 3)
		Fixture.carve(world, cell)
		seed(chosen_seed)
		world.gear.spawn_ore(cell, "iron")
		var badges: Array = world.gear.get_children().filter(func(child): return child is YieldPopup and not child.is_queued_for_deletion())
		check(badges.size() == maxi(0, amount - 1), "new %d-piece yield has expected transient bonus count" % amount)
		if amount > 1:
			var badge: Node2D = badges.back()
			badge.set_process(false)
			check(badge.label.text == "x%d" % amount and badge.position == Grid.center(cell), "bonus text matches actual yield and broken cell")
			badge.advance(0.25)
	var saved: Dictionary = world.gear.snapshot()
	world.gear.restore(saved, false)
	check(world.gear.get_children().filter(func(child): return child is YieldPopup and not child.is_queued_for_deletion()).is_empty(), "restoring ore does not replay old bonus notifications")

func bonus_pixels() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(160, 90)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var badges: Array[Node2D] = []
	for amount in [2, 3]:
		var badge := YieldPopup.new()
		badge.amount = amount
		badge.position = Vector2(40 + (amount - 2) * 80, 55)
		viewport.add_child(badge)
		badge.set_process(false)
		badges.append(badge)
	var before := await pixels(viewport)
	check(not before.is_invisible(), "x2/x3 render real native glyph pixels")
	check(before.save_png("res://reports/mining-yield-detail.png") == OK, "capture readable mining multiplier sprites")
	for badge in badges: badge.advance(0.75)
	var after := await pixels(viewport)
	check(before.get_data() != after.get_data(), "native multiplier pixels move and fade")
	for badge in badges: badge.advance(0.5)
	var expired := await pixels(viewport)
	check(expired.is_invisible(), "expired bonus sprites leave no pixels")
	viewport.queue_free()
	await process_frame

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	await water_pixels()
	await bonus_pixels()
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	freeze(world)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	Fixture.lab_room(world)
	world.player.position = Vector2(-100, 160)
	yield_feedback()
	# Showcase real irregular reservoir geometry with the normal player light.
	world.player.position = Vector2(-620, 480)
	Fixture.carve(world, Vector2i(-16, 11))
	Fixture.carve(world, Vector2i(-16, 12))
	world.drone.position = Vector2(-610, 430)
	world.camera.position = Vector2(-500, 465)
	world.camera.zoom = Vector2.ONE * 1.6
	world.ambient_time = 0.7
	world.equip_tool(1)
	world.active_tool().scanner_level = 4
	world.scanner_view.advance(1.8)
	for slot in [0, 1]:
		world.equip_tool(slot)
		if slot == 1: world.scanner_view.advance(1.8)
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			world.camera.force_update_scroll()
			world.queue_redraw()
			world.scanner_view.queue_redraw()
			world.reservoir_view.queue_redraw()
			world._refresh_hud()
			var image := await pixels(root)
			check(image.save_png("res://reports/water-feedback-%s-%dp.png" % ["scan" if slot else "normal", size.y]) == OK, "saved water mode %d / %dp screenshot" % [slot, size.y])
	print("WATER FEEDBACK VISUAL: %d failures" % failures)
	quit(1 if failures else 0)
