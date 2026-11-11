extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const Components = preload("res://scripts/data/component_catalog.gd")
const IndustryCatalog = preload("res://scripts/data/industry_catalog.gd")
const VALVE_COST := {"structural_component": 2, "electronic_component": 1}
const PASSIVE_RATE := 0.35
const PUMP_RATE := 0.7
const MAX_LIFT := 6.0
const EPS := 0.000001
var valves: Array = []
var outlets: Array = []
var pumps: Dictionary = {}
var rates: Dictionary = {}
var delivery: Dictionary = {}
var _barriers: Dictionary = {}
var _blocked: Dictionary = {}

static func capacity() -> float:
	return float(IndustryCatalog.load_data().pump_capacity)

func at(cell: Vector2i) -> Dictionary:
	for entry: Dictionary in valves + outlets:
		if entry.cell == cell:
			return entry
	return {}

static func key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func placement_blocker(kind: String, cell: Vector2i, direction: Vector2i, outpost) -> String:
	var site: RefCounted = outpost.world.site
	if valves.size() + outlets.size() >= 200:
		return "Limite di 200 dispositivi idraulici raggiunto"
	if kind not in ["valve", "outlet"] or direction not in Network.OFFSETS:
		return "Orientamento non valido"
	if not outpost.laboratory_unlocked():
		return "Attiva prima il primo laboratorio"
	if not site.contains(cell) or not site.material(cell).is_empty() or not outpost.reachable_cell(cell):
		return "Serve una cella libera e raggiungibile"
	if not at(cell).is_empty():
		return "Cella gia' occupata da una presa o uno scarico"
	if kind == "outlet":
		var target := cell + direction
		if not outpost.network.cells.water.has(cell):
			return "Posa prima il tubo acqua"
		if not site.contains(target) or not site.material(target).is_empty() or outpost.network.cells.water.has(target):
			return "Orienta lo scarico verso una cella libera senza tubo"
		return ""
	var anchor := cell + direction
	if not site.contains(anchor) or site.material(anchor).is_empty() or site.indestructible(anchor):
		return "Fissa la presa alla faccia di una roccia perforabile"
	for building: Dictionary in outpost.buildings.structures:
		if outpost.buildings.footprint(building.id, building.origin).has_point(cell):
			return "Spazio occupato da un'installazione"
	return "" if outpost.world.field_cargo.can_pay(VALVE_COST, outpost.world.drone_help_available()) else "Servono 2 strutturali + 1 elettronico nel carico accessibile"

func place(kind: String, cell: Vector2i, direction: Vector2i, outpost) -> bool:
	var reason := placement_blocker(kind, cell, direction, outpost)
	if not reason.is_empty():
		outpost.world._note(reason)
		return false
	if kind == "valve" and not outpost.world.field_cargo.pay(VALVE_COST, outpost.world.drone_help_available()):
		return false
	var entry := {"kind": kind, "cell": cell, "direction": direction, "opened": false, "total": 0.0}
	if kind == "valve":
		entry.drilled = false
		valves.append(entry)
	else:
		entry.role = "outlet"
		outlets.append(entry)
	outpost.world.guide_event("water_" + kind + "_placed")
	return true

func drill_blocker(entry: Dictionary, outpost) -> String:
	if not valves.has(entry) or entry.drilled or not outpost.reachable_cell(entry.cell):
		return "Presa non raggiungibile o gia' perforata"
	var anchor: Vector2i = entry.cell + entry.direction
	var material: String = outpost.world.site.material(anchor)
	var tool: Resource = outpost.world.active_tool()
	if tool == null or tool.mode != "mine" or material not in tool.materials or outpost.world.site.indestructible(anchor):
		return "Seleziona un estrattore compatibile con la parete"
	return ""

func drill(entry: Dictionary, outpost) -> bool:
	var reason := drill_blocker(entry, outpost)
	if not reason.is_empty():
		outpost.world._note(reason)
		return false
	entry.drilled = true
	outpost.world.guide_event("water_valve_drilled")
	return true

func toggle(entry: Dictionary, outpost) -> bool:
	if not (valves.has(entry) or outlets.has(entry)) or not outpost.reachable_cell(entry.cell):
		return false
	if not entry.opened and (not outpost.network.cells.water.has(entry.cell) or (entry.kind == "valve" and not entry.drilled)):
		outpost.world._note("Collega il tubo e completa la perforazione prima di aprire")
		return false
	entry.opened = not entry.opened
	return true

func set_role(entry: Dictionary, role: String, outpost) -> bool:
	if not outlets.has(entry) or role not in ["outlet", "intake"] or not outpost.reachable_cell(entry.cell): return false
	entry.role = role
	entry.opened = false
	rates.erase("outlet:" + key(entry.cell))
	return true

func remove(entry: Dictionary, outpost) -> bool:
	if not outpost.reachable_cell(entry.cell):
		return false
	if valves.has(entry):
		valves.erase(entry)
		return true
	if outlets.has(entry):
		outlets.erase(entry)
		return true
	return false

func pump_ports(building: Dictionary) -> Dictionary:
	var left: Vector2i = building.origin + Vector2i(0, 1)
	var right := left + Vector2i.RIGHT
	var reverse: bool = pumps.get(key(building.origin), false)
	return {"input": right if reverse else left, "output": left if reverse else right}

func reverse_pump(building: Dictionary, outpost) -> bool:
	if building.id != "pump" or not outpost.buildings.structures.has(building) or not outpost.site_reachable(building):
		return false
	var id := key(building.origin)
	pumps[id] = not pumps.get(id, false)
	return true

func _topology(outpost) -> void:
	_barriers.clear()
	_blocked.clear()
	for pump: Dictionary in outpost.buildings.structures:
		if pump.id != "pump" or pump.get("state", "active") == "planned": continue
		var ports := pump_ports(pump)
		_barriers[Vector4i(ports.input.x, ports.input.y, ports.output.x, ports.output.y)] = true
		_barriers[Vector4i(ports.output.x, ports.output.y, ports.input.x, ports.input.y)] = true
		_blocked[pump.origin] = true
		_blocked[pump.origin + Vector2i.RIGHT] = true

func _route(start: Vector2i, end: Vector2i, network: RefCounted, ceiling: float = -INF) -> bool:
	if not network.cells.water.has(start) or not network.cells.water.has(end) or start.y + 0.5 < ceiling:
		return false
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cell == end: return true
		for direction: Vector2i in Network.OFFSETS:
			var next := cell + direction
			if seen.has(next) or _blocked.has(next) or next.y + 0.5 < ceiling or not network.cells.water.has(next): continue
			if _barriers.has(Vector4i(cell.x, cell.y, next.x, next.y)): continue
			seen[next] = true
			queue.append(next)
	return false

func _source(entry: Dictionary) -> Vector2i:
	return entry.cell + entry.direction * (2 if entry.kind == "valve" else 1)

func _head(entry: Dictionary, field: RefCounted) -> float:
	var source := _source(entry)
	return source.y + 1.0 - float(field.water.get(source, 0))

func _take(entry: Dictionary, field: RefCounted, budget: float) -> float:
	var source := _source(entry)
	var volume: float = field.water.get(source, 0)
	var taken := minf(volume, maxf(0, budget))
	if taken <= 0: return 0
	if volume - taken <= EPS: field.water.erase(source)
	else: field.water[source] = volume - taken
	entry.total += taken
	return taken

func _target(entry: Dictionary, outpost) -> Vector2i:
	return entry.cell + entry.direction

func _room(entry: Dictionary, outpost) -> float:
	var target := _target(entry, outpost)
	var field: RefCounted = outpost.world.environment
	if not outpost.world.site.contains(target) or not outpost.world.site.material(target).is_empty() or outpost.network.cells.water.has(target): return 0
	if float(field.oil.get(target, 0)) > EPS or float(field.acid.get(target, 0)) > EPS: return 0
	return maxf(0, 1.0 - field.liquid_volume(target))

func _release(entry: Dictionary, outpost, volume: float) -> void:
	if volume <= 0: return
	var cell := _target(entry, outpost)
	var field: RefCounted = outpost.world.environment
	field.water[cell] = float(field.water.get(cell, 0)) + volume
	entry.total += volume
	rates["outlet:" + key(entry.cell)] = float(rates.get("outlet:" + key(entry.cell), 0)) + volume

func _valid_sources(outpost) -> Array:
	var result: Array = []
	for entry: Dictionary in valves.duplicate():
		if outpost.world.site.material(entry.cell + entry.direction).is_empty():
			valves.erase(entry)
			continue
		if not outpost.network.cells.water.has(entry.cell): entry.opened = false
		if entry.opened and entry.drilled and float(outpost.world.environment.water.get(_source(entry), 0)) > EPS:
			result.append(entry)
	for entry: Dictionary in outlets:
		if not outpost.network.cells.water.has(entry.cell): entry.opened = false
		if entry.opened and entry.role == "intake" and float(outpost.world.environment.water.get(_source(entry), 0)) > EPS:
			result.append(entry)
	return result

func synchronize(outpost) -> void:
	_valid_sources(outpost)
	for id: String in pumps.keys():
		if not outpost.buildings.structures.any(func(building: Dictionary): return building.id == "pump" and key(building.origin) == id):
			pumps.erase(id)

func advance(delta: float, outpost, powered_seconds: float) -> void:
	if not is_finite(delta) or delta <= 0 or not is_finite(powered_seconds): return
	_topology(outpost)
	rates.clear()
	delivery.clear()
	var duration := minf(delta, 60)
	var power_fraction := clampf(powered_seconds / delta, 0, 1)
	var remaining := duration
	while remaining > EPS:
		var step := minf(remaining, 0.2)
		_step(step, outpost, step * power_fraction)
		remaining -= step
	for id: String in rates: rates[id] = float(rates[id]) / duration

func _step(delta: float, outpost, powered: float) -> void:
	var field: RefCounted = outpost.world.environment
	var sources := _valid_sources(outpost)
	var budgets := {}
	for entry: Dictionary in sources: budgets[key(entry.cell)] = PUMP_RATE * delta
	for pump: Dictionary in outpost.buildings.structures:
		if pump.id != "pump" or powered <= 0 or not outpost.device_powered(pump): continue
		var ports := pump_ports(pump)
		var storage: Dictionary = outpost.industry.state(pump)
		var budget := minf(PUMP_RATE * powered, maxf(0, capacity() - float(storage.water)))
		for entry: Dictionary in sources:
			var head := _head(entry, field)
			if ports.input.y + 0.5 < head - MAX_LIFT or not _route(entry.cell, ports.input, outpost.network, head - MAX_LIFT): continue
			var volume := _take(entry, field, minf(budget, budgets[key(entry.cell)]))
			storage.water += volume
			budget -= volume
			budgets[key(entry.cell)] -= volume
			var rate_key: String = entry.kind + ":" + key(entry.cell)
			rates[rate_key] = float(rates.get(rate_key, 0)) + volume
			rates["pump:" + key(pump.origin)] = float(rates.get("pump:" + key(pump.origin), 0)) + volume
			pump.drained = float(pump.get("drained", 0)) + volume
		var output_budget := minf(PUMP_RATE * powered, float(storage.water))
		for outlet: Dictionary in outlets:
			if outlet.role != "outlet" or not outlet.opened or _target(outlet, outpost).y + 0.5 < ports.output.y + 0.5 - MAX_LIFT or not _route(ports.output, outlet.cell, outpost.network, ports.output.y + 0.5 - MAX_LIFT): continue
			var volume := minf(output_budget, _room(outlet, outpost))
			_release(outlet, outpost, volume)
			storage.water = maxf(0, float(storage.water) - volume)
			output_budget = maxf(0, output_budget - volume)
		delivery[key(pump.origin)] = float(delivery.get(key(pump.origin), 0)) + output_budget
	for entry: Dictionary in sources:
		var budget := minf(PASSIVE_RATE * delta, budgets[key(entry.cell)])
		var head := _head(entry, field)
		for outlet: Dictionary in outlets:
			if outlet.role != "outlet" or not outlet.opened or _target(outlet, outpost).y + 0.5 <= head or not _route(entry.cell, outlet.cell, outpost.network, head): continue
			var volume := _take(entry, field, minf(budget, _room(outlet, outpost)))
			_release(outlet, outpost, volume)
			budget -= volume
			var rate_key: String = entry.kind + ":" + key(entry.cell)
			rates[rate_key] = float(rates.get(rate_key, 0)) + volume

func pumps_for(building: Dictionary, outpost) -> Array:
	_topology(outpost)
	var target := Network.port(building, "water")
	return outpost.buildings.structures.filter(func(pump: Dictionary): return pump.id == "pump" and outpost.device_powered(pump) and target.y >= pump_ports(pump).output.y - MAX_LIFT and _route(pump_ports(pump).output, target, outpost.network, pump_ports(pump).output.y + 0.5 - MAX_LIFT))

func deliverable(building: Dictionary, outpost) -> float:
	var result := 0.0
	for pump: Dictionary in pumps_for(building, outpost):
		result += minf(float(outpost.industry.state(pump).water), float(delivery.get(key(pump.origin), 0)))
	return result

func withdraw(building: Dictionary, requested: float, outpost) -> float:
	if not is_finite(requested) or requested <= 0: return 0
	var remaining := requested
	for pump: Dictionary in pumps_for(building, outpost):
		var storage: Dictionary = outpost.industry.state(pump)
		var id := key(pump.origin)
		var taken := maxf(0, minf(remaining, minf(float(storage.water), float(delivery.get(id, 0)))))
		storage.water = maxf(0, float(storage.water) - taken)
		delivery[id] = maxf(0, float(delivery.get(id, 0)) - taken)
		remaining -= taken
	return requested - remaining

func report(entry: Dictionary, outpost) -> Dictionary:
	var rate: float = rates.get(entry.get("kind", "") + ":" + key(entry.cell), 0)
	var status := "Flusso attivo" if rate > EPS else "In attesa di un percorso e di una destinazione libera"
	if not outpost.network.cells.water.has(entry.cell): status = "Tubo acqua scollegato / chiusura di sicurezza"
	elif entry.kind == "valve" and not entry.drilled: status = "Da perforare / parete ancora integra"
	elif not entry.opened: status = "Chiusa" if entry.kind == "valve" else "Scarico chiuso"
	elif entry.kind == "valve" and float(outpost.world.environment.water.get(_source(entry), 0)) <= EPS: status = "Nessuna acqua all'altezza della presa"
	elif entry.kind == "outlet" and entry.role == "intake" and float(outpost.world.environment.water.get(_source(entry), 0)) <= EPS: status = "Bocca di aspirazione asciutta"
	elif entry.kind == "outlet" and entry.role == "outlet" and _room(entry, outpost) <= EPS: status = "Uscita piena, ostruita o contaminata"
	return {"status": status, "rate": rate, "total": float(entry.get("total", 0)), "kind": entry.kind}

func pump_report(building: Dictionary, outpost) -> Dictionary:
	var ports := pump_ports(building)
	var rate: float = rates.get("pump:" + key(building.origin), 0)
	var status := "Aspirazione attiva" if rate > EPS else "In attesa di acqua o ricevente"
	if not building.get("enabled", true): status = "Spenta"
	elif not outpost.device_powered(building): status = "Nessuna alimentazione o collegamento al laboratorio"
	elif not outpost.network.cells.water.has(ports.input): status = "Ingresso acqua scollegato"
	elif not outpost.network.cells.water.has(ports.output): status = "Uscita acqua scollegata"
	elif float(outpost.industry.state(building).water) >= capacity() - EPS: status = "Buffer pieno / verifica il ricevente e il dislivello"
	return {"status": status, "rate": rate, "total": float(building.get("drained", 0)), "kind": "pump"}

func snapshot() -> Dictionary:
	var data := {"version": 1, "valves": [], "outlets": [], "pumps": pumps.duplicate()}
	for kind: String in ["valves", "outlets"]:
		for entry: Dictionary in get(kind):
			var saved := entry.duplicate()
			saved.cell = [entry.cell.x, entry.cell.y]
			saved.direction = [entry.direction.x, entry.direction.y]
			data[kind].append(saved)
	return data

func restore(data: Variant, site: RefCounted, buildings: RefCounted) -> bool:
	if not data is Dictionary: return false
	if data.is_empty():
		valves.clear()
		outlets.clear()
		pumps.clear()
		rates.clear()
		delivery.clear()
		return true
	if data.get("version") != 1 or not data.get("valves") is Array or not data.get("outlets") is Array or not data.get("pumps") is Dictionary or data.valves.size() + data.outlets.size() > 200 or data.pumps.size() > 200: return false
	var parsed := {"valves": [], "outlets": []}
	var seen := {}
	for group: String in parsed:
		for saved in data[group]:
			if not saved is Dictionary: return false
			var fields := ["kind", "cell", "direction", "opened", "total", "drilled"] if group == "valves" else ["kind", "cell", "direction", "opened", "total", "role"]
			if saved.size() != fields.size() or saved.keys().any(func(property): return property not in fields): return false
			var cell = Grid.decode_cell(saved.get("cell"))
			var direction = Grid.decode_cell(saved.get("direction"))
			if not cell is Vector2i or not direction is Vector2i or direction not in Network.OFFSETS or not site.contains(cell) or not site.material(cell).is_empty() or seen.has(cell): return false
			if saved.get("kind") != ("valve" if group == "valves" else "outlet") or not saved.get("opened") is bool or not (saved.get("total") is int or saved.get("total") is float) or not is_finite(float(saved.total)) or saved.total < 0: return false
			if group == "valves":
				if not saved.get("drilled") is bool or (saved.opened and not saved.drilled) or not site.contains(cell + direction) or site.material(cell + direction).is_empty() or site.indestructible(cell + direction): return false
				if buildings.structures.any(func(building: Dictionary): return buildings.footprint(building.id, building.origin).has_point(cell)): return false
			elif saved.get("role") not in ["outlet", "intake"] or not site.contains(cell + direction) or not site.material(cell + direction).is_empty(): return false
			var entry: Dictionary = saved.duplicate(true)
			entry.cell = cell
			entry.direction = direction
			entry.total = float(entry.total)
			parsed[group].append(entry)
			seen[cell] = true
	var next_pumps := {}
	for id in data.pumps:
		if not id is String or not data.pumps[id] is bool or not buildings.structures.any(func(building: Dictionary): return building.id == "pump" and key(building.origin) == id): return false
		next_pumps[id] = data.pumps[id]
	valves = parsed.valves
	outlets = parsed.outlets
	pumps = next_pumps
	rates.clear()
	delivery.clear()
	return true
