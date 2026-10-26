extends RefCounted

static func pockets(seed_value: int, layout_version: int = 1) -> Array:
	var shift := posmod(seed_value, 3)
	var result := [
		{"id": "gas_west", "kind": "gas", "origin": Vector2i(-9 - shift, 2), "size": Vector2i(2, 2)},
		{"id": "water_east", "kind": "water", "origin": Vector2i(3 + shift, 3), "size": Vector2i(2, 2)}
	]
	if seed_value == 0 and layout_version >= 1:
		result.append_array([
			{"id": "water_deep", "kind": "water", "origin": Vector2i(-14, 11), "size": Vector2i(3, 2)},
			{"id": "gas_deep", "kind": "gas", "origin": Vector2i(11, 11), "size": Vector2i(2, 2)},
			{"id": "oil_west", "kind": "oil", "origin": Vector2i(-13, 17), "size": Vector2i(3, 2)},
			{"id": "oil_east", "kind": "oil", "origin": Vector2i(6, 16), "size": Vector2i(3, 2)}
		])
	return result

static func cells(pocket: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size: Vector2i = pocket["size"]
	var origin: Vector2i = pocket["origin"]
	for y in range(size.y):
		for x in range(size.x):
			result.append(origin + Vector2i(x, y))
	return result
