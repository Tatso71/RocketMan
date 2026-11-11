extends GdUnitTestSuite

const PATH := "res://scripts/ui/terrain_renderer.gd"

func test_facets_are_deterministic_and_stay_inside_the_metric_cell() -> void:
	assert_bool(ResourceLoader.exists(PATH)).is_true()
	if not ResourceLoader.exists(PATH):
		return
	var renderer = load(PATH)
	var cell := Vector2i(-3, 7)
	var first: Array = renderer.facets_for(cell, 0)
	assert_int(first.size()).is_greater_equal(3)
	assert_array(first).is_equal(renderer.facets_for(cell, 0))
	assert_bool(first == renderer.facets_for(cell, 11)).is_false()
	for facet: PackedVector2Array in first:
		for point: Vector2 in facet:
			assert_bool(point.x >= -120 and point.x <= -80 and point.y >= 280 and point.y <= 320).is_true()

func test_exposed_profiles_extend_only_a_few_visual_pixels_outside_the_cell() -> void:
	var renderer = load(PATH)
	assert_bool(renderer.has_method("edge_profile")).is_true()
	if not renderer.has_method("edge_profile"): return
	var cell := Vector2i(-3, 7)
	var rect := Rect2(Vector2(-120, 280), Vector2(40, 40))
	for side in range(4):
		var points: PackedVector2Array = renderer.edge_profile(cell, side, 0)
		assert_int(points.size()).is_greater_equal(5)
		assert_array(Array(points)).is_equal(Array(renderer.edge_profile(cell, side, 0)))
		assert_bool(points == renderer.edge_profile(cell, side, 11)).is_false()
		var protrudes := false
		for point: Vector2 in points:
			assert_bool(rect.grow(5.01).encloses(Rect2(point, Vector2.ZERO))).is_true()
			protrudes = protrudes or not rect.has_point(point)
		assert_bool(protrudes).is_true()
	assert_vector(renderer.edge_profile(cell, 0, 0)[-1]).is_equal(renderer.edge_profile(cell + Vector2i.RIGHT, 0, 0)[0])

func test_static_geometry_reuses_noise_but_invalidates_for_a_new_seed() -> void:
	var renderer = load(PATH)
	assert_bool(renderer.has_method("cached_cell")).is_true()
	if not renderer.has_method("cached_cell"):
		return
	var cache := {}
	var cell := Vector2i(-3, 7)
	var first: Dictionary = renderer.cached_cell(cache, cell, 0)
	assert_bool(is_same(first, renderer.cached_cell(cache, cell, 0))).is_true()
	assert_int(first.points.size()).is_equal(5)
	assert_int(first.indices.size()).is_equal(12)
	var changed: Dictionary = renderer.cached_cell(cache, cell, 11)
	assert_bool(first.points == changed.points).is_false()
	assert_bool(first.uvs == changed.uvs).is_false()
	assert_int(cache.cells.size()).is_equal(1)
	assert_bool(is_same(changed, renderer.cached_cell(cache, cell, 11))).is_true()
	assert_bool(first.points == renderer.cached_cell(cache, cell, 0).points).is_true()

func test_cached_uvs_keep_world_space_continuity_and_atlas_padding() -> void:
	var renderer = load(PATH)
	assert_bool(renderer.has_method("cached_cell")).is_true()
	if not renderer.has_method("cached_cell"):
		return
	var cache := {}
	var left: Dictionary = renderer.cached_cell(cache, Vector2i(-1, 3), 0)
	var right: Dictionary = renderer.cached_cell(cache, Vector2i(0, 3), 0)
	for layer in range(4):
		assert_vector(left.uvs[layer][1]).is_equal(right.uvs[layer][0])
		assert_vector(left.uvs[layer][2]).is_equal(right.uvs[layer][3])
		for uv: Vector2 in left.uvs[layer]:
			assert_bool(uv.x > 0 and uv.x < 1 and uv.y > 0 and uv.y < 1).is_true()

func test_batch_cache_rebuilds_for_same_count_different_cells_and_seed() -> void:
	var renderer = load(PATH)
	assert_bool(renderer.has_method("cached_batch")).is_true()
	if not renderer.has_method("cached_batch"):
		return
	var cache := {}
	var cells := [Vector2i(-3, 4), Vector2i(-2, 4)]
	var first: Dictionary = renderer.cached_batch(cache, cells, 0)
	assert_bool(is_same(first, renderer.cached_batch(cache, cells, 0))).is_true()
	assert_int(first.points.size()).is_equal(8)
	assert_int(first.indices.size()).is_equal(24)
	assert_vector(first.points[0]).is_equal(Vector2(-120, 160))
	assert_int(first.indices[1]).is_equal(first.indices[12])
	assert_int(first.indices[4]).is_equal(first.indices[19])
	cells[1] = Vector2i(-1, 4)
	var edited: Dictionary = renderer.cached_batch(cache, cells, 0)
	assert_vector(edited.points[5]).is_equal(Vector2(-40, 160))
	assert_bool(is_same(first, edited)).is_false()
	var reseeded: Dictionary = renderer.cached_batch(cache, cells, 11)
	assert_bool(edited.points == reseeded.points).is_false()
	assert_bool(edited.uvs == reseeded.uvs).is_false()

class PocketWorld extends Node2D:
	var site = preload("res://scripts/systems/dig_site.gd").new()
	var environment = preload("res://scripts/systems/environment_field.gd").new(site)

func test_pocket_cache_tracks_release_keys_seed_layout_and_site_replacement() -> void:
	var renderer = load(PATH)
	var world := PocketWorld.new()
	var original: Dictionary = renderer.hidden_pockets(world)
	assert_bool(original.has(Vector2i(3, 3))).is_false()
	assert_bool(original.has(Vector2i(-20, 12))).is_true()
	world.environment.released["water_east"] = true
	assert_bool(renderer.hidden_pockets(world).has(Vector2i(3, 3))).is_false()
	world.environment.released = {"acid_west": true}
	assert_bool(renderer.hidden_pockets(world).has(Vector2i(3, 3))).is_false()
	assert_bool(renderer.hidden_pockets(world).has(Vector2i(-20, 12))).is_false()
	world.environment.released.clear()
	world.site.terrain_seed = 1
	assert_bool(renderer.hidden_pockets(world).has(Vector2i(3, 3))).is_false()
	assert_bool(renderer.hidden_pockets(world).has(Vector2i(5, 3))).is_false()
	world.site.terrain_seed = 0
	world.site.layout_version = 0
	assert_bool(renderer.hidden_pockets(world).has(Vector2i(-20, 12))).is_false()
	world.site = preload("res://scripts/systems/dig_site.gd").new()
	assert_bool(renderer.hidden_pockets(world).has(Vector2i(-20, 12))).is_true()
	world.free()
