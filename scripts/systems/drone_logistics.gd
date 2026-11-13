extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const Components = preload("res://scripts/data/component_catalog.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const RAW := ["copper", "iron", "crystal", "silica", "cobalt"]
const MISSIONS := ["follow", "outbound", "returning", "collecting", "loading", "delivering", "building"]
var world: Node2D
var worker: CharacterBody2D
var automatic := true
var target: Dictionary = {}
var source_identity: Array = []
var destination := Vector2.ZERO
var status := "Ti seguo"
var timer := 0.0
var cargo_idle := 0.0
var last_raw := 0

func enabled() -> bool:
	return automatic and is_instance_valid(world) and not world.is_robbie()

func stock() -> Dictionary:
	return world.ship_state.resources if world.ship_state != null else world.local_store

func capacity() -> int:
	return world.ship_state.cargo_capacity() if world.ship_state != null else 120

func reset() -> void:
	target = {}
	source_identity = []
	worker.mission = "follow"
	timer = 0
	cargo_idle = 0
	last_raw = 0

func available_components() -> Dictionary:
	var available := {}
	for id: String in Components.COMPONENT_IDS:
		available[id] = int(world.field_cargo.drone.get(id, 0))
		for source: Dictionary in _sources():
			available[id] += int(source.stock.get(id, 0)) + int(world.outpost.fabrication.buffer_at(source.identity).get(id, 0))
	return available

func _sources() -> Array:
	var sources: Array = [{"identity": ["ship"], "stock": stock(), "point": worker.UNLOAD_POINT}]
	for lab: Dictionary in world.outpost.buildings.labs():
		sources.append({"identity": ["laboratory", lab.origin.x, lab.origin.y], "stock": lab.stock, "point": _goal_for(lab), "building": lab})
	return sources

func _source_accessible(source: Dictionary, point: Vector2) -> bool:
	if source.identity == ["ship"]:
		return point.distance_to(worker.UNLOAD_POINT) < 14 and worker._clear(point, worker.UNLOAD_POINT)
	var lab: Dictionary = source.get("building", {})
	return world.outpost.buildings.structures.has(lab) and world.outpost.Buildings.is_active(lab) and world.outpost.environment_safe(lab) and world.outpost.site_reachable(lab, point)

func _supply_for(building: Dictionary) -> Dictionary:
	if not _components_ready(building): return {}
	var nearest := {}
	var distance := INF
	for source: Dictionary in _sources():
		if not _reachable(source.point) or not _source_accessible(source, source.point): continue
		for id: String in world.outpost.site_cost(building):
			var amount: int = int(source.stock.get(id, 0)) + int(world.outpost.fabrication.buffer_at(source.identity).get(id, 0))
			if amount <= 0 or int(world.field_cargo.drone.get(id, 0)) >= int(world.outpost.site_cost(building)[id]): continue
			if world.field_cargo.room_for(world.field_cargo.drone, id, world.field_cargo.drone_capacity) <= 0: continue
			if worker.position.distance_to(source.point) < distance:
				nearest = source
				distance = worker.position.distance_to(source.point)
	return nearest

func _carried(cost: Dictionary) -> bool:
	for id: String in cost:
		if int(world.field_cargo.drone.get(id, 0)) < int(cost[id]): return false
	return true

func _plan() -> Dictionary:
	var head := queue_head()
	if head.is_empty() or not _usable(head): return {}
	return head if head.get("state") == "planned" or head.get("automatic", false) else {}

func queue_head() -> Dictionary:
	for building: Dictionary in world.outpost.buildings.structures:
		if building.get("state") in ["planned", "building"]: return building
	return {}

func ready_or_ordered_components() -> Dictionary:
	var total := available_components()
	for job: Dictionary in world.outpost.fabrication.jobs:
		var recipe := Components.recipe(job.id)
		if not recipe.is_empty() and recipe.output in Components.COMPONENT_IDS:
			total[recipe.output] += int(recipe.amount) * int(job.get("batches", 1))
	return total

func project_deficits(building: Dictionary) -> Dictionary:
	var result := {}
	if building.is_empty() or building.get("state") != "planned": return result
	var reserved := ready_or_ordered_components()
	for id: String in world.outpost.site_cost(building):
		var amount := maxi(0, int(world.outpost.site_cost(building)[id]) - int(reserved.get(id, 0)))
		if amount > 0: result[id] = amount
	return result

func _can_prepare(building: Dictionary) -> bool:
	if building.is_empty() or world.gear.workshop_damaged(): return false
	for id: String in project_deficits(building):
		var recipe := Components.recipe(id)
		var affordable: bool = world.ship_energy() >= float(recipe.energy)
		for raw: String in recipe.cost:
			if int(stock().get(raw, 0)) + int(world.field_cargo.drone.get(raw, 0)) < int(recipe.cost[raw]): affordable = false
		if affordable: return true
	return false

func _request_project_components(building: Dictionary) -> void:
	if building.is_empty(): return
	var missing := project_deficits(building)
	for id: String in missing:
		var recipe := Components.recipe(id)
		var batches := mini(20, ceili(float(missing[id]) / float(recipe.amount)))
		for raw: String in recipe.cost:
			batches = mini(batches, (int(stock().get(raw, 0)) + int(world.field_cargo.drone.get(raw, 0))) / int(recipe.cost[raw]))
		batches = mini(batches, floori(world.ship_energy() / float(recipe.energy)))
		if batches > 0: world.outpost.fabricate_components(id, batches, {"kind": "ship"}, true)

func _usable(building: Dictionary) -> bool:
	if building.get("damaged", false) or not _reachable(_goal_for(building)): return false
	if not world.outpost.placement_blocker(building.id, building.origin, building, _goal_for(building)).is_empty(): return false
	return world.ship_energy() > 0 and world.outpost.construction_connected(building)

func at_site(building: Dictionary) -> bool:
	return enabled() and worker.mission == "building" and target == building and world.outpost.site_reachable(building, worker.position)

func _goal_for(building: Dictionary) -> Vector2:
	var center: Vector2 = world.outpost.buildings.world_rect(building).get_center()
	if worker.graph.get_point_count() == 0: return center
	return worker.graph.get_point_position(worker.graph.get_closest_point(center))

func _assign(mission: String, point: Vector2, text: String) -> void:
	if worker.mission != mission or destination.distance_to(point) > 4:
		worker.route_timer = 0
		worker.has_resting_goal = false
	worker.mission = mission
	destination = point
	status = text

func goal() -> Vector2:
	return destination

func _reached(point: Vector2) -> bool:
	return worker.position.distance_to(point) < 14 and worker._clear(worker.position, point)

func _reachable(point: Vector2) -> bool:
	if worker.graph.get_point_count() == 0: return false
	var start: int = worker.graph.get_closest_point(worker.position)
	var end: int = worker.graph.get_closest_point(point)
	return worker.graph.get_point_position(end).distance_to(point) < 40 and worker.navigation_components.get(start, -1) == worker.navigation_components.get(end, -2)

func _ore_goal() -> Variant:
	var best: Variant = null
	var distance := INF
	for cell: Vector2i in world.gear.drops:
		if world.field_cargo.room_for(world.field_cargo.drone, world.gear.drops[cell], world.field_cargo.drone_capacity) <= 0: continue
		for point: Vector2 in world.gear.fragment_positions(cell):
			if point.distance_to(worker.position) < distance and _reachable(point):
				best = point
				distance = point.distance_to(worker.position)
	return best

func _raw_count() -> int:
	var amount := 0
	for id: String in RAW: amount += int(world.field_cargo.drone.get(id, 0))
	return amount

func _load(building: Dictionary, source: Dictionary) -> bool:
	if not _source_accessible(source, worker.position): return false
	var cost: Dictionary = world.outpost.site_cost(building)
	var trial := Cargo.new()
	trial.enable_drone_only(world.field_cargo.drone_capacity)
	trial.drone = world.field_cargo.drone.duplicate()
	var amounts := {}
	var buffer: Dictionary = world.outpost.fabrication.buffer_at(source.identity)
	for id: String in cost:
		var missing := maxi(0, int(cost[id]) - int(trial.drone.get(id, 0)))
		var taken := mini(missing, int(source.stock.get(id, 0)) + int(buffer.get(id, 0)))
		if taken > 0:
			if not trial.collect_drone(id, taken): return false
			amounts[id] = taken
	if amounts.is_empty(): return false
	for id: String in amounts:
		var taken: int = amounts[id]
		var stored := mini(taken, int(source.stock.get(id, 0)))
		source.stock[id] = int(source.stock.get(id, 0)) - stored
		if taken > stored:
			buffer[id] -= taken - stored
		world.field_cargo.drone[id] = int(world.field_cargo.drone.get(id, 0)) + taken
	world.guide_event("components_collected")
	return true

func _components_ready(building: Dictionary) -> bool:
	if building.is_empty(): return false
	var available := available_components()
	var complete := true
	for id: String in world.outpost.site_cost(building):
		if int(available.get(id, 0)) < int(world.outpost.site_cost(building)[id]): complete = false
	return complete

func _room_for_plan(building: Dictionary) -> bool:
	var trial := Cargo.new()
	trial.enable_drone_only(world.field_cargo.drone_capacity)
	trial.drone = world.field_cargo.drone.duplicate()
	for id: String in world.outpost.site_cost(building):
		var missing := maxi(0, int(world.outpost.site_cost(building)[id]) - int(trial.drone.get(id, 0)))
		if missing > 0 and not trial.collect_drone(id, missing): return false
	return true

func advance(delta: float) -> void:
	if not enabled() or delta <= 0 or not is_finite(delta): return
	cargo_idle += delta
	var raw := _raw_count()
	if raw != last_raw:
		cargo_idle = 0
		last_raw = raw
	timer -= delta
	if timer > 0: return
	timer = 0.2
	if worker.graph.get_point_count() == 0: return
	if not target.is_empty() and target != queue_head():
		target = {}
		_assign("follow", world.player_center(), "Attendo il primo progetto della coda")
	if not target.is_empty() and (not world.outpost.buildings.structures.has(target) or target.get("state") == "active"):
		target = {}
		_assign("returning", world.player_center(), "Rientro verso di te")
	if not target.is_empty() and worker.mission in ["loading", "delivering", "building"] and not _usable(target):
		target = {}
		_assign("follow", world.player_center(), "Cantiere sospeso / Cerco un altro incarico")
	if worker.mission == "loading" and not target.is_empty():
		var source := {}
		for candidate: Dictionary in _sources():
			if candidate.identity == source_identity: source = candidate
		if not source.is_empty() and _reachable(source.point) and _source_accessible(source, source.point):
			_assign("loading", source.point, "Ritiro semilavorati ordinati")
			if not _reached(source.point): return
			_load(target, source)
		_assign("follow", world.player_center(), "Scelgo la prossima consegna")
	if worker.mission == "building" and not target.is_empty():
		if target.get("state") == "building":
			_assign("building", _goal_for(target), "Montaggio: " + world.outpost.Buildings.NAMES[target.id])
			return
	if worker.mission == "delivering" and not target.is_empty():
		_assign("delivering", _goal_for(target), status)
		if target.get("state") != "planned":
			target = {}
		elif _reached(destination):
			if world.outpost.fund_site_for_worker(target):
				_assign("building", destination, "Montaggio in corso")
			else:
				status = world.outpost.funding_blocker(target, worker.position)
			if worker.mission == "building": return
			if not _carried(world.outpost.site_cost(target)):
				target = {}
			else: return
		else: return
	if worker.mission == "outbound":
		if not _reached(worker.UNLOAD_POINT): return
		world.field_cargo.unload_drone(stock(), capacity())
		world.outpost._flush_component_buffers()
		if world.gear.workshop_damaged() or world.ship_energy() <= 0:
			status = "Officina della nave danneggiata" if world.gear.workshop_damaged() else "Batteria nave scarica"
			return
		target = _plan()
		_request_project_components(target)
		if not target.is_empty() and target.get("state") == "building":
			_assign("building", _goal_for(target), "Riprendo il montaggio")
			return
		if _raw_count() > 0 or world.field_cargo.used(world.field_cargo.drone) >= world.field_cargo.drone_capacity:
			status = "Deposito nave pieno / Carico conservato"
			return
		_assign("returning", world.player_center(), "Rientro verso di te")
		raw = _raw_count()
	if worker.mission == "returning":
		_assign("returning", world.player_center(), "Rientro verso di te")
		if _reached(world.player_center()) or worker.position.distance_to(world.player_center()) <= 100:
			_assign("follow", world.player_center(), "Ti seguo")
	target = _plan()
	if not target.is_empty() and target.get("state") == "building":
		_assign("building", _goal_for(target), "Montaggio in corso")
		return
	if not target.is_empty() and _carried(world.outpost.site_cost(target)):
		_assign("delivering", _goal_for(target), "Consegna al cantiere")
		return
	if not target.is_empty() and _components_ready(target) and not _room_for_plan(target):
		_assign("outbound", worker.UNLOAD_POINT, "Scarico per fare spazio ai semilavorati")
		return
	var source := _supply_for(target) if not target.is_empty() else {}
	if not source.is_empty():
		source_identity = source.identity.duplicate()
		_assign("loading", source.point, "Ritiro semilavorati ordinati")
		return
	var used: int = world.field_cargo.used(world.field_cargo.drone)
	if _can_prepare(target) or used >= world.field_cargo.drone_capacity or (raw > 0 and (cargo_idle > 2 or used >= world.field_cargo.drone_capacity - 1)):
		_assign("outbound", worker.UNLOAD_POINT, "Alla nave per scaricare")
		return
	var ore: Variant = _ore_goal()
	if ore is Vector2:
		_assign("collecting", ore, "Raccolta minerali")
	else:
		if worker.mission != "returning":
			_assign("follow", world.player_center(), "Ti seguo" if target.is_empty() else "In attesa dei semilavorati ordinati")

func project_status(building: Dictionary) -> String:
	if building.get("state") == "active": return "Attivo"
	var head := queue_head()
	if not head.is_empty() and head != building:
		var pending: Array = world.outpost.buildings.structures.filter(func(item: Dictionary): return item.get("state") in ["planned", "building"])
		return "In coda %d/%d / Attende il progetto precedente: %s" % [pending.find(building) + 1, pending.size(), world.outpost.Buildings.NAMES[head.id]]
	if building.get("damaged", false): return "Cantiere danneggiato / Riparazione necessaria"
	if world.ship_energy() <= 0: return "Batteria nave scarica"
	var reason: String = world.outpost.placement_blocker(building.id, building.origin, building, _goal_for(building))
	if not reason.is_empty(): return reason
	if not _reachable(_goal_for(building)): return "Percorso di Robbie ostruito"
	if target == building and worker.mission in ["loading", "delivering", "building"]: return status
	var available := available_components()
	var ordered := ready_or_ordered_components()
	var missing: Array[String] = []
	var in_production := false
	for id: String in world.outpost.site_cost(building):
		var needed: int = int(world.outpost.site_cost(building)[id])
		if int(available.get(id, 0)) < needed: in_production = true
		var deficit: int = needed - int(ordered.get(id, 0))
		if deficit > 0:
			missing.append("%d %s" % [deficit, "strutturali" if id == "structural_component" else "elettronici"])
	if not missing.is_empty():
		return "Preparo %s per questo progetto / Servono minerali ed energia alla nave" % ", ".join(missing)
	if in_production: return "Semilavorati ordinati / In coda o in lavorazione al laboratorio"
	return "In coda a Robbie / Componenti pronti per la consegna"
