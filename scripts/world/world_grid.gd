extends RefCounted

# Integer cells are the source of truth; rendering converts metres to pixels.
const CELL_METRES := 1.0
const PIXELS_PER_METRE := 40
const CELL_SIZE := 40
const ROOM_HEIGHT := 3
const ROCKET_HALF_WIDTH := 4
const ROCKET_FLOORS := [-8, -5, -2]
const ROCKET_CEILING := -11
const PLAYER_HEIGHT_METRES := 1.6
const PLAYER_WIDTH_METRES := 0.6

static func to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))

static func to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE

static func center(cell: Vector2i) -> Vector2:
	return to_world(cell) + Vector2.ONE * CELL_SIZE * 0.5

static func rect(cell: Vector2i) -> Rect2:
	return Rect2(to_world(cell), Vector2.ONE * CELL_SIZE)

static func metres(value: float) -> float:
	return value * PIXELS_PER_METRE

static func decode_cell(value: Variant) -> Variant:
	if not value is Array or value.size() != 2:
		return null
	for coordinate in value:
		if not (coordinate is int or coordinate is float):
			return null
		var number := float(coordinate)
		if not is_finite(number) or number != floorf(number) or number < -2147483648.0 or number > 2147483647.0:
			return null
	return Vector2i(int(value[0]), int(value[1]))
