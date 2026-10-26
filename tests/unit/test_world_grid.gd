extends GdUnitTestSuite

const Grid = preload("res://scripts/world/world_grid.gd")

func test_cell_is_one_metre_and_round_trips() -> void:
	assert_float(Grid.metres(1)).is_equal(40.0)
	for y in range(-12, 25):
		for x in range(-24, 25):
			var cell := Vector2i(x, y)
			assert_vector(Grid.to_cell(Grid.center(cell))).is_equal(cell)
	assert_vector(Grid.rect(Vector2i(2, 3)).size).is_equal(Vector2(40, 40))

func test_negative_coordinates_floor_instead_of_truncate() -> void:
	assert_vector(Grid.to_cell(Vector2(-0.1, -40.1))).is_equal(Vector2i(-1, -2))
	assert_vector(Grid.to_cell(Vector2(-40, 0))).is_equal(Vector2i(-1, 0))

func test_player_fits_two_metre_tunnel() -> void:
	assert_float(Grid.PLAYER_HEIGHT_METRES).is_less(2.0)
	assert_float(Grid.PLAYER_WIDTH_METRES).is_less(1.0)
	assert_int(Grid.ROOM_HEIGHT).is_equal(3)
	for index in range(1, Grid.ROCKET_FLOORS.size()):
		assert_int(Grid.ROCKET_FLOORS[index] - Grid.ROCKET_FLOORS[index - 1]).is_equal(Grid.ROOM_HEIGHT)
	assert_int(Grid.ROCKET_FLOORS[0] - Grid.ROCKET_CEILING).is_equal(Grid.ROOM_HEIGHT)

func test_saved_cells_must_be_integral_and_finite() -> void:
	assert_vector(Grid.decode_cell([2.0, -3.0])).is_equal(Vector2i(2, -3))
	assert_that(Grid.decode_cell([1.2, 3])).is_null()
	assert_that(Grid.decode_cell([INF, 0])).is_null()
	assert_that(Grid.decode_cell(["2", 3])).is_null()
