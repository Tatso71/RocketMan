extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const Components = preload("res://scripts/data/component_catalog.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const RAW := ["copper", "iron", "crystal", "silica", "cobalt"]
const DEFAULT_BUFFER := {"structural_component": 4, "electronic_component": 2}
const MISSIONS := ["follow", "outbound", "returning", "collecting", "delivering", "building"]
var world: Node2D
var worker: CharacterBody2D
var automatic := true
var target: Dictionary = {}
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
	worker.mission = "follow"
	timer = 0
	cargo_idle = 0
	last_raw = 0

func available_components() -> Dictionary:
	var available := {}
	for id: String in Components.COMPONENT_IDS:
		available[id] = int(stock().get(id, 0)) + int(world.field_cargo.drone.get(id, 0)) + int(world.outpost.fabrication.buffer_at(["ship"]).get(id, 0))
	return available

func _carried(cost: Dictionary) -> bool:
	for id: String in cost:
		if int(world.field_cargo.drone.get(id, 0)) < int(cost[id]): return false
	return true

func _plan() -> Dictionary:
	for building: Dictionary in world.outpost.buildings.structures:
		if building.get("state") == "building" and building.get("automatic", false) and _usable(building): return building
	var waiting := {}
	for building: Dictionary in world.outpost.buildings.structures:
		if building.get("state") != "planned" or not _usable(building): continue
		if _carried(world.outpost.site_cost(building)) or _ship_work_ready(building): return building
		if waiting.is_empty(): waiting = building
	return waiting

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

func _demand() -> Dictionary:
	var result := DEFAULT_BUFFER.duplicate()
	for building: Dictionary in world.outpost.buildings.structures:
		if building.get("state") != "planned": continue
		for id: String in world.outpost.site_cost(building):
			result[id] = maxi(int(result[id]), int(world.outpost.site_cost(building)[id]))
	return result

func _start_production() -> bool:
	var outpost: Node2D = world.outpost
	if not outpost.fabrication.job_at(["ship"]).is_empty(): return true
	if world.gear.workshop_damaged() or world.ship_energy() <= 0: return false
	var available := available_components()
	var demand := _demand()
	for id: String in demand:
		if int(available[id]) >= int(demand[id]): continue
		var recipe := Components.recipe(id)
		var affordable: bool = world.ship_energy() >= float(recipe.energy)
		for raw: String in recipe.cost:
			if int(stock().get(raw, 0)) + int(world.field_cargo.drone.get(raw, 0)) < int(recipe.cost[raw]): affordable = false
		if not affordable: continue
		# Reserve ingredients atomically into the existing paid production job.
		for raw: String in recipe.cost:
			var from_store := mini(int(stock().get(raw, 0)), int(recipe.cost[raw]))
			stock()[raw] = int(stock().get(raw, 0)) - from_store
			world.field_cargo.drone[raw] = int(world.field_cargo.drone.get(raw, 0)) - (int(recipe.cost[raw]) - from_store)
		world._set_ship_energy(world.ship_energy() - float(recipe.energy))
		outpost.fabrication.jobs.append({"id": id, "level": 1, "station": ["ship"], "elapsed": 0.0, "seconds": outpost.fabrication_seconds({"kind": "ship"}, id), "batches": 1})
		world.guide_event("component_production_started")
		return true
	return false

func _load(building: Dictionary) -> bool:
	var cost: Dictionary = world.outpost.site_cost(building)
	var trial := Cargo.new()
	trial.enable_drone_only(world.field_cargo.drone_capacity)
	trial.drone = world.field_cargo.drone.duplicate()
	var available := available_components()
	for id: String in cost:
		if int(available.get(id, 0)) < int(cost[id]): return false
		var missing := maxi(0, int(cost[id]) - int(trial.drone.get(id, 0)))
		if missing > 0 and not trial.collect_drone(id, missing): return false
	for id: String in cost:
		var taken := maxi(0, int(cost[id]) - int(world.field_cargo.drone.get(id, 0)))
		var stored := mini(taken, int(stock().get(id, 0)))
		stock()[id] = int(stock().get(id, 0)) - stored
		if taken > stored:
			world.outpost.fabrication.buffer_at(["ship"])[id] -= taken - stored
		world.field_cargo.drone[id] = int(world.field_cargo.drone.get(id, 0)) + taken
	world.guide_event("components_collected")
	return true

func _ship_work_ready(building: Dictionary) -> bool:
	if building.is_empty(): return false
	var available := available_components()
	var complete := true
	for id: String in world.outpost.site_cost(building):
		if int(available.get(id, 0)) < int(world.outpost.site_cost(building)[id]): complete = false
	if complete: return true
	if world.ship_energy() <= 0 or world.gear.workshop_damaged(): return false
	for id: String in _demand():
		if int(available.get(id, 0)) >= int(_demand()[id]): continue
		var recipe := Components.recipe(id)
		var ready := true
		for raw: String in recipe.cost:
			if int(stock().get(raw, 0)) < int(recipe.cost[raw]): ready = false
		if ready: return true
	return false

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
	if not target.is_empty() and (not world.outpost.buildings.structures.has(target) or target.get("state") == "active"):
		target = {}
		_assign("returning", world.player_center(), "Rientro verso di te")
	if not target.is_empty() and worker.mission in ["delivering", "building"] and not _usable(target):
		target = {}
		_assign("follow", world.player_center(), "Cantiere sospeso / Cerco un altro incarico")
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
		if not target.is_empty() and target.get("state") == "building":
			_assign("building", _goal_for(target), "Riprendo il montaggio")
			return
		if not target.is_empty() and target.get("state") == "planned" and _load(target):
			_assign("delivering", _goal_for(target), "Consegna: " + world.outpost.Buildings.NAMES[target.id])
			return
		if _start_production():
			status = "Conversione materiali alla nave"
			return
		if _raw_count() > 0 or world.field_cargo.used(world.field_cargo.drone) >= world.field_cargo.drone_capacity:
			status = "Deposito nave pieno / Carico conservato"
			return
		_assign("returning", world.player_center(), "Rientro verso di te")
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
	var need_stock := _ship_work_ready(target)
	if (raw > 0 and (cargo_idle > 2 or world.field_cargo.used(world.field_cargo.drone) >= world.field_cargo.drone_capacity - 1)) or need_stock:
		_assign("outbound", worker.UNLOAD_POINT, "Alla nave: scarico e conversione")
		return
	var ore: Variant = _ore_goal()
	if ore is Vector2:
		_assign("collecting", ore, "Raccolta minerali")
	else:
		if worker.mission != "returning":
			_assign("follow", world.player_center(), "Ti seguo" if target.is_empty() else "In attesa dei minerali per il cantiere")

func project_status(building: Dictionary) -> String:
	if building.get("state") == "active": return "Attivo"
	if building.get("damaged", false): return "Cantiere danneggiato / Riparazione necessaria"
	if world.ship_energy() <= 0: return "Batteria nave scarica"
	var reason: String = world.outpost.placement_blocker(building.id, building.origin, building, _goal_for(building))
	if not reason.is_empty(): return reason
	if not _reachable(_goal_for(building)): return "Percorso di Robbie ostruito"
	if target == building and worker.mission in ["delivering", "building"]: return status
	return "In coda a Robbie / Materiali in raccolta o conversione"
