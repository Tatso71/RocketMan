extends RefCounted

const Catalog = preload("res://scripts/data/industry_catalog.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var machines: Dictionary = {}
var collected_pods: Array[String] = []

static func key(building: Dictionary) -> String:
	return "%s:%d:%d" % [building.id, building.origin.x, building.origin.y]

static func defaults(id: String) -> Dictionary:
	match id:
		"pump": return {"water": 0.0}
		"gas_converter": return {"energy": 0.0, "produced": 0.0}
		"furnace": return {"recipe": "", "elapsed": 0.0, "output": ""}
		"greenhouse": return {"crop": "", "elapsed": 0.0}
	return {}

func state(building: Dictionary) -> Dictionary:
	var identity := key(building)
	if not machines.has(identity):
		machines[identity] = defaults(building.id)
	return machines[identity]

func healthy(building: Dictionary, outpost: Node2D) -> bool:
	if building.get("id") not in ["pump", "gas_converter", "furnace", "greenhouse"]:
		return false
	if not outpost.Buildings.is_active(building) or not building.get("enabled", true):
		return false
	return outpost.environment_safe(building)

func linked(building: Dictionary, kind: String, supplier: String, outpost: Node2D) -> Array:
	return outpost.buildings.structures.filter(func(item: Dictionary): return item.id == supplier and healthy(item, outpost) and outpost.network.connected(kind, Network.port(building, kind), Network.port(item, kind)))

func energy_available(building: Dictionary, outpost: Node2D) -> float:
	var result := 0.0
	for converter: Dictionary in linked(building, "energy", "gas_converter", outpost):
		result += float(state(converter).energy)
	return result

func water_available(building: Dictionary, outpost: Node2D) -> float:
	var result := 0.0
	for pump: Dictionary in linked(building, "water", "pump", outpost):
		result += float(state(pump).water)
	return result

func _consume(building: Dictionary, kind: String, amount: float, outpost: Node2D) -> void:
	var supplier := "gas_converter" if kind == "energy" else "pump"
	for source: Dictionary in linked(building, kind, supplier, outpost):
		var storage := state(source)
		var taken := minf(amount, float(storage[kind]))
		storage[kind] = maxf(0, float(storage[kind]) - taken)
		amount -= taken
		if amount <= 0.000001:
			break

func pump_budget(pump: Dictionary, outpost: Node2D, budget: float) -> float:
	if outpost.network.component("water", Network.port(pump, "water")).is_empty():
		return budget
	return minf(budget, maxf(0, float(Catalog.load_data().pump_capacity) - float(state(pump).water)))

func capture_water(pump: Dictionary, outpost: Node2D, volume: float) -> void:
	if not outpost.network.component("water", Network.port(pump, "water")).is_empty():
		state(pump).water = minf(Catalog.load_data().pump_capacity, float(state(pump).water) + volume)

func status(building: Dictionary, outpost: Node2D) -> String:
	if not outpost.Buildings.is_active(building):
		return "Montaggio in corso"
	if not building.get("enabled", true):
		return "Spento"
	if not outpost.environment_safe(building):
		return "Area contaminata: acqua, gas o petrolio"
	var storage := state(building)
	if building.id == "pump":
		return "Serbatoio %.2f / %.0f u" % [storage.water, Catalog.load_data().pump_capacity]
	if building.id == "gas_converter":
		if float(storage.energy) >= float(Catalog.load_data().converter.capacity) - 0.00001:
			return "Accumulatore pieno"
		var component: Array = outpost.network.component("gas", Network.port(building, "gas"))
		if component.is_empty():
			return "Ingresso gas scollegato"
		var fuel := 0.0
		for cell: Vector2i in component:
			fuel += float(outpost.world.environment.gas.get(cell, 0))
		return "Conversione gas attiva" if fuel > 0.000001 else "Gas esaurito nella condotta"
	if building.id == "furnace" and not storage.output.is_empty():
		return "Prodotto pronto da ritirare"
	if building.id == "greenhouse" and not storage.crop.is_empty() and float(storage.elapsed) >= float(Catalog.load_data().crops[storage.crop].seconds):
		return "Coltura matura"
	if (building.id == "furnace" and storage.recipe.is_empty()) or (building.id == "greenhouse" and storage.crop.is_empty()):
		return "In attesa di un ordine" if building.id == "furnace" else "In attesa di semina"
	if outpost.network.component("energy", Network.port(building, "energy")).is_empty():
		return "Cavo energia scollegato"
	if energy_available(building, outpost) <= 0.000001:
		return "Nessuna energia dal convertitore"
	if building.id == "greenhouse" and water_available(building, outpost) <= 0.000001:
		return "Manca acqua: collega una pompa con i tubi"
	return "Fusione in corso" if building.id == "furnace" else "Coltivazione in corso"

func start_smelting(building: Dictionary, recipe: String, outpost: Node2D) -> bool:
	if building.get("id") != "furnace" or not healthy(building, outpost) or not outpost.site_reachable(building) or not Catalog.load_data().smelting.has(recipe):
		return false
	var storage := state(building)
	if not storage.recipe.is_empty() or not storage.output.is_empty():
		return false
	if not outpost.world.field_cargo.pay(Catalog.load_data().smelting[recipe].cost, true, outpost.payment_cache()):
		return false
	storage.recipe = recipe
	storage.elapsed = 0.0
	return true

func plant(building: Dictionary, crop: String, outpost: Node2D) -> bool:
	if building.get("id") != "greenhouse" or not healthy(building, outpost) or not outpost.site_reachable(building) or crop not in Catalog.CROP_IDS:
		return false
	var storage := state(building)
	var seeds: Dictionary = outpost.world.seeds()
	if not storage.crop.is_empty() or int(seeds.get(crop, 0)) <= 0:
		return false
	seeds[crop] = int(seeds[crop]) - 1
	storage.crop = crop
	storage.elapsed = 0.0
	return true

func collect(building: Dictionary, outpost: Node2D) -> bool:
	if not outpost.site_reachable(building) or not outpost.Buildings.is_active(building):
		return false
	var storage := state(building)
	var cargo: RefCounted = outpost.world.field_cargo
	var with_drone: bool = outpost.world.drone_can_collect()
	if building.id == "furnace" and not storage.output.is_empty():
		if not cargo.collect(storage.output, 1, with_drone):
			return false
		storage.output = ""
		return true
	if building.id != "greenhouse" or storage.crop.is_empty():
		return false
	var crop: Dictionary = Catalog.load_data().crops[storage.crop]
	if float(storage.elapsed) < float(crop.seconds) or not cargo.collect(crop.food, int(crop["yield"]), with_drone):
		return false
	var seeds: Dictionary = outpost.world.seeds()
	seeds[storage.crop] = mini(999, int(seeds.get(storage.crop, 0)) + int(crop.seeds))
	storage.crop = ""
	storage.elapsed = 0.0
	return true

func collect_seed(pod: Dictionary, outpost: Node2D) -> bool:
	var valid: Array = Catalog.seed_sites(outpost.world.site.terrain_seed).filter(func(item: Dictionary): return item.id == pod.get("id") and item.cell == pod.get("cell") and item.crop == pod.get("crop"))
	if valid.is_empty() or pod.id in collected_pods or not outpost.world.site.material(pod.cell).is_empty() or not outpost.reachable_cell(pod.cell):
		return false
	var seeds: Dictionary = outpost.world.seeds()
	if int(seeds.get(pod.crop, 0)) > 997:
		return false
	seeds[pod.crop] = int(seeds.get(pod.crop, 0)) + 2
	collected_pods.append(pod.id)
	outpost.world.guide_event("seeds_found")
	return true

func advance(delta: float, outpost: Node2D, active: Array) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	var remaining := minf(delta, 60)
	while remaining > 0.000001:
		var step := minf(remaining, 0.25)
		_step(step, outpost, active)
		remaining -= step

func _step(delta: float, outpost: Node2D, active: Array) -> void:
	var data := Catalog.load_data()
	for converter: Dictionary in active:
		if converter.id != "gas_converter" or not healthy(converter, outpost):
			continue
		var storage := state(converter)
		var budget := minf(float(data.converter.gas_per_second) * delta, maxf(0, (float(data.converter.capacity) - float(storage.energy)) / float(data.converter.kwh_per_gas)))
		var consumed := 0.0
		for cell: Vector2i in outpost.network.component("gas", Network.port(converter, "gas")):
			if budget <= 0.000001:
				break
			var take: float = outpost.world.environment.drain_gas(cell, 0, budget)
			consumed += take
			budget -= take
		var generated := consumed * float(data.converter.kwh_per_gas)
		storage.energy = minf(data.converter.capacity, float(storage.energy) + generated)
		storage.produced = float(storage.produced) + generated
	for building: Dictionary in active:
		if building.id not in ["furnace", "greenhouse"] or not healthy(building, outpost):
			continue
		var storage := state(building)
		var id: String = storage.recipe if building.id == "furnace" else storage.crop
		if id.is_empty():
			continue
		var definition: Dictionary = data.smelting[id] if building.id == "furnace" else data.crops[id]
		var duration := minf(delta, maxf(0, float(definition.seconds) - float(storage.elapsed)))
		duration = minf(duration, energy_available(building, outpost) / float(definition.power))
		if building.id == "greenhouse":
			duration = minf(duration, water_available(building, outpost) * float(definition.seconds) / float(definition.water))
		if duration <= 0.000001:
			continue
		_consume(building, "energy", duration * float(definition.power), outpost)
		if building.id == "greenhouse":
			_consume(building, "water", duration * float(definition.water) / float(definition.seconds), outpost)
		storage.elapsed = minf(float(definition.seconds), float(storage.elapsed) + duration)
		if float(definition.seconds) - float(storage.elapsed) < 0.000001:
			storage.elapsed = float(definition.seconds)
			if building.id == "furnace":
				storage.output = storage.recipe
				storage.recipe = ""
				storage.elapsed = 0.0

func snapshot() -> Dictionary:
	return {"version": 1, "machines": machines.duplicate(true), "collected_pods": collected_pods.duplicate()}

func restore(data: Variant, buildings: RefCounted, site: RefCounted) -> bool:
	if not data is Dictionary:
		return false
	if data.is_empty():
		machines.clear()
		collected_pods.clear()
		return true
	if data.get("version") != 1 or not data.get("machines") is Dictionary or not data.get("collected_pods") is Array or data.machines.size() > 200:
		return false
	var next := {}
	for identity in data.machines:
		var matches: Array = buildings.structures.filter(func(item: Dictionary): return key(item) == identity and item.id in ["pump", "furnace", "greenhouse", "gas_converter"])
		if matches.size() != 1 or not data.machines[identity] is Dictionary:
			return false
		var id: String = matches[0].id
		var entry: Dictionary = data.machines[identity]
		var shape := defaults(id)
		if entry.size() != shape.size():
			return false
		for property: String in shape:
			if shape[property] is String:
				if not entry.get(property) is String:
					return false
			elif not (entry.get(property) is int or entry.get(property) is float) or not is_finite(entry[property]) or entry[property] < 0:
				return false
		if not preload("res://scripts/systems/outpost_buildings.gd").is_active(matches[0]) and entry != shape:
			return false
		if id == "pump" and entry.water > Catalog.load_data().pump_capacity:
			return false
		if id == "gas_converter" and (entry.energy > Catalog.load_data().converter.capacity or entry.energy > entry.produced + 0.00001):
			return false
		if id == "furnace":
			if (not entry.recipe.is_empty() and not Catalog.load_data().smelting.has(entry.recipe)) or (not entry.output.is_empty() and not Catalog.load_data().smelting.has(entry.output)):
				return false
			if (entry.recipe.is_empty() and entry.elapsed != 0) or (not entry.recipe.is_empty() and (entry.elapsed >= Catalog.load_data().smelting[entry.recipe].seconds or not entry.output.is_empty())):
				return false
		if id == "greenhouse":
			if (not entry.crop.is_empty() and entry.crop not in Catalog.CROP_IDS) or (entry.crop.is_empty() and entry.elapsed != 0):
				return false
			if not entry.crop.is_empty() and entry.elapsed > Catalog.load_data().crops[entry.crop].seconds:
				return false
		next[identity] = entry.duplicate(true)
	var pods: Array[String] = []
	var valid_ids: Array = Catalog.seed_sites(site.terrain_seed).map(func(item: Dictionary): return item.id)
	for id in data.collected_pods:
		if not id is String or id not in valid_ids or id in pods:
			return false
		var pod: Dictionary = Catalog.seed_sites(site.terrain_seed).filter(func(item: Dictionary): return item.id == id)[0]
		if not site.material(pod.cell).is_empty():
			return false
		pods.append(id)
	machines = next
	collected_pods = pods
	return true
