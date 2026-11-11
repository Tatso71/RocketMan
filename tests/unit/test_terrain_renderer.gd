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
