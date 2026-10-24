extends RefCounted

static func pockets(seed_value: int) -> Array:
	var shift := posmod(seed_value, 3)
	return [
		{"id": "gas_west", "kind": "gas", "origin": Vector2i(-9 - shift, 2), "size": Vector2i(2, 2)},
		{"id": "water_east", "kind": "water", "origin": Vector2i(3 + shift, 3), "size": Vector2i(2, 2)}
	]

static func cells(pocket: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size: Vector2i = pocket["size"]
	var origin: Vector2i = pocket["origin"]
	for y in range(size.y):
		for x in range(size.x):
			result.append(origin + Vector2i(x, y))
	return result
