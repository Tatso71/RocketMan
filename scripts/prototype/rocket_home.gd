extends Node2D

const Grid = preload("res://scripts/world/world_grid.gd")
const DigSite = preload("res://scripts/systems/dig_site.gd")
const Explorer = preload("res://scripts/player/rocket_explorer.gd")
const InventoryModel = preload("res://scripts/systems/inventory.gd")
const Tools = preload("res://scripts/data/digital_tool_catalog.gd")
const HazardField = preload("res://scripts/systems/environment_field.gd")
const FieldCargo = preload("res://scripts/systems/field_cargo.gd")
const Drone = preload("res://scripts/player/support_drone.gd")
const Outpost = preload("res://scripts/prototype/outpost_controller.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const GuideState = preload("res://scripts/systems/drone_guide_state.gd")
const GuideUI = preload("res://scripts/ui/drone_guide.gd")
const ShipRooms = preload("res://scripts/ui/ship_rooms.gd")
const TutorialUI = preload("res://scripts/ui/ocra_tutorial_ui.gd")
const MATERIAL_NAMES := {"soil": "Terra", "stone": "Pietra", "copper": "Rame", "crystal": "Cristallo", "bedrock": "Roccia compatta", "anchor": "Nucleo indistruttibile"}
const MATERIAL_COLORS := {"soil": Color("a45148"), "stone": Color("746b7a"), "copper": Color("bb8162"), "crystal": Color("55c5c6"), "bedrock": Color("454750"), "anchor": Color("465761")}
var site := DigSite.new()
var environment := HazardField.new(site)
var inventory := InventoryModel.new()
var player: CharacterBody2D
var camera: Camera2D
var terrain := Node2D.new()
var blocks: Dictionary = {}
var ladders: Dictionary = {}
var hatch: StaticBody2D
var hatch_open := false
var show_grid := true
var target_cell := Vector2i.ZERO
var mouse_aim := false
var mine_timer := 0.0
var message_time := 0.0
var ambient_time := 0.0
var resources_label: Label
var location_label: Label
var status_label: Label
var reset_dialog: ConfirmationDialog
var campaign: Node
var planet_def: Resource
var ship_state: RefCounted
var controls_locked := false
var standalone_slot := 0
var scanned: Dictionary = {}
var beam_time := 0.0
var beam_target := Vector2.ZERO
var beam_tool: Resource
var target_zoom := 1.1
var tool_buttons: Array[Button] = []
var metric_label: Label
var mouse_mining := false
var local_suit := 100.0
var hazard_label: Label
var field_cargo := FieldCargo.new()
var local_store: Dictionary = {"soil": 0, "stone": 0, "copper": 0, "crystal": 0, "lamp_kit": 0}
var drone: CharacterBody2D
var outpost: Node2D
var navigation_revision := 0
var drone_label: Label
var guide_state := GuideState.new()
var guide: CanvasLayer
var rooms: Node
var local_energy := 60.0
var local_crew_energy := 100.0
var power_label: Label
var tutorial_ui: CanvasLayer

func is_ocra() -> bool:
	return planet_def == null or planet_def.planet_id == "ochre"

func observe_tutorial(room_ready: bool = false) -> void:
	if not is_ocra():
		return
	var tutorial: RefCounted = guide_state.ocra
	if aboard_workshop():
		tutorial.mark("workshop_entered")
	if hatch_open:
		tutorial.mark("hatch_opened")
	if guide_state.facts.get("ladder", false) or ladders.keys().any(func(cell: Vector2i): return cell.y >= 0):
		tutorial.mark("ladder")
	if outpost.lab_cube_count() > 0:
		tutorial.mark("lab_cube_crafted")
		tutorial.mark("lab_materials_ready")
	if not outpost.fabrication.jobs.is_empty():
		tutorial.mark("lab_materials_ready")
	if outpost.fabrication.carried_id != 0:
		tutorial.mark("lab_cube_carried")
	if field_cargo.can_pay(outpost.lab_definition().get("cost", {}), true, outpost.fabrication_stock()):
		tutorial.mark("lab_materials_ready")
	if room_ready:
		tutorial.mark("lab_room_ready")
	for building: Dictionary in outpost.buildings.structures:
		if building.id == "laboratory":
			tutorial.mark("lab_room_ready")
			if building.get("state") != "planned":
				tutorial.mark("lab_cube_crafted")
				tutorial.mark("lab_materials_ready")
			if Buildings.is_active(building):
				tutorial.mark("lab_built")
	if guide_state.facts.get("lab_built", false) or (ship_state != null and ship_state.lab_research_unlocked):
		tutorial.mark("lab_built")

func crew_energy() -> float:
	return ship_state.crew_energy if ship_state != null else local_crew_energy

func _set_crew_energy(value: float) -> void:
	if ship_state != null:
		ship_state.crew_energy = clampf(value, 0, 100)
	else:
		local_crew_energy = clampf(value, 0, 100)

func ship_energy() -> float:
	return ship_state.energy if ship_state != null else local_energy

func _set_ship_energy(value: float) -> void:
	var capacity: float = ship_state.energy_capacity() if ship_state != null else 60
	if ship_state != null:
		ship_state.energy = clampf(value, 0, capacity)
	else:
		local_energy = clampf(value, 0, capacity)

func guide_event(id: String) -> void:
	if is_instance_valid(guide):
		guide.event(id)

func aboard_workshop() -> bool:
	return is_instance_valid(player) and absf(player.position.x) < 160 and player.position.y <= -78 and player.position.y > -200

func drone_help_available() -> bool:
	return is_instance_valid(drone)

func drone_can_collect() -> bool:
	return is_instance_valid(drone) and drone.signal_connected() and drone.position.distance_to(player.position - Vector2(0, 32)) <= Grid.metres(3) and drone._clear(drone.position, player.position - Vector2(0, 32))

func suit_integrity() -> float:
	return ship_state.suit_integrity if ship_state != null else local_suit

func _set_suit(value: float) -> void:
	if ship_state != null:
		ship_state.suit_integrity = clampf(value, 0, 100)
	else:
		local_suit = clampf(value, 0, 100)

func player_environment() -> Dictionary:
	return environment.exposure(player.position)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or controls_blocked():
		return
	environment.advance(delta)
	outpost.advance(delta)
	var danger := player_environment()
	var damage := (12.0 if danger.submerged else 0.0) + clampf((float(danger.gas) - 0.03) / 0.22, 0, 1) * 18
	if damage > 0:
		_set_suit(suit_integrity() - damage * delta)
	if suit_integrity() <= 0:
		return_home()
		_set_suit(25)
		_note("Richiamo di emergenza: tuta compromessa")

func active_tool() -> Resource:
	var slot: int = ship_state.active_tool_slot if ship_state != null else standalone_slot
	var slots: Array = ship_state.tool_slots if ship_state != null else ["pulse", "scanner", "", ""]
	return Tools.find(slots[slot])

func equip_tool(slot: int) -> bool:
	var slots: Array = ship_state.tool_slots if ship_state != null else ["pulse", "scanner", "", ""]
	if slot < 0 or slot >= Tools.SLOT_COUNT or str(slots[slot]).is_empty():
		return false
	if ship_state != null:
		ship_state.active_tool_slot = slot
	else:
		standalone_slot = slot
	_note(active_tool().display_name)
	return true

func configure(owner_campaign: Node, planet: Resource, ship: RefCounted) -> void:
	campaign = owner_campaign
	planet_def = planet
	ship_state = ship
	site = DigSite.new(planet.terrain_seed)
	environment = HazardField.new(site)
	field_cargo = ship.field_cargo
	guide_state = ship.drone_guide
	inventory.materials = field_cargo.backpack

func controls_blocked() -> bool:
	return controls_locked or (is_instance_valid(reset_dialog) and reset_dialog.visible) or (is_instance_valid(rooms) and rooms.is_open()) or (is_instance_valid(outpost) and ((is_instance_valid(outpost.cargo_window) and outpost.cargo_window.visible) or (is_instance_valid(outpost.station_menu) and outpost.station_menu.is_open()) or (is_instance_valid(outpost.construction) and outpost.construction.is_open())))

func _ready() -> void:
	_register_input()
	add_child(terrain)
	_build_terrain()
	_build_ship_collision()
	for y in range(-2, 0):
		ladders[Vector2i(0, y)] = true
	inventory.materials = field_cargo.backpack
	player = Explorer.new()
	player.world = self
	player.position = Vector2(-60, -320)
	player.z_index = 5
	add_child(player)
	drone = Drone.new()
	drone.world = self
	drone.range_metres = ship_state.drone_range_metres() if ship_state != null else 15
	drone.position = Vector2(-140, -380)
	drone.z_index = 6
	add_child(drone)
	outpost = Outpost.new()
	outpost.world = self
	add_child(outpost)
	camera = Camera2D.new()
	camera.position = Vector2(0, -350)
	camera.zoom = Vector2.ONE * target_zoom
	add_child(camera)
	rooms = ShipRooms.new()
	rooms.world = self
	add_child(rooms)
	_build_hud()
	guide = GuideUI.new()
	guide.world = self
	guide.state = guide_state
	add_child(guide)
	tutorial_ui = TutorialUI.new()
	tutorial_ui.world = self
	add_child(tutorial_ui)
	_refresh_hud()
	queue_redraw()

func _register_input() -> void:
	_action("climb_up", [KEY_W, KEY_UP], JOY_BUTTON_DPAD_UP)
	_action("climb_down", [KEY_S, KEY_DOWN], JOY_BUTTON_DPAD_DOWN)
	_action("mine", [KEY_F], JOY_BUTTON_RIGHT_SHOULDER)
	_action("place_ladder", [KEY_B], JOY_BUTTON_Y)
	_action("toggle_grid", [KEY_G], JOY_BUTTON_LEFT_STICK)
	_action("return_home", [KEY_HOME], JOY_BUTTON_BACK)
	_action("toggle_zoom", [KEY_C], JOY_BUTTON_RIGHT_STICK)
	_action("next_tool", [KEY_Q], JOY_BUTTON_LEFT_SHOULDER)
	_action("toggle_build", [KEY_V], -1)
	_action("drone_help", [KEY_H], -1)
	_action("field_inventory", [KEY_I], -1)
	for action in ["climb_up", "climb_down"]:
		var axis := InputEventJoypadMotion.new()
		axis.axis = JOY_AXIS_LEFT_Y
		axis.axis_value = -1 if action == "climb_up" else 1
		if not InputMap.action_has_event(action, axis):
			InputMap.action_add_event(action, axis)

func _action(action: String, keys: Array, button: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.3)
	for code in keys:
		var key := InputEventKey.new()
		key.physical_keycode = code
		InputMap.action_add_event(action, key)
	if button >= 0:
		var joy := InputEventJoypadButton.new()
		joy.button_index = button
		InputMap.action_add_event(action, joy)

func _body(rectangle: Rect2, parent: Node, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rectangle.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rectangle.size
	shape.shape = box
	shape.one_way_collision = one_way
	body.add_child(shape)
	parent.add_child(body)
	return body

func _build_terrain() -> void:
	for y in range(site.DEPTH):
		for x in range(site.LEFT, site.RIGHT):
			var cell := Vector2i(x, y)
			if not site.material(cell).is_empty():
				blocks[cell] = _body(Grid.rect(cell), terrain)
	_body(Rect2(Grid.to_world(Vector2i(site.LEFT, site.DEPTH)), Vector2((site.RIGHT - site.LEFT) * Grid.CELL_SIZE, Grid.CELL_SIZE)), self)
	_body(Rect2(Grid.to_world(Vector2i(site.LEFT - 1, -20)), Vector2(Grid.CELL_SIZE, (site.DEPTH + 20) * Grid.CELL_SIZE)), self)
	_body(Rect2(Grid.to_world(Vector2i(site.RIGHT, -20)), Vector2(Grid.CELL_SIZE, (site.DEPTH + 20) * Grid.CELL_SIZE)), self)

func _build_ship_collision() -> void:
	var half_width := Grid.ROCKET_HALF_WIDTH * Grid.CELL_SIZE
	var ceiling := Grid.metres(Grid.ROCKET_CEILING)
	var bottom := Grid.metres(Grid.ROCKET_FLOORS[-1])
	_body(Rect2(-half_width - 12, ceiling, 12, bottom - ceiling), self)
	_body(Rect2(half_width, ceiling, 12, bottom - ceiling), self)
	_body(Rect2(-half_width, ceiling - 4, half_width * 2, 8), self)
	for floor_cell in Grid.ROCKET_FLOORS.slice(0, 2):
		var floor_y := Grid.metres(floor_cell)
		_body(Rect2(-half_width, floor_y, 240, 8), self)
		_body(Rect2(120, floor_y, 40, 8), self)
	_body(Rect2(-half_width, -80, 120, 8), self)
	_body(Rect2(40, -80, 120, 8), self)
	hatch = _body(Rect2(-40, -80, 80, 8), self)

func on_ladder(feet: Vector2) -> bool:
	if absf(feet.x - 100) < 18 and feet.y >= -376 and feet.y <= -78:
		return true
	if not hatch_open and feet.y < -70:
		return false
	var torso := feet - Vector2(0, Grid.metres(0.8))
	for point in [torso, feet - Vector2(0, 4)]:
		var cell := Grid.to_cell(point)
		if ladders.has(cell) and absf(feet.x - Grid.center(cell).x) < 22:
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("field_inventory") and outpost.cargo_window.visible:
		outpost.cargo_window.hide()
		get_viewport().set_input_as_handled()
		return
	if controls_blocked():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not outpost.build_mode and drone.hit_test(event.position):
		mouse_mining = false
		guide.repeat_last()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("drone_help"):
		guide.request_help()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("field_inventory"):
		outpost.open_cargo()
		get_viewport().set_input_as_handled()
		return
	if rooms.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(outpost) and outpost.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4:
		equip_tool(event.physical_keycode - KEY_1)
	if event.is_action_pressed("toggle_zoom"):
		target_zoom = 0.78 if target_zoom > 0.9 else 1.1
	if event.is_action_pressed("next_tool"):
		var current: int = ship_state.active_tool_slot if ship_state != null else standalone_slot
		for offset in range(1, Tools.SLOT_COUNT + 1):
			if equip_tool((current + offset) % Tools.SLOT_COUNT):
				break
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = minf(1.5, target_zoom + 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = maxf(0.78, target_zoom - 0.1)
	if event is InputEventMouseMotion:
		mouse_aim = true
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		mouse_aim = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_aim = true
		mouse_mining = event.pressed
		if event.pressed:
			target_cell = Grid.to_cell(get_global_mouse_position())
			_mine_target()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact"):
		if not outpost.nearby_lab().is_empty():
			outpost.open_station(outpost.nearby_station(), player.get_global_transform_with_canvas() * Vector2(0, -80))
		elif player.position.distance_to(Vector2(0, -80)) < Grid.metres(2.5):
			set_hatch(not hatch_open)
		else:
			_note("Botola fuori portata")
	if event.is_action_pressed("place_ladder"):
		place_ladder()
	if event.is_action_pressed("toggle_grid"):
		show_grid = not show_grid
	if event.is_action_pressed("return_home"):
		return_home()

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	ambient_time += delta
	beam_time = maxf(0, beam_time - delta)
	mine_timer -= delta
	message_time -= delta
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mouse_mining = false
	var desired := Vector2(player.position.x * 0.65, maxf(-350, player.position.y - 145))
	desired.x = clampf(desired.x, -450, 450)
	desired.y = minf(desired.y, 720)
	camera.position = camera.position.lerp(desired, 1.0 - exp(-delta * 4))
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, 1.0 - exp(-delta * 5))
	if mouse_aim:
		target_cell = Grid.to_cell(get_global_mouse_position())
	else:
		var pads := Input.get_connected_joypads()
		var aim := Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_X), Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_Y)) if not pads.is_empty() else Vector2.ZERO
		if aim.length() < 0.3:
			aim = Vector2(player.facing, Input.get_axis("climb_up", "climb_down"))
		target_cell = Grid.to_cell(player.position - Vector2(0, 32) + aim.normalized() * 60)
	if (Input.is_action_pressed("mine") or mouse_mining) and mine_timer <= 0 and not controls_blocked() and not outpost.build_mode:
		_mine_target()
	if player.position.y > Grid.metres(site.DEPTH + 1):
		return_home()
	_refresh_hud()
	queue_redraw()

func can_reach(cell: Vector2i) -> bool:
	var hand := player.position - Vector2(0, Grid.metres(0.8))
	if hand.distance_to(Grid.center(cell)) > Grid.metres(active_tool().reach_metres):
		return false
	# Cast against the same physics rectangles used by movement: no mining through walls.
	var query := PhysicsRayQueryParameters2D.create(hand, Grid.center(cell), 1, [player.get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and blocks.get(cell) == hit.collider

func target_blocker(cell: Vector2i) -> String:
	if not outpost.fabrication.carried().is_empty():
		return "Posa il cubo con Spazio prima di usare lo strumento"
	if site.material(cell).is_empty():
		return "Spazio libero"
	if not can_reach(cell):
		return "Fuori portata o percorso ostruito"
	var tool := active_tool()
	if tool.mode == "mine" and is_instance_valid(outpost) and not outpost.mining_blocker(cell).is_empty():
		return outpost.mining_blocker(cell)
	if tool.mode == "mine" and site.material(cell) == "anchor":
		return "Indistruttibile: devi aggirare questo nucleo"
	if tool.mode == "mine" and site.material(cell) not in tool.materials:
		return "Materiale incompatibile: serve un altro strumento"
	if ship_energy() < tool.energy_per_pulse:
		return "Energia esaurita: ricarica in officina"
	if tool.mode == "mine" and field_cargo.free_space(drone_can_collect()) <= 0:
		return "Carico pieno: deposita zaino e drone"
	return ""

func _mine_target() -> void:
	if mine_timer > 0:
		return
	mine_timer = 0.22
	var blocker := target_blocker(target_cell)
	if not blocker.is_empty():
		_note(blocker)
		return
	var tool := active_tool()
	beam_time = 0.24
	_set_crew_energy(crew_energy() - (1.0 if tool.mode == "mine" else 0.15))
	beam_target = Grid.center(target_cell)
	beam_tool = tool
	player.facing = 1 if beam_target.x >= player.position.x else -1
	_set_ship_energy(ship_energy() - tool.energy_per_pulse)
	if tool.mode == "scan":
		scanned[target_cell] = site.material(target_cell)
		var kind := site.material(target_cell)
		var warning := environment.reading(target_cell)
		var resistance := "Indistruttibile" if kind == "anchor" else "Resistenza %d" % site.COST[kind]
		_note("%s / %s%s" % [MATERIAL_NAMES[kind], resistance, " / " + warning if not warning.is_empty() else ""])
		return
	var power: int = tool.power + (ship_state.drill_power() - 1 if ship_state != null else 0)
	var collected := site.mine(target_cell, power, "bedrock" in tool.materials)
	if not collected.is_empty():
		var body: StaticBody2D = blocks[target_cell]
		terrain.remove_child(body)
		body.queue_free()
		blocks.erase(target_cell)
		navigation_revision += 1
		var resource_id: String = site.RESOURCE_YIELDS.get(collected, collected)
		field_cargo.collect(resource_id, 1, drone_can_collect())
		scanned.erase(target_cell)
		guide_event("mined")
		_note("+1 " + MATERIAL_NAMES[resource_id])
		var breaches := environment.detect_breaches()
		if "gas" in breaches:
			guide_event("gas_leak")
			_note("Allarme: sacca di gas aperta! Allontanati dalla nube")
		elif "water" in breaches:
			guide_event("water_leak")
			_note("Allarme: infiltrazione d'acqua! Mantieni una via di risalita")
	queue_redraw()

func set_hatch(open: bool, notify: bool = true) -> void:
	if not open and player.position.x > -52 and player.position.x < 52 and player.position.y > -80 and player.position.y < -8:
		_note("Passaggio occupato")
		return
	var changed := hatch_open != open
	hatch_open = open
	if open and changed and notify:
		guide_event("hatch_opened")
	hatch.get_child(0).set_deferred("disabled", open)
	navigation_revision += 1
	_note("Botola aperta" if open else "Botola chiusa")

func place_ladder() -> bool:
	var cell := Grid.to_cell(player.position - Vector2(0, 20))
	return place_ladder_at(cell)

func place_ladder_at(cell: Vector2i) -> bool:
	if cell.y < 0 or not site.contains(cell) or not site.material(cell).is_empty() or ladders.has(cell):
		_note("Qui non puoi aggiungere una scala")
		return false
	if Grid.center(cell).distance_to(player.position - Vector2(0, 32)) > Grid.metres(1.5):
		_note("Scala fuori portata")
		return false
	if not field_cargo.pay({"soil": 2}, drone_help_available(), outpost.payment_cache()):
		_note("Servono 2 unita di terra per una scala")
		return false
	ladders[cell] = true
	guide_event("ladder")
	_note("Scala installata: 1 m")
	return true

func return_home() -> void:
	player.position = Vector2(-60, -80)
	player.velocity = Vector2.ZERO
	player.climbing = false
	_note("Rientro in officina")

func capture_state() -> Dictionary:
	var saved_ladders: Array = []
	for cell: Vector2i in ladders:
		saved_ladders.append([cell.x, cell.y])
	var readings: Array = []
	for cell: Vector2i in scanned:
		readings.append([cell.x, cell.y])
	return {"version": 1, "cell_metres": Grid.CELL_METRES, "terrain_seed": site.terrain_seed, "removed": site.snapshot(), "ladders": saved_ladders, "scanned": readings, "hazards": environment.snapshot(), "buildings": outpost.buildings.snapshot(), "fabrication": outpost.fabrication.snapshot(), "local_lab_level": outpost.local_lab_level, "field_cargo": field_cargo.snapshot(), "drone_guide": guide_state.snapshot(), "store": local_store.duplicate(), "drone_position": [drone.position.x, drone.position.y], "suit_integrity": suit_integrity(), "crew_energy": crew_energy(), "ship_energy": ship_energy(), "materials": inventory.materials.duplicate(), "player": [player.position.x, player.position.y], "hatch_open": hatch_open}

func save_run() -> bool:
	if campaign != null:
		return campaign.save_campaign()
	var ok: bool = SaveManager.write_rocket_save(capture_state())
	_note("Avamposto salvato" if ok else "Salvataggio non riuscito")
	return ok

func load_run() -> bool:
	if campaign != null:
		return campaign.load_campaign()
	var data: Dictionary = SaveManager.read_rocket_save()
	return restore_state(data)

func restore_state(data: Dictionary, restore_inventory: bool = true) -> bool:
	if data.get("version") != 1 or data.get("cell_metres") != Grid.CELL_METRES or data.get("terrain_seed", 0) != site.terrain_seed or not data.get("removed") is Array or not data.get("materials") is Dictionary or not data.get("ladders") is Array:
		_note("Nessun salvataggio compatibile")
		return false
	var next_site := DigSite.new(site.terrain_seed)
	next_site.restore(data.removed)
	var next_environment := HazardField.new(next_site)
	if not next_environment.restore(data.get("hazards", {})):
		_note("Dati ambientali non validi")
		return false
	var next_buildings := Buildings.new()
	if not next_buildings.restore(data.get("buildings", []), next_site):
		_note("Dati delle costruzioni non validi")
		return false
	var next_fabrication := Outpost.Fabrication.new()
	if not next_fabrication.restore(data.get("fabrication", {})) or not next_fabrication.valid_world(next_site, next_buildings) or not Outpost.Fabrication.integer(data.get("local_lab_level", 1), 1, 3):
		_note("Dati di fabbricazione non validi")
		return false
	var next_cargo := FieldCargo.new()
	next_cargo.drone_capacity = field_cargo.drone_capacity
	if restore_inventory and not next_cargo.restore(data.get("field_cargo", {"backpack": {}, "drone": {}})):
		_note("Dati del carico non validi")
		return false
	var next_guide := GuideState.new()
	if restore_inventory and not next_guide.restore(data.get("drone_guide", {})):
		_note("Dati della guida non validi")
		return false
	for key: String in ["crew_energy", "ship_energy"]:
		var value = data.get(key, 100 if key == "crew_energy" else 60)
		var maximum: float = 100 if key == "crew_energy" else (ship_state.energy_capacity() if ship_state != null else 60)
		if restore_inventory and (not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > maximum):
			return false
	for child in terrain.get_children():
		terrain.remove_child(child)
		child.queue_free()
	blocks.clear()
	site = next_site
	environment = next_environment
	outpost.buildings = next_buildings
	outpost.fabrication = next_fabrication
	outpost.local_lab_level = int(data.get("local_lab_level", 1))
	outpost.activation_cube_id = 0
	outpost.selected_station = {}
	outpost.station_menu.popup.hide()
	outpost.station_menu.window.hide()
	outpost.construction.picker.hide()
	outpost.construction.activation_popup.hide()
	rooms.popup.hide()
	rooms._close_bed()
	outpost.build_mode = false
	outpost.preview_fixed = false
	navigation_revision += 1
	scanned.clear()
	if data.get("scanned", []) is Array:
		for entry in data.get("scanned", []):
			var cell = Grid.decode_cell(entry)
			if cell is Vector2i and not site.material(cell).is_empty():
				scanned[cell] = site.material(cell)
	# Rebuild only cell bodies; planet boundaries are persistent nodes.
	for y in range(site.DEPTH):
		for x in range(site.LEFT, site.RIGHT):
			var cell := Vector2i(x, y)
			if not site.material(cell).is_empty():
				blocks[cell] = _body(Grid.rect(cell), terrain)
	if restore_inventory:
		var saved_suit = data.get("suit_integrity", 100)
		if (saved_suit is int or saved_suit is float) and is_finite(float(saved_suit)):
			_set_suit(float(saved_suit))
		field_cargo.restore(next_cargo.snapshot())
		guide_state.restore(next_guide.snapshot())
		_set_crew_energy(float(data.get("crew_energy", 100)))
		_set_ship_energy(float(data.get("ship_energy", 60)))
		if data.get("store") is Dictionary and FieldCargo.valid_stock(data.store, 120):
			local_store = data.store.duplicate()
		elif not data.has("field_cargo") and FieldCargo.valid_stock(data.materials, 120):
			local_store = data.materials.duplicate()
	ladders.clear()
	for entry in data.ladders:
		var cell = Grid.decode_cell(entry)
		if cell is Vector2i:
			if cell.x >= site.LEFT and cell.x < site.RIGHT and cell.y >= -2 and cell.y < site.DEPTH and site.material(cell).is_empty():
				ladders[cell] = true
	for building: Dictionary in outpost.buildings.structures:
		if building.id == "ladder" and Buildings.is_active(building):
			ladders[building.origin] = true
	return_home()
	set_hatch(bool(data.get("hatch_open", false)), false)
	var position_data = data.get("player", [])
	if position_data is Array and position_data.size() == 2 and (position_data[0] is float or position_data[0] is int) and (position_data[1] is float or position_data[1] is int):
		var candidate := Vector2(float(position_data[0]), float(position_data[1]))
		if _safe_position(candidate):
			player.position = candidate
	var drone_point = data.get("drone_position")
	if drone_point is Array and drone_point.size() == 2 and (drone_point[0] is int or drone_point[0] is float) and (drone_point[1] is int or drone_point[1] is float):
		var candidate := Vector2(float(drone_point[0]), float(drone_point[1]))
		if candidate.is_finite() and candidate.distance_to(Vector2(0, -80)) <= Grid.metres(drone.range_metres) and drone._free(Grid.to_cell(candidate)):
			drone.position = candidate
	if not data.has("drone_guide"):
		# Older saves infer milestones from the restored outpost, not tutorial text.
		if site.removed.size() > DigSite.new(site.terrain_seed).removed.size():
			guide_state.facts.mined = true
		if not outpost.buildings.labs().is_empty():
			guide_state.facts.lab_built = true
		if outpost.buildings.structures.any(func(building: Dictionary): return building.id == "lamp"):
			guide_state.facts.lamp_placed = true
	if guide_state.facts.get("mined", false) and int(guide_state.ocra.counters.get("mined_cells", 0)) == 0:
		guide_state.ocra.counters["mined_cells"] = maxi(1, site.removed.size() - DigSite.new(site.terrain_seed).removed.size())
		guide_state.ocra.counters["mined"] = guide_state.ocra.counters["mined_cells"]
		guide_state.ocra.mark("workshop_entered")
		guide_state.ocra.mark("hatch_opened")
	observe_tutorial()
	_note("Avamposto caricato")
	return true

func _safe_position(point: Vector2) -> bool:
	if not point.is_finite() or point.x < Grid.metres(site.LEFT + 1) or point.x > Grid.metres(site.RIGHT - 1) or point.y < -376 or point.y > Grid.metres(site.DEPTH - 1):
		return false
	# Validate the restored model, not physics bodies pending their next server sync.
	var body := Rect2(point - Vector2(12, 64), Vector2(24, 64)).grow(-0.5)
	var first := Grid.to_cell(body.position)
	var last := Grid.to_cell(body.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if y >= 0 and not site.material(Vector2i(x, y)).is_empty():
				return false
	if body.position.y < 0:
		if body.position.y < -440 or body.position.x < -160 or body.end.x > 160:
			return false
		if body.end.y > -72 and (body.position.x < -40 or body.end.x > 40):
			return false
		for floor_y in [-320, -200, -80]:
			var hole_left := -40 if floor_y == -80 else 80
			var hole_right := 40 if floor_y == -80 else 120
			if body.intersects(Rect2(-160, floor_y, hole_left + 160, 8)) or body.intersects(Rect2(hole_right, floor_y, 160 - hole_right, 8)):
				return false
		if not hatch_open and body.intersects(Rect2(-40, -80, 80, 8)):
			return false
	return true

func _note(message: String) -> void:
	message_time = 3.0
	if is_instance_valid(status_label):
		status_label.text = message

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := ColorRect.new()
	top.color = Color("182c36")
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 60
	root.add_child(top)
	hazard_label = Label.new()
	hazard_label.position = Vector2(22, 76)
	hazard_label.add_theme_font_size_override("font_size", 14)
	hazard_label.add_theme_constant_override("outline_size", 5)
	hazard_label.add_theme_color_override("font_outline_color", Color("17212a"))
	root.add_child(hazard_label)
	drone_label = Label.new()
	drone_label.position = Vector2(22, 104)
	drone_label.add_theme_font_size_override("font_size", 14)
	drone_label.add_theme_color_override("font_outline_color", Color("17212a"))
	drone_label.add_theme_constant_override("outline_size", 4)
	root.add_child(drone_label)
	power_label = Label.new()
	power_label.position = Vector2(22, 132)
	power_label.add_theme_font_size_override("font_size", 14)
	power_label.add_theme_color_override("font_outline_color", Color("17212a"))
	power_label.add_theme_constant_override("outline_size", 4)
	root.add_child(power_label)
	var title := Label.new()
	title.text = "ROCKETMAN  /  " + (planet_def.display_name.to_upper() if planet_def != null else "AVAMPOSTO 01")
	title.position = Vector2(22, 10)
	title.add_theme_font_size_override("font_size", 18)
	top.add_child(title)
	location_label = Label.new()
	location_label.position = Vector2(22, 34)
	location_label.add_theme_font_size_override("font_size", 12)
	location_label.modulate = Color("9ccece")
	top.add_child(location_label)
	resources_label = Label.new()
	resources_label.position = Vector2(405, 22)
	resources_label.add_theme_font_size_override("font_size", 13)
	top.add_child(resources_label)
	var tools := HBoxContainer.new()
	tools.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tools.offset_left = -485 if campaign != null else -400
	tools.offset_right = -16
	tools.offset_top = 13
	tools.add_theme_constant_override("separation", 6)
	top.add_child(tools)
	_button(tools, "Inventario", "Zaino, drone e deposito (I)", func(): outpost.open_cargo())
	if campaign != null:
		_button(tools, "Nave", "Stato, riparazioni e moduli", func(): campaign.open_ship_menu())
	_button(tools, "Salva", "Salva questo avamposto", save_run)
	_button(tools, "Carica", "Carica l'avamposto salvato", load_run)
	if campaign != null:
		_button(tools, "Decolla", "Rientra a bordo e chiudi la botola prima del decollo", func(): campaign.request_takeoff())
	else:
		_button(tools, "Nuovo", "Nuovo scavo (il salvataggio resta disponibile)", func(): reset_dialog.popup_centered())
	var bottom := ColorRect.new()
	bottom.color = Color("182c36")
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -38
	root.add_child(bottom)
	status_label = Label.new()
	status_label.position = Vector2(22, 8)
	status_label.add_theme_font_size_override("font_size", 14)
	bottom.add_child(status_label)
	metric_label = Label.new()
	metric_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	metric_label.offset_left = -300
	metric_label.offset_top = 8
	metric_label.add_theme_font_size_override("font_size", 13)
	metric_label.modulate = Color("9ccece")
	bottom.add_child(metric_label)
	var hotbar := HBoxContainer.new()
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.offset_left = -282
	hotbar.offset_right = 282
	hotbar.offset_top = -90
	hotbar.offset_bottom = -46
	hotbar.add_theme_constant_override("separation", 6)
	root.add_child(hotbar)
	for slot in range(Tools.SLOT_COUNT):
		var button := Button.new()
		button.custom_minimum_size = Vector2(135, 42)
		button.pressed.connect(equip_tool.bind(slot))
		hotbar.add_child(button)
		tool_buttons.append(button)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "Nuovo avamposto"
	reset_dialog.dialog_text = "Abbandonare le modifiche non salvate? Il salvataggio esistente non verra cancellato."
	reset_dialog.confirmed.connect(func(): get_tree().reload_current_scene())
	root.add_child(reset_dialog)

func _button(parent: Node, text: String, tip: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(86, 32)
	button.pressed.connect(callback)
	parent.add_child(button)

func _refresh_hud() -> void:
	resources_label.text = "Zaino %d/8   Robbie %d/%d" % [field_cargo.used(field_cargo.backpack), field_cargo.used(field_cargo.drone), field_cargo.drone_capacity]
	drone_label.text = "ROBBIE / %s / %.0f m" % [drone.status, drone.range_metres]
	var depth := maxf(0, player.position.y / Grid.PIXELS_PER_METRE)
	var room := "Sottosuolo" if player.position.y > 0 else ("Officina" if player.position.y > -200 else ("Zona abitativa" if player.position.y > -320 else "Cabina"))
	location_label.text = "%s  |  Profondita %.1f m  |  Botola %s" % [room, depth, "aperta" if hatch_open else "chiusa"]
	var danger := player_environment()
	var risk := "Nessuna esposizione"
	if danger.submerged:
		risk = "SOMMERSO / Risali o raggiungi una zona asciutta"
	elif float(danger.gas) >= 0.03:
		risk = "GAS / Allontanati dalla nube"
	elif danger.wet:
		risk = "ACQUA / Movimento rallentato"
	hazard_label.text = "TUTA %.0f%%  |  ENERGIA PERSONALE %.0f%%  |  %s" % [suit_integrity(), crew_energy(), risk]
	hazard_label.modulate = Color("ffd777") if danger.wet or float(danger.gas) >= 0.03 else Color("d4e9df")
	var capacity: float = ship_state.energy_capacity() if ship_state != null else 60
	var load: float = outpost.network_load()
	power_label.text = "BATTERIA NAVE %.1f / %.0f kWh\nRete %.2f kWh/min%s" % [ship_energy(), capacity, load * 60, " / %.1f min" % (ship_energy() / load / 60) if load > 0 else " / nessun consumo"]
	power_label.modulate = Color("ffb18e") if ship_energy() < 5 else Color("d4e9df")
	var tool := active_tool()
	metric_label.text = "1 CELLA = 1 m  |  %s / %.1f m" % [tool.display_name, tool.reach_metres]
	var slots: Array = ship_state.tool_slots if ship_state != null else ["pulse", "scanner", "", ""]
	var active: int = ship_state.active_tool_slot if ship_state != null else standalone_slot
	for slot in range(tool_buttons.size()):
		var definition := Tools.find(slots[slot])
		tool_buttons[slot].text = "%d  %s" % [slot + 1, definition.display_name if definition != null else "Vuoto"]
		tool_buttons[slot].disabled = definition == null
		tool_buttons[slot].modulate = definition.beam_color if slot == active else Color("ccd9d8")
		tool_buttons[slot].tooltip_text = "%.1f m / %.2f kWh per impulso" % [definition.reach_metres, definition.energy_per_pulse] if definition != null else "Nessuno strumento assegnato"
	if message_time <= 0:
		var blocker := target_blocker(target_cell)
		status_label.text = blocker if not blocker.is_empty() else ("%s / [%d, %d] m" % [MATERIAL_NAMES.get(scanned.get(target_cell, ""), "Blocco non analizzato"), target_cell.x, target_cell.y])
		if scanned.has(target_cell):
			var warning := environment.reading(target_cell)
			if not warning.is_empty():
				status_label.text = warning

func _draw() -> void:
	_draw_landscape()
	_draw_terrain()
	_draw_ship()
	_draw_environment()
	if show_grid:
		_draw_metric_overlay()
		if is_instance_valid(player):
			draw_arc(player.position - Vector2(0, 32), Grid.metres(active_tool().reach_metres), 0, TAU, 72, Color(active_tool().beam_color, 0.22), 1, true)
	for cell: Vector2i in ladders:
		_ladder(Grid.to_world(cell) + Vector2(20, 0), 40)
	if site.contains(target_cell) and not site.material(target_cell).is_empty():
		var available := target_blocker(target_cell).is_empty() if is_instance_valid(player) else false
		draw_rect(Grid.rect(target_cell).grow(-1), active_tool().beam_color if available else Color("ff6265"), false, 2.5)
		var damage := float(site.damage.get(target_cell, 0))
		if damage > 0:
			var origin := Grid.to_world(target_cell)
			draw_line(origin + Vector2(8, 4), origin + Vector2(22, 22), Color("2b252f"), 2)
			draw_line(origin + Vector2(22, 22), origin + Vector2(14, 36), Color("2b252f"), 2)
	if beam_time > 0 and beam_tool != null:
		_draw_beam()

func _draw_landscape() -> void:
	draw_rect(Rect2(-4000, -3000, 8000, 6000), planet_def.surface_color if planet_def != null else Color("75bac4"))
	draw_circle(Vector2(570, -410), 190, Color("acd9cf"))
	draw_arc(Vector2(570, -410), 230, -0.2, 2.9, 50, Color("d2e4d3"), 8)
	for index in range(-8, 9):
		var x := index * 170.0
		var height := 90 + posmod(index * 73, 190)
		_polygon([Vector2(x - 80, 30), Vector2(x - 65, -height), Vector2(x - 20, -height - 20), Vector2(x + 25, -height + 30), Vector2(x + 70, 30)], Color("b18d9a"))
		_polygon([Vector2(x - 20, -height - 20), Vector2(x + 25, -height + 30), Vector2(x + 70, 30), Vector2(x - 5, 30)], Color("9e8497"))
	draw_rect(Rect2(-3000, -6, 6000, 16), Color("d98b72"))

func _draw_terrain() -> void:
	var darkness := Color("101721")
	draw_rect(Rect2(Grid.to_world(Vector2i(site.LEFT, 0)), Grid.to_world(Vector2i(site.RIGHT - site.LEFT, site.DEPTH))), darkness)
	for y in range(site.DEPTH):
		for x in range(site.LEFT, site.RIGHT):
			var cell := Vector2i(x, y)
			var rect := Grid.rect(cell)
			var kind := site.material(cell)
			var light := _illumination(Grid.center(cell))
			if kind.is_empty():
				draw_rect(rect, darkness.lerp(Color("41444c"), light * 0.85))
				if show_grid and light > 0.15:
					draw_rect(rect, Color(0.65, 0.7, 0.73, light * 0.18), false, 1)
				continue
			var tint: Color = MATERIAL_COLORS[kind]
			if planet_def != null and kind == "soil":
				tint = planet_def.rock_color
			var variation := float(posmod(x * 13 + y * 23, 9)) * 0.012
			tint = tint.lightened(variation)
			tint = darkness.lerp(tint, light)
			draw_rect(rect, tint)
			var p := rect.position
			if light > 0.12:
				_polygon([p, p + Vector2(40, 0), p + Vector2(29, 13), p + Vector2(7, 8)], tint.lightened(light * 0.1))
				_polygon([p + Vector2(40, 0), p + Vector2(40, 40), p + Vector2(27, 34), p + Vector2(29, 13)], tint.darkened(light * 0.13))
			if light > 0.3 and (kind == "copper" or kind == "crystal"):
				var ore := Color("8ae8df") if kind == "crystal" else Color("e9b66d")
				_polygon([p + Vector2(9, 29), p + Vector2(13, 12), p + Vector2(22, 7), p + Vector2(27, 24), p + Vector2(20, 32)], ore)
				_polygon([p + Vector2(22, 7), p + Vector2(27, 24), p + Vector2(20, 32), p + Vector2(18, 17)], ore.darkened(0.2))
			if light > 0.2 and kind == "anchor":
				draw_rect(rect.grow(-5), tint.lightened(0.18), false, 3)
				draw_line(p + Vector2(9, 9), p + Vector2(31, 31), Color("a7b9b6"), 3)
				draw_line(p + Vector2(31, 9), p + Vector2(9, 31), Color("a7b9b6"), 3)
			if light > 0.2 and scanned.has(cell) and not environment.reading(cell).is_empty():
				_polygon([p + Vector2(20, 6), p + Vector2(34, 32), p + Vector2(6, 32)], Color("e8c56e"))
				draw_line(p + Vector2(20, 14), p + Vector2(20, 23), Color("29353e"), 3)
				draw_circle(p + Vector2(20, 28), 1.5, Color("29353e"))
			if show_grid and light > 0.2:
				draw_rect(rect, Color(0.14, 0.12, 0.17, 0.3), false, 1)

func _draw_environment() -> void:
	for cell: Vector2i in environment.water:
		var light := _illumination(Grid.center(cell))
		if light < 0.12:
			continue
		var rect := Grid.rect(cell)
		var amount := float(environment.water[cell])
		var height := Grid.CELL_SIZE * amount
		if height < 0.3:
			continue
		var top := rect.end.y - height
		draw_rect(Rect2(rect.position.x, top, Grid.CELL_SIZE, height), Color(0.19, 0.65, 0.85, light * 0.65))
		if float(environment.water.get(cell + Vector2i.UP, 0)) < 0.05:
			draw_line(Vector2(rect.position.x, top + sin(ambient_time * 3 + cell.x) * 1.5), Vector2(rect.end.x, top), Color(0.6, 0.9, 0.98, light * 0.8), 1.5)
	for cell: Vector2i in environment.gas:
		var light := _illumination(Grid.center(cell))
		var density := float(environment.gas[cell])
		if light < 0.12 or density < 0.015:
			continue
		var p := Grid.to_world(cell)
		var sway := sin(ambient_time * 2 + cell.x + cell.y) * 3
		_polygon([p + Vector2(1, 15 + sway), p + Vector2(10, 4), p + Vector2(25, 7 + sway), p + Vector2(39, 16), p + Vector2(34, 35), p + Vector2(7, 37)], Color(0.72, 0.81, 0.31, minf(0.65, density * 2) * light))

func _illumination(point: Vector2) -> float:
	var hand := player.position - Vector2(0, 32) if is_instance_valid(player) else Vector2(0, -100)
	var reach := Grid.metres(active_tool().reach_metres)
	var distance := point.distance_to(hand)
	var light := 1.0 - smoothstep(reach * 0.65, reach * 1.4, distance)
	var built_light: float = outpost.light_at(point) if is_instance_valid(outpost) else 0.0
	return maxf(light, built_light)

func _draw_beam() -> void:
	var start := player.position + Vector2(player.facing * 46, -34)
	var direction := (beam_target - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array()
	for index in range(25):
		var t := index / 24.0
		var wave := sin(t * 24 + ambient_time * 55) * 3 * sin(t * PI)
		points.append(start.lerp(beam_target, t) + normal * wave)
	var color: Color = beam_tool.beam_color
	draw_polyline(points, Color(color, 0.18), beam_tool.beam_width + 8, true)
	draw_polyline(points, color, beam_tool.beam_width, true)
	draw_polyline(points, Color("f4fff2"), maxf(1, beam_tool.beam_width * 0.3), true)
	draw_circle(beam_target, 4 + beam_tool.beam_width, Color(color, 0.6))

func _draw_ship() -> void:
	# All structural boundaries are whole-metre coordinates; bevels are visual only.
	for side in [-1, 1]:
		var x: float = side * 200.0
		draw_line(Vector2(side * 152, -100), Vector2(side * 216, -8), Color("4c5360"), 15)
		draw_line(Vector2(side * 152, -100), Vector2(side * 216, -8), Color("e8b553"), 9)
		draw_rect(Rect2(side * 216 - 28, -8, 56, 8), Color("46525c"))
		_polygon([Vector2(x - 34, -110), Vector2(x - 34, -260), Vector2(x - 20, -284), Vector2(x + 20, -284), Vector2(x + 34, -260), Vector2(x + 34, -110)], Color("d6e0d7"))
		draw_rect(Rect2(x - 34, -132, 68, 22), Color("db9f3f"))
		draw_rect(Rect2(x - 22, -110, 44, 18), Color("394854"))
		draw_rect(Rect2(x - 7, -248, 14, 82), Color("254751"))
		draw_rect(Rect2(x - 3, -244, 6, 74), Color("76e2d9"))
		_polygon([Vector2(x + side * 34, -215), Vector2(x + side * 65, -95), Vector2(x + side * 34, -112)], Color("e3ad4c"))
	_polygon([Vector2(-174, -80), Vector2(-174, -429), Vector2(-138, -456), Vector2(138, -456), Vector2(174, -429), Vector2(174, -80)], Color("e1e4d8"))
	_polygon([Vector2(-138, -456), Vector2(0, -520), Vector2(138, -456)], Color("e8ad42"))
	_polygon([Vector2(0, -520), Vector2(48, -456), Vector2(138, -456)], Color("f7ce69"))
	_polygon([Vector2(-138, -456), Vector2(0, -520), Vector2(-45, -456)], Color("c78b35"))
	for floor_cell in Grid.ROCKET_FLOORS:
		var floor_y := Grid.metres(floor_cell)
		draw_rect(Rect2(-160, floor_y - 112, 320, 112), Color("64585a"))
		draw_rect(Rect2(-150, floor_y - 103, 300, 95), Color("8d7a6a"))
		draw_rect(Rect2(-148, floor_y - 100, 296, 89), Color("ab9479"))
		for seam_x in range(-120, 151, 40):
			draw_line(Vector2(seam_x, floor_y - 98), Vector2(seam_x, floor_y - 13), Color(0.3, 0.27, 0.27, 0.15), 1)
		_lamp(Vector2(-25, floor_y - 106))
		var span := 120 if floor_y == -80 else 240
		draw_rect(Rect2(-160, floor_y, span, 8), Color("49525a"))
		draw_line(Vector2(-160, floor_y), Vector2(-160 + span, floor_y), Color("dce5dc"), 3)
		draw_rect(Rect2(40 if floor_y == -80 else 120, floor_y, 120 if floor_y == -80 else 40, 8), Color("49525a"))
		draw_rect(Rect2(-174, floor_y - 12, 14, 20), Color("e7ae47"))
		draw_rect(Rect2(160, floor_y - 12, 14, 20), Color("e7ae47"))
	_ladder(Vector2(100, -440), 360)
	_draw_cockpit()
	_draw_bedroom()
	_draw_workshop()
	for x in [-167, 167]:
		for y in range(-380, -80, 40):
			draw_circle(Vector2(x, y), 2, Color("81948f"))
	draw_rect(Rect2(-47, -72, 94, 72), Color("4b5961"), false, 7)
	if not hatch_open:
		draw_rect(Rect2(-40, -80, 80, 8), Color("e8b553"))
		draw_line(Vector2(-12, -76), Vector2(12, -76), Color("54636a"), 2)
	draw_circle(Vector2(-52, -94), 4, Color("7cddd1") if hatch_open else Color("f1bd5a"))

func _draw_cockpit() -> void:
	if is_instance_valid(rooms) and rooms.available("cabin"):
		draw_rect(ShipRooms.CABIN.grow(-5), Color(0.55, 0.9, 1, 0.13))
		draw_rect(ShipRooms.CABIN.grow(-5), Color("a6edee"), false, 2)
	draw_circle(Vector2(-45, -370), 33, Color("e7b35a"))
	draw_circle(Vector2(-45, -370), 27, Color("76bdc7"))
	draw_arc(Vector2(-45, -370), 24, 3.4, 5.6, 20, Color("c7e7dc"), 3)
	draw_rect(Rect2(-125, -349, 173, 12), Color("3f5059"))
	for x in [-115, -68, -21]:
		draw_rect(Rect2(x, -345, 32, 12), Color("264957"))
		draw_rect(Rect2(x + 3, -343, 26, 6), Color("78d6cf"))
	draw_line(Vector2(-114, -337), Vector2(-114, -320), Color("49525a"), 5)
	draw_rect(Rect2(-25, -354, 24, 22), Color("405664"))
	draw_rect(Rect2(-31, -332, 36, 7), Color("405664"))
	draw_line(Vector2(-13, -325), Vector2(-13, -320), Color("c4cabd"), 4)

func _draw_bedroom() -> void:
	if is_instance_valid(rooms) and rooms.available("bedroom"):
		draw_rect(ShipRooms.BEDROOM.grow(-5), Color(0.65, 1, 0.62, 0.12))
		draw_rect(ShipRooms.BEDROOM.grow(-5), Color("b7ffb6"), false, 2)
	draw_rect(Rect2(-138, -226, 117, 26), Color("49525b"))
	draw_rect(Rect2(-138, -235, 117, 15), Color("e3e4cf"))
	draw_rect(Rect2(-102, -235, 81, 19), Color("dba751"))
	draw_rect(Rect2(-134, -236, 30, 12), Color("f4efda"))
	if is_instance_valid(rooms) and rooms.resting:
		draw_string(ThemeDB.fallback_font, Vector2(-84, -254), "Z z", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("c8f6db"))
	draw_rect(Rect2(20, -244, 42, 44), Color("4a6770"))
	for y in [-239, -220]:
		draw_rect(Rect2(24, y, 34, 14), Color("809d9c"))
		draw_line(Vector2(36, y + 5), Vector2(48, y + 5), Color("d8dfc8"), 2)
	draw_rect(Rect2(-137, -284, 62, 5), Color("52636a"))
	for x in [-131, -112, -94]:
		draw_rect(Rect2(x, -299, 11, 15), Color("90b6a3"))
	var bob := sin(ambient_time * 2) * 1.5
	draw_circle(Vector2(-54, -249 + bob), 12, Color("8bc680"))
	draw_circle(Vector2(-62, -261 + bob), 5, Color("8bc680"))
	draw_circle(Vector2(-46, -261 + bob), 5, Color("8bc680"))
	draw_circle(Vector2(-59, -251 + bob), 2, Color("283e43"))
	draw_circle(Vector2(-49, -251 + bob), 2, Color("283e43"))

func _draw_workshop() -> void:
	draw_rect(Rect2(-142, -158, 37, 78), Color("3b6370"))
	draw_rect(Rect2(-136, -150, 25, 56), Color("67d5cb"))
	for y in [-138, -123, -108]:
		draw_line(Vector2(-137, y), Vector2(-110, y), Color("c0ebe0"), 2)
	draw_rect(Rect2(-97, -127, 112, 8), Color("d7ad5f"))
	draw_rect(Rect2(-92, -119, 8, 39), Color("52616a"))
	draw_rect(Rect2(0, -119, 8, 39), Color("52616a"))
	draw_rect(Rect2(-92, -181, 101, 45), Color("736e67"))
	for x in [-75, -45, -15]:
		draw_line(Vector2(x, -172), Vector2(x, -148), Color("cad6cc"), 4)
		draw_circle(Vector2(x, -171), 5, Color("cad6cc"), false, 2)
	_crate(Vector2(49, -112), Vector2(26, 32))
	if aboard_workshop():
		var glow := 0.09 + sin(ambient_time * 3) * 0.015
		draw_rect(Rect2(-150, -188, 300, 104), Color(0.65, 1, 0.62, glow))
		draw_rect(Rect2(-148, -186, 168, 106), Color("b7ffb6"), false, 2)
		draw_line(Vector2(-97, -127), Vector2(15, -127), Color("d2ffd0"), 4)

func _ladder(top: Vector2, height: float) -> void:
	draw_line(top + Vector2(-14, 0), top + Vector2(-14, height), Color("dfb15a"), 3)
	draw_line(top + Vector2(14, 0), top + Vector2(14, height), Color("dfb15a"), 3)
	for y in range(8, int(height), 16):
		draw_line(top + Vector2(-14, y), top + Vector2(14, y), Color("e4c78b"), 3)

func _lamp(point: Vector2) -> void:
	draw_circle(point + Vector2(0, 8), 28, Color(1, 0.81, 0.45, 0.045))
	draw_circle(point + Vector2(0, 8), 18, Color(1, 0.81, 0.45, 0.08))
	draw_rect(Rect2(point - Vector2(13, 0), Vector2(26, 5)), Color("4c5960"))
	draw_line(point + Vector2(-8, 5), point + Vector2(8, 5), Color("ffdf95"), 4)

func _crate(point: Vector2, size: Vector2) -> void:
	draw_rect(Rect2(point, size), Color("687a7b"))
	draw_rect(Rect2(point, size), Color("adb6a5"), false, 2)
	draw_rect(Rect2(point + Vector2(size.x * 0.4, 0), Vector2(5, size.y)), Color("d5b775"))

func _polygon(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _draw_metric_overlay() -> void:
	for y in range(Grid.ROCKET_CEILING, Grid.ROCKET_FLOORS[-1]):
		for x in range(-Grid.ROCKET_HALF_WIDTH, Grid.ROCKET_HALF_WIDTH):
			draw_rect(Grid.rect(Vector2i(x, y)), Color(0.85, 0.96, 0.91, 0.09), false, 1)
	var ink := Color("d6eee5")
	var top := Grid.metres(Grid.ROCKET_CEILING)
	var bottom := top + Grid.metres(Grid.ROOM_HEIGHT)
	var ruler_x := Grid.metres(-7.5)
	draw_line(Vector2(ruler_x, top), Vector2(ruler_x, bottom), ink, 1)
	for y in [top, bottom]:
		draw_line(Vector2(ruler_x - 5, y), Vector2(ruler_x + 5, y), ink, 1)
	draw_string(ThemeDB.fallback_font, Vector2(ruler_x - 36, (top + bottom) * 0.5 + 5), "3 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
