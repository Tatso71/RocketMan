extends RefCounted

const CURRENT_VERSION := 2

static func pockets(seed_value: int, layout_version: int = CURRENT_VERSION) -> Array:
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
	if seed_value == 0 and layout_version >= 2:
		var shapes := {
			"water_deep": {"origin": Vector2i(-15, 10), "rows": ["..###.", "######", "######", ".####."]},
			"gas_deep": {"origin": Vector2i(10, 10), "rows": [".###.", "#####", "####.", ".##.."]},
			"oil_west": {"origin": Vector2i(-15, 16), "rows": [".####.", "######", "######", ".####."]},
			"oil_east": {"origin": Vector2i(4, 16), "rows": [".###.", "#####", "#####", ".###."]}
		}
		for pocket: Dictionary in result:
			if shapes.has(pocket.id):
				pocket.merge(shapes[pocket.id], true)
				pocket.size = Vector2i(pocket.rows[0].length(), pocket.rows.size())
		result.append({"id": "acid_west", "kind": "acid", "origin": Vector2i(-20, 11), "size": Vector2i(4, 4), "rows": [".##.", "####", "####", ".##."]})
	return result

static func cells(pocket: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size: Vector2i = pocket["size"]
	var origin: Vector2i = pocket["origin"]
	for y in range(size.y):
		for x in range(size.x):
			if not pocket.has("rows") or pocket.rows[y][x] == "#":
				result.append(origin + Vector2i(x, y))
	return result

static func boundary(pocket: Dictionary) -> Array[Vector2i]:
	var occupied := {}
	for cell: Vector2i in cells(pocket):
		occupied[cell] = true
	var result: Array[Vector2i] = []
	for cell: Vector2i in occupied:
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor := cell + offset
			if not occupied.has(neighbor) and neighbor not in result:
				result.append(neighbor)
	return result
