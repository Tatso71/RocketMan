extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const DARK := Color("030509")
static var rock_atlas: Texture2D = load("res://assets/terrain/rock-atlas-v1.png")

static func noise_at(point: Vector2, seed: int) -> float:
	return sin(point.x * 0.031 + seed * 0.71) * cos(point.y * 0.026 - seed * 0.37) * 0.055 + sin(point.x * 0.013 + point.y * 0.021) * 0.035

static func facets_for(cell: Vector2i, seed: int) -> Array:
	var p := Grid.to_world(cell)
	var hash_value := absi(cell.x * 73856093 ^ cell.y * 19349663 ^ seed * 83492791)
	var center := p + Vector2(11 + hash_value % 19, 11 + (hash_value / 19) % 19)
	var corners := [p, p + Vector2(40, 0), p + Vector2(40, 40), p + Vector2(0, 40)]
	var result: Array = []
	for i in range(4):
		result.append(PackedVector2Array([corners[i], corners[(i + 1) % 4], center]))
	return result

static func draw(world: Node2D) -> void:
	world.draw_rect(Rect2(-4000, 0, 8000, 3000), DARK)
	var center: Vector2 = world.camera.get_screen_center_position()
	var size: Vector2 = world.get_viewport_rect().size / world.camera.zoom
	var visible := Rect2(center - size * 0.5, size).grow(60)
	var lighting := {}
	for y in range(world.site.DEPTH):
		for x in range(world.site.LEFT, world.site.RIGHT):
			var cell := Vector2i(x, y)
			var rect := Grid.rect(cell)
			if not rect.intersects(visible):
				continue
			var kind: String = world.site.material(cell)
			var light: float = world._illumination(rect.get_center())
			var base: Color = Color("41444c") if kind.is_empty() else world.MATERIAL_COLORS[kind]
			if kind == "soil" and world.planet_def != null:
				base = world.planet_def.rock_color
			if kind.is_empty():
				var corners := PackedVector2Array([rect.position, rect.position + Vector2(40, 0), rect.end, rect.position + Vector2(0, 40)])
				var inks := PackedColorArray()
				for point: Vector2 in corners:
					inks.append(DARK.lerp(base, world._illumination(point) * 0.85))
				world.draw_polygon(corners, inks)
			else:
				var row := 0 if kind == "soil" else (3 if kind == "anchor" else (2 if kind == "bedrock" else 1))
				var variant := posmod(cell.x * 13 + cell.y * 7 + world.site.terrain_seed, 4)
				var tile_size := Vector2(rock_atlas.get_size()) / 4.0
				for facet: PackedVector2Array in facets_for(cell, world.site.terrain_seed):
					var inks := PackedColorArray()
					var uvs := PackedVector2Array()
					for point: Vector2 in facet:
						if not lighting.has(point):
							lighting[point] = world._illumination(point)
						var tint := Color.WHITE.lightened(noise_at(point, world.site.terrain_seed))
						inks.append(DARK.lerp(tint, lighting[point]))
						uvs.append((Vector2(variant, row) * tile_size + Vector2.ONE + (point - rect.position) / 40.0 * (tile_size - Vector2(2, 2))) / Vector2(rock_atlas.get_size()))
					world.draw_polygon(facet, inks, uvs, rock_atlas)
				if light > 0.08:
					_draw_edges(world, cell, base, light)
					_draw_fracture(world, cell, base, light)
				if light > 0.18 and not world.site.resource_yield(kind).is_empty():
					_draw_ore(world, cell, kind, light)
				if light > 0.2 and kind == "anchor":
					world.draw_polyline(PackedVector2Array([rect.position + Vector2(5, 29), rect.position + Vector2(17, 8), rect.position + Vector2(29, 32), rect.position + Vector2(36, 15)]), DARK.lerp(Color("b4bfb3"), light * 0.55), 3, true)
			if world.show_grid and light > 0.15:
				world.draw_rect(rect, Color(0.65, 0.7, 0.73, light * 0.2), false, 1)
			if light > 0.2 and world.scanned.has(cell) and not world.environment.reading(cell).is_empty():
				world.draw_circle(rect.get_center(), 6, Color("ecc267"))

static func _draw_edges(world: Node2D, cell: Vector2i, base: Color, light: float) -> void:
	var p := Grid.to_world(cell)
	var hash_value := absi(cell.x * 97 + cell.y * 61)
	for side in range(4):
		var offset: Vector2i = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][side]
		if not world.site.material(cell + offset).is_empty():
			continue
		var a: Vector2 = [Vector2(0, 0), Vector2(40, 0), Vector2(40, 40), Vector2(0, 40)][side]
		var b: Vector2 = [Vector2(40, 0), Vector2(40, 40), Vector2(0, 40), Vector2(0, 0)][side]
		var inward := Vector2(-offset) * (3 + hash_value % 6)
		var ridge := p + a.lerp(b, 0.25 + (hash_value % 40) * 0.01) + inward
		world.draw_colored_polygon(PackedVector2Array([p + a, p + b, ridge]), DARK.lerp(base.lightened(0.2 if side == 0 else -0.15), light * 0.9))

static func _draw_fracture(world: Node2D, cell: Vector2i, base: Color, light: float) -> void:
	var p := Grid.to_world(cell)
	var depth := posmod(cell.x * 7 + cell.y * 11, 13)
	if depth > 7:
		return
	var band := 10.0 + sin(float(cell.x) * 0.42 + floorf(float(cell.y) / 3.0)) * 7
	var end_band := 10.0 + sin(float(cell.x + 1) * 0.42 + floorf(float(cell.y) / 3.0)) * 7
	world.draw_polyline(PackedVector2Array([p + Vector2(0, band), p + Vector2(14, band + depth), p + Vector2(27, end_band - 3), p + Vector2(40, end_band)]), DARK.lerp(base.darkened(0.3), light), 1.3, true)

static func _draw_ore(world: Node2D, cell: Vector2i, kind: String, light: float) -> void:
	var p := Grid.to_world(cell)
	var shift := float(posmod(cell.x * 13 + cell.y * 7, 8))
	var ink := DARK.lerp(Cargo.COLORS[kind], light)
	world.draw_colored_polygon(PackedVector2Array([p + Vector2(5, 31 - shift), p + Vector2(12 + shift, 9), p + Vector2(24, 5 + shift), p + Vector2(32, 19), p + Vector2(21, 33)]), ink)
	world.draw_polyline(PackedVector2Array([p + Vector2(11, 28), p + Vector2(18, 16), p + Vector2(28, 12)]), ink.lightened(light * 0.28), 2, true)
