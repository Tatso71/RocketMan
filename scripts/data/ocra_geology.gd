extends RefCounted

# Coordinates are metres/cells, relative to the hatch. The first 8 m retain
# the tutorial's resource distribution; deeper veins invite lateral exploration.
const VEINS := [
	{"kind": "copper", "center": Vector2i(-10, 8), "radius": Vector2(3, 1.6)},
	{"kind": "copper", "center": Vector2i(8, 6), "radius": Vector2(2.5, 1.5)},
	{"kind": "copper", "center": Vector2i(-3, 10), "radius": Vector2(2, 1.5)},
	{"kind": "copper", "center": Vector2i(16, 13), "radius": Vector2(3, 2)},
	{"kind": "crystal", "center": Vector2i(-7, 12), "radius": Vector2(2.5, 1.5)},
	{"kind": "crystal", "center": Vector2i(4, 13), "radius": Vector2(2, 1.6)},
	{"kind": "crystal", "center": Vector2i(-18, 19), "radius": Vector2(2, 2)}
]
const MASSIFS := [Rect2i(-20, 7, 4, 2), Rect2i(10, 8, 5, 1), Rect2i(-11, 14, 5, 2), Rect2i(12, 17, 4, 3)]

static func protected(cell: Vector2i) -> bool:
	for massif: Rect2i in MASSIFS:
		if massif.has_point(cell):
			return true
	return false

static func ore(cell: Vector2i) -> String:
	if absi(cell.x) <= 5 and cell.y <= 8:
		return ""
	for vein: Dictionary in VEINS:
		var offset: Vector2 = Vector2(cell - vein.center) / vein.radius
		if offset.length_squared() <= 1:
			return vein.kind
	return ""

static func component_ore(cell: Vector2i) -> String:
	# Keep crystals on the same early route as copper and iron, before deep hazards.
	if cell in [Vector2i(-5, 2), Vector2i(-5, 3), Vector2i(-4, 4)]:
		return "crystal"
	if cell.y in [2, 3] and cell.x >= -4 and cell.x <= -1:
		return "iron"
	if cell.y == 1 and cell.x >= -4 and cell.x <= -2:
		return "copper"
	if cell == Vector2i(1, 3) or cell == Vector2i(1, 4):
		return "crystal"
	for vein: Dictionary in [
		{"kind": "iron", "center": Vector2i(6, 6), "radius": Vector2(2.5, 1.7)},
		{"kind": "iron", "center": Vector2i(-12, 6), "radius": Vector2(2, 1.5)},
		{"kind": "silica", "center": Vector2i(6, 10), "radius": Vector2(2, 1.5)},
		{"kind": "silica", "center": Vector2i(-14, 7), "radius": Vector2(1.6, 1.2)},
		{"kind": "cobalt", "center": Vector2i(-2, 12), "radius": Vector2(1.5, 1.2)},
		{"kind": "cobalt", "center": Vector2i(19, 11), "radius": Vector2(1.3, 1.5)}
	]:
		if (Vector2(cell - vein.center) / vein.radius).length_squared() <= 1:
			return vein.kind
	return ""
