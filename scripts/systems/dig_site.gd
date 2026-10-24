extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const CELL := Grid.CELL_SIZE
const LEFT := -24
const RIGHT := 24
const DEPTH := 24
const COST := {"soil": 1, "stone": 2, "copper": 2, "crystal": 3, "bedrock": 99}
const RESOURCE_YIELDS := {"bedrock": "stone"}
var removed: Dictionary = {}
var damage: Dictionary = {}
var terrain_seed := 0

func _init(seed_value: int = 0) -> void:
	terrain_seed = seed_value
	for y in range(4):
		for x in range(-1, 1):
			removed[Vector2i(x, y)] = true
	for x in range(-5, -1):
		for y in range(2, 4):
			removed[Vector2i(x, y)] = true

func contains(cell: Vector2i) -> bool:
	return cell.x >= LEFT and cell.x < RIGHT and cell.y >= 0 and cell.y < DEPTH

func material(cell: Vector2i) -> String:
	if not contains(cell) or removed.has(cell):
		return ""
	if cell.y >= 15:
		return "bedrock"
	var sample := posmod(cell.x * 37 + cell.y * 73 + terrain_seed, 29)
	if cell.y > 4 and sample < 3:
		return "crystal"
	if cell.y > 1 and sample < 8:
		return "copper"
	return "soil" if cell.y < 5 else "stone"

func exposed(cell: Vector2i) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = cell + offset
		if neighbor.y < 0 or (contains(neighbor) and material(neighbor).is_empty()):
			return true
	return false

func mine(cell: Vector2i, power: int = 1, allow_bedrock: bool = false) -> String:
	var kind := material(cell)
	if kind.is_empty() or (kind == "bedrock" and not allow_bedrock) or not exposed(cell):
		return ""
	damage[cell] = int(damage.get(cell, 0)) + power
	if int(damage[cell]) < int(COST[kind]):
		return ""
	removed[cell] = true
	damage.erase(cell)
	return kind

func snapshot() -> Array:
	var cells: Array = []
	for cell: Vector2i in removed:
		cells.append([cell.x, cell.y])
	return cells

func restore(cells: Array) -> void:
	removed.clear()
	damage.clear()
	for entry in cells:
		var cell = Grid.decode_cell(entry)
		if cell is Vector2i and contains(cell):
			removed[cell] = true
