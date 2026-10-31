extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const HazardLayout = preload("res://scripts/data/hazard_layout.gd")
const Geology = preload("res://scripts/data/ocra_geology.gd")
const CELL := Grid.CELL_SIZE
const LEFT := -24
const RIGHT := 24
const DEPTH := 24
const COST := {"soil": 1, "stone": 2, "copper": 2, "crystal": 3, "bedrock": 99, "anchor": 0}
const RESOURCE_YIELDS := {"bedrock": "stone"}
const ANCHORS := [Vector2i(-6, 6), Vector2i(-5, 6), Vector2i(-4, 6), Vector2i(7, 7), Vector2i(7, 8)]
var removed: Dictionary = {}
var damage: Dictionary = {}
var terrain_seed := 0
var layout_version := HazardLayout.CURRENT_VERSION

func _init(seed_value: int = 0, version: int = HazardLayout.CURRENT_VERSION) -> void:
	terrain_seed = seed_value
	layout_version = version
	_add_pocket_cavities()

func _add_pocket_cavities() -> void:
	for pocket: Dictionary in pockets():
		for cell: Vector2i in HazardLayout.cells(pocket):
			removed[cell] = true

func indestructible(cell: Vector2i) -> bool:
	return cell in ANCHORS or cell.y == DEPTH - 1 or (terrain_seed == 0 and layout_version >= 1 and Geology.protected(cell))

func pockets() -> Array:
	return HazardLayout.pockets(terrain_seed, layout_version)

func contains(cell: Vector2i) -> bool:
	return cell.x >= LEFT and cell.x < RIGHT and cell.y >= 0 and cell.y < DEPTH

func material(cell: Vector2i) -> String:
	if not contains(cell) or removed.has(cell):
		return ""
	if indestructible(cell):
		return "anchor"
	if terrain_seed == 0 and layout_version >= 1:
		var ore := Geology.ore(cell)
		if not ore.is_empty():
			return ore
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
	if kind.is_empty() or kind == "anchor" or power <= 0 or (kind == "bedrock" and not allow_bedrock) or not exposed(cell):
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
		if cell is Vector2i and contains(cell) and not indestructible(cell):
			removed[cell] = true
	_add_pocket_cavities()
