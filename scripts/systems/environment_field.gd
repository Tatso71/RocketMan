extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const Layout = preload("res://scripts/data/hazard_layout.gd")
const STEP := 0.2
const EPSILON := 0.000001
var site: RefCounted
var water: Dictionary = {}
var gas: Dictionary = {}
var released: Dictionary = {}
var accumulator := 0.0

func _init(dig_site: RefCounted) -> void:
	site = dig_site
	for pocket: Dictionary in Layout.pockets(site.terrain_seed):
		for cell: Vector2i in Layout.cells(pocket):
			if pocket.kind == "water":
				water[cell] = 1.0
			else:
				gas[cell] = 1.0

func _open(cell: Vector2i) -> bool:
	return site.contains(cell) and site.material(cell).is_empty()

func detect_breaches() -> Array[String]:
	var events: Array[String] = []
	for pocket: Dictionary in Layout.pockets(site.terrain_seed):
		if released.has(pocket.id):
			continue
		var cells := Layout.cells(pocket)
		var breached := false
		for cell: Vector2i in cells:
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = cell + offset
				if neighbor not in cells and _open(neighbor):
					breached = true
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
		_step_water()
		_step_gas()

func _step_water() -> void:
	# Finite cell volumes: gravity first, then lateral equalization. No new water is created.
	var next := water.duplicate()
	var cells: Array = water.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.y > b.y if a.y != b.y else a.x < b.x)
	for cell: Vector2i in cells:
		var below := cell + Vector2i.DOWN
		if _open(below):
			_transfer(next, cell, below, minf(float(next.get(cell, 0)), 1.0 - float(next.get(below, 0))))
		for offset in [Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor: Vector2i = cell + offset
			if _open(neighbor):
				var difference := (float(next.get(cell, 0)) - float(next.get(neighbor, 0))) * 0.25
				_transfer(next, cell, neighbor, maxf(0, minf(0.2, difference)))
	water = _clean(next)

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
			if not _open(neighbor):
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
	var dispersing := false
	for pocket: Dictionary in Layout.pockets(site.terrain_seed):
		if pocket.kind == "gas" and released.has(pocket.id):
			dispersing = true
	if dispersing:
		for cell: Vector2i in next:
			# Prototype dispersal after a breach; ventilation hardware is a later system.
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
	return {"wet": _wet(feet - Vector2(0, 4)) or _wet(feet - Vector2(0, Grid.metres(0.8))), "submerged": _wet(head), "gas": float(gas.get(head_cell, 0))}

func drain_water(intake: Vector2i, radius: int, amount: float) -> float:
	if not _open(intake) or radius < 0 or not is_finite(amount) or amount <= 0:
		return 0
	var queue: Array[Vector2i] = [intake]
	var visited := {intake: true}
	var head := 0
	var drained := 0.0
	while head < queue.size() and drained < amount:
		var cell := queue[head]
		head += 1
		var volume := float(water.get(cell, 0))
		var take := minf(volume, amount - drained)
		if take > 0:
			drained += take
			if volume - take <= EPSILON:
				water.erase(cell)
			else:
				water[cell] = volume - take
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := cell + offset
			if not visited.has(next) and absi(next.x - intake.x) + absi(next.y - intake.y) <= radius and _open(next):
				visited[next] = true
				queue.append(next)
	return drained

func _wet(point: Vector2) -> bool:
	var cell := Grid.to_cell(point)
	var level := float(water.get(cell, 0))
	return level > 0 and point.y >= Grid.to_world(cell).y + Grid.CELL_SIZE * (1.0 - level)

func reading(cell: Vector2i) -> String:
	var kinds: Array[String] = []
	for pocket: Dictionary in Layout.pockets(site.terrain_seed):
		var nearby := false
		for pocket_cell: Vector2i in Layout.cells(pocket):
			if absi(pocket_cell.x - cell.x) + absi(pocket_cell.y - cell.y) <= 1:
				nearby = true
		if nearby:
			var label := "Gas" if pocket.kind == "gas" else "Acqua"
			kinds.append(label + (": perdita rilevata" if released.has(pocket.id) else ": sacca sigillata oltre la parete"))
	return " / ".join(kinds)

func snapshot() -> Dictionary:
	return {"version": 1, "water": _encode(water), "gas": _encode(gas), "released": released.keys()}

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
	if data.get("version") != 1 or not data.get("water") is Array or not data.get("gas") is Array or not data.get("released") is Array:
		return false
	var next_water = _decode(data.water, "water")
	var next_gas = _decode(data.gas, "gas")
	if next_water == null or next_gas == null:
		return false
	var ids: Array[String] = []
	for pocket: Dictionary in Layout.pockets(site.terrain_seed):
		ids.append(pocket.id)
	var next_released := {}
	for id in data.released:
		if not id is String or id not in ids:
			return false
		next_released[id] = true
	water = next_water
	gas = next_gas
	released = next_released
	accumulator = 0
	return true

func _decode(entries: Array, kind: String) -> Variant:
	if entries.size() > site.DEPTH * (site.RIGHT - site.LEFT):
		return null
	var result := {}
	var total := 0.0
	var capacity := 0.0
	for pocket: Dictionary in Layout.pockets(site.terrain_seed):
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
