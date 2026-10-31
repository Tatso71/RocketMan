extends Node2D

const Grid = preload("res://scripts/world/world_grid.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const InventoryUI = preload("res://scripts/ui/field_inventory_ui.gd")
const StationMenu = preload("res://scripts/ui/workstation_menu.gd")
const ConstructionUI = preload("res://scripts/ui/fabrication_ui.gd")
const OcraCatalog = preload("res://scripts/data/ocra_catalog.gd")
const Fabrication = preload("res://scripts/systems/fabrication_state.gd")
const CubeView = preload("res://scripts/ui/physical_cube_view.gd")
const EnergyUI = preload("res://scripts/ui/laboratory_energy_ui.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const Industry = preload("res://scripts/systems/industry_state.gd")
const IndustryUI = preload("res://scripts/ui/industry_ui.gd")
const SHIP_LAB_RECT := Rect2(-156, -194, 312, 114)
const ITEM_NAMES := Cargo.NAMES
var world: Node2D
var buildings := Buildings.new()
var build_mode := false
var blueprint := "laboratory"
var origin := Vector2i.ZERO
var cargo_window: Window
var cargo_ui: CanvasLayer
var light_sources: Array = []
var stick_timer := 0.0
var station_menu: Node
var selected_station: Dictionary = {}
var construction: Node
var preview_fixed := false
var power_load := 0.0
var fabrication := Fabrication.new()
var local_lab_level := 1
var activation_cube_id := 0
var energy_ui: CanvasLayer
var network := Network.new()
var industry := Industry.new()
var industry_ui: Node2D

func toggle_build() -> void:
	world._note("Fabbrica un cubo nel laboratorio, prendilo e posalo con Spazio")

func placement_origin(id: String, anchor: Vector2i) -> Vector2i:
	var size := buildings.size_for(id)
	return anchor - Vector2i(size.x / 2, size.y - 1)

func _ready() -> void:
	_build_interface()
	station_menu = StationMenu.new()
	station_menu.outpost = self
	add_child(station_menu)
	construction = ConstructionUI.new()
	construction.outpost = self
	add_child(construction)
	var cube_view := CubeView.new()
	cube_view.outpost = self
	cube_view.z_index = 7
	add_child(cube_view)
	energy_ui = EnergyUI.new()
	energy_ui.outpost = self
	add_child(energy_ui)
	industry_ui = IndustryUI.new()
	industry_ui.outpost = self
	add_child(industry_ui)

func station_rect(station: Dictionary) -> Rect2:
	return SHIP_LAB_RECT if station.get("kind") == "ship" else buildings.world_rect(station.building)

func station_available(station: Dictionary) -> bool:
	if station.is_empty():
		return false
	if station.get("kind") == "ship":
		return world.aboard_workshop() and (not is_instance_valid(world.gear) or not world.gear.workshop_damaged())
	if station.get("kind") != "laboratory" or not buildings.structures.has(station.get("building")) or not Buildings.is_active(station.building):
		return false
	return site_reachable(station.building)

func site_reachable(building: Dictionary) -> bool:
	if not buildings.structures.has(building):
		return false
	var point: Vector2 = world.player.position - Vector2(0, 32)
	var rect := buildings.world_rect(building)
	var closest := point.clamp(rect.position + Vector2.ONE, rect.end - Vector2.ONE)
	if point.distance_to(closest) > Grid.metres(1.5):
		return false
	if rect.has_point(point):
		return true
	var ray := PhysicsRayQueryParameters2D.create(point, closest, 1, [world.player.get_rid(), world.drone.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func station_at(point: Vector2) -> Dictionary:
	if SHIP_LAB_RECT.has_point(point) and station_available({"kind": "ship"}):
		return {"kind": "ship"}
	for lab: Dictionary in buildings.labs():
		var station := {"kind": "laboratory", "building": lab}
		if station_rect(station).has_point(point) and station_available(station):
			return station
	return {}

func nearby_station() -> Dictionary:
	if station_available(selected_station):
		return selected_station
	if station_available({"kind": "ship"}):
		return {"kind": "ship"}
	var lab := nearby_lab()
	return {"kind": "laboratory", "building": lab} if not lab.is_empty() else {}

func storage_capacity() -> int:
	var station := nearby_station()
	if station.get("kind") == "ship":
		return world.ship_state.cargo_capacity() if world.ship_state != null else 120
	return Buildings.cache_capacity(station.building) if not station.is_empty() else Buildings.CACHE_CAPACITY

func open_station(station: Dictionary, viewport_point: Vector2) -> bool:
	if not station_available(station):
		return false
	selected_station = station
	world.guide_event("workshop_interacted" if station.get("kind") == "ship" else "laboratory_interacted")
	world.mouse_mining = false
	station_menu.open(viewport_point)
	return true

func station_name() -> String:
	return "Laboratorio di bordo" if nearby_station().get("kind") == "ship" else "Laboratorio sotterraneo"

func signal_range() -> float:
	return world.ship_state.drone_range_metres() if world.ship_state != null else 15.0

func operational(building: Dictionary) -> bool:
	if building.id != "laboratory" or not Buildings.is_active(building) or not building.get("enabled", true) or not safe_link(building):
		return false
	return world.ship_energy() > 0

func safe_link(building: Dictionary) -> bool:
	if buildings.world_rect(building).get_center().distance_to(Vector2(0, -80)) > Grid.metres(signal_range()):
		return false
	return environment_safe(building)

func environment_safe(building: Dictionary) -> bool:
	var rect := buildings.footprint(building.id, building.origin)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if not Buildings.environment_safe(building.id, float(world.environment.water.get(cell, 0)), float(world.environment.gas.get(cell, 0)), float(world.environment.oil.get(cell, 0)), float(world.environment.acid.get(cell, 0))):
				return false
	return true

func has_lab() -> bool:
	return buildings.labs().any(func(building: Dictionary): return operational(building))

func laboratory_unlocked() -> bool:
	return (world.ship_state != null and world.ship_state.lab_research_unlocked) or world.guide_state.facts.get("lab_built", false) or not buildings.labs().is_empty()

func recipe_visible(id: String) -> bool:
	return id in ["laboratory", "bomb"] or ((id in Buildings.DEVICE_IDS or id in Buildings.INDUSTRIAL_IDS) and laboratory_unlocked())

func reachable_cell(cell: Vector2i, reach: float = 3.0) -> bool:
	if not world.site.contains(cell):
		return false
	var hand: Vector2 = world.player.position - Vector2(0, 32)
	if hand.distance_to(Grid.center(cell)) > Grid.metres(reach):
		return false
	var ray := PhysicsRayQueryParameters2D.create(hand, Grid.center(cell), 1, [world.player.get_rid(), world.drone.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func conduit_blocker(kind: String, cell: Vector2i) -> String:
	if kind not in Network.KINDS or not world.site.contains(cell) or not world.site.material(cell).is_empty():
		return "Serve una cella scavata"
	if network.cells[kind].has(cell):
		return "Condotto gia presente"
	if not reachable_cell(cell):
		return "Condotto fuori portata o dietro una parete"
	return "" if world.field_cargo.can_pay(Industry.Catalog.load_data().conduit_cost, true, payment_cache()) else "Serve 1 rame per metro di condotto"

func place_conduit(kind: String, cell: Vector2i) -> bool:
	var reason := conduit_blocker(kind, cell)
	if not reason.is_empty():
		world._note(reason)
		return false
	if not world.field_cargo.pay(Industry.Catalog.load_data().conduit_cost, true, payment_cache()):
		return false
	network.add(kind, cell)
	world._note(Network.NAMES[kind] + " installato / 1 m")
	return true

func remove_conduit(kind: String, cell: Vector2i) -> bool:
	if not reachable_cell(cell) or not network.remove(kind, cell):
		return false
	world._note(Network.NAMES[kind] + " rimosso")
	return true

func find_laboratory_space() -> Variant:
	var torso: Vector2 = world.player.position - Vector2(0, 32)
	var near := Grid.to_cell(torso)
	for y in range(maxi(0, near.y - 4), mini(world.site.DEPTH - 3, near.y + 3)):
		for x in range(maxi(world.site.LEFT, near.x - 5), mini(world.site.RIGHT - 3, near.x + 3)):
			var cell := Vector2i(x, y)
			var center := Grid.to_world(cell) + Grid.to_world(Buildings.LAB_SIZE) * 0.5
			if torso.distance_to(center) <= Grid.metres(3) and center.distance_to(Vector2(0, -80)) <= Grid.metres(signal_range()) and buildings.blocker("laboratory", cell, world.site, world.environment).is_empty():
				return cell
	return null

func nearby_lab() -> Dictionary:
	if selected_station.get("kind") == "laboratory" and station_available(selected_station):
		return selected_station.building
	for building: Dictionary in buildings.labs():
		if station_available({"kind": "laboratory", "building": building}):
			return building
	return {}

func payment_cache() -> Dictionary:
	var lab := nearby_lab()
	return lab.stock if not lab.is_empty() else {}

func source_stock() -> Dictionary:
	if world.aboard_workshop():
		return world.ship_state.resources if world.ship_state != null else world.local_store
	return payment_cache()

func source_available() -> bool:
	return station_available({"kind": "ship"}) or not nearby_lab().is_empty()

func lab_definition() -> Dictionary:
	return recipe_definition("laboratory")

func recipe_definition(id: String) -> Dictionary:
	if id == "bomb":
		return {"name_it": "Bomba", "cost": world.Gear.BOMB_COST.duplicate(), "seconds": 2.0, "energy": 0.01}
	return OcraCatalog.load_data().get("fabrication", {}).get(id, {})

func cube_event(id: String, phase: String) -> String:
	if id == "lamp" and phase == "crafted":
		return "lamp_crafted"
	return ("lab" if id == "laboratory" else id) + "_cube_" + phase

func lab_cube_count() -> int:
	return fabrication.cubes.filter(func(cube: Dictionary): return cube.id == "laboratory").size() + world.field_cargo.available("lab_cube", true)

func station_identity(station: Dictionary) -> Array:
	return ["ship"] if station.get("kind") == "ship" else ["laboratory", station.building.origin.x, station.building.origin.y]

func resolve_station(identity: Array) -> Dictionary:
	if identity == ["ship"]:
		return {"kind": "ship"}
	for lab: Dictionary in buildings.labs():
		if identity == ["laboratory", lab.origin.x, lab.origin.y]:
			return {"kind": "laboratory", "building": lab}
	return {}

func station_level(station: Dictionary = {}) -> int:
	var current := nearby_station() if station.is_empty() else station
	return int(world.ship_state.laboratory_level if world.ship_state != null else local_lab_level) if current.get("kind") == "ship" else int(current.get("building", {}).get("level", 1))

func fabrication_seconds(station: Dictionary = {}, id: String = "laboratory") -> float:
	return float(recipe_definition(id).get("seconds", 5.0)) / (1.0 + 0.5 * (station_level(station) - 1))

func fabrication_stock() -> Dictionary:
	return source_stock() if source_available() else {}

func fabrication_amount(id: String) -> int:
	return world.field_cargo.available(id, true, fabrication_stock())

func station_output(station: Dictionary) -> Vector2:
	return Vector2(-80, -80) if station.get("kind") == "ship" else Vector2(buildings.world_rect(station.building).get_center().x, buildings.world_rect(station.building).end.y)

func fabrication_blocker(id: String = "laboratory") -> String:
	var definition := recipe_definition(id)
	if definition.is_empty():
		return "Ricetta non disponibile"
	if not recipe_visible(id):
		return "Attiva il primo laboratorio per sbloccare questa ricetta"
	var station := nearby_station()
	if station.is_empty():
		return "Raggiungi un laboratorio per fabbricare il cubo"
	if station.get("kind") != "ship" and not operational(station.building):
		return "Laboratorio spento, non alimentato o area non sicura"
	if id == "bomb" and world.gear.ammo() >= world.Gear.BOMB_CAPACITY:
		return "Scorte bombe piene: 4/4"
	var identity := station_identity(station)
	if not fabrication.job_at(identity).is_empty():
		return "Produzione in corso su questo banco"
	if not fabrication.output_at(identity).is_empty():
		return "Prendi il cubo pronto sul banco con Spazio"
	if fabrication.cubes.any(func(cube: Dictionary): return cube.uid != fabrication.carried_id and cube.position.distance_to(station_output(station)) < 32):
		return "Banco occupato da un cubo posato: spostalo con Spazio"
	if fabrication.jobs.size() + fabrication.cubes.size() >= 200:
		return "Troppi cubi o lavorazioni: utilizza quelli gia prodotti"
	if world.ship_energy() < float(definition.energy):
		return "Ricarica la batteria della nave"
	if not world.field_cargo.can_pay(definition.cost, true, fabrication_stock()):
		if not world.drone_help_available() and world.field_cargo.used(world.field_cargo.drone) > 0:
			return "Attendi Robbie entro 3 m per usare il suo carico"
		var missing: Array[String] = []
		for resource: String in definition.cost:
			var deficit: int = int(definition.cost[resource]) - fabrication_amount(resource)
			if deficit > 0:
				missing.append("%d %s" % [deficit, ITEM_NAMES[resource].to_lower()])
		return "Mancano: " + ", ".join(missing)
	return ""

func fabricate_lab_cube() -> bool:
	return fabricate_cube("laboratory")

func fabricate_cube(id: String) -> bool:
	var reason := fabrication_blocker(id)
	if not reason.is_empty():
		world._note(reason)
		return false
	var definition := recipe_definition(id)
	if not world.field_cargo.pay(definition.cost, true, fabrication_stock()):
		return false
	world._set_ship_energy(world.ship_energy() - float(definition.energy))
	fabrication.jobs.append({"id": id, "level": 1, "station": station_identity(nearby_station()), "elapsed": 0.0, "seconds": fabrication_seconds({}, id)})
	world.guide_event(("lab" if id == "laboratory" else id) + "_fabrication_started")
	world._note("Produzione avviata: " + definition.name_it)
	return true

func advance_fabrication(delta: float) -> void:
	if delta <= 0 or not is_finite(delta):
		return
	for job: Dictionary in fabrication.jobs.duplicate():
		var station := resolve_station(job.station)
		if not fabrication_pause_reason(job).is_empty():
			continue
		job.elapsed = minf(job.seconds, float(job.elapsed) + delta)
		if job.elapsed >= job.seconds:
			if job.id == "bomb":
				world.gear.set_ammo(world.gear.ammo() + 1)
				fabrication.jobs.erase(job)
				world._note("Bomba fabbricata / Scorte %d/4" % world.gear.ammo())
				continue
			fabrication.add_cube(station_output(station), job.station, job.id)
			fabrication.jobs.erase(job)
			world.guide_event(cube_event(job.id, "crafted"))
			world._note("Cubo %s pronto sul banco: premi Spazio" % Buildings.NAMES[job.id].to_lower())

func fabrication_pause_reason(job: Dictionary) -> String:
	if job.id == "bomb" and world.gear.ammo() >= world.Gear.BOMB_CAPACITY:
		return "Produzione in pausa / Scorte bombe piene"
	var station := resolve_station(job.station)
	if station.is_empty():
		return "Produzione in pausa / laboratorio non disponibile"
	if world.ship_energy() <= 0:
		return "Produzione in pausa / ricarica la batteria della nave"
	if station.kind != "ship" and not operational(station.building):
		return "Produzione in pausa / accendi il laboratorio e verifica collegamento e sicurezza"
	if station.kind == "ship" and world.gear.workshop_damaged():
		return "Produzione in pausa / ripara il laboratorio di bordo"
	return ""

func cube_near_player(cube: Dictionary) -> bool:
	var point: Vector2 = cube.position
	return absf(point.x - world.player.position.x) <= Grid.metres(1.1) and absf(point.y - world.player.position.y) <= Grid.metres(1.1) and _clear_cube_path(point)

func _clear_cube_path(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(world.player.position - Vector2(0, 24), point - Vector2(0, 20), 1, [world.player.get_rid(), world.drone.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func cube_at(point: Vector2) -> Dictionary:
	for cube: Dictionary in fabrication.cubes:
		if cube.uid != fabrication.carried_id and Rect2(cube.position - Vector2(22, 42), Vector2(44, 46)).has_point(point) and cube_near_player(cube):
			return cube
	return {}

func use_cube() -> bool:
	var carried := fabrication.carried()
	if not carried.is_empty():
		var cell := Grid.to_cell(world.player.position - Vector2(0, 1))
		if not world.on_ladder(world.player.position) and not world.player.is_on_floor():
			world._note("Per posare il cubo fermati sul pavimento o su una scala")
			return true
		if cell.y >= 0 and (not world.site.contains(cell) or not world.site.material(cell).is_empty()):
			world._note("Non puoi posare il cubo dentro la roccia")
			return true
		var point := Vector2(Grid.center(cell).x, (cell.y + 1) * Grid.CELL_SIZE)
		if cell.y < 0:
			point = Vector2(world.player.position.x, world.player.position.y)
		if fabrication.cubes.any(func(cube: Dictionary): return cube.uid != carried.uid and cube.position.distance_to(point) < 32):
			world._note("C'e gia un cubo in questo punto")
			return true
		for job: Dictionary in fabrication.jobs:
			var station := resolve_station(job.station)
			if not station.is_empty() and station_output(station).distance_to(point) < 32:
				world._note("Il banco sta producendo un cubo: posa questo altrove")
				return true
		carried.position = point
		fabrication.carried_id = 0
		world.player.queue_redraw()
		world.guide_event(cube_event(carried.id, "dropped"))
		world._note("Cubo posato: clic destro sul cubo per attivarlo")
		return true
	var nearest: Dictionary = {}
	var distance := INF
	for cube: Dictionary in fabrication.cubes:
		var candidate: float = cube.position.distance_to(world.player.position)
		if cube_near_player(cube) and candidate < distance:
			nearest = cube
			distance = candidate
	if nearest.is_empty():
		# Old saves carried paid cubes as inventory items. Materialize one on pickup.
		if world.field_cargo.available("lab_cube", true) <= 0:
			return false
		world.field_cargo.pay({"lab_cube": 1}, true)
		nearest = fabrication.add_cube(world.player.position)
	fabrication.carried_id = nearest.uid
	world.player.queue_redraw()
	nearest.station = []
	activation_cube_id = 0
	build_mode = false
	world.guide_event(cube_event(nearest.id, "carried"))
	world._note("%s in mano / Spazio per posare" % Buildings.NAMES[nearest.id])
	return true

func cube_origin(cube: Dictionary) -> Vector2i:
	return placement_origin(cube.id, Grid.to_cell(cube.position - Vector2(0, 1)))

func activation_cube() -> Dictionary:
	for cube: Dictionary in fabrication.cubes:
		if cube.uid == activation_cube_id and cube.uid != fabrication.carried_id:
			return cube
	return {}

func activate_cube(cube: Dictionary) -> bool:
	if not fabrication.cubes.has(cube) or cube.uid == fabrication.carried_id or not cube_near_player(cube):
		world._note("Avvicinati al cubo posato per attivarlo")
		return false
	activation_cube_id = cube.uid
	blueprint = cube.id
	origin = cube_origin(cube)
	preview_fixed = true
	build_mode = true
	var reason := placement_blocker(cube.id, origin)
	if not reason.is_empty():
		world._note(reason + ". Riprendi il cubo con Spazio e spostalo.")
		return false
	var building: Dictionary = buildings.plan(cube.id, origin)
	building.state = "building"
	building.progress = 0.0
	fabrication.cubes.erase(cube)
	activation_cube_id = 0
	build_mode = false
	world.guide_event(cube_event(cube.id, "deployed"))
	world._note("Apertura: %s / materiali gia pagati" % Buildings.NAMES[cube.id])
	return true

func move_fabrication_to_ship() -> void:
	if world.ship_state == null:
		return
	var aboard := Fabrication.new()
	for job: Dictionary in fabrication.jobs.duplicate():
		if job.station == ["ship"]:
			aboard.jobs.append(job)
			fabrication.jobs.erase(job)
	for cube: Dictionary in fabrication.cubes.duplicate():
		if cube.uid == fabrication.carried_id or (cube.position.y < 0 and absf(cube.position.x) < 160):
			var copy := aboard.add_cube(cube.position, cube.station, cube.id)
			if cube.uid == fabrication.carried_id:
				aboard.carried_id = copy.uid
				fabrication.carried_id = 0
			fabrication.cubes.erase(cube)
	world.ship_state.fabrication = aboard

func preview_blocker(id: String, cell: Vector2i) -> String:
	var reason := placement_blocker(id, cell)
	if not reason.is_empty():
		return reason
	var cube := activation_cube()
	if cube.is_empty() or cube.id != id:
		return "Posa il cubo con Spazio e attivalo con clic destro"
	return ""

func deploy_lab_cube(cell: Vector2i) -> bool:
	var cube := activation_cube()
	return not cube.is_empty() and cube_origin(cube) == cell and activate_cube(cube)

func place_blueprint(cell: Vector2i) -> bool:
	return deploy_lab_cube(cell)

func placement_blocker(id: String, cell: Vector2i) -> String:
	if (id in Buildings.DEVICE_IDS or id in Buildings.INDUSTRIAL_IDS) and not laboratory_unlocked():
		return "Costruisci e attiva il primo laboratorio"
	if buildings.structures.size() >= 200:
		return "Limite di strutture e cantieri raggiunto"
	var reason := buildings.blocker(id, cell, world.site, world.environment)
	if not reason.is_empty():
		return reason
	var rect := Rect2(Grid.to_world(cell), Grid.to_world(buildings.size_for(id)))
	if is_instance_valid(world.gear) and world.gear.bombs.any(func(bomb: Dictionary): return rect.intersects(Grid.rect(bomb.cell))):
		return "Ingombro occupato da una bomba"
	var torso: Vector2 = world.player.position - Vector2(0, 32)
	if torso.distance_to(rect.get_center()) > Grid.metres(3):
		return "Cantiere fuori portata"
	if id == "laboratory" and rect.get_center().distance_to(Vector2(0, -80)) > Grid.metres(signal_range()):
		return "Laboratorio fuori dal segnale della nave"
	if id == "ladder" and world.ladders.has(cell):
		return "Scala gia presente"
	if id in Buildings.DEVICE_IDS and not has_lab():
		return "Costruisci prima un laboratorio operativo"
	if id in Buildings.DEVICE_IDS and not buildings.labs().any(func(lab: Dictionary): return operational(lab) and buildings.world_rect(lab).get_center().distance_to(rect.get_center()) <= Grid.metres(Buildings.light_range(lab))):
		return "Struttura fuori dal collegamento del laboratorio"
	return ""

func place(id: String, cell: Vector2i) -> bool:
	if id == "ladder":
		return world.place_ladder_at(cell)
	var reason := placement_blocker(id, cell)
	if not reason.is_empty():
		world._note(reason)
		return false
	buildings.plan(id, cell)
	world._note("Cubo posato: avvicinati per trasferire le materie prime")
	build_mode = false
	_refresh_light_sources()
	queue_redraw()
	return true

func site_cost(building: Dictionary) -> Dictionary:
	if building.id == "lamp" and world.field_cargo.available("lamp_kit", world.drone_help_available(), payment_cache()) > 0:
		return {"lamp_kit": 1}
	return Buildings.cost_for(building.id)

func funding_blocker(building: Dictionary) -> String:
	if building.id == "ladder":
		return "Le scale si costruiscono direttamente con B"
	if not site_reachable(building) or building.get("state") != "planned":
		return "Cubo non disponibile o fuori portata"
	var reason := buildings.blocker(building.id, building.origin, world.site, world.environment, building)
	if not reason.is_empty():
		return reason
	if building.id != "ladder" and not safe_link(building):
		return "Cantiere fuori dal collegamento della nave o area non sicura"
	if building.id in Buildings.DEVICE_IDS and not has_lab():
		return "Serve un laboratorio operativo per costruire questa struttura"
	var missing: Array[String] = []
	for id: String in site_cost(building):
		var deficit: int = int(site_cost(building)[id]) - world.field_cargo.available(id, world.drone_help_available(), payment_cache())
		if deficit > 0:
			missing.append("%d %s" % [deficit, ITEM_NAMES[id].to_lower()])
	if not missing.is_empty():
		return "Mancano: " + ", ".join(missing)
	return "La batteria della nave e scarica" if world.ship_energy() <= 0 and building.id != "ladder" else ""

func fund_site(building: Dictionary) -> bool:
	if not funding_blocker(building).is_empty():
		return false
	if not world.field_cargo.pay(site_cost(building), world.drone_help_available(), payment_cache()):
		return false
	building.state = "building"
	building.progress = 0.0
	world._note("Materie trasferite: apertura del cubo in corso")
	return true

func lamp_powered(building: Dictionary) -> bool:
	return building.id == "lamp" and device_powered(building)

func device_powered(building: Dictionary) -> bool:
	if building.id not in Buildings.DEVICE_IDS or not Buildings.is_active(building) or not building.get("enabled", true) or not safe_link(building):
		return false
	return not supplying_lab(building).is_empty()

func supplying_lab(building: Dictionary, powered_only: bool = true) -> Dictionary:
	var nearest: Dictionary = {}
	var distance := INF
	for lab: Dictionary in buildings.labs():
		if powered_only and not operational(lab):
			continue
		var candidate := buildings.world_rect(lab).get_center().distance_to(buildings.world_rect(building).get_center())
		if candidate <= Grid.metres(Buildings.light_range(lab)) and candidate < distance:
			nearest = lab
			distance = candidate
	return nearest

func consumption_for(building: Dictionary) -> float:
	if building.get("damaged", false):
		return 0.0
	if building.get("state") == "building":
		var connected := environment_safe(building) if building.id in Buildings.INDUSTRIAL_IDS else safe_link(building)
		return Buildings.power_draw(building) if connected and world.ship_energy() > 0 else 0.0
	var powered := operational(building) if building.id == "laboratory" else device_powered(building)
	return Buildings.power_draw(building) if powered else 0.0

func network_load() -> float:
	var load := 0.0
	for building: Dictionary in buildings.structures:
		load += consumption_for(building)
	return load

func power_report(lab: Dictionary = {}) -> Dictionary:
	var reports := power_reports()
	return reports.get(lab.origin, reports.ship) if not lab.is_empty() else reports.ship

func _empty_power_report() -> Dictionary:
	var report := {"charge": world.ship_energy(), "capacity": world.ship_state.energy_capacity() if world.ship_state != null else 60.0, "load": 0.0, "potential": 0.0, "network": 0.0, "groups": {}, "counts": {}}
	for id: String in Buildings.CUBE_IDS:
		report.groups[id] = 0.0
		report.counts[id] = 0
	return report

func power_reports() -> Dictionary:
	var reports := {"ship": _empty_power_report()}
	for lab: Dictionary in buildings.labs():
		reports[lab.origin] = _empty_power_report()
	for building: Dictionary in buildings.structures:
		if building.id not in Buildings.CUBE_IDS or building.get("state") not in ["active", "building"]:
			continue
		var draw := consumption_for(building)
		var owner: Dictionary = building if building.id == "laboratory" else supplying_lab(building, draw > 0)
		if owner.is_empty():
			owner = supplying_lab(building, false)
		var targets: Array = [reports.ship]
		if not owner.is_empty() and reports.has(owner.origin):
			targets.append(reports[owner.origin])
		for report: Dictionary in targets:
			report.groups[building.id] += draw
			report.counts[building.id] += 1
			report.load += draw
			report.potential += Buildings.power_draw(building)
	for report: Dictionary in reports.values():
		report.network = reports.ship.load
	return reports

func advance(delta: float) -> void:
	if delta <= 0 or not is_finite(delta):
		return
	power_load = network_load()
	var active_before := buildings.structures.filter(func(building: Dictionary): return Buildings.is_active(building))
	var running_devices := buildings.structures.filter(func(building: Dictionary): return building.id in ["pump", "fan"] and device_powered(building))
	var duration := minf(delta, world.ship_energy() / power_load) if power_load > 0 else 0.0
	for building: Dictionary in buildings.structures:
		var connected := environment_safe(building) if building.id in Buildings.INDUSTRIAL_IDS else safe_link(building)
		if building.get("damaged", false) or building.get("state") != "building" or (building.id != "ladder" and not connected):
			continue
		var seconds: float = float(recipe_definition(building.id).get("deployment_seconds", Buildings.build_seconds(building.id)))
		building.progress = 1.0 if building.id == "ladder" else minf(1, float(building.progress) + duration / seconds)
		if building.progress >= 1:
			building.state = "active"
			if building.id == "laboratory" and world.ship_state != null:
				world.ship_state.lab_research_unlocked = true
			if building.id == "ladder":
				world.ladders[building.origin] = true
			world.guide_event({"laboratory": "lab_built", "lamp": "lamp_placed", "pump": "pump_built", "fan": "fan_built", "ladder": "ladder"}.get(building.id, building.id + "_built"))
			world._note(Buildings.NAMES.get(building.id, "Scala") + " attivo")
	for building: Dictionary in running_devices:
		var intake := Grid.to_cell(buildings.world_rect(building).get_center())
		var budget := Buildings.PUMP_RATE * duration if building.id == "pump" else Buildings.FAN_RATE * duration
		if building.id == "pump":
			budget = industry.pump_budget(building, self, budget)
		var removed: float = world.environment.drain_water(intake, Buildings.PUMP_RADIUS, budget) if building.id == "pump" else world.environment.drain_gas(intake, Buildings.FAN_RADIUS, budget)
		building.drained = float(building.get("drained", 0)) + removed
		if building.id == "pump":
			industry.capture_water(building, self, removed)
	world._set_ship_energy(world.ship_energy() - power_load * duration)
	industry.advance(delta, self, active_before)
	_refresh_light_sources()

func lamp_craft_blocker() -> String:
	var lab := nearby_lab()
	var aboard: bool = world.aboard_workshop() and (world.ship_state.lab_research_unlocked if world.ship_state != null else has_lab())
	if lab.is_empty() and not aboard:
		return "Richiede un laboratorio sotterraneo operativo o la sua ricerca sbloccata a bordo"
	if not aboard and not operational(lab):
		return "Laboratorio senza alimentazione"
	var with_drone: bool = world.drone_help_available()
	var trial := Cargo.new()
	trial.drone_capacity = world.field_cargo.drone_capacity
	trial.restore(world.field_cargo.snapshot())
	var source: Dictionary = source_stock()
	var stock: Dictionary = source.duplicate()
	if not trial.pay(Buildings.LAMP_RECIPE, with_drone, stock):
		return "Servono 1 terra + 1 rame nel carico o nel deposito locale"
	return "" if trial.collect("lamp_kit", 1, with_drone) else "Libera un posto nel carico per la luce"

func craft_lamp() -> bool:
	var reason := lamp_craft_blocker()
	if not reason.is_empty():
		world._note(reason)
		return false
	var with_drone: bool = world.drone_help_available()
	var source: Dictionary = source_stock()
	world.field_cargo.pay(Buildings.LAMP_RECIPE, with_drone, source)
	world.field_cargo.collect("lamp_kit", 1, with_drone)
	world._note("Luce portatile fabbricata")
	world.guide_event("lamp_crafted")
	return true

func upgrade_blocker() -> String:
	var station := nearby_station()
	if station.is_empty():
		return "Laboratorio fuori portata"
	if station.kind == "ship":
		if not laboratory_unlocked():
			return "Attiva prima il primo laboratorio sotterraneo"
		var level := station_level(station)
		return "Livello massimo raggiunto" if level >= 3 else ("" if world.field_cargo.can_pay({"stone": 4 * level, "copper": 3 * level}, true, source_stock()) else "Materiali insufficienti nel carico comune e nel deposito")
	var cost := Buildings.upgrade_cost(station.building)
	if not operational(station.building):
		return "Accendi il laboratorio e controlla la batteria della nave"
	return "Livello massimo raggiunto" if cost.is_empty() else ("" if world.field_cargo.can_pay(cost, world.drone_help_available(), station.building.stock) else "Materiali insufficienti nel carico o nel deposito locale")

func upgrade_station() -> bool:
	if not upgrade_blocker().is_empty():
		return false
	var station := nearby_station()
	if station.kind == "ship":
		var level := station_level(station)
		if not world.field_cargo.pay({"stone": 4 * level, "copper": 3 * level}, true, source_stock()):
			return false
		if world.ship_state != null:
			world.ship_state.laboratory_level += 1
		else:
			local_lab_level += 1
		return true
	var cost := Buildings.upgrade_cost(station.building)
	if not world.field_cargo.pay(cost, world.drone_help_available(), station.building.stock):
		return false
	station.building.level = int(station.building.get("level", 1)) + 1
	return true

func suit_repair_blocker() -> String:
	if not source_available():
		return "Laboratorio fuori portata"
	if world.suit_integrity() >= 100:
		return "Tuta gia integra"
	if not world.aboard_workshop() and not operational(nearby_lab()):
		return "Laboratorio senza alimentazione"
	return "" if world.aboard_workshop() or world.field_cargo.can_pay({"soil": 2, "copper": 1}, world.drone_help_available(), payment_cache()) else "Servono 2 terra + 1 rame nel carico o nel deposito locale"

func repair_suit() -> bool:
	if not suit_repair_blocker().is_empty():
		return false
	if not world.aboard_workshop() and not world.field_cargo.pay({"soil": 2, "copper": 1}, world.drone_help_available(), payment_cache()):
		return false
	world._set_suit(100)
	return true

func light_at(point: Vector2) -> float:
	var light := 0.0
	for source: Dictionary in light_sources:
		light = maxf(light, 1.0 - smoothstep(source.inner, source.outer, point.distance_to(source.point)))
	return light

func _refresh_light_sources() -> void:
	light_sources.clear()
	var lab_points: Array = []
	for lab: Dictionary in buildings.labs():
		if operational(lab):
			var point := buildings.world_rect(lab).get_center()
			lab_points.append({"point": point, "range": Grid.metres(Buildings.light_range(lab))})
			light_sources.append({"point": point, "inner": Grid.metres(1.5), "outer": Grid.metres(4)})
	for building: Dictionary in buildings.structures:
		if building.id == "lamp" and lamp_powered(building):
			var point := Grid.center(building.origin)
			if lab_points.any(func(lab: Dictionary): return lab.point.distance_to(point) <= lab.range):
				light_sources.append({"point": point, "inner": Grid.metres(1.2), "outer": Grid.metres(3.5)})
		elif building.id in ["greenhouse", "furnace"] and Buildings.is_active(building) and industry.healthy(building, self) and industry.energy_available(building, self) > 0:
			var storage := industry.state(building)
			var growing: bool = building.id == "greenhouse" and not storage.crop.is_empty()
			if growing:
				growing = float(storage.elapsed) < float(Industry.Catalog.load_data().crops[storage.crop].seconds) and industry.water_available(building, self) > 0
			if growing or (building.id == "furnace" and not storage.recipe.is_empty()):
				light_sources.append({"point": buildings.world_rect(building).get_center(), "inner": Grid.metres(1.0), "outer": Grid.metres(2.5 if building.id == "greenhouse" else 1.5)})

func mining_blocker(cell: Vector2i) -> String:
	for cube: Dictionary in fabrication.cubes:
		if cube.uid != fabrication.carried_id and Grid.to_cell(cube.position - Vector2(0, 1)) + Vector2i.DOWN == cell:
			return "Sposta prima il cubo appoggiato su questo blocco"
	for building: Dictionary in buildings.structures:
		if building.id == "ladder":
			continue
		var rect := buildings.footprint(building.id, building.origin)
		if cell.y == rect.end.y and cell.x >= rect.position.x and cell.x < rect.end.x:
			return "Pavimento portante della struttura: scava altrove"
	return ""

func _process(delta: float) -> void:
	if not world.controls_locked:
		advance_fabrication(delta)
		if is_instance_valid(industry_ui) and industry_ui.window.visible:
			advance(delta)
	var carried := fabrication.carried()
	if not carried.is_empty():
		carried.position = world.player.position - Vector2(0, 66)
	if activation_cube_id != 0 and (activation_cube().is_empty() or not cube_near_player(activation_cube())):
		activation_cube_id = 0
		build_mode = false
	_refresh_light_sources()
	if build_mode:
		if world.mouse_aim and not preview_fixed:
			origin = placement_origin(blueprint, Grid.to_cell(world.get_global_mouse_position()))
		elif not preview_fixed:
			stick_timer -= delta
			var pads := Input.get_connected_joypads()
			if not pads.is_empty() and stick_timer <= 0:
				var aim := Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_X), Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_Y))
				if aim.length() > 0.5:
					origin += Vector2i(signi(int(aim.x * 10)), signi(int(aim.y * 10)))
					stick_timer = 0.18
	queue_redraw()

func handle_input(event: InputEvent) -> bool:
	if is_instance_valid(industry_ui) and industry_ui.handle_input(event):
		return true
	if event.is_action_pressed("toggle_build") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y and Input.is_joy_button_pressed(event.device, JOY_BUTTON_LEFT_SHOULDER)):
		toggle_build()
		return true
	if build_mode and (event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)):
		build_mode = false
		return true
	if build_mode and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			build_mode = false
		elif event.button_index == MOUSE_BUTTON_LEFT:
			return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		var cube := cube_at(point)
		if not cube.is_empty():
			construction.open_cube(cube, event.position)
			return true
		if open_station(station_at(point), event.position):
			return true
		for building: Dictionary in buildings.structures:
			if building.id in Buildings.DEVICE_IDS and Buildings.is_active(building) and buildings.world_rect(building).has_point(point) and site_reachable(building):
				construction.open_device(building, event.position)
				return true
			if not Buildings.is_active(building) and buildings.world_rect(building).has_point(point) and site_reachable(building):
				if building.state == "planned":
					construction.open_site(building)
				else:
					world._note("Costruzione %.0f%%" % (float(building.progress) * 100))
				return true
		world._note("I cubi si creano al laboratorio. Scale immediate con B.")
		return true
	return false

func open_cargo() -> void:
	cargo_ui.open_inventory()

func _build_interface() -> void:
	cargo_ui = InventoryUI.new()
	cargo_ui.world = world
	add_child(cargo_ui)
	cargo_window = cargo_ui.window

func _draw() -> void:
	var energy_reports := power_reports()
	for building: Dictionary in buildings.structures:
		var rect := buildings.world_rect(building)
		var state: String = building.get("state", "active")
		if state == "planned":
			_dashed_rect(rect, Color("e7d28b"))
			_draw_cube(rect, 0, building.id)
			continue
		var progress: float = float(building.get("progress", 1.0))
		if state == "building":
			_dashed_rect(rect, Color("8be7df"))
			_draw_cube(rect, progress, building.id)
			draw_rect(Rect2(rect.position - Vector2(0, 14), Vector2(rect.size.x, 7)), Color("222b2e"))
			draw_rect(Rect2(rect.position - Vector2(0, 14), Vector2(rect.size.x * progress, 7)), Color("8be7df"))
			if sin(world.ambient_time * 15) < -0.3:
				continue
			var anchor := Vector2(rect.get_center().x, rect.end.y)
			var scale_factor := lerpf(0.15, 1.0, progress)
			draw_set_transform(anchor * (1 - scale_factor), 0, Vector2.ONE * scale_factor)
		if building.id == "laboratory":
			var available := station_available({"kind": "laboratory", "building": building})
			var color := Color("b7ffb6") if available and operational(building) else (Color("8bd9c3") if operational(building) else Color("c3936d"))
			draw_rect(rect.grow(-4), Color(0.11, 0.21, 0.24, 0.6))
			if available:
				draw_rect(rect.grow(-3), Color(0.65, 1, 0.62, 0.12))
				draw_rect(rect.grow(1), Color(0.65, 1, 0.62, 0.17), false, 6)
			draw_rect(rect.grow(-4), color, false, 3)
			draw_line(rect.position + Vector2(6, 6), rect.position + Vector2(rect.size.x - 6, 6), Color("e2c27d"), 6)
			var base := rect.position + Vector2(20, rect.size.y - 38)
			draw_rect(Rect2(base, Vector2(110, 32)), Color("577a80"))
			draw_rect(Rect2(base + Vector2(45, -24), Vector2(38, 23)), Color("263e4c"))
			draw_rect(Rect2(base + Vector2(49, -20), Vector2(30, 14)), color)
			for x in [5, 22, 38]:
				draw_rect(Rect2(base + Vector2(x, -14), Vector2(9, 13)), Color("dcb65b"))
			if state == "active" and not operational(building):
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, 20), "NON ALIMENTATO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f2ba85"))
			if state == "active":
				_draw_energy_bars(rect, energy_reports.get(building.origin, _empty_power_report()))
		elif building.id == "lamp":
			var center := rect.get_center()
			draw_line(center + Vector2(0, 15), center - Vector2(0, 12), Color("7b9499"), 4)
			draw_rect(Rect2(center - Vector2(13, 16), Vector2(26, 8)), Color("f6d683") if lamp_powered(building) else Color("727c7e"))
		elif building.id == "pump":
			var working := device_powered(building)
			var base := rect.position + Vector2(8, 18)
			draw_rect(Rect2(base, Vector2(64, 60)), Color("63888b"))
			draw_rect(Rect2(base + Vector2(4, 6), Vector2(28, 48)), Color("25424b"))
			draw_rect(Rect2(base + Vector2(8, 25), Vector2(20, 25)), Color("76d7dd") if working else Color("62777d"))
			var rotor := base + Vector2(47, 28)
			draw_circle(rotor, 13, Color("263b42"))
			for index in range(3):
				var angle: float = index * TAU / 3 + (world.ambient_time * 6 if working else 0)
				draw_line(rotor, rotor + Vector2(cos(angle), sin(angle)) * 10, Color("d5e5d6"), 4)
			draw_line(base + Vector2(15, 58), base + Vector2(15, 62), Color("d6bd74"), 8)
			draw_circle(base + Vector2(49, 8), 3, Color("a8f9a6") if working else Color("e8a477"))
			if state == "active":
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(2, 10), "DRENATO %.1f u" % float(building.get("drained", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("b6e7df"))
		elif building.id == "fan":
			var working := device_powered(building)
			var center := rect.get_center() + Vector2(0, 2)
			draw_rect(rect.grow(-8), Color("74897e"))
			draw_rect(rect.grow(-12), Color("233b38"))
			draw_circle(center, 25, Color("afc7b5"))
			draw_circle(center, 22, Color("304e46"))
			for index in range(4):
				var angle: float = index * TAU / 4 + (world.ambient_time * 8 if working else 0)
				draw_line(center, center + Vector2(cos(angle), sin(angle)) * 18, Color("c8eea5") if working else Color("8b9c92"), 7)
			draw_circle(center, 6, Color("e8d296"))
			draw_rect(Rect2(center + Vector2(-25, 29), Vector2(50, 7)), Color("8d9d85"))
			draw_circle(rect.position + Vector2(65, 15), 3, Color("c0f7a3") if working else Color("e8a477"))
			if state == "active":
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(2, 10), "FILTRATO %.1f u" % float(building.get("drained", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d2efb8"))
		elif building.id == "ladder" and state == "building":
			for x in [-12, 12]:
				draw_line(rect.position + Vector2(20 + x, 0), rect.position + Vector2(20 + x, 40), Color("e4c78b"), 3)
			for y in [8, 20, 32]:
				draw_line(rect.position + Vector2(8, y), rect.position + Vector2(32, y), Color("e4c78b"), 3)
		draw_set_transform(Vector2.ZERO)
	if build_mode:
		var rect := Rect2(Grid.to_world(origin), Grid.to_world(buildings.size_for(blueprint)))
		var valid := preview_blocker(blueprint, origin).is_empty()
		var color := Color("87e4c0") if valid else Color("f16d72")
		draw_rect(rect, Color(color, 0.14))
		_dashed_rect(rect, color)
		var cube := activation_cube()
		if not cube.is_empty() and not valid:
			var text := placement_blocker(cube.id, origin)
			draw_string(ThemeDB.fallback_font, rect.position - Vector2(0, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ff9a9e"))

func _dashed_rect(rect: Rect2, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for index in range(4):
		draw_dashed_line(corners[index], corners[(index + 1) % 4], color, 2, 7)

func _draw_energy_bars(rect: Rect2, report: Dictionary) -> void:
	var width := rect.size.x - 12
	var start := rect.position + Vector2(6, -26)
	draw_rect(Rect2(start, Vector2(width, 5)), Color("142229"))
	var charge_color := Color("a7e5b4") if report.charge / report.capacity > 0.2 else Color("ef876d")
	draw_rect(Rect2(start, Vector2(width * report.charge / report.capacity, 5)), charge_color)
	start.y += 9
	draw_rect(Rect2(start, Vector2(width, 5)), Color("142229"))
	var x := start.x
	for id: String in Buildings.CUBE_IDS:
		var size: float = width * float(report.groups[id]) / maxf(float(report.potential), 0.000001)
		if size > 0:
			draw_rect(Rect2(Vector2(x, start.y), Vector2(size, 5)), Buildings.CUBE_COLORS[id])
			x += size
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, -32), "%.1f/%.0f kWh | %.2f/m" % [report.charge, report.capacity, float(report.load) * 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("daeee1"))

func _draw_cube(rect: Rect2, opening: float, id: String) -> void:
	var base := Vector2(rect.get_center().x, rect.end.y - 18)
	var color: Color = Buildings.CUBE_COLORS.get(id, Color("e8c77a"))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -12), base + Vector2(0, -20), base + Vector2(16, -12), base + Vector2(0, -4)]), color.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -12), base + Vector2(0, -4), base + Vector2(0, 15), base + Vector2(-16, 7)]), color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([base + Vector2(0, -4), base + Vector2(16, -12), base + Vector2(16, 7), base + Vector2(0, 15)]), color)
	if opening > 0:
		for side in [-1, 1]:
			draw_line(base + Vector2(side * 14, -12), base + Vector2(side * (20 + opening * 28), -20 - opening * 20), Color("d0fff3"), 5)
