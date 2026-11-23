extends SceneTree

const IndustryUI = preload("res://scripts/ui/industry_ui.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const Grid = preload("res://scripts/world/world_grid.gd")

class DarkWorld extends Node2D:
	var ambient_time := 0.0
	func _illumination(_point: Vector2) -> float: return 0.0

class EdgeFlows extends RefCounted:
	var rate := 0.0
	func at(_cell: Vector2i) -> Dictionary: return {}
	func flow_between(first: Vector2i, second: Vector2i) -> float:
		if first.y != 3 or second.y != 3: return 0.0
		return rate * signi(second.x - first.x)

class Structures extends RefCounted:
	var structures: Array[Dictionary] = []

class RenderOutpost extends Node2D:
	const SHIP_ENERGY_PORTS := [Vector2i(-6, -2), Vector2i(5, -2)]
	var world := DarkWorld.new()
	var network := Network.new()
	var hydraulics := EdgeFlows.new()
	var buildings := Structures.new()

class SocketRenderer extends Node2D:
	var ui: Node2D
	func _draw() -> void: ui._draw_energy_ports(self)

var failures := 0
var ui: Node2D
var outpost: RenderOutpost
var renderer: Node2D

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func frame() -> Image:
	renderer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func colored_width(image: Image, x: int, y: int, blue_only := false, vertical_pipe := false) -> int:
	var count := 0
	for dy in range(-8, 9):
		var color := image.get_pixel(x + dy if vertical_pipe else x, y if vertical_pipe else y + dy)
		if (color.b > color.r * 1.4 and color.b > 0.12) if blue_only else color.r + color.g + color.b > 0.12:
			count += 1
	return count

func bright_center(image: Image, start: Vector2i) -> float:
	var total := 0.0
	var count := 0
	for x in range(start.x, start.x + 20):
		for y in range(start.y - 2, start.y + 3):
			var color := image.get_pixel(x, y)
			if color.r > 0.45 and color.g > 0.5:
				total += x
				count += 1
	return total / count if count else -1.0

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this pixel suite with the native gl_compatibility renderer")
		quit(2)
		return
	root.transparent_bg = false
	RenderingServer.set_default_clear_color(Color.BLACK)
	outpost = RenderOutpost.new()
	root.add_child(outpost)
	outpost.add_child(outpost.world)
	ui = IndustryUI.new()
	ui.outpost = outpost
	renderer = IndustryUI.PipeRenderer.new()
	renderer.ui = ui
	root.add_child(renderer)
	for cell: Vector2i in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(4, 4)]: outpost.network.add("water", cell)
	for kind: String in ["gas", "energy"]:
		for x in range(3, 6): outpost.network.add(kind, Vector2i(x, 6 if kind == "gas" else 8))
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		root.content_scale_size = size
		for index in range(3): await process_frame
		outpost.hydraulics.rate = 0
		var still := await frame()
		check(colored_width(still, 150, 140) == 10, "water outer width is 10 native pixels in darkness at " + str(size))
		check(colored_width(still, 150, 140, true) == 6, "water inner width is 6 native pixels in darkness at " + str(size))
		check(colored_width(still, 180, 150, true, true) == 6, "vertical junction has coherent six-pixel inner bore")
		check(still.get_pixel(180, 140).b > 0.12, "T junction has no dark seam")
		check(still.get_pixel(150, 260).g > 0.1 and still.get_pixel(150, 346).r > 0.1, "installed gas and energy remain dimly visible without a tool")
		check(still.get_pixel(260, 180).is_equal_approx(Color.BLACK), "empty unbuilt cells remain black")
		outpost.world.ambient_time = 0.3
		outpost.hydraulics.rate = 0.7
		var flowing := await frame()
		var first := bright_center(flowing, Vector2i(140, 140))
		outpost.world.ambient_time = 0.4
		var later := await frame()
		var second := bright_center(later, Vector2i(140, 140))
		check(first >= 0 and second > first, "positive actual flow moves right at " + str(size))
		check(flowing.get_region(Rect2i(175, 150, 10, 25)).get_data() == later.get_region(Rect2i(175, 150, 10, 25)).get_data(), "zero-flow branch does not animate")
		outpost.hydraulics.rate = -0.7
		outpost.world.ambient_time = 0.3
		first = bright_center(await frame(), Vector2i(140, 140))
		outpost.world.ambient_time = 0.4
		second = bright_center(await frame(), Vector2i(140, 140))
		check(first >= 0 and second < first, "negative actual flow moves left")
		outpost.hydraulics.rate = 0
		outpost.world.ambient_time = 0.8
		check((await frame()).get_data() == still.get_data(), "no actual transfer means no fake water animation")
		if "--capture" in OS.get_cmdline_user_args(): later.save_png("res://reports/utility-render-%d.png" % size.y)
	check(ui.has_method("_draw_energy_ports"), "energy sockets have a shared renderer for ship and laboratory")
	if ui.has_method("_draw_energy_ports"):
		var sockets := SocketRenderer.new()
		sockets.ui = ui
		sockets.position = Vector2(400, 400)
		root.add_child(sockets)
		outpost.buildings.structures.append({"id": "laboratory", "origin": Vector2i(2, 1), "state": "active"})
		await process_frame
		var image := await frame()
		for cell: Vector2i in outpost.SHIP_ENERGY_PORTS:
			var point := Vector2i(Grid.center(cell) + Vector2(400, 406))
			check(image.get_pixelv(point + Vector2i(5, 0)).r > 0.7, "ship socket remains fully visible at " + str(cell))
		var lab_port := Network.port(outpost.buildings.structures[0], "energy")
		var lab_point := Vector2i(Grid.center(lab_port) + Vector2(400, 406))
		check(image.get_pixelv(lab_point + Vector2i(5, 0)).r > 0.2, "laboratory bottom-left energy socket stays visible in darkness")
		check(image.get_pixelv(lab_point + Vector2i(5, 0)).r < 0.7, "laboratory socket uses the dim utility floor, not ship brightness")
		sockets.free()
	renderer.free()
	ui.free()
	outpost.free()
	print("UTILITY RENDER UI: %d failures" % failures)
	quit(1 if failures else 0)
