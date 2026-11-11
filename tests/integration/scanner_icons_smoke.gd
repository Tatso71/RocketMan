extends SceneTree

const Scanner = preload("res://scripts/ui/scanner_pulse_view.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0
var world: Node2D

class IconWorld extends Node2D:
	const MATERIAL_NAMES := {}
	var player := Node2D.new()
	var tool: Resource = preload("res://scripts/data/digital_tool_catalog.gd").find("scanner").duplicate()
	func _init() -> void:
		add_child(player)
		player.position = Vector2(20, 52)
	func active_tool() -> Resource:
		return tool
	func controls_blocked() -> bool:
		return false
	func player_center() -> Vector2:
		return player.position - Vector2(0, 32)

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value:
		failures += 1

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		freeze(child)

func pixels(viewport: Viewport) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func sample(view: Node2D, cell: Vector2i, kind: String) -> void:
	view.revealed[cell] = {"kind": kind, "until": view.clock + 2.0, "duration": 2.0}

func verify_native_icons() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = true
	root.add_child(viewport)
	var stage := IconWorld.new()
	viewport.add_child(stage)
	var camera := Camera2D.new()
	camera.position = Vector2(80, 20)
	stage.add_child(camera)
	var view := Scanner.new()
	view.world = stage
	stage.add_child(view)
	view.set_process(false)
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0), Vector2i(3, 0)]
	for cell in cells:
		sample(view, cell, "copper")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		viewport.size = size
		for zoom: float in [0.6, 1.0, 1.6]:
			camera.zoom = Vector2.ONE * zoom
			camera.force_update_scroll()
			view.queue_redraw()
			var image := await pixels(viewport)
			check(image.get_size() == size, "%dp zoom %.1f renders exact native dimensions" % [size.y, zoom])
			var bounds: Array[Rect2] = []
			var transform := stage.get_global_transform_with_canvas()
			for cell in cells:
				# Literal 28 px footprint, independently checked against actual rendered pixels.
				var rect := transform * Rect2(Grid.center(cell) - Vector2(14, 14), Vector2(28, 28))
				bounds.append(rect.grow(1))
				if cell != Vector2i(3, 0):
					# Include the native renderer's antialias fringe at fractional zooms.
					bounds.append((transform * Grid.rect(cell)).grow(3))
				var count := 0
				for y in range(floori(rect.position.y), ceili(rect.end.y)):
					for x in range(floori(rect.position.x), ceili(rect.end.x)):
						if image.get_pixel(x, y).a > 0.1:
							count += 1
				check(count > 10, "%dp zoom %.1f has an icon in cell %s" % [size.y, zoom, cell])
			var outside := 0
			for y in range(size.y):
				for x in range(size.x):
					if image.get_pixel(x, y).a > 0.01 and not bounds.any(func(rect: Rect2): return rect.has_point(Vector2(x, y))):
						outside += 1
			check(outside == 0, "%dp zoom %.1f draws only icons and recognized-cell outlines without callouts or fills" % [size.y, zoom])
			var far_point: Vector2 = transform * Grid.center(Vector2i(3, 0))
			var far_rect := Rect2i(Vector2i(far_point - Vector2(14, 14) * zoom), Vector2i(Vector2(28, 28) * zoom))
			var unknown := image.get_region(far_rect)
			var gray := true
			for y in range(unknown.get_height()):
				for x in range(unknown.get_width()):
					var pixel := unknown.get_pixel(x, y)
					if pixel.a > 0.05 and (absf(pixel.r - pixel.g) > 0.005 or absf(pixel.g - pixel.b) > 0.005):
						gray = false
			check(gray, "%dp zoom %.1f distant marker pixels are neutral gray" % [size.y, zoom])
		view.revealed[Vector2i(3, 0)].kind = "acid"
		view.queue_redraw()
		var acid := await pixels(viewport)
		view.revealed[Vector2i(3, 0)].kind = "cobalt"
		view.queue_redraw()
		var cobalt := await pixels(viewport)
		check(acid.get_data() == cobalt.get_data(), "%dp unknown acid and cobalt render identically" % size.y)
		view.revealed[Vector2i(3, 0)].kind = "copper"
		stage.tool.mode = "mine"
		view.queue_redraw()
		var hidden := await pixels(viewport)
		check(hidden.is_invisible(), "%dp leaving scanner mode hides all icon pixels" % size.y)
		stage.tool.mode = "scan"
	viewport.queue_free()
	await process_frame

func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("Scanner icons timeout"); quit(2))
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	freeze(world)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	Fixture.lab_room(world)
	world.equip_tool(1)
	world.message_time = 0
	world.player.position = Vector2(-100, 160)
	world.camera.position = Vector2(-100, 128)
	world.camera.zoom = Vector2.ONE
	var view: Node2D = world.scanner_view
	view.revealed.clear()
	view.advance(0.01)
	view.advance(1.79)
	check(not view.revealed.is_empty(), "real passive waves reveal special cells")
	check(view.find_children("*", "Control", true, false).is_empty() and view.find_children("*", "CanvasLayer", true, false).is_empty(), "scanner creates no standalone popup UI")
	var target := Vector2i(-3, 4)
	world.target_cell = target
	sample(view, target, "iron")
	world.player.position = Grid.center(target) + Vector2(100, 32)
	world._refresh_hud()
	check(world.status_label.text.contains("Ferro"), "existing HUD identifies target at L1 identification boundary")
	world._note("Messaggio precedente")
	world._refresh_hud()
	check(world.status_label.text.contains("Ferro"), "hover identity immediately overrides temporary status messages")
	world.target_cell = Vector2i(20, 0)
	world._refresh_hud()
	check(not world.status_label.text.contains("Ferro"), "hover exit clears identity even while an earlier message timer is active")
	world.target_cell = target
	world._refresh_hud()
	world.standalone_slot = 0
	world._refresh_hud()
	check(not world.status_label.text.contains("Ferro"), "leaving scanner clears a previous hover readout without relying on a new notification")
	world.standalone_slot = 1
	world.message_time = 0
	world.player.position.x += 0.1
	world._refresh_hud()
	check(view.aimed_identity(target).is_empty() and not world.status_label.text.contains("Ferro"), "existing HUD hides target identity immediately beyond identification range")
	world.player.position = Grid.center(target) + Vector2(0, 32)
	sample(view, target, "cobalt")
	world.active_tool().scanner_level = 2
	world._refresh_hud()
	check(view.aimed_identity(target).is_empty() and not world.status_label.text.contains("Cobalto"), "level II cannot identify nearby rare cobalt in existing HUD")
	world.active_tool().scanner_level = 3
	world._refresh_hud()
	check(world.status_label.text.contains("Cobalto"), "level III identifies nearby cobalt in existing HUD")
	world.active_tool().scanner_level = 1
	world.player.position = Vector2(-100, 160)
	sample(view, target, "iron")
	world._refresh_hud()
	view.queue_redraw()
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			world.camera.force_update_scroll()
			world.queue_redraw()
			var image := await pixels(root)
			check(image.save_png("res://reports/scanner-icons-%dp.png" % size.y) == OK, "saved native %dp scanner screenshot" % size.y)
		await verify_native_icons()
	world.equip_tool(0)
	view.advance(0.1)
	check(view.revealed.is_empty() and view.aimed_identity(target).is_empty(), "switching modes clears icons and HUD identity")
	print("SCANNER ICONS SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
