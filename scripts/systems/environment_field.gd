extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const Layout = preload("res://scripts/data/hazard_layout.gd")
const Fluids = preload("res://scripts/data/fluid_catalog.gd")
const STEP := 0.2
const EPSILON := 0.000001
var site: RefCounted
var water: Dictionary = {}
var gas: Dictionary = {}
var oil: Dictionary = {}
var acid: Dictionary = {}
var released: Dictionary = {}
var accumulator := 0.0

func _init(dig_site: RefCounted) -> void:
	site = dig_site
	for pocket: Dictionary in site.pockets():
		for cell: Vector2i in Layout.cells(pocket):
			get(pocket.kind)[cell] = 1.0

func _open(cell: Vector2i) -> bool:
	return site.contains(cell) and site.material(cell).is_empty()

func detect_breaches() -> Array[String]:
	var events: Array[String] = []
	for pocket: Dictionary in site.pockets():
		if released.has(pocket.id):
			continue
		var breached := false
		for cell: Vector2i in Layout.boundary(pocket):
			if _open(cell):
				breached = true
				break
		if breached:
			released[pocket.id] = true
			events.append(pocket.kind)
	return events

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	accumulator += minf(delta, 0.5)
	while accumulator >= STEP:
		accumulator -= STEP
		detect_breaches()
		for kind: String in Fluids.LIQUID_IDS:
			var occupied := {}
			for other: String in Fluids.LIQUID_IDS:
				if other == kind:
					continue
				for cell: Vector2i in get(other):
					occupied[cell] = float(occupied.get(cell, 0)) + float(get(other)[cell])
			var definition: Dictionary = Fluids.KINDS[kind]
			set(kind, _step_liquid(get(kind), occupied, definition.fall, definition.spread))
		_step_gas()

func _step_liquid(field: Dictionary, other: Dictionary, fall_rate: float, spread_rate: float) -> Dictionary:
	# Gravity first, then lateral equalization; all liquids share one cell's capacity.
	var next := field.duplicate()
	var cells: Array = field.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.y > b.y if a.y != b.y else a.x < b.x)
	for cell: Vector2i in cells:
		var below := cell + Vector2i.DOWN
		if _open(below):
			_transfer(next, cell, below, maxf(0, minf(fall_rate, minf(float(next.get(cell, 0)), 1.0 - float(other.get(below, 0)) - float(next.get(below, 0))))))
		for offset in [Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor: Vector2i = cell + offset
			if _open(neighbor):
				var difference := (float(next.get(cell, 0)) - float(next.get(neighbor, 0))) * 0.25
				var capacity := 1.0 - float(other.get(neighbor, 0)) - float(next.get(neighbor, 0))
				_transfer(next, cell, neighbor, maxf(0, minf(capacity, minf(spread_rate, difference))))
	return _clean(next)

func _transfer(field: Dictionary, source: Vector2i, destination: Vector2i, amount: float) -> void:
	if amount <= 0:
		return
	field[source] = float(field.get(source, 0)) - amount
	field[destination] = float(field.get(destination, 0)) + amount

func _step_gas() -> void:
	# Diffusion crosses only excavated faces; a sealed pocket stays unchanged.
	var changes := {}
	var pairs := {}
	for cell: Vector2i in gas:
		for offset in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not _open(neighbor) or liquid_volume(neighbor) >= 0.95:
				continue
			var start := cell if cell.x < neighbor.x or (cell.x == neighbor.x and cell.y < neighbor.y) else neighbor
			var end := neighbor if start == cell else cell
			var key := Vector4i(start.x, start.y, end.x, end.y)
			if pairs.has(key):
				continue
			pairs[key] = true
			var flow := (float(gas.get(start, 0)) - float(gas.get(end, 0))) * 0.15
			changes[start] = float(changes.get(start, 0)) - flow
			changes[end] = float(changes.get(end, 0)) + flow
	var next := gas.duplicate()
	for cell: Vector2i in changes:
		next[cell] = maxf(0, float(next.get(cell, 0)) + float(changes[cell]))
	# Buoyancy supplements diffusion without crossing solid ceilings or full liquids.
	var rising: Array = next.keys()
	rising.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.y != b.y else a.x < b.x)
	for cell: Vector2i in rising:
		var above := cell + Vector2i.UP
		if _open(above):
			var capacity := maxf(0, 1.0 - liquid_volume(above) - float(next.get(above, 0)))
			_transfer(next, cell, above, minf(float(next.get(cell, 0)) * 0.08, capacity))
	var dispersing := false
	var sealed := {}
	for pocket: Dictionary in site.pockets():
		if pocket.kind == "gas" and released.has(pocket.id):
			dispersing = true
		elif pocket.kind == "gas":
			for cell: Vector2i in Layout.cells(pocket):
				sealed[cell] = true
	if dispersing:
		for cell: Vector2i in next:
			# Slow natural dispersal remains separate from active powered ventilation.
			if not sealed.has(cell):
				next[cell] = float(next[cell]) * exp(-STEP * 0.025)
	gas = _clean(next)

func _clean(field: Dictionary) -> Dictionary:
	var result := {}
	for cell: Vector2i in field:
		if float(field[cell]) > EPSILON:
			result[cell] = clampf(float(field[cell]), 0, 1)
	return result

func exposure(feet: Vector2) -> Dictionary:
	var head := feet - Vector2(0, Grid.metres(1.4))
	var head_cell := Grid.to_cell(head)
	return {"wet": _wet(feet - Vector2(0, 4)) or _wet(feet - Vector2(0, Grid.metres(0.8))), "submerged": _in_liquid(head, water), "oil": _in_liquid(feet - Vector2(0, 4), oil) or _in_liquid(head, oil), "acid": _in_liquid(feet - Vector2(0, 4), acid) or _in_liquid(head, acid), "gas": float(gas.get(head_cell, 0))}

func liquid_volume(cell: Vector2i) -> float:
	return float(water.get(cell, 0)) + float(acid.get(cell, 0)) + float(oil.get(cell, 0))

func liquid_rect(cell: Vector2i, kind: String) -> Rect2:
	var bottom := Grid.rect(cell).end.y
	# The catalog order places the heavier fluids below oil in shared cells.
	for other: String in Fluids.LIQUID_IDS:
		if other == kind:
			break
		bottom -= Grid.CELL_SIZE * float(get(other).get(cell, 0))
	var height := Grid.CELL_SIZE * float(get(kind).get(cell, 0))
	return Rect2(Grid.to_world(cell).x, bottom - height, Grid.CELL_SIZE, height)

func drain_water(intake: Vector2i, radius: int, amount: float) -> float:
	return _drain(water, intake, radius, amount)

func drain_gas(intake: Vector2i, radius: int, amount: float) -> float:
	return _drain(gas, intake, radius, amount)

func _drain(field: Dictionary, intake: Vector2i, radius: int, amount: float) -> float:
	if not _open(intake) or radius < 0 or not is_finite(amount) or amount <= 0:
		return 0
	var queue: Array[Vector2i] = [intake]
	var visited := {intake: true}
	var head := 0
	var drained := 0.0
	while head < queue.size() and drained < amount:
		var cell := queue[head]
		head += 1
		var volume := float(field.get(cell, 0))
		var take := minf(volume, amount - drained)
		if take > 0:
			drained += take
			if volume - take <= EPSILON:
				field.erase(cell)
			else:
				field[cell] = volume - take
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := cell + offset
			if not visited.has(next) and absi(next.x - intake.x) + absi(next.y - intake.y) <= radius and _open(next):
				visited[next] = true
				queue.append(next)
	return drained

func _wet(point: Vector2) -> bool:
	return _in_liquid(point, water) or _in_liquid(point, oil) or _in_liquid(point, acid)

func _in_liquid(point: Vector2, field: Dictionary) -> bool:
	var cell := Grid.to_cell(point)
	for kind: String in Fluids.LIQUID_IDS:
		if is_same(field, get(kind)):
			return float(field.get(cell, 0)) > 0 and liquid_rect(cell, kind).has_point(point)
	return false

func reading(cell: Vector2i) -> String:
	var kinds: Array[String] = []
	for pocket: Dictionary in site.pockets():
		var nearby := false
		for pocket_cell: Vector2i in Layout.cells(pocket):
			if absi(pocket_cell.x - cell.x) + absi(pocket_cell.y - cell.y) <= 1:
				nearby = true
		if nearby:
			var label: String = Fluids.KINDS[pocket.kind].name
			kinds.append(label + (": falda aperta / perdita rilevata" if released.has(pocket.id) else ": falda sigillata oltre la parete"))
	return " / ".join(kinds)

func snapshot() -> Dictionary:
	return {"version": 3, "water": _encode(water), "gas": _encode(gas), "oil": _encode(oil), "acid": _encode(acid), "released": released.keys()}

func _encode(field: Dictionary) -> Array:
	var cells: Array = []
	for cell: Vector2i in field:
		cells.append([cell.x, cell.y, field[cell]])
	return cells

func restore(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.is_empty():
		return true
	var version = data.get("version")
	if not (version is int or version is float) or (version != 1 and version != 2 and version != 3):
		return false
	if not data.get("water") is Array or not data.get("gas") is Array or not data.get("released") is Array or (version >= 2 and not data.get("oil") is Array) or (version == 3 and not data.get("acid") is Array):
		return false
	var next_water = _decode(data.water, "water")
	var next_gas = _decode(data.gas, "gas")
	var next_oil = _decode(data.get("oil", []), "oil")
	var next_acid = _decode(data.get("acid", []), "acid")
	if next_water == null or next_gas == null or next_oil == null or next_acid == null:
		return false
	var occupied := {}
	for field: Dictionary in [next_water, next_oil, next_acid]:
		for cell: Vector2i in field:
			occupied[cell] = float(occupied.get(cell, 0)) + float(field[cell])
	for cell: Vector2i in occupied:
		if float(occupied[cell]) > 1.001:
			return false
	var ids: Array[String] = []
	for pocket: Dictionary in site.pockets():
		ids.append(pocket.id)
	var next_released := {}
	for id in data.released:
		if not id is String or id not in ids:
			return false
		next_released[id] = true
	water = next_water
	gas = next_gas
	oil = next_oil
	acid = next_acid
	released = next_released
	accumulator = 0
	return true

func _decode(entries: Array, kind: String) -> Variant:
	if entries.size() > site.DEPTH * (site.RIGHT - site.LEFT):
		return null
	var result := {}
	var total := 0.0
	var capacity := 0.0
	for pocket: Dictionary in site.pockets():
		if pocket.kind == kind:
			capacity += Layout.cells(pocket).size()
	for entry in entries:
		if not entry is Array or entry.size() != 3:
			return null
		var cell = Grid.decode_cell(entry.slice(0, 2))
		var amount = entry[2]
		if not cell is Vector2i or not _open(cell) or result.has(cell) or not (amount is int or amount is float):
			return null
		if not is_finite(float(amount)) or float(amount) < 0 or float(amount) > 1:
			return null
		result[cell] = float(amount)
		total += float(amount)
	return result if total <= capacity + 0.001 else null
