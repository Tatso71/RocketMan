extends Node2D

const Grid = preload("res://scripts/world/world_grid.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const InventoryUI = preload("res://scripts/ui/field_inventory_ui.gd")
const StationMenu = preload("res://scripts/ui/workstation_menu.gd")
const ConstructionUI = preload("res://scripts/ui/construction_ui.gd")
const OcraCatalog = preload("res://scripts/data/ocra_catalog.gd")
const SHIP_LAB_RECT := Rect2(-156, -194, 312, 114)
const ITEM_NAMES := {"soil": "Terra", "stone": "Pietra", "copper": "Rame", "crystal": "Cristallo", "lamp_kit": "Luce portatile", "lab_cube": "Cubo laboratorio"}
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

func toggle_build() -> void:
	build_mode = not build_mode
	world.mouse_mining = false
	if build_mode:
		origin = placement_origin(blueprint, Grid.to_cell(world.player.position - Vector2(0, 1)))

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

func station_rect(station: Dictionary) -> Rect2:
	return SHIP_LAB_RECT if station.get("kind") == "ship" else buildings.world_rect(station.building)

func station_available(station: Dictionary) -> bool:
	if station.is_empty():
		return false
	if station.get("kind") == "ship":
		return world.aboard_workshop()
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
	if SHIP_LAB_RECT.has_point(point) and world.aboard_workshop():
		return {"kind": "ship"}
	for lab: Dictionary in buildings.labs():
		var station := {"kind": "laboratory", "building": lab}
		if station_rect(station).has_point(point) and station_available(station):
			return station
	return {}

func nearby_station() -> Dictionary:
	if station_available(selected_station):
		return selected_station
	if world.aboard_workshop():
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
	var rect := buildings.footprint(building.id, building.origin)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if (building.id != "pump" and float(world.environment.water.get(cell, 0)) > 0.05) or float(world.environment.gas.get(cell, 0)) > 0.03:
				return false
	return true

func has_lab() -> bool:
	return buildings.labs().any(func(building: Dictionary): return operational(building))

func laboratory_unlocked() -> bool:
	return (world.ship_state != null and world.ship_state.lab_research_unlocked) or world.guide_state.facts.get("lab_built", false) or not buildings.labs().is_empty()

func recipe_visible(id: String) -> bool:
	return id == "laboratory" or (id in ["lamp", "pump"] and laboratory_unlocked())

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
	return world.aboard_workshop() or not nearby_lab().is_empty()

func lab_definition() -> Dictionary:
	return OcraCatalog.load_data().get("laboratory", {})

func lab_cube_count() -> int:
	return world.field_cargo.available("lab_cube", world.drone_help_available())

func fabrication_blocker() -> String:
	var definition := lab_definition()
	if definition.is_empty():
		return "Catalogo del laboratorio non disponibile"
	if not world.aboard_workshop():
		return "Raggiungi l'officina della nave per fabbricare il cubo"
	if world.ship_energy() < float(definition.energy):
		return "Ricarica la batteria della nave"
	var trial := Cargo.new()
	trial.drone_capacity = world.field_cargo.drone_capacity
	trial.restore(world.field_cargo.snapshot())
	if not trial.pay(definition.cost, world.drone_help_available(), source_stock().duplicate()):
		var missing: Array[String] = []
		for id: String in definition.cost:
			var deficit: int = int(definition.cost[id]) - world.field_cargo.available(id, world.drone_help_available(), source_stock())
			if deficit > 0:
				missing.append("%d %s" % [deficit, ITEM_NAMES[id].to_lower()])
		return "Mancano nell'officina o nel carico: " + ", ".join(missing)
	if not trial.collect("lab_cube", 1, world.drone_help_available()):
		return "Libera 4 posti nello stesso zaino: tuo o di Robbie"
	return ""

func fabricate_lab_cube() -> bool:
	var reason := fabrication_blocker()
	if not reason.is_empty():
		world._note(reason)
		return false
	var definition := lab_definition()
	world.field_cargo.pay(definition.cost, world.drone_help_available(), source_stock())
	world.field_cargo.collect("lab_cube", 1, world.drone_help_available())
	world._set_ship_energy(world.ship_energy() - float(definition.energy))
	world.guide_event("lab_cube_crafted")
	world._note("Cubo laboratorio nel carico: 4 posti, materiali gia pagati")
	return true

func preview_blocker(id: String, cell: Vector2i) -> String:
	var reason := placement_blocker(id, cell)
	if not reason.is_empty():
		return reason
	if id == "laboratory" and lab_cube_count() <= 0:
		return "Cubo laboratorio assente: fabbricalo nell'officina"
	return ""

func deploy_lab_cube(cell: Vector2i) -> bool:
	var reason := preview_blocker("laboratory", cell)
	if not reason.is_empty():
		world._note(reason)
		return false
	if not world.field_cargo.pay({"lab_cube": 1}, world.drone_help_available()):
		return false
	buildings.plan("laboratory", cell)
	var building: Dictionary = buildings.structures.back()
	building.state = "building"
	building.progress = 0.0
	world.guide_event("lab_cube_deployed")
	world._note("Il cubo si apre: nessun altro materiale da trasferire")
	build_mode = false
	queue_redraw()
	return true

func place_blueprint(cell: Vector2i) -> bool:
	return deploy_lab_cube(cell) if blueprint == "laboratory" else place(blueprint, cell)

func placement_blocker(id: String, cell: Vector2i) -> String:
	if id in ["lamp", "pump"] and not recipe_visible(id):
		return "Costruisci e attiva il primo laboratorio"
	if buildings.structures.size() >= 200:
		return "Limite di strutture e cantieri raggiunto"
	var reason := buildings.blocker(id, cell, world.site, world.environment)
	if not reason.is_empty():
		return reason
	var rect := Rect2(Grid.to_world(cell), Grid.to_world(buildings.size_for(id)))
	var body := Rect2(world.player.position - Vector2(12, 64), Vector2(24, 64))
	if id == "lamp" and rect.intersects(body):
		return "Spostati fuori dall'ingombro del progetto"
	var torso: Vector2 = world.player.position - Vector2(0, 32)
	if torso.distance_to(rect.get_center()) > Grid.metres(3):
		return "Cantiere fuori portata"
	if id == "laboratory" and rect.get_center().distance_to(Vector2(0, -80)) > Grid.metres(signal_range()):
		return "Laboratorio fuori dal segnale della nave"
	if id == "ladder" and world.ladders.has(cell):
		return "Scala gia presente"
	if id in ["lamp", "pump"] and not has_lab():
		return "Costruisci prima un laboratorio operativo"
	if id in ["lamp", "pump"] and not buildings.labs().any(func(lab: Dictionary): return operational(lab) and buildings.world_rect(lab).get_center().distance_to(rect.get_center()) <= Grid.metres(Buildings.light_range(lab))):
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
	if building.id in ["lamp", "pump"] and not has_lab():
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
	if building.id not in ["lamp", "pump"] or not Buildings.is_active(building) or not building.get("enabled", true) or not safe_link(building):
		return false
	return buildings.labs().any(func(lab: Dictionary): return operational(lab) and buildings.world_rect(lab).get_center().distance_to(buildings.world_rect(building).get_center()) <= Grid.metres(Buildings.light_range(lab)))

func network_load() -> float:
	var load := 0.0
	for building: Dictionary in buildings.structures:
		var powered := operational(building) if building.id == "laboratory" else device_powered(building)
		if building.get("state") == "building":
			powered = safe_link(building) and world.ship_energy() > 0
		if powered:
			load += Buildings.power_draw(building)
	return load

func advance(delta: float) -> void:
	if delta <= 0 or not is_finite(delta):
		return
	power_load = network_load()
	var duration := minf(delta, world.ship_energy() / power_load) if power_load > 0 else 0.0
	var completed: Array = []
	for building: Dictionary in buildings.structures:
		if building.get("state") != "building" or (building.id != "ladder" and not safe_link(building)):
			continue
		var seconds: float = float(lab_definition().get("deployment_seconds", Buildings.build_seconds(building.id))) if building.id == "laboratory" else Buildings.build_seconds(building.id)
		building.progress = 1.0 if building.id == "ladder" else minf(1, float(building.progress) + duration / seconds)
		if building.progress >= 1:
			building.state = "active"
			completed.append(building)
			if building.id == "laboratory" and world.ship_state != null:
				world.ship_state.lab_research_unlocked = true
			if building.id == "ladder":
				world.ladders[building.origin] = true
			world.guide_event({"laboratory": "lab_built", "lamp": "lamp_placed", "pump": "pump_built", "ladder": "ladder"}[building.id])
			world._note({"laboratory": "Laboratorio attivo: nuove rotte sbloccate", "lamp": "Luce attiva", "pump": "Pompa attiva", "ladder": "Scala pronta"}[building.id])
	for building: Dictionary in buildings.structures:
		if building.id == "pump" and building not in completed and device_powered(building):
			var removed: float = world.environment.drain_water(Grid.to_cell(buildings.world_rect(building).get_center()), Buildings.PUMP_RADIUS, Buildings.PUMP_RATE * duration)
			building.drained = float(building.get("drained", 0)) + removed
	world._set_ship_energy(world.ship_energy() - power_load * duration)
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
		if world.ship_state == null:
			return "Potenziamenti della nave disponibili nella spedizione"
		var reason: String = world.ship_state.upgrade_blocker("drill")
		if not reason.is_empty():
			return reason
		var cost: Dictionary = world.ship_state.upgrade_cost("drill")
		return "Livello massimo raggiunto" if cost.is_empty() else ("" if world.ship_state.can_afford(cost) else "Materiali insufficienti nella stiva")
	var cost := Buildings.upgrade_cost(station.building)
	if not operational(station.building):
		return "Accendi il laboratorio e controlla la batteria della nave"
	return "Livello massimo raggiunto" if cost.is_empty() else ("" if world.field_cargo.can_pay(cost, world.drone_help_available(), station.building.stock) else "Materiali insufficienti nel carico o nel deposito locale")

func upgrade_station() -> bool:
	if not upgrade_blocker().is_empty():
		return false
	var station := nearby_station()
	if station.kind == "ship":
		return world.ship_state.upgrade("drill")
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

func mining_blocker(cell: Vector2i) -> String:
	for building: Dictionary in buildings.structures:
		if building.id == "ladder":
			continue
		var rect := buildings.footprint(building.id, building.origin)
		if cell.y == rect.end.y and cell.x >= rect.position.x and cell.x < rect.end.x:
			return "Pavimento portante della struttura: scava altrove"
	return ""

func _process(delta: float) -> void:
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
	if event.is_action_pressed("toggle_build") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y and Input.is_joy_button_pressed(event.device, JOY_BUTTON_LEFT_SHOULDER)):
		toggle_build()
		return true
	if build_mode and (event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)):
		build_mode = false
		return true
	if build_mode and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			build_mode = false
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
			place_blueprint(placement_origin(blueprint, Grid.to_cell(point)))
			return true
	if build_mode and event.is_action_pressed("interact"):
		place_blueprint(origin)
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		if open_station(station_at(point), event.position):
			return true
		for building: Dictionary in buildings.structures:
			if not Buildings.is_active(building) and buildings.world_rect(building).has_point(point) and site_reachable(building):
				if building.state == "planned":
					construction.open_site(building)
				else:
					world._note("Costruzione %.0f%%" % (float(building.progress) * 100))
				return true
		construction.open_picker(Grid.to_cell(point), event.position)
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
	for building: Dictionary in buildings.structures:
		var rect := buildings.world_rect(building)
		var state: String = building.get("state", "active")
		if state == "planned":
			_dashed_rect(rect, Color("e7d28b"))
			_draw_cube(rect, 0)
			continue
		var progress: float = float(building.get("progress", 1.0))
		if state == "building":
			_dashed_rect(rect, Color("8be7df"))
			_draw_cube(rect, progress)
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
		elif state == "building":
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

func _dashed_rect(rect: Rect2, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for index in range(4):
		draw_dashed_line(corners[index], corners[(index + 1) % 4], color, 2, 7)

func _draw_cube(rect: Rect2, opening: float) -> void:
	var base := Vector2(rect.get_center().x, rect.end.y - 18)
	var color := Color("e8c77a") if opening == 0 else Color("8be7df")
	draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -12), base + Vector2(0, -20), base + Vector2(16, -12), base + Vector2(0, -4)]), color.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -12), base + Vector2(0, -4), base + Vector2(0, 15), base + Vector2(-16, 7)]), color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([base + Vector2(0, -4), base + Vector2(16, -12), base + Vector2(16, 7), base + Vector2(0, 15)]), color)
	if opening > 0:
		for side in [-1, 1]:
			draw_line(base + Vector2(side * 14, -12), base + Vector2(side * (20 + opening * 28), -20 - opening * 20), Color("d0fff3"), 5)
