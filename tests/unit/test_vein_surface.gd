extends GdUnitTestSuite

var Renderer = load("res://scripts/ui/terrain_renderer.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const PATH := "res://scripts/ui/vein_surface.gd"
const VEIN := {"id": "fixture", "kind": "copper", "origin": Vector2i(-3, 4), "rows": ["###", "###"], "size": Vector2i(3, 2)}

func _surface() -> Variant:
	assert_bool(ResourceLoader.exists(PATH)).is_true()
	return load(PATH) if ResourceLoader.exists(PATH) else null

func test_seeded_geometry_is_reused_and_recreated_deterministically() -> void:
	var surface = _surface()
	if surface == null: return
	var cache := {}
	var first: Dictionary = surface.cached_vein(cache, VEIN, 0)
	assert_bool(is_same(first, surface.cached_vein(cache, VEIN, 0))).is_true()
	assert_int(first.cells.size()).is_equal(6)
	assert_dict(first).is_equal(surface.cached_vein({}, VEIN, 0))
	var changed: Dictionary = surface.cached_vein(cache, VEIN, 11)
	assert_bool(first.cells[Vector2i(-3, 4)].points == changed.cells[Vector2i(-3, 4)].points).is_false()
	assert_dict(first).is_equal(surface.cached_vein(cache, VEIN, 0))

func test_triangles_leave_host_rock_visible_and_clip_to_the_irregular_mask() -> void:
	var surface = _surface()
	if surface == null: return
	var description := VEIN.duplicate(true)
	description.rows = [".##", "##."]
	var geometry: Dictionary = surface.cached_vein({}, description, 0)
	assert_bool(geometry.cells.has(Vector2i(-3, 4))).is_false()
	assert_bool(geometry.cells.has(Vector2i(-1, 5))).is_false()
	var area := 0.0
	for cell: Vector2i in geometry.cells:
		var data: Dictionary = geometry.cells[cell]
		assert_int(data.points.size()).is_greater(0)
		assert_int(data.points.size()).is_less(1800)
		assert_int(data.colors.size()).is_equal(data.points.size())
		var rect := Rect2(Vector2(cell) * 40, Vector2(40, 40)).grow(0.001)
		for point: Vector2 in data.points:
			assert_bool(rect.has_point(point)).is_true()
		for i in range(0, data.indices.size(), 3):
			var a: Vector2 = data.points[data.indices[i]]
			var b: Vector2 = data.points[data.indices[i + 1]]
			var c: Vector2 = data.points[data.indices[i + 2]]
			area += absf((b - a).cross(c - a)) * 0.5
	assert_float(area).is_greater(500.0)
	# Includes overlapping shadow/ridge layers, so this is a conservative bound.
	assert_float(area).is_less(4 * 1600.0)

func test_adjacent_cells_share_identical_mineral_cross_sections() -> void:
	var surface = _surface()
	if surface == null: return
	var geometry: Dictionary = surface.cached_vein({}, VEIN, 0)
	var left := _boundary(geometry.cells[Vector2i(-3, 4)], 0, -80)
	var right := _boundary(geometry.cells[Vector2i(-2, 4)], 0, -80)
	assert_int(left.size()).is_greater(2)
	assert_array(left).is_equal(right)
	var top := _boundary(geometry.cells[Vector2i(-2, 4)], 1, 200)
	var bottom := _boundary(geometry.cells[Vector2i(-2, 5)], 1, 200)
	assert_int(top.size()).is_greater(2)
	assert_array(top).is_equal(bottom)

func _boundary(data: Dictionary, axis: int, coordinate: float) -> Array:
	var values := []
	for point: Vector2 in data.points:
		if absf(point[axis] - coordinate) < 0.001:
			var value := roundi(point[1 - axis] * 100)
			if not values.has(value): values.append(value)
	values.sort()
	return values

func test_vein_cache_invalidates_edited_mask_origin_and_kind() -> void:
	var surface = _surface()
	if surface == null: return
	var cache := {}
	var first: Dictionary = surface.cached_vein(cache, VEIN, 0)
	var description := VEIN.duplicate(true)
	description.rows = [".##", "###"]
	var cut: Dictionary = surface.cached_vein(cache, description, 0)
	assert_bool(cut.cells.has(Vector2i(-3, 4))).is_false()
	description.origin = Vector2i(5, 9)
	var moved: Dictionary = surface.cached_vein(cache, description, 0)
	assert_bool(moved.cells.has(Vector2i(-2, 4))).is_false()
	assert_bool(moved.cells.has(Vector2i(6, 9))).is_true()
	description.kind = "crystal"
	var recolored: Dictionary = surface.cached_vein(cache, description, 0)
	assert_bool(moved.cells[Vector2i(6, 9)].colors == recolored.cells[Vector2i(6, 9)].colors).is_false()
	assert_bool(first.cells.has(Vector2i(-3, 4))).is_true()

func test_visible_batch_excludes_buried_dark_hidden_and_destroyed_ore() -> void:
	assert_bool(Renderer.has_method("cached_vein_batch")).is_true()
	if not Renderer.has_method("cached_vein_batch"): return
	var site := Site.new()
	var cache := {}
	var cell := Vector2i(-22, 4)
	var candidates := [cell, Vector2i(18, 20), Vector2i(-4, 1)]
	var lit := func(_point: Vector2) -> float: return 1.0
	var dark := func(_point: Vector2) -> float: return 0.0
	assert_int(Renderer.cached_vein_batch(cache, site, candidates, lit).points.size()).is_equal(0)

	site.removed[cell + Vector2i.UP] = true
	var exposed: Dictionary = Renderer.cached_vein_batch(cache, site, candidates, lit)
	assert_array(exposed.cells).is_equal([cell])
	assert_int(exposed.points.size()).is_greater(0)
	assert_bool(is_same(exposed, Renderer.cached_vein_batch(cache, site, candidates, lit))).is_true()
	assert_int(Renderer.cached_vein_batch(cache, site, candidates, dark).points.size()).is_equal(0)
	assert_int(Renderer.cached_vein_batch(cache, site, candidates, lit, {cell: "acid"}).points.size()).is_equal(0)
	assert_str(site.mine(cell, 10)).is_equal("copper")
	assert_int(Renderer.cached_vein_batch(cache, site, candidates, lit).points.size()).is_equal(0)

func test_exposed_ordinary_rock_never_requests_extra_mineral_lighting() -> void:
	var site := Site.new()
	var cell := Vector2i(-4, 1)
	site.removed[cell + Vector2i.UP] = true
	var calls := {"count": 0}
	var lit := func(_point: Vector2) -> float:
		calls.count += 1
		return 1.0
	assert_int(Renderer.cached_vein_batch({}, site, [cell], lit).points.size()).is_equal(0)
	assert_int(calls.count).is_equal(0)

func test_batch_rebuilds_for_same_count_different_cells_site_seed_and_layout() -> void:
	assert_bool(Renderer.has_method("cached_vein_batch")).is_true()
	if not Renderer.has_method("cached_vein_batch"): return
	var site := Site.new()
	var cache := {}
	var lit := func(_point: Vector2) -> float: return 1.0
	site.removed[Vector2i(-22, 3)] = true
	site.removed[Vector2i(-21, 3)] = true
	var first: Dictionary = Renderer.cached_vein_batch(cache, site, [Vector2i(-22, 4)], lit)
	var second: Dictionary = Renderer.cached_vein_batch(cache, site, [Vector2i(-21, 4)], lit)
	assert_bool(first.points == second.points).is_false()
	var replacement := Site.new()
	replacement.removed[Vector2i(-21, 3)] = true
	assert_bool(is_same(second, Renderer.cached_vein_batch(cache, replacement, [Vector2i(-21, 4)], lit))).is_false()
	var before_seed: Dictionary = Renderer.cached_vein_batch(cache, replacement, [Vector2i(-21, 4)], lit)
	replacement.terrain_seed = 11
	var after_seed: Dictionary = Renderer.cached_vein_batch(cache, replacement, [Vector2i(-21, 4)], lit)
	assert_bool(before_seed.points == after_seed.points).is_false()
	replacement.layout_version += 1
	assert_bool(is_same(after_seed, Renderer.cached_vein_batch(cache, replacement, [Vector2i(-21, 4)], lit))).is_false()

class LightWorld extends Node2D:
	var calls := 0
	var level := 1.0
	func _illumination(_point: Vector2) -> float:
		calls += 1
		return level

func test_live_ore_lighting_reuses_rock_corner_samples_not_per_facet_queries() -> void:
	assert_bool(Renderer.has_method("lit_vein_colors")).is_true()
	if not Renderer.has_method("lit_vein_colors"): return
	var site := Site.new()
	site.removed[Vector2i(-22, 3)] = true
	var batch: Dictionary = Renderer.cached_vein_batch({}, site, [Vector2i(-22, 4)], func(_p: Vector2) -> float: return 1.0)
	var world := LightWorld.new()
	var lighting := {}
	var lit: PackedColorArray = Renderer.lit_vein_colors(world, batch, lighting)
	assert_int(world.calls).is_less_equal(4)
	for index in range(lit.size()):
		assert_bool(lit[index].is_equal_approx(batch.colors[index])).is_true()
	world.level = 0
	var dark: PackedColorArray = Renderer.lit_vein_colors(world, batch, {})
	for ink: Color in dark: assert_float(ink.a).is_equal(0.0)
	world.level = 1
	world.calls = 0
	for point: Vector2 in batch.light_points: lighting[point] = 0.0
	var reused: PackedColorArray = Renderer.lit_vein_colors(world, batch, lighting)
	assert_int(world.calls).is_equal(0)
	for ink: Color in reused: assert_float(ink.a).is_equal(0.0)
	world.free()
