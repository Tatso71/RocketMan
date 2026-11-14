extends GdUnitTestSuite

const PipeUI = preload("res://scripts/ui/industry_ui.gd")

func test_strokes_are_cardinal_connected_complete_in_all_directions() -> void:
	var first := Vector2i(-8, 3)
	for x in range(-6, 7):
		for y in range(-6, 7):
			var last := first + Vector2i(x, y)
			var path := PipeUI.stroke_cells(first, last)
			assert_vector(path.front()).is_equal(first)
			assert_vector(path.back()).is_equal(last)
			assert_int(path.size()).is_equal(absi(x) + absi(y) + 1)
			for index in range(1, path.size()):
				var delta: Vector2i = path[index] - path[index - 1]
				assert_int(absi(delta.x) + absi(delta.y)).is_equal(1)

func test_huge_outside_world_pointer_jump_is_bounded() -> void:
	assert_array(PipeUI.stroke_cells(Vector2i.ZERO, Vector2i(2000000000, 0))).is_empty()
	assert_array(PipeUI.stroke_cells(Vector2i.ZERO, Vector2i.ZERO)).is_equal([Vector2i.ZERO])
