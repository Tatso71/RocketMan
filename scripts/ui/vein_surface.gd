extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
# Shadow, lower face, upper face, narrow mineral cleavage. No emissive colors.
const PALETTES := {
	"copper": [Color("60392f"), Color("aa603e"), Color("db945b"), Color("f4c78a")],
	"iron": [Color("343a42"), Color("69777d"), Color("a9b7b9"), Color("dce4dd")],
	"crystal": [Color("244c50"), Color("368a8d"), Color("76c6bf"), Color("c5eee1")],
	"silica": [Color("645d6c"), Color("afa7b6"), Color("d7d1ce"), Color("faf0df")],
	"cobalt": [Color("29344c"), Color("3c5897"), Color("728fce"), Color("bacded")]
}

static func cached_vein(cache: Dictionary, vein: Dictionary, seed: int) -> Dictionary:
	if cache.get("seed") != seed:
		cache.clear()
		cache.merge({"seed": seed, "veins": {}})
	var id: String = vein.id
	if cache.veins.has(id) and cache.veins[id].description == vein:
		return cache.veins[id].geometry
	var result := _build(vein, seed)
	cache.veins[id] = {"description": vein.duplicate(true), "geometry": result}
	return result

static func empty_batch() -> Dictionary:
	return {"cells": [], "points": PackedVector2Array(), "indices": PackedInt32Array(), "colors": PackedColorArray()}

static func append_geometry(batch: Dictionary, data: Dictionary) -> void:
	var offset: int = batch.points.size()
	batch.points.append_array(data.points)
	batch.colors.append_array(data.colors)
	for index: int in data.indices:
		batch.indices.append(index + offset)

static func _build(vein: Dictionary, seed: int) -> Dictionary:
	var cells := {}
	for y in range(vein.rows.size()):
		for x in range(vein.rows[y].length()):
			if vein.rows[y][x] == "#":
				cells[vein.origin + Vector2i(x, y)] = empty_batch()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ String(vein.id).hash() ^ (vein.origin.x * 73856093) ^ (vein.origin.y * 19349663)
	var origin := Grid.to_world(vein.origin)
	var size := Vector2(vein.rows[0].length(), vein.rows.size()) * Grid.CELL_SIZE
	var palette: Array = PALETTES[vein.kind]
	var phase := rng.randf_range(-PI, PI)
	var source: Array = []
	# All strands are constructed across the WHOLE deposit before cell clipping.
	# Shared source triangles preserve color and cross-section at cell boundaries.
	for strand in range(3):
		var path := PackedVector2Array()
		var widths := PackedFloat32Array()
		for step in range(ceili(size.x / 12.0) + 3):
			var x := float(step * 12 - 12)
			var y := size.y * 0.5 + (x - size.x * 0.5) * 0.32
			y += (strand - 1) * 32 + sin(x * 0.037 + phase + strand * 0.6) * 10
			y += rng.randf_range(-3.2, 3.2)
			path.append(origin + Vector2(x, y))
			widths.append(rng.randf_range(2.7, 5.8))
		_ribbon(source, path, widths, palette)
		# A thin fork rejoins the adjacent seam rather than forming a crystal spike.
		if strand == 1:
			var branch := PackedVector2Array()
			var branch_widths := PackedFloat32Array()
			for index in range(2, path.size() - 2):
				var fraction := float(index - 2) / float(path.size() - 5)
				branch.append(path[index] + Vector2(0, -sin(fraction * PI) * 27))
				branch_widths.append(1.1 + sin(fraction * PI) * 1.1)
			_ribbon(source, branch, branch_widths, palette)
	# Small, flat lenticular inclusions break up the host rock between the seams.
	for inclusion in range(ceili(size.x / 9.0)):
		var p := origin + Vector2(rng.randf_range(4, size.x - 4), rng.randf_range(4, size.y - 4))
		var length := rng.randf_range(3, 8)
		var a := p - Vector2(length, length * 0.3)
		var b := p + Vector2(length, length * 0.3)
		_triangle(source, a, p + Vector2(1, -2.1), b, Color(palette[2], 0.86))
		_triangle(source, a, b, p + Vector2(-1, 2.3), Color(palette[1], 0.9))
	for cell: Vector2i in cells:
		var rect := Grid.rect(cell)
		var mask := PackedVector2Array([rect.position, rect.position + Vector2(40, 0), rect.end, rect.position + Vector2(0, 40)])
		var data: Dictionary = cells[cell]
		for face: Array in source:
			var triangle: PackedVector2Array = face[0]
			var bounds := Rect2(triangle[0], Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
			if not rect.intersects(bounds): continue
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(triangle, mask):
				var indices := Geometry2D.triangulate_polygon(clipped)
				if indices.is_empty(): continue
				var offset: int = data.points.size()
				data.points.append_array(clipped)
				for point: Vector2 in clipped: data.colors.append(face[1])
				for index: int in indices: data.indices.append(offset + index)
	return {"cells": cells}

static func _ribbon(source: Array, path: PackedVector2Array, widths: PackedFloat32Array, palette: Array) -> void:
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for index in range(path.size()):
		var tangent := path[mini(index + 1, path.size() - 1)] - path[maxi(0, index - 1)]
		var normal := Vector2(tangent.y, -tangent.x).normalized()
		upper.append(path[index] + normal * widths[index])
		lower.append(path[index] - normal * widths[index] * 0.72)
	for index in range(path.size() - 1):
		var a := upper[index]
		var b := upper[index + 1]
		var c := lower[index + 1]
		var d := lower[index]
		var m := path[index]
		var n := path[index + 1]
		var variation := 0.04 * sin(index * 2.7)
		_quad(source, a + Vector2(0, -1.4), b + Vector2(0, -1.4), b, a, Color(palette[0], 0.65))
		_quad(source, d, c, c + Vector2(0, 1.7), d + Vector2(0, 1.7), Color(palette[0], 0.8))
		_triangle(source, a, b, m, Color(palette[2].lightened(variation), 0.94))
		_triangle(source, b, n, m, Color(palette[2].darkened(0.08 - variation), 0.94))
		_triangle(source, m, n, d, Color(palette[1].lightened(variation), 0.95))
		_triangle(source, n, c, d, Color(palette[1].darkened(0.08 + variation), 0.95))
		if index % 3 != 1:
			var glint_start := a.lerp(b, 0.12)
			var glint_end := a.lerp(b, 0.78)
			_quad(source, glint_start, glint_end, glint_end.lerp(n, 0.12), glint_start.lerp(m, 0.12), Color(palette[3], 0.65))

static func _triangle(source: Array, a: Vector2, b: Vector2, c: Vector2, ink: Color) -> void:
	if absf((b - a).cross(c - a)) > 0.001:
		source.append([PackedVector2Array([a, b, c]), ink])

static func _quad(source: Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2, ink: Color) -> void:
	_triangle(source, a, b, c, ink)
	_triangle(source, a, c, d, ink)
