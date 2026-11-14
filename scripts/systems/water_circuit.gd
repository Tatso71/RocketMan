extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const Layout = preload("res://scripts/data/hazard_layout.gd")
const IndustryCatalog = preload("res://scripts/data/industry_catalog.gd")
const PASSIVE_RATE := 0.35
const PUMP_RATE := 0.7
const MAX_LIFT := 6.0
const EPS := 0.000001
const SHIP_CAPACITY := 40.0
var valves: Array = []
var pumps: Dictionary = {}
var rates: Dictionary = {}
var local_ship_water := {"left": 0.0, "right": 0.0}
var _ship_ports: Array = [
	{"kind": "ship", "cell": Vector2i(-6, -3), "opened": true, "total": 0.0, "id": "left"},
	{"kind": "ship", "cell": Vector2i(5, -3), "opened": true, "total": 0.0, "id": "right"},
]
var _context: WeakRef
var _nodes: Dictionary = {}
var _blocked: Dictionary = {}
var _cavities: Dictionary = {}

static func capacity() -> float:
	return float(IndustryCatalog.load_data().pump_capacity)

static func key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func ship_ports() -> Array:
	return _ship_ports

func at(cell: Vector2i) -> Dictionary:
	for entry: Dictionary in valves + _ship_ports:
		if entry.cell == cell: return entry
	return {}

func _bind(outpost) -> void:
	_context = weakref(outpost)

func _water_neighbors(cell: Vector2i, outpost) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in Network.OFFSETS:
		var neighbor := cell + direction
		if outpost.world.site.contains(neighbor) and outpost.world.site.material(neighbor).is_empty() and float(outpost.world.environment.water.get(neighbor, 0)) > EPS:
			result.append(neighbor)
	return result

func placement_blocker(kind: String, cell: Vector2i, outpost) -> String:
	_bind(outpost)
	if kind != "valve": return "Dispositivo acqua non valido"
	if valves.size() >= 200: return "Limite di 200 valvole raggiunto"
	if not at(cell).is_empty(): return "Cella gia' occupata da una valvola"
	if not outpost.world.site.contains(cell) or outpost.world.site.material(cell).is_empty():
		return "La valvola va su una cella di roccia"
	if _water_neighbors(cell, outpost).is_empty(): return "Serve acqua reale in una cella adiacente"
	return ""

func place(kind: String, cell: Vector2i, outpost) -> bool:
	var reason := placement_blocker(kind, cell, outpost)
	if not reason.is_empty():
		outpost.world._note(reason)
		return false
	valves.append({"kind": "valve", "cell": cell, "opened": true, "total": 0.0})
	for neighbor: Vector2i in _water_neighbors(cell, outpost): _cavities[neighbor] = true
	outpost.world.guide_event("water_valve_placed")
	return true

func toggle(entry: Dictionary, _outpost) -> bool:
	if not valves.has(entry) and not _ship_ports.has(entry): return false
	entry.opened = not entry.opened
	return true

func remove(entry: Dictionary, _outpost) -> bool:
	if not valves.has(entry): return false
	valves.erase(entry)
	return true

func _neighbors(cell: Vector2i, outpost) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in Network.OFFSETS:
		var neighbor := cell + direction
		if outpost.network.cells.water.has(neighbor) or not at(neighbor).is_empty(): result.append(direction)
	return result

func pump_placement_blocker(cell: Vector2i, outpost) -> String:
	_bind(outpost)
	if not outpost.network.cells.water.has(cell) or not outpost.world.site.material(cell).is_empty(): return "Posa prima un tubo acqua nella cella della pompa"
	var neighbors := _neighbors(cell, outpost)
	if neighbors.is_empty(): return "Collega almeno un tubo o una valvola accanto alla pompa"
	if neighbors.size() > 2 or (neighbors.size() == 2 and neighbors[0] != -neighbors[1]): return "Serve un tubo diritto o terminale, non una curva o un incrocio"
	return ""

func pump_direction(building: Dictionary) -> Vector2i:
	var id := key(building.origin)
	if pumps.has(id): return pumps[id]
	var outpost = _context.get_ref() if _context != null else null
	if outpost != null:
		var neighbors := _neighbors(building.origin, outpost)
		if not neighbors.is_empty(): return Vector2i.DOWN if neighbors[0].x == 0 else Vector2i.RIGHT
		if int(outpost.network.water_axes.get(building.origin, 0)) == 1: return Vector2i.DOWN
	return Vector2i.RIGHT

func pump_ports(building: Dictionary) -> Dictionary:
	var direction := pump_direction(building)
	return {"input": building.origin - direction, "output": building.origin + direction, "direction": direction}

func set_pump_direction(building: Dictionary, direction: Vector2i, outpost) -> bool:
	_bind(outpost)
	if building.get("id") != "pump" or direction not in Network.OFFSETS or not outpost.buildings.structures.has(building) or not outpost.site_reachable(building): return false
	if not pump_placement_blocker(building.origin, outpost).is_empty(): return false
	for neighbor: Vector2i in _neighbors(building.origin, outpost):
		if neighbor != direction and neighbor != -direction: return false
	pumps[key(building.origin)] = direction
	return true

func reverse_pump(building: Dictionary, outpost) -> bool:
	_bind(outpost)
	return set_pump_direction(building, -pump_direction(building), outpost)

func toggle_pump(building: Dictionary, outpost) -> bool:
	if building.get("id") != "pump" or not outpost.buildings.structures.has(building) or not outpost.site_reachable(building): return false
	building.enabled = not building.get("enabled", true)
	return true

func synchronize(outpost) -> void:
	_bind(outpost)
	for entry: Dictionary in valves.duplicate():
		if outpost.world.site.material(entry.cell).is_empty(): valves.erase(entry)
	for id: String in pumps.keys():
		if not outpost.buildings.structures.any(func(b: Dictionary): return b.id == "pump" and key(b.origin) == id): pumps.erase(id)

func _topology(outpost) -> void:
	synchronize(outpost)
	_nodes.clear()
	_blocked.clear()
	for b: Dictionary in outpost.buildings.structures:
		if b.id == "pump" and b.get("state", "active") != "planned": _blocked[b.origin] = true
	for cell: Vector2i in outpost.network.cells.water:
		if Network.valid_cell(cell, outpost.world.site) and not _blocked.has(cell): _nodes[cell] = true
	for entry: Dictionary in valves + _ship_ports:
		if entry.opened and not _blocked.has(entry.cell): _nodes[entry.cell] = true
	for pocket: Dictionary in outpost.world.site.pockets():
		if pocket.kind == "water":
			for cell: Vector2i in Layout.cells(pocket): _cavities[cell] = true

func _route(start: Vector2i, end: Vector2i, ceiling: float) -> bool:
	if not _nodes.has(start) or not _nodes.has(end) or start.y + 0.5 < ceiling - EPS: return false
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if cell == end: return true
		for direction: Vector2i in Network.OFFSETS:
			var next := cell + direction
			if seen.has(next) or not _nodes.has(next) or next.y + 0.5 < ceiling - EPS: continue
			seen[next] = true
			queue.append(next)
	return false

func _ship_water(outpost) -> Dictionary:
	var ship = outpost.world.get("ship_state")
	return ship.water_tanks if ship != null else local_ship_water

func _endpoints(outpost, powered: float) -> Array:
	var result: Array = []
	for entry: Dictionary in valves:
		if not entry.opened: continue
		for direction: Vector2i in Network.OFFSETS:
			var cell: Vector2i = entry.cell + direction
			var water := float(outpost.world.environment.water.get(cell, 0))
			if water > EPS: _cavities[cell] = true
			if not _cavities.has(cell) or not outpost.world.site.contains(cell) or not outpost.world.site.material(cell).is_empty(): continue
			if float(outpost.world.environment.oil.get(cell, 0)) > EPS or float(outpost.world.environment.acid.get(cell, 0)) > EPS: continue
			result.append({"id": "water:" + key(cell), "owner": "valve:" + key(entry.cell), "kind": "water", "cell": cell, "input": entry.cell, "output": entry.cell, "entry": entry, "storage": outpost.world.environment.water, "slot": cell, "capacity": 1.0, "powered": false})
	for entry: Dictionary in _ship_ports:
		if not entry.opened: continue
		result.append({"id": "ship:" + entry.id, "owner": "ship:" + key(entry.cell), "kind": "ship", "cell": entry.cell, "input": entry.cell, "output": entry.cell, "entry": entry, "storage": _ship_water(outpost), "slot": entry.id, "capacity": SHIP_CAPACITY, "powered": false})
	for b: Dictionary in outpost.buildings.structures:
		if b.id not in ["pump", "greenhouse", "water_tank"] or b.get("state", "active") != "active" or b.get("damaged", false): continue
		var port := Network.port(b, "water")
		var input := port
		var output := port
		var active := false
		if b.id == "pump":
			if powered <= 0 or not b.get("enabled", true) or not outpost.device_powered(b) or not pump_placement_blocker(b.origin, outpost).is_empty(): continue
			var ports := pump_ports(b)
			var aligned := true
			for neighbor: Vector2i in _neighbors(b.origin, outpost):
				if neighbor != ports.direction and neighbor != -ports.direction: aligned = false
			if not aligned: continue
			input = ports.input
			output = ports.output
			port = b.origin
			active = true
		var id: String = b.id + ":" + key(b.origin)
		var storage_capacity := float(IndustryCatalog.load_data()[b.id + "_capacity"])
		result.append({"id": id, "owner": id, "kind": b.id, "cell": port, "input": input, "output": output, "building": b, "storage": outpost.industry.state(b), "slot": "water", "capacity": storage_capacity, "powered": active})
	return result

func _volume(endpoint: Dictionary) -> float:
	return maxf(0, float(endpoint.storage.get(endpoint.slot, 0)))

func _head(endpoint: Dictionary) -> float:
	return endpoint.cell.y + 1.0 - _volume(endpoint) if endpoint.kind == "water" else endpoint.cell.y + 0.5

func _record(endpoint: Dictionary, volume: float, intake: bool) -> void:
	if endpoint.has("entry"): endpoint.entry.total = float(endpoint.entry.total) + volume
	if endpoint.kind == "pump" and intake: endpoint.building.drained = float(endpoint.building.get("drained", 0)) + volume
	if endpoint.kind != "pump" or intake:
		rates[endpoint.owner] = float(rates.get(endpoint.owner, 0)) + volume

func advance(delta: float, outpost, powered_seconds: float) -> void:
	if not is_finite(delta) or delta <= 0 or not is_finite(powered_seconds): return
	_topology(outpost)
	rates.clear()
	var duration := minf(delta, 60.0)
	var fraction := clampf(powered_seconds / delta, 0, 1)
	var remaining := duration
	while remaining > EPS:
		var step := minf(remaining, 0.2)
		_step(step, outpost, step * fraction)
		remaining -= step
	for id: String in rates: rates[id] = float(rates[id]) / duration

func _step(delta: float, outpost, powered: float) -> void:
	var endpoints := _endpoints(outpost, powered)
	var available := {}
	var outgoing := {}
	var passive := {}
	var incoming := {}
	for endpoint: Dictionary in endpoints:
		available[endpoint.id] = _volume(endpoint)
		outgoing[endpoint.owner] = PUMP_RATE * (powered if endpoint.powered else delta)
		passive[endpoint.owner] = PASSIVE_RATE * delta
		incoming[endpoint.id] = PUMP_RATE * powered if endpoint.powered else INF
	# Only water present at the start of this substep can leave an endpoint.
	# Shared cell/valve and pump budgets prevent branch multiplication and recycling.
	for source: Dictionary in endpoints:
		if source.kind == "greenhouse": continue
		for target: Dictionary in endpoints:
			if source.id == target.id or source.owner == target.owner: continue
			var active: bool = source.powered or target.powered
			var source_head := _head(source)
			var ceiling := source_head - (MAX_LIFT if active else 0.0)
			if _head(target) < ceiling - EPS: continue
			if not active and _head(target) <= source_head + EPS: continue
			var direct_handoff: bool = source.kind == "pump" and target.kind == "pump" and source.output == target.building.origin and target.input == source.building.origin
			if not direct_handoff and not _route(source.output, target.input, ceiling): continue
			var room := maxf(0, float(target.capacity) - _volume(target))
			if target.kind == "water": room = minf(room, maxf(0, target.cell.y + 1.0 - ceiling - _volume(target)))
			var budget := minf(float(available[source.id]), float(outgoing[source.owner]))
			budget = minf(budget, float(incoming[target.id]))
			if not active: budget = minf(budget, float(passive[source.owner]))
			var volume := minf(budget, room)
			if volume <= 0: continue
			source.storage[source.slot] = _volume(source) - volume
			target.storage[target.slot] = _volume(target) + volume
			available[source.id] = maxf(0, float(available[source.id]) - volume)
			outgoing[source.owner] = maxf(0, float(outgoing[source.owner]) - volume)
			incoming[target.id] = maxf(0, float(incoming[target.id]) - volume)
			if not active: passive[source.owner] = maxf(0, float(passive[source.owner]) - volume)
			_record(source, volume, false)
			_record(target, volume, true)

func pumps_for(building: Dictionary, outpost) -> Array:
	_topology(outpost)
	var target := Network.port(building, "water")
	return outpost.buildings.structures.filter(func(pump: Dictionary): return pump.id == "pump" and outpost.device_powered(pump) and _route(pump_ports(pump).output, target, pump.origin.y + 0.5 - MAX_LIFT))

func deliverable(building: Dictionary, outpost) -> float:
	if building.get("id") != "greenhouse" or building.get("state", "active") != "active" or building.get("damaged", false): return 0.0
	return maxf(0, float(outpost.industry.state(building).get("water", 0)))

func withdraw(building: Dictionary, requested: float, outpost) -> float:
	if not is_finite(requested) or requested <= 0: return 0.0
	var volume := minf(requested, deliverable(building, outpost))
	if volume > 0:
		var storage: Dictionary = outpost.industry.state(building)
		storage.water = maxf(0, float(storage.water) - volume)
	return volume

func report(entry: Dictionary, outpost) -> Dictionary:
	_bind(outpost)
	var rate := float(rates.get(entry.kind + ":" + key(entry.cell), 0))
	var status := "Flusso attivo" if rate > EPS else "In attesa di un percorso e di un ricevente libero"
	var connected: bool = outpost.network.cells.water.has(entry.cell)
	for direction: Vector2i in Network.OFFSETS:
		if outpost.network.cells.water.has(entry.cell + direction): connected = true
	if not entry.opened: status = "Valvola chiusa"
	elif not connected: status = "Tubo acqua scollegato"
	elif entry.kind == "valve" and _water_neighbors(entry.cell, outpost).is_empty(): status = "Nessuna acqua adiacente / disponibile come ricevente"
	var water := float(_ship_water(outpost).get(entry.get("id", ""), 0)) if entry.kind == "ship" else 0.0
	return {"status": status, "rate": rate, "total": float(entry.total), "kind": entry.kind, "water": water, "capacity": SHIP_CAPACITY if entry.kind == "ship" else 0.0}

func pump_report(building: Dictionary, outpost) -> Dictionary:
	_bind(outpost)
	var ports := pump_ports(building)
	var rate := float(rates.get("pump:" + key(building.origin), 0))
	var status := "Aspirazione attiva" if rate > EPS else "In attesa di acqua o ricevente entro 6 m"
	var water := float(outpost.industry.state(building).get("water", 0))
	if building.get("state", "active") != "active": status = "Montaggio in corso"
	elif not building.get("enabled", true): status = "Spenta"
	elif not outpost.device_powered(building): status = "Nessuna alimentazione o collegamento al laboratorio"
	elif not pump_placement_blocker(building.origin, outpost).is_empty(): status = "Tubo scollegato, curva o incrocio presso la pompa"
	elif not outpost.network.cells.water.has(ports.input) and at(ports.input).is_empty(): status = "Ingresso acqua scollegato"
	elif not outpost.network.cells.water.has(ports.output) and at(ports.output).is_empty(): status = "Uscita acqua scollegata / accumulo nel buffer"
	elif water >= capacity() - EPS: status = "Buffer pieno / verifica ricevente e dislivello"
	return {"status": status, "rate": rate, "total": float(building.get("drained", 0)), "kind": "pump", "water": water, "capacity": capacity(), "direction": ports.direction}

func snapshot() -> Dictionary:
	var data := {"version": 2, "valves": [], "pumps": {}, "local_ship_water": local_ship_water.duplicate(), "cavities": [], "ship_opened": {}}
	for entry: Dictionary in valves:
		data.valves.append({"kind": "valve", "cell": [entry.cell.x, entry.cell.y], "opened": entry.opened, "total": entry.total})
	for id: String in pumps:
		var direction: Vector2i = pumps[id]
		data.pumps[id] = [direction.x, direction.y]
	for cell: Vector2i in _cavities:
		if valves.any(func(entry: Dictionary): return cell - entry.cell in Network.OFFSETS): data.cavities.append([cell.x, cell.y])
	for entry: Dictionary in _ship_ports: data.ship_opened[entry.id] = entry.opened
	return data

static func _fields(data: Dictionary, fields: Array) -> bool:
	return data.size() == fields.size() and data.keys().all(func(property): return property in fields)

static func _number(value: Variant, maximum: float = INF) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= maximum

func restore(data: Variant, site: RefCounted, buildings: RefCounted) -> bool:
	if not data is Dictionary: return false
	if data.is_empty():
		valves = []
		pumps = {}
		local_ship_water = {"left": 0.0, "right": 0.0}
		rates.clear()
		_cavities.clear()
		for entry: Dictionary in _ship_ports:
			entry.opened = true
			entry.total = 0.0
		return true
	if not _fields(data, ["version", "valves", "pumps", "local_ship_water", "cavities", "ship_opened"]) or data.get("version") != 2 or not data.get("valves") is Array or not data.get("pumps") is Dictionary or not data.get("local_ship_water") is Dictionary or not data.get("cavities") is Array or not data.get("ship_opened") is Dictionary: return false
	if data.valves.size() > 200 or data.pumps.size() > 200 or not _fields(data.local_ship_water, ["left", "right"]): return false
	if data.cavities.size() > 800 or not _fields(data.ship_opened, ["left", "right"]) or not data.ship_opened.left is bool or not data.ship_opened.right is bool: return false
	for value in data.local_ship_water.values():
		if not _number(value, SHIP_CAPACITY): return false
	var parsed: Array = []
	var seen := {}
	for saved in data.valves:
		if not saved is Dictionary or not _fields(saved, ["kind", "cell", "opened", "total"]): return false
		var cell = Grid.decode_cell(saved.cell)
		if not cell is Vector2i or not site.contains(cell) or site.material(cell).is_empty() or seen.has(cell): return false
		if saved.kind != "valve" or not saved.opened is bool or not _number(saved.total): return false
		if buildings.structures.any(func(b: Dictionary): return buildings.footprint(b.id, b.origin).has_point(cell)): return false
		parsed.append({"kind": "valve", "cell": cell, "opened": saved.opened, "total": float(saved.total)})
		seen[cell] = true
	var next_cavities := {}
	for saved in data.cavities:
		var cell = Grid.decode_cell(saved)
		if not cell is Vector2i or not site.contains(cell) or not site.material(cell).is_empty() or next_cavities.has(cell): return false
		if not parsed.any(func(entry: Dictionary): return cell - entry.cell in Network.OFFSETS): return false
		next_cavities[cell] = true
	var next_pumps := {}
	for id in data.pumps:
		var direction = Grid.decode_cell(data.pumps[id])
		if not id is String or not direction is Vector2i or direction not in Network.OFFSETS: return false
		if buildings.structures.filter(func(b: Dictionary): return b.id == "pump" and key(b.origin) == id).size() != 1: return false
		next_pumps[id] = direction
	valves = parsed
	pumps = next_pumps
	local_ship_water = {"left": float(data.local_ship_water.left), "right": float(data.local_ship_water.right)}
	rates.clear()
	_cavities = next_cavities
	for entry: Dictionary in _ship_ports:
		entry.opened = data.ship_opened[entry.id]
		entry.total = 0.0
	return true
