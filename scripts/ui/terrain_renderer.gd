extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const DARK := Color("030509")
static var rock_atlas: Texture2D = load("res://assets/terrain/rock-atlas-v1.png")
static var noises: Dictionary = {}

static func field(point: Vector2, seed: int) -> float:
	if not noises.has(seed):
		var noise := FastNoiseLite.new()
		noise.seed = seed
		noise.frequency = 0.005
		noises[seed] = noise
	return noises[seed].get_noise_2d(point.x, point.y)

static func surface_uv(point: Vector2, seed: int, layer: int) -> Vector2:
	var warp := Vector2(field(point, seed), field(point + Vector2(931, 207), seed)) * 65
	return warped_uv(point, warp, layer)

static func warped_uv(point: Vector2, warp: Vector2, layer: int) -> Vector2:
	var scale := Vector2(310, 270) if layer % 2 == 0 else Vector2(527, 443)
	var coordinate := (point + warp) / scale + Vector2(0.17, 0.31) * layer
	return Vector2(1.0 - absf(fposmod(coordinate.x, 2.0) - 1.0), 1.0 - absf(fposmod(coordinate.y, 2.0) - 1.0))

static func geology(point: Vector2, seed: int) -> float:
	return smoothstep(80, 470, point.y + field(point, seed) * 330)

static func hidden_pockets(world: Node2D) -> Dictionary:
	var key := [world.site.get_instance_id(), world.site.terrain_seed, world.site.layout_version, world.site.HazardLayout.gas_pockets_enabled]
	var cache: Dictionary = world.get_meta("terrain_pockets", {})
	if cache.get("key") == key and cache.released == world.environment.released:
		return cache.hidden
	var hidden := {}
	for pocket: Dictionary in world.site.pockets():
		if pocket.kind == "water" or world.environment.released.has(pocket.id):
			continue
		for cell: Vector2i in world.site.HazardLayout.cells(pocket):
			hidden[cell] = pocket.kind
	world.set_meta("terrain_pockets", {"key": key, "released": world.environment.released.duplicate(), "hidden": hidden})
	return hidden

static func _prepare_cache(cache: Dictionary, seed: int) -> void:
	var atlas_key := [rock_atlas.get_instance_id(), rock_atlas.get_size()]
	if cache.get("seed") != seed or cache.get("atlas") != atlas_key:
		cache.clear()
		cache.merge({"seed": seed, "atlas": atlas_key, "cells": {}, "vertices": {}})

static func cached_cell(cache: Dictionary, cell: Vector2i, seed: int) -> Dictionary:
	_prepare_cache(cache, seed)
	if cache.cells.has(cell):
		return cache.cells[cell]
	var facets := facets_for(cell, seed)
	var points := PackedVector2Array([facets[0][0], facets[1][0], facets[2][0], facets[3][0], facets[0][2]])
	var uvs: Array = []
	var alphas: Array = []
	var atlas_size := Vector2(rock_atlas.get_size())
	var tile_size := atlas_size / 4.0
	for layer in range(4):
		uvs.append(PackedVector2Array())
		alphas.append(PackedFloat32Array())
	for point: Vector2 in points:
		if not cache.vertices.has(point):
			var sample := field(point, seed)
			var blend := smoothstep(80, 470, point.y + sample * 330)
			var warp := Vector2(sample, field(point + Vector2(931, 207), seed)) * 65
			var weights := [1.0, 0.28 + field(point + Vector2(310, 0), seed) * 0.2, blend, blend * 0.35]
			var coordinates := PackedVector2Array()
			for layer in range(4):
				coordinates.append((Vector2(layer % 2 * 2, layer / 2) * tile_size + Vector2(8, 8) + warped_uv(point, warp, layer) * (tile_size - Vector2(16, 16))) / atlas_size)
			cache.vertices[point] = {"uvs": coordinates, "alphas": weights}
		var vertex: Dictionary = cache.vertices[point]
		for layer in range(4):
			uvs[layer].append(vertex.uvs[layer])
			alphas[layer].append(vertex.alphas[layer])
	var result := {"points": points, "indices": PackedInt32Array([0, 1, 4, 1, 2, 4, 2, 3, 4, 3, 0, 4]), "uvs": uvs, "alphas": alphas, "base": Color("a45148").lerp(Color("746b7a"), geology(Grid.center(cell), seed))}
	cache.cells[cell] = result
	return result

static func cached_batch(cache: Dictionary, cells: Array, seed: int) -> Dictionary:
	_prepare_cache(cache, seed)
	if cache.has("batch") and cache.batch.cells == cells:
		return cache.batch
	var batch := {"cells": cells.duplicate(), "points": PackedVector2Array(), "indices": PackedInt32Array(), "uvs": [], "alphas": [], "dark_colors": []}
	var vertex_indices := {}
	for layer in range(4):
		batch.uvs.append(PackedVector2Array())
		batch.alphas.append(PackedFloat32Array())
		batch.dark_colors.append(PackedColorArray())
	for cell: Vector2i in cells:
		var geometry := cached_cell(cache, cell, seed)
		var local_indices := PackedInt32Array()
		for local in range(geometry.points.size()):
			var point: Vector2 = geometry.points[local]
			if not vertex_indices.has(point):
				vertex_indices[point] = batch.points.size()
				batch.points.append(point)
				for layer in range(4):
					var alpha: float = geometry.alphas[layer][local]
					batch.uvs[layer].append(geometry.uvs[layer][local])
					batch.alphas[layer].append(alpha)
					batch.dark_colors[layer].append(Color(DARK, alpha))
			local_indices.append(vertex_indices[point])
		for index: int in geometry.indices:
			batch.indices.append(local_indices[index])
	cache.batch = batch
	return batch

static func _draw_rocks(world: Node2D, batch: Dictionary, lighting: Dictionary) -> void:
	if batch.points.is_empty():
		return
	var colors: Array = []
	for dark_colors: PackedColorArray in batch.dark_colors:
		colors.append(dark_colors.duplicate())
	for index in range(batch.points.size()):
		var light := _light(world, lighting, batch.points[index])
		if light == 0.0:
			continue
		var tint := DARK.lerp(Color.WHITE, light)
		for layer in range(4):
			colors[layer][index] = Color(tint, batch.alphas[layer][index])
	# Cell interiors do not overlap. Retain their original triangles while
	# grouping atlas layers; the decorative edges still draw in the final pass.
	for layer in range(4):
		RenderingServer.canvas_item_add_triangle_array(world.get_canvas_item(), batch.indices, batch.points, colors[layer], batch.uvs[layer], PackedInt32Array(), PackedFloat32Array(), rock_atlas.get_rid())

static func _light(world: Node2D, lighting: Dictionary, point: Vector2) -> float:
	if not lighting.has(point):
		lighting[point] = world._illumination(point)
	return lighting[point]

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

static func edge_profile(cell: Vector2i, side: int, seed: int) -> PackedVector2Array:
	var p := Grid.to_world(cell)
	var a: Vector2 = [Vector2(0, 0), Vector2(40, 0), Vector2(40, 40), Vector2(0, 40)][side]
	var b: Vector2 = [Vector2(40, 0), Vector2(40, 40), Vector2(0, 40), Vector2(0, 0)][side]
	var outward := Vector2([Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][side])
	var profile := PackedVector2Array()
	for fraction: float in [0.0, 0.14, 0.31, 0.51, 0.69, 0.87, 1.0]:
		var point := p + a.lerp(b, fraction)
		var hash_value := absi(roundi(point.x * 10) * 73856093 ^ roundi(point.y * 10) * 19349663 ^ seed * 83492791)
		var depth := 1.0 + float(hash_value % 1024) / 1023.0 * 3.8
		profile.append(point + outward * depth)
	return profile

static func draw(world: Node2D) -> void:
	world.draw_rect(Rect2(-4000, 0, 8000, 3000), DARK)
	var center: Vector2 = world.camera.get_screen_center_position()
	var size: Vector2 = world.get_viewport_rect().size / world.camera.zoom
	var visible := Rect2(center - size * 0.5, size).grow(60)
	var lighting := {}
	var cache: Dictionary = world.get_meta("terrain_geometry", {})
	world.set_meta("terrain_geometry", cache)
	var hidden := hidden_pockets(world)
	var rock_cells: Array = []
	var exposed_edges: Array = []
	var grid_cells: Array = []
	for y in range(maxi(0, floori(visible.position.y / 40)), mini(world.site.DEPTH, ceili(visible.end.y / 40))):
		for x in range(maxi(world.site.LEFT, floori(visible.position.x / 40)), mini(world.site.RIGHT, ceili(visible.end.x / 40))):
			var cell := Vector2i(x, y)
			var rect := Grid.rect(cell)
			if not rect.intersects(visible):
				continue
			var kind: String = world.site.material(cell)
			if hidden.has(cell):
				kind = "stone"
			var light := _light(world, lighting, rect.get_center())
			if kind.is_empty():
				var corners := PackedVector2Array([rect.position, rect.position + Vector2(40, 0), rect.end, rect.position + Vector2(0, 40)])
				var inks := PackedColorArray()
				for point: Vector2 in corners:
					inks.append(DARK.lerp(Color("41444c"), _light(world, lighting, point) * 0.85))
				world.draw_polygon(corners, inks)
			else:
				rock_cells.append(cell)
				if light > 0.08:
					exposed_edges.append({"cell": cell, "light": light})
			if world.show_grid and light > 0.15:
				grid_cells.append({"rect": rect, "light": light})
	_draw_rocks(world, cached_batch(cache, rock_cells, world.site.terrain_seed), lighting)
	# Decorate after all air cells, so their backgrounds cannot erase the silhouette.
	for entry: Dictionary in exposed_edges:
		if world.site.exposed(entry.cell) and not world.site.pure_vein(entry.cell).is_empty():
			var kind: String = world.site.material(entry.cell)
			world.draw_colored_polygon(PackedVector2Array(cache.cells[entry.cell].points.slice(0, 4)), Color(Cargo.COLORS[kind], entry.light * 0.38))
		_draw_edges(world, entry.cell, cache.cells[entry.cell].base, entry.light, hidden)
	for entry: Dictionary in grid_cells:
		world.draw_rect(entry.rect, Color(0.65, 0.7, 0.73, entry.light * 0.2), false, 1)

static func _draw_edges(world: Node2D, cell: Vector2i, base: Color, light: float, hidden: Dictionary = {}) -> void:
	var p := Grid.to_world(cell)
	var hash_value := absi(cell.x * 97 + cell.y * 61)
	for side in range(4):
		var offset: Vector2i = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][side]
		if not world.site.material(cell + offset).is_empty() or hidden.has(cell + offset):
			continue
		var a: Vector2 = [Vector2(0, 0), Vector2(40, 0), Vector2(40, 40), Vector2(0, 40)][side]
		var b: Vector2 = [Vector2(40, 0), Vector2(40, 40), Vector2(0, 40), Vector2(0, 0)][side]
		var profile := edge_profile(cell, side, world.site.terrain_seed)
		var strip := PackedVector2Array([p + a, p + b])
		for index in range(profile.size() - 1, -1, -1):
			strip.append(profile[index])
		var edge_ink := DARK.lerp(base.lightened(0.2 if side == 0 else -0.15), light * 0.9)
		world.draw_colored_polygon(strip, edge_ink)
		world.draw_polyline(profile, DARK.lerp(base.darkened(0.3), light), 1.0, true)
		var inward := Vector2(-offset) * (3 + hash_value % 6)
		var ridge := p + a.lerp(b, 0.25 + (hash_value % 40) * 0.01) + inward
		world.draw_colored_polygon(PackedVector2Array([p + a, p + b, ridge]), edge_ink)

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
