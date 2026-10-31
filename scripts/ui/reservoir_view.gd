extends Node2D

const Grid = preload("res://scripts/world/world_grid.gd")
const Fluids = preload("res://scripts/data/fluid_catalog.gd")
var world: Node2D

func _ready() -> void:
	z_index = 2

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world.player):
		return
	for kind: String in Fluids.LIQUID_IDS:
		_draw_liquid(kind)
	_draw_gas()

func _fill(rect: Rect2, tint: Color, opacity: float) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var colors := PackedColorArray()
	for point: Vector2 in points:
		var light: float = world._illumination(point)
		colors.append(Color(Color("030509").lerp(tint, light), opacity))
	draw_polygon(points, colors)

func _edge(start: Vector2, end: Vector2, color: Color, strength: float = 0.65) -> void:
	var light: float = world._illumination((start + end) * 0.5)
	if light > 0.06:
		draw_line(start, end, Color(color, light * strength), 1.7, true)

func _draw_liquid(kind: String) -> void:
	var field: Dictionary = world.environment.get(kind)
	var definition: Dictionary = Fluids.KINDS[kind]
	for cell: Vector2i in field:
		var rect: Rect2 = world.environment.liquid_rect(cell, kind)
		if rect.size.y < 0.3:
			continue
		_fill(rect, definition.color, 0.88 if kind == "oil" else 0.78)
		var above := cell + Vector2i.UP
		if float(field[cell]) < 0.99 or float(field.get(above, 0)) < 0.01:
			if world.site.material(above).is_empty() and world.environment.liquid_volume(above) < 0.01:
				var points := PackedVector2Array()
				for step in range(9):
					var x := rect.position.x + rect.size.x * step / 8.0
					points.append(Vector2(x, rect.position.y + sin(world.ambient_time * 2.5 + x * 0.065) * minf(1.5, rect.size.y * 0.2)))
				var light: float = world._illumination(rect.get_center())
				draw_polyline(points, Color(definition.edge, light * 0.9), 1.8, true)
			else:
				_edge(rect.position, Vector2(rect.end.x, rect.position.y), definition.edge)
		if float(field.get(cell + Vector2i.LEFT, 0)) < 0.01:
			_edge(rect.position, Vector2(rect.position.x, rect.end.y), definition.edge)
		if float(field.get(cell + Vector2i.RIGHT, 0)) < 0.01:
			_edge(Vector2(rect.end.x, rect.position.y), rect.end, definition.edge)
		if float(field.get(cell + Vector2i.DOWN, 0)) < 0.01:
			_edge(Vector2(rect.position.x, rect.end.y), rect.end, definition.edge, 0.4)
		if kind == "acid" and posmod(cell.x * 13 + cell.y * 7, 3) == 0:
			var phase := fposmod(world.ambient_time * 0.3 + cell.x * 0.3, 1.0)
			var point := Vector2(rect.position.x + 18, lerpf(rect.end.y - 3, rect.position.y + 3, phase))
			draw_arc(point, 2.5, 0, TAU, 12, Color(definition.edge, world._illumination(point) * sin(phase * PI) * 0.45), 1, true)

func _draw_gas() -> void:
	var field: Dictionary = world.environment.gas
	var definition: Dictionary = Fluids.KINDS.gas
	for cell: Vector2i in field:
		var density := float(field[cell])
		if density < 0.015:
			continue
		var rect := Grid.rect(cell)
		_fill(rect, definition.color, minf(0.67, density * 0.7))
		for edge: Array in [
			[Vector2i.UP, rect.position, Vector2(rect.end.x, rect.position.y)],
			[Vector2i.LEFT, rect.position, Vector2(rect.position.x, rect.end.y)],
			[Vector2i.RIGHT, Vector2(rect.end.x, rect.position.y), rect.end],
			[Vector2i.DOWN, Vector2(rect.position.x, rect.end.y), rect.end]
		]:
			if float(field.get(cell + edge[0], 0)) < 0.015:
				_edge(edge[1], edge[2], definition.edge, minf(0.6, density))
		if density > 0.1:
			var points := PackedVector2Array()
			for step in range(9):
				var x := rect.position.x + rect.size.x * step / 8.0
				var y := rect.position.y + 21 + sin(world.ambient_time * 1.5 + x * 0.025) * 4 + sin(cell.y * 1.7) * 3
				points.append(Vector2(x, y))
			draw_polyline(points, Color(definition.edge, world._illumination(rect.get_center()) * density * 0.12), 1.5, true)
