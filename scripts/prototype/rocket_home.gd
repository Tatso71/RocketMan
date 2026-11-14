extends Node2D

const Grid = preload("res://scripts/world/world_grid.gd")
const DigSite = preload("res://scripts/systems/dig_site.gd")
const Explorer = preload("res://scripts/player/rocket_explorer.gd")
const InventoryModel = preload("res://scripts/systems/inventory.gd")
const Tools = preload("res://scripts/data/digital_tool_catalog.gd")
const ItemIcons = preload("res://scripts/data/item_icon_catalog.gd")
const HazardField = preload("res://scripts/systems/environment_field.gd")
const FieldCargo = preload("res://scripts/systems/field_cargo.gd")
const Drone = preload("res://scripts/player/support_drone.gd")
const Outpost = preload("res://scripts/prototype/outpost_controller.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const GuideState = preload("res://scripts/systems/drone_guide_state.gd")
const GuideUI = preload("res://scripts/ui/drone_guide.gd")
const ShipRooms = preload("res://scripts/ui/ship_rooms.gd")
const TutorialUI = preload("res://scripts/ui/ocra_tutorial_ui.gd")
const HATCH_RECT := Rect2(0, -80, Grid.CELL_SIZE, 8)
const PERSONAL_LIGHT_RADIUS_METRES := 3.0
const Gear = preload("res://scripts/prototype/expedition_gear.gd")
const ScannerPulses = preload("res://scripts/ui/scanner_pulse_view.gd")
const ReservoirView = preload("res://scripts/ui/reservoir_view.gd")
const CryoCrewView = preload("res://scripts/ui/cryo_crew_view.gd")
const TerrainRenderer = preload("res://scripts/ui/terrain_renderer.gd")
const VitalsMeters = preload("res://scripts/ui/vitals_meters.gd")
const MiningFeedback = preload("res://scripts/ui/mining_feedback.gd")
const LadderLayer = preload("res://scripts/ui/ladder_layer.gd")
@export_enum("explorer", "robbie") var variant := "explorer"
@export var organic_terrain := true
const MATERIAL_NAMES := {"soil": "Terra", "stone": "Pietra", "copper": "Rame", "iron": "Ferro", "crystal": "Cristallo", "silica": "Quarzo", "cobalt": "Cobalto", "bedrock": "Roccia compatta", "anchor": "Nucleo indistruttibile", "water": "Acqua", "gas": "Gas", "oil": "Petrolio", "acid": "Acido"}
const MATERIAL_COLORS := {"soil": Color("a45148"), "stone": Color("746b7a"), "copper": Color("bb8162"), "iron": Color("a58f89"), "crystal": Color("55c5c6"), "silica": Color("c6c8b1"), "cobalt": Color("536fbb"), "bedrock": Color("454750"), "anchor": Color("465761")}
var site := DigSite.new()
var environment := HazardField.new(site)
var inventory := InventoryModel.new()
var player: CharacterBody2D
var camera: Camera2D
var terrain := Node2D.new()
var blocks: Dictionary = {}
var ladders: Dictionary = {}
var ladder_layer: Node2D
var hatch: StaticBody2D
var hatch_open := false
var show_grid := false
var target_cell := Vector2i.ZERO
var mouse_aim := false
var mine_timer := 0.0
var message_time := 0.0
var scanner_readout_active := false
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
var vitals_meters: HBoxContainer
var field_cargo := FieldCargo.new()
var local_store: Dictionary = {"soil": 0, "stone": 0, "copper": 0, "crystal": 0, "lamp_kit": 0}
var drone: CharacterBody2D
var outpost: Node2D
var navigation_revision := 0
var local_seed_bank := Outpost.Industry.Catalog.initial_seeds()
var drone_label: Label
var guide_state := GuideState.new()
var guide: CanvasLayer
var rooms: Node
var local_energy := 60.0
var local_crew_energy := 100.0
var power_label: Label
var tutorial_ui: CanvasLayer
var gear: Node2D
var jetpack_meter: ProgressBar
var scanner_view: Node2D
var debug_scanner: Resource
var reservoir_view: Node2D
var mining_feedback: PanelContainer

func is_robbie() -> bool:
	return variant == "robbie"

func seeds() -> Dictionary:
	return ship_state.seed_bank if ship_state != null else local_seed_bank

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
	var source: Dictionary = outpost.fabrication_stock()
	if field_cargo.can_pay({"iron": 8, "copper": 3, "crystal": 1}, drone_help_available(), source) or field_cargo.can_pay(Buildings.LAB_COST, drone_help_available(), source) or (int(tutorial.counters.get("collected_iron", 0)) >= 8 and int(tutorial.counters.get("collected_copper", 0)) >= 3 and int(tutorial.counters.get("collected_crystal", 0)) >= 1):
		tutorial.mark("lab_materials_ready")
	if field_cargo.can_pay(Buildings.LAB_COST, drone_help_available()):
		tutorial.mark("components_collected")
	if room_ready:
		tutorial.mark("lab_room_ready")
	for building: Dictionary in outpost.buildings.structures:
		if building.id == "laboratory":
			tutorial.mark("lab_room_ready")
			if building.get("state") != "planned":
				tutorial.mark("components_produced")
				tutorial.mark("components_collected")
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
	return drone_can_collect()

func drone_can_collect() -> bool:
	if is_robbie():
		return true
	return is_instance_valid(drone) and drone.mission == "follow" and drone.position.distance_to(player_center()) <= Grid.metres(3) and drone._clear(drone.position, player_center())

func suit_integrity() -> float:
	return ship_state.suit_integrity if ship_state != null else local_suit

func _set_suit(value: float) -> void:
	if ship_state != null:
		ship_state.suit_integrity = clampf(value, 0, 100)
	else:
		local_suit = clampf(value, 0, 100)

func player_environment() -> Dictionary:
	return environment.exposure(player.position, player.body_size().y / Grid.PIXELS_PER_METRE)

func player_center() -> Vector2:
	return player.body_center()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or controls_blocked():
		return
	field_cargo.drone_available = drone_can_collect()
	environment.advance(delta)
	outpost.advance(delta)
	gear.advance(delta)
	var danger := player_environment()
	var damage := (12.0 if danger.submerged else 0.0) + (4.0 if danger.oil else 0.0) + (HazardField.Fluids.KINDS.acid.damage if danger.acid else 0.0) + clampf((float(danger.gas) - 0.03) / 0.22, 0, 1) * 18
	if damage > 0:
		_set_suit(suit_integrity() - damage * delta)
	if suit_integrity() <= 0:
		return_home()
		_set_suit(25)
		_note("Richiamo di emergenza: scocca compromessa" if is_robbie() else "Richiamo di emergenza: tuta compromessa")

func active_tool() -> Resource:
	var slot: int = ship_state.active_tool_slot if ship_state != null else standalone_slot
	var slots: Array = ship_state.tool_slots if ship_state != null else ["pulse", "scanner", "bomb", "jetpack"]
	var tool: Resource = Tools.find(slots[slot])
	return debug_scanner if tool != null and tool.mode == "scan" and debug_scanner != null else tool

func _scanner_level_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed or event.meta_pressed or active_tool().mode != "scan":
		return false
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	var change := 1 if key in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD] or event.unicode == 43 else (-1 if key in [KEY_MINUS, KEY_KP_SUBTRACT] or event.unicode == 45 else 0)
	if change == 0: return false
	if debug_scanner == null:
		debug_scanner = active_tool().duplicate()
	debug_scanner.scanner_level = clampi(debug_scanner.scanner_level + change, 1, 4)
	scanner_view.pulses.clear()
	scanner_view.revealed.clear()
	scanner_view.emission_timer = 0
	scanner_view.queue_redraw()
	_refresh_hud()
	_note("Scanner %s / Raggio %.1f m" % [["I", "II", "III", "IV"][debug_scanner.scanner_level - 1], debug_scanner.effective_reach_metres()])
	return true

func equip_tool(slot: int) -> bool:
	var slots: Array = ship_state.tool_slots if ship_state != null else ["pulse", "scanner", "bomb", "jetpack"]
	if slot < 0 or slot >= Tools.SLOT_COUNT or str(slots[slot]).is_empty():
		return false
	if ship_state != null:
		ship_state.active_tool_slot = slot
	else:
		standalone_slot = slot
	beam_time = 0.0
	beam_tool = null
	mouse_mining = false
	if is_instance_valid(mining_feedback): mining_feedback.clear()
	if player != null:
		player.animation.stop_firing()
	_note(active_tool().display_name)
	mine_timer = 0
	return true

func configure(owner_campaign: Node, planet: Resource, ship: RefCounted) -> void:
	campaign = owner_campaign
	planet_def = planet
	ship_state = ship
	variant = owner_campaign.model.variant
	site = DigSite.new(planet.terrain_seed)
	environment = HazardField.new(site)
	field_cargo = ship.field_cargo
	guide_state = ship.drone_guide
	inventory.materials = field_cargo.drone

func controls_blocked() -> bool:
	if is_instance_valid(gear) and is_instance_valid(gear.repair_menu) and gear.repair_menu.visible:
		return true
	if is_instance_valid(outpost) and is_instance_valid(outpost.industry_ui) and outpost.industry_ui.is_open():
		return true
	if is_instance_valid(outpost) and is_instance_valid(outpost.hydraulic_ui) and outpost.hydraulic_ui.is_open():
		return true
	return controls_locked or (is_instance_valid(reset_dialog) and reset_dialog.visible) or (is_instance_valid(rooms) and rooms.is_open()) or (is_instance_valid(outpost) and ((is_instance_valid(outpost.cargo_window) and outpost.cargo_window.visible) or (is_instance_valid(outpost.station_menu) and outpost.station_menu.is_open()) or (is_instance_valid(outpost.construction) and outpost.construction.is_open()) or (is_instance_valid(outpost.assembly) and outpost.assembly.is_open())))

func _ready() -> void:
	guide_state.variant = variant
	guide_state.ocra.variant = variant
	_register_input()
	add_child(terrain)
	_build_terrain()
	_build_ship_collision()
	for y in range(-2, 0):
		ladders[Vector2i(0, y)] = true
	field_cargo.enable_drone_only(ship_state.drone_capacity() if ship_state != null else 20)
	inventory.materials = field_cargo.drone
	player = Explorer.new()
	player.world = self
	player.position = Vector2(-60, -320)
	player.z_index = 5
	add_child(player)
	drone = Drone.new()
	drone.world = self
	drone.position = Vector2(-140, -380)
	drone.z_index = 6
	add_child(drone)
	outpost = Outpost.new()
	outpost.world = self
	add_child(outpost)
	ladder_layer = LadderLayer.new()
	ladder_layer.world = self
	ladder_layer.z_index = 2
	add_child(ladder_layer)
	gear = Gear.new()
	gear.world = self
	add_child(gear)
	scanner_view = ScannerPulses.new()
	scanner_view.world = self
	add_child(scanner_view)
	reservoir_view = ReservoirView.new()
	reservoir_view.world = self
	add_child(reservoir_view)
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
	_action("send_drone", [KEY_Y], -1)
	_action("detonate_bombs", [KEY_ENTER, KEY_KP_ENTER], -1)
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
	_body(Rect2(-half_width, HATCH_RECT.position.y, half_width + HATCH_RECT.position.x, HATCH_RECT.size.y), self)
	_body(Rect2(HATCH_RECT.end.x, HATCH_RECT.position.y, half_width - HATCH_RECT.end.x, HATCH_RECT.size.y), self)
	hatch = _body(HATCH_RECT, self)

func on_ladder(feet: Vector2) -> bool:
	if absf(feet.x - 100) < 18 and feet.y >= -376 and feet.y <= -78:
		return true
	if not hatch_open and feet.y < -70:
		return false
	# Keep a grip until the feet clear the floor, so either side is a safe exit.
	if hatch_open and absf(feet.x - HATCH_RECT.get_center().x) < 22 and feet.y >= HATCH_RECT.position.y - 4 and feet.y <= HATCH_RECT.end.y:
		return true
	var torso := feet - Vector2(0, player.body_size().y * 0.5)
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
	if outpost.industry_ui.mode == "water" and outpost.industry_ui.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if _scanner_level_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("send_drone"):
		drone.send_to_ship()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("detonate_bombs"):
		gear.detonate()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not outpost.build_mode and not outpost.industry_ui.tool_active() and not outpost.hydraulic_tool_active() and drone.hit_test(event.position):
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
	if gear.handle_input(event):
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
		elif player.position.distance_to(Vector2(HATCH_RECT.get_center().x, HATCH_RECT.position.y)) < Grid.metres(2.5):
			set_hatch(not hatch_open)
		else:
			_note("Botola fuori portata")
	if event.is_action_pressed("place_ladder"):
		if event is InputEventKey and event.shift_pressed:
			remove_ladder_at(Grid.to_cell(player.position - Vector2(0, 20)))
		else:
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
	if controls_blocked():
		beam_time = 0.0
		beam_tool = null
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
		target_cell = Grid.to_cell(player_center() + aim.normalized() * 60)
	if (Input.is_action_pressed("mine") or mouse_mining) and active_tool().mode in ["mine", "bomb"] and mine_timer <= 0 and not controls_blocked() and not outpost.build_mode and not outpost.industry_ui.tool_active() and not outpost.hydraulic_tool_active():
		_mine_target()
	if player.position.y > Grid.metres(site.DEPTH + 1):
		return_home()
	_refresh_hud()
	queue_redraw()

func can_reach(cell: Vector2i) -> bool:
	return _reachable_target_point(cell) != null

func _reachable_target_point(cell: Vector2i) -> Variant:
	var hand := player_center()
	var center := Grid.center(cell)
	if not blocks.has(cell) or hand.distance_to(center) > Grid.metres(active_tool().effective_reach_metres()):
		return null
	var points := PackedVector2Array([center])
	# A ledge can hide a cell's centre while leaving its near face exposed.
	for normal: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		if (hand - center).dot(normal) < Grid.CELL_SIZE * 0.5:
			continue
		var face := center + normal * (Grid.CELL_SIZE * 0.5 - 0.01)
		var tangent := Vector2(-normal.y, normal.x)
		var half := Grid.CELL_SIZE * 0.5 - 0.5
		points.append(face + tangent * clampf((hand - face).dot(tangent), -half, half))
		points.append(face)
		points.append(face - tangent * half)
		points.append(face + tangent * half)
	for point: Vector2 in points:
		var query := PhysicsRayQueryParameters2D.create(hand, point, 1, [player.get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and blocks[cell] == hit.collider:
			return point
	return null

func target_blocker(cell: Vector2i) -> String:
	if active_tool().mode == "bomb":
		return gear.placement_blocker(cell)
	if active_tool().mode == "jetpack":
		return "Jetpack %.0f%% / Spazio o W / Ricarica toccando terra" % gear.charge()
	if not outpost.fabrication.carried().is_empty():
		return "Posa il cubo con Spazio prima di usare lo strumento"
	if site.material(cell).is_empty():
		if ladders.has(cell) and active_tool().mode == "mine":
			return "Scala della nave protetta" if cell.y < 0 else ("" if outpost.reachable_cell(cell) else "Scala fuori portata")
		return "Spazio libero"
	if not can_reach(cell):
		return "Fuori portata o percorso ostruito"
	var tool := active_tool()
	if tool.mode == "mine" and is_instance_valid(outpost) and not outpost.mining_blocker(cell).is_empty():
		return outpost.mining_blocker(cell)
	if tool.mode == "mine" and site.material(cell) == "anchor":
		return "Indistruttibile: non si rompe con utensili o bombe"
	if tool.mode == "mine" and site.material(cell) not in tool.materials:
		var required: Resource
		for candidate: Resource in Tools.all():
			if candidate.mode == "mine" and site.material(cell) in candidate.materials and (required == null or candidate.required_level < required.required_level):
				required = candidate
		return "Strumento non adatto: serve " + required.display_name if required != null else "Non hai lo strumento giusto per questo blocco"
	if ship_energy() < tool.energy_per_pulse:
		return "Energia esaurita: ricarica in officina"
	return ""

func _mine_target() -> void:
	var tool := active_tool()
	if tool.mode != "mine":
		beam_time = 0.0
		beam_tool = null
		mouse_mining = false
		if tool.mode != "bomb":
			return
	if mine_timer > 0:
		return
	mine_timer = 0.22
	if active_tool().mode == "bomb":
		gear.place_bomb(target_cell)
		mouse_mining = false
		return
	if site.material(target_cell).is_empty() and ladders.has(target_cell) and active_tool().mode == "mine":
		var reason := target_blocker(target_cell)
		if not reason.is_empty():
			_note(reason)
		elif remove_ladder_at(target_cell):
			beam_time = 0.24
			beam_tool = active_tool()
			beam_target = Grid.center(target_cell)
			player.facing = 1 if beam_target.x >= player.position.x else -1
			player.mining_pulse()
		return
	var blocker := target_blocker(target_cell)
	if not blocker.is_empty():
		_note(blocker)
		beam_time = 0.0
		if not site.material(target_cell).is_empty(): mining_feedback.show_reason(target_cell, blocker)
		return
	mining_feedback.clear()
	var aim_point = _reachable_target_point(target_cell)
	if aim_point == null:
		return
	beam_time = 0.24
	_set_crew_energy(crew_energy() - 1.0)
	beam_target = aim_point
	beam_tool = tool
	player.facing = 1 if beam_target.x >= player.position.x else -1
	if tool.mode == "mine":
		player.mining_pulse()
	_set_ship_energy(ship_energy() - tool.energy_per_pulse)
	var power: int = tool.power + (ship_state.drill_power() - 1 if ship_state != null else 0)
	var collected := site.mine(target_cell, power, "bedrock" in tool.materials)
	if not collected.is_empty():
		remove_mined_block(target_cell, collected)
		var resource_id: String = site.resource_yield(collected)
		if not resource_id.is_empty():
			gear.spawn_ore(target_cell, resource_id)
		guide_event("mined")
		_note("Scavo libero" if resource_id.is_empty() else ("%s a terra / Robbie lo raccogliera" % MATERIAL_NAMES[resource_id] if gear.drops.has(target_cell) else "+1 " + MATERIAL_NAMES[resource_id]))
		var breaches := environment.detect_breaches()
		if "gas" in breaches:
			guide_event("gas_leak")
			_note("Allarme: sacca di gas aperta! Allontanati dalla nube")
		elif "water" in breaches:
			guide_event("water_leak")
			_note("Allarme: infiltrazione d'acqua! Mantieni una via di risalita")
		elif "oil" in breaches:
			guide_event("oil_leak")
			_note("Petrolio in uscita! Evita il contatto con la tuta")
		elif "acid" in breaches:
			guide_event("acid_leak")
			_note("Falda di acido aperta! Allontanati dal liquido corrosivo")
	queue_redraw()

func remove_mined_block(cell: Vector2i, kind: String) -> void:
	if blocks.has(cell):
		var body: StaticBody2D = blocks[cell]
		terrain.remove_child(body)
		body.queue_free()
		blocks.erase(cell)
	if is_instance_valid(outpost):
		outpost.hydraulics.synchronize(outpost)
	if is_instance_valid(scanner_view):
		scanner_view.revealed.erase(cell)
	navigation_revision += 1
	gear.burst(Grid.center(cell), MATERIAL_COLORS.get(kind, Color("b9ada0")))

func set_hatch(open: bool, notify: bool = true) -> void:
	var body: Rect2 = player.body_rect_at(player.position)
	if not open and body.intersects(HATCH_RECT):
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
	if gear.bombs.any(func(bomb: Dictionary): return bomb.cell == cell):
		_note("La cella e occupata da una bomba")
		return false
	if cell.y < 0 or not site.contains(cell) or not site.material(cell).is_empty() or ladders.has(cell):
		_note("Qui non puoi aggiungere una scala")
		return false
	if Grid.center(cell).distance_to(player_center()) > Grid.metres(1.5):
		_note("Scala fuori portata")
		return false
	ladders[cell] = true
	guide_event("ladder")
	_note("Scala installata: 1 m")
	return true

func remove_ladder_at(cell: Vector2i) -> bool:
	if cell.y < 0 or not ladders.has(cell) or not outpost.reachable_cell(cell):
		_note("Scala protetta o fuori portata")
		return false
	ladders.erase(cell)
	outpost.buildings.structures = outpost.buildings.structures.filter(func(item: Dictionary): return not (item.id == "ladder" and item.origin == cell))
	player.climbing = false
	_note("Scala rimossa")
	queue_redraw()
	return true

func return_home() -> void:
	beam_time = 0.0
	beam_tool = null
	mouse_mining = false
	if is_instance_valid(mining_feedback): mining_feedback.clear()
	player.position = Vector2(-60, -80)
	player.velocity = Vector2.ZERO
	player.climbing = false
	_note("Rientro in officina")
	player.reset_animation()

func capture_state() -> Dictionary:
	outpost.hydraulics.synchronize(outpost)
	var saved_ladders: Array = []
	for cell: Vector2i in ladders:
		saved_ladders.append([cell.x, cell.y])
	var readings: Array = []
	for cell: Vector2i in scanned:
		readings.append([cell.x, cell.y])
	var data := {"version": 1, "economy_version": 2, "layout_version": site.layout_version, "cell_metres": Grid.CELL_METRES, "terrain_seed": site.terrain_seed, "removed": site.snapshot(), "ladders": saved_ladders, "scanned": readings, "hazards": environment.snapshot(), "buildings": outpost.buildings.snapshot(), "fabrication": outpost.fabrication.snapshot(), "local_lab_level": outpost.local_lab_level, "field_cargo": field_cargo.snapshot(), "drone_guide": guide_state.snapshot(), "store": local_store.duplicate(), "drone_position": [drone.position.x, drone.position.y], "suit_integrity": suit_integrity(), "crew_energy": crew_energy(), "ship_energy": ship_energy(), "materials": inventory.materials.duplicate(), "player": [player.position.x, player.position.y], "hatch_open": hatch_open}
	data.variant = variant
	data.network = outpost.network.snapshot()
	data.industry = outpost.industry.snapshot()
	data.hydraulics = outpost.hydraulics.snapshot()
	data.seed_bank = seeds().duplicate()
	data.gear = gear.snapshot()
	data.drone_mission = drone.mission
	data.scan_findings = []
	for cell: Vector2i in scanned:
		data.scan_findings.append({"cell": [cell.x, cell.y], "kind": scanned[cell]})
	return data

func save_run() -> bool:
	if campaign != null:
		return campaign.save_campaign()
	var ok: bool = SaveManager.write_rocket_save(capture_state())
	_note("Avamposto salvato" if ok else "Salvataggio non riuscito")
	return ok

func load_run() -> bool:
	if campaign != null:
		return campaign.load_campaign()
	var data: Dictionary = SaveManager.read_rocket_save(variant)
	return restore_state(data)

func restore_state(data: Dictionary, restore_inventory: bool = true) -> bool:
	if data.get("variant", "explorer") != variant:
		_note("Questo salvataggio appartiene a un'altra variante")
		return false
	if data.get("version") != 1 or data.get("economy_version") != 2 or data.get("cell_metres") != Grid.CELL_METRES or data.get("terrain_seed", 0) != site.terrain_seed or not data.get("removed") is Array or not data.get("materials") is Dictionary or not data.get("ladders") is Array:
		_note("Nessun salvataggio compatibile")
		return false
	if not Outpost.Fabrication.integer(data.get("layout_version", 0), 0, DigSite.HazardLayout.CURRENT_VERSION):
		return false
	var next_findings := {}
	if data.has("scan_findings"):
		if not site.valid_scan_findings(data.scan_findings):
			return false
		for entry in data.scan_findings:
			var cell = Grid.decode_cell(entry.get("cell"))
			next_findings[cell] = entry.kind
	var next_site := DigSite.new(site.terrain_seed, int(data.get("layout_version", 0)))
	next_site.restore(data.removed)
	var next_environment := HazardField.new(next_site)
	if not next_environment.restore(data.get("hazards", {})):
		_note("Dati ambientali non validi")
		return false
	var next_buildings := Buildings.new()
	if not next_buildings.restore(data.get("buildings", []), next_site):
		_note("Dati delle costruzioni non validi")
		return false
	var next_network := Outpost.Network.new()
	var next_industry := Outpost.Industry.new()
	if not next_network.restore(data.get("network", {}), next_site):
		_note("Condotti non compatibili: avvia una nuova partita")
		return false
	if not next_industry.restore(data.get("industry", {}), next_buildings, next_site):
		_note("Dati degli impianti non validi")
		return false
	var next_hydraulics := Outpost.WaterCircuit.new()
	if not next_hydraulics.restore(data.get("hydraulics", {}), next_site, next_buildings):
		_note("Circuito acqua non compatibile: avvia una nuova partita")
		return false
	if not Gear.valid(data.get("gear", {}), next_site, next_buildings) or data.get("drone_mission", "follow") not in outpost.logistics.MISSIONS:
		return false
	if restore_inventory and not Outpost.Industry.Catalog.seeds_valid(data.get("seed_bank", Outpost.Industry.Catalog.initial_seeds())):
		return false
	var next_fabrication := Outpost.Fabrication.new()
	if not next_fabrication.restore(data.get("fabrication", {})) or not next_fabrication.valid_world(next_site, next_buildings) or not Outpost.Fabrication.integer(data.get("local_lab_level", 1), 1, 3):
		_note("Dati di fabbricazione non validi")
		return false
	var next_cargo := FieldCargo.new()
	next_cargo.enable_drone_only(field_cargo.drone_capacity)
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
	outpost.network = next_network
	outpost.industry = next_industry
	outpost.hydraulics = next_hydraulics
	outpost.hydraulic_ui.reset()
	gear.restore(data.get("gear", {}), restore_inventory)
	drone.mission = data.get("drone_mission", "follow")
	if outpost.logistics.enabled(): outpost.logistics.reset()
	drone.has_resting_goal = false
	drone.revision = -1
	outpost.industry_ui.window.hide()
	outpost.industry_ui.menu.hide()
	outpost.industry_ui.context_menu.hide()
	outpost.industry_ui.mode = ""
	outpost.industry_ui.dragging = false
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
	scanner_view.revealed.clear()
	scanner_view.pulses.clear()
	if data.get("scanned", []) is Array:
		for entry in data.get("scanned", []):
			var cell = Grid.decode_cell(entry)
			if cell is Vector2i and not site.material(cell).is_empty():
				scanned[cell] = site.material(cell)
	if data.has("scan_findings"):
		scanned = next_findings
	# Rebuild only cell bodies; planet boundaries are persistent nodes.
	for y in range(site.DEPTH):
		for x in range(site.LEFT, site.RIGHT):
			var cell := Vector2i(x, y)
			if not site.material(cell).is_empty():
				blocks[cell] = _body(Grid.rect(cell), terrain)
	if restore_inventory:
		seeds().clear()
		seeds().merge(data.get("seed_bank", Outpost.Industry.Catalog.initial_seeds()))
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
		if candidate.is_finite() and drone._free(Grid.to_cell(candidate)):
			drone.position = candidate
	if not data.has("drone_guide"):
		# Older saves infer milestones from the restored outpost, not tutorial text.
		if site.removed.size() > DigSite.new(site.terrain_seed, site.layout_version).removed.size():
			guide_state.facts.mined = true
		if not outpost.buildings.labs().is_empty():
			guide_state.facts.lab_built = true
		if outpost.buildings.structures.any(func(building: Dictionary): return building.id == "lamp"):
			guide_state.facts.lamp_placed = true
	field_cargo.drone_available = drone_can_collect()
	guide_state.variant = variant
	guide_state.ocra.variant = variant
	if is_robbie():
		drone.sync_controlled()
	if guide_state.facts.get("mined", false) and int(guide_state.ocra.counters.get("mined_cells", 0)) == 0:
		guide_state.ocra.counters["mined_cells"] = maxi(1, site.removed.size() - DigSite.new(site.terrain_seed, site.layout_version).removed.size())
		guide_state.ocra.counters["mined"] = guide_state.ocra.counters["mined_cells"]
		guide_state.ocra.mark("workshop_entered")
		guide_state.ocra.mark("hatch_opened")
	observe_tutorial()
	_note("Avamposto caricato")
	return true

func _safe_position(point: Vector2) -> bool:
	var minimum_feet: float = Grid.metres(Grid.ROCKET_CEILING) + player.body_size().y
	if not point.is_finite() or point.x < Grid.metres(site.LEFT + 1) or point.x > Grid.metres(site.RIGHT - 1) or point.y < minimum_feet or point.y > Grid.metres(site.DEPTH - 1):
		return false
	# Validate the restored model, not physics bodies pending their next server sync.
	var body: Rect2 = player.body_rect_at(point).grow(-0.5)
	var first := Grid.to_cell(body.position)
	var last := Grid.to_cell(body.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if y >= 0 and not site.material(Vector2i(x, y)).is_empty():
				return false
	if body.position.y < 0:
		if body.position.y < -440 or body.position.x < -160 or body.end.x > 160:
			return false
		if body.end.y > HATCH_RECT.end.y and (body.position.x < HATCH_RECT.position.x or body.end.x > HATCH_RECT.end.x):
			return false
		for floor_y in [-320, -200, -80]:
			var hole_left: float = HATCH_RECT.position.x if floor_y == -80 else 80
			var hole_right: float = HATCH_RECT.end.x if floor_y == -80 else 120
			if body.intersects(Rect2(-160, floor_y, hole_left + 160, 8)) or body.intersects(Rect2(hole_right, floor_y, 160 - hole_right, 8)):
				return false
		if not hatch_open and body.intersects(HATCH_RECT):
			return false
	return true

func _note(message: String) -> void:
	message_time = 3.0
	scanner_readout_active = false
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
	vitals_meters = VitalsMeters.new()
	vitals_meters.position = Vector2(22, 70)
	root.add_child(vitals_meters)
	hazard_label = Label.new()
	hazard_label.position = Vector2(22, 100)
	hazard_label.add_theme_font_size_override("font_size", 13)
	hazard_label.add_theme_constant_override("outline_size", 5)
	hazard_label.add_theme_color_override("font_outline_color", Color("17212a"))
	root.add_child(hazard_label)
	drone_label = Label.new()
	drone_label.position = Vector2(22, 121)
	drone_label.add_theme_font_size_override("font_size", 13)
	drone_label.add_theme_color_override("font_outline_color", Color("17212a"))
	drone_label.add_theme_constant_override("outline_size", 4)
	root.add_child(drone_label)
	power_label = Label.new()
	power_label.position = Vector2(22, 142)
	power_label.add_theme_font_size_override("font_size", 13)
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
	_button(tools, "Inventario", "Carico Robbie e deposito (I)", func(): outpost.open_cargo())
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
	hotbar.offset_left = -337
	hotbar.offset_right = 337
	hotbar.offset_top = -90
	hotbar.offset_bottom = -46
	hotbar.add_theme_constant_override("separation", 6)
	root.add_child(hotbar)
	for slot in range(Tools.SLOT_COUNT):
		var button := Button.new()
		button.custom_minimum_size = Vector2(164, 42)
		button.add_theme_font_size_override("font_size", 15)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		button.pressed.connect(equip_tool.bind(slot))
		hotbar.add_child(button)
		tool_buttons.append(button)
		if slot == 3:
			jetpack_meter = ProgressBar.new()
			jetpack_meter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			jetpack_meter.offset_left = 8
			jetpack_meter.offset_right = -8
			jetpack_meter.offset_top = -7
			jetpack_meter.offset_bottom = -3
			jetpack_meter.show_percentage = false
			var empty_style := StyleBoxFlat.new()
			empty_style.bg_color = Color("12212a")
			jetpack_meter.add_theme_stylebox_override("background", empty_style)
			var charge_style := StyleBoxFlat.new()
			charge_style.bg_color = Color("8dbdeb")
			jetpack_meter.add_theme_stylebox_override("fill", charge_style)
			jetpack_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(jetpack_meter)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "Nuovo avamposto"
	reset_dialog.dialog_text = "Abbandonare le modifiche non salvate? Il salvataggio esistente non verra cancellato."
	reset_dialog.confirmed.connect(func(): get_tree().reload_current_scene())
	root.add_child(reset_dialog)
	mining_feedback = MiningFeedback.new()
	mining_feedback.world = self
	root.add_child(mining_feedback)

func _button(parent: Node, text: String, tip: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(86, 32)
	button.pressed.connect(callback)
	parent.add_child(button)

func _refresh_hud() -> void:
	resources_label.text = "Robbie %d/%d   Jet %.0f%%" % [field_cargo.used(field_cargo.drone), field_cargo.drone_capacity, gear.charge()]
	jetpack_meter.value = gear.charge()
	drone_label.text = "ROBBIE / %s / Magnete %.2f m" % [drone.status, gear.magnet_range_metres()]
	if is_robbie():
		drone_label.text = "ROBBIE / Controllo manuale / Criogenia 3 capsule stabili"
	var depth := maxf(0, player.position.y / Grid.PIXELS_PER_METRE)
	var room := "Sottosuolo" if player.position.y > 0 else ("Officina" if player.position.y > -200 else ("Zona abitativa" if player.position.y > -320 else "Cabina"))
	location_label.text = "%s  |  Profondita %.1f m  |  Botola %s" % [room, depth, "aperta" if hatch_open else "chiusa"]
	var danger := player_environment()
	var risk := "Nessuna esposizione"
	if danger.acid:
		risk = "ACIDO / Corrosione della tuta: torna all'asciutto"
	elif danger.submerged:
		risk = "SOMMERSO / Risali o raggiungi una zona asciutta"
	elif float(danger.gas) >= 0.03:
		risk = "GAS / Allontanati dalla nube"
	elif danger.oil:
		risk = "PETROLIO / Tuta contaminata: torna all'asciutto"
	elif danger.wet:
		risk = "ACQUA / Movimento rallentato"
	vitals_meters.update_values(crew_energy(), suit_integrity(), is_robbie())
	hazard_label.text = risk.replace("tuta", "scocca") if is_robbie() else risk
	hazard_label.modulate = Color("ffd777") if danger.wet or float(danger.gas) >= 0.03 else Color("d4e9df")
	if danger.acid:
		hazard_label.modulate = Color("e0f58a")
	var capacity: float = ship_state.energy_capacity() if ship_state != null else 60
	var load: float = outpost.network_load()
	power_label.text = "BATTERIA NAVE %.1f / %.0f kWh\nRete %.2f kWh/min%s" % [ship_energy(), capacity, load * 60, " / %.1f min" % (ship_energy() / load / 60) if load > 0 else " / nessun consumo"]
	power_label.modulate = Color("ffb18e") if ship_energy() < 5 else Color("d4e9df")
	var tool := active_tool()
	metric_label.text = "1 CELLA = 1 m  |  %s / %.1f m" % [tool.display_name, tool.effective_reach_metres()]
	if tool.mode == "scan":
		metric_label.text = "1 CELLA = 1 m  |  Scanner %s / %.1f m" % [["I", "II", "III", "IV"][tool.scanner_level - 1], tool.effective_reach_metres()]
	var slots: Array = ship_state.tool_slots if ship_state != null else ["pulse", "scanner", "bomb", "jetpack"]
	var active: int = ship_state.active_tool_slot if ship_state != null else standalone_slot
	for slot in range(tool_buttons.size()):
		var definition := Tools.find(slots[slot])
		tool_buttons[slot].icon = ItemIcons.texture(slots[slot])
		tool_buttons[slot].text = "%d  %s" % [slot + 1, definition.display_name if definition != null else "Vuoto"]
		if definition != null and definition.mode == "scan" and tool.mode == "scan":
			tool_buttons[slot].text += " " + ["I", "II", "III", "IV"][tool.scanner_level - 1]
		tool_buttons[slot].disabled = definition == null
		tool_buttons[slot].modulate = definition.beam_color if slot == active else Color("ccd9d8")
		tool_buttons[slot].tooltip_text = "%.1f m / %.2f kWh per impulso" % [definition.effective_reach_metres(), definition.energy_per_pulse] if definition != null else "Nessuno strumento assegnato"
		if definition != null and definition.mode == "bomb":
			tool_buttons[slot].text = "3  Bombe %d/%d" % [gear.ammo(), Gear.BOMB_CAPACITY]
			tool_buttons[slot].tooltip_text = "Click: posa una bomba pronta / Enter: detona da almeno 4 m / Fabbrica al laboratorio"
		elif definition != null and definition.mode == "jetpack":
			tool_buttons[slot].text = "4  Jetpack %.0f%%" % gear.charge()
			tool_buttons[slot].tooltip_text = "Mantieni Spazio o W / Ricarica automatica toccando un pavimento solido"
		elif definition != null and definition.mode == "scan":
			tool_buttons[slot].tooltip_text = "Scanner passivo / %.1f m / Nessun raggio di estrazione" % definition.effective_reach_metres()
	if active_tool().mode == "scan" and is_instance_valid(scanner_view):
		var reading: Dictionary = scanner_view.aimed_identity(target_cell)
		var title := "Segnale non identificato" if scanner_view.reveal_strength(target_cell) > 0 else "Nessun segnale"
		if not reading.is_empty():
			title = reading.name + " / " + reading.detail
		status_label.text = "%s / [%d, %d] m" % [title, target_cell.x, target_cell.y]
		scanner_readout_active = true
	elif message_time <= 0 or scanner_readout_active:
		var blocker := target_blocker(target_cell)
		status_label.text = blocker if not blocker.is_empty() else "Blocco non analizzato / [%d, %d] m" % [target_cell.x, target_cell.y]
		scanner_readout_active = false

func _draw() -> void:
	_draw_landscape()
	_draw_terrain()
	_draw_ship()
	if show_grid:
		_draw_metric_overlay()
		if is_instance_valid(player) and active_tool().mode == "mine":
			draw_arc(player_center(), Grid.metres(active_tool().effective_reach_metres()), 0, TAU, 72, Color(active_tool().beam_color, 0.22), 1, true)
	if active_tool().mode == "mine" and site.contains(target_cell) and (not site.material(target_cell).is_empty() or ladders.has(target_cell)):
		var available := target_blocker(target_cell).is_empty() if is_instance_valid(player) else false
		draw_rect(Grid.rect(target_cell).grow(-1), active_tool().beam_color if available else Color("ff6265"), false, 2.5)
		var damage := float(site.damage.get(target_cell, 0))
		if damage > 0:
			var origin := Grid.to_world(target_cell)
			draw_line(origin + Vector2(8, 4), origin + Vector2(22, 22), Color("2b252f"), 2)
			draw_line(origin + Vector2(22, 22), origin + Vector2(14, 36), Color("2b252f"), 2)
			var fraction := clampf(damage / maxf(1, site.mining_cost(target_cell)), 0, 1)
			draw_rect(Rect2(origin + Vector2(4, 32), Vector2(32, 3)), Color("17242a"))
			draw_rect(Rect2(origin + Vector2(4, 32), Vector2(32 * fraction, 3)), active_tool().beam_color)
	if beam_time > 0 and beam_tool != null and beam_tool.mode == "mine" and active_tool().mode == "mine":
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
	if organic_terrain:
		TerrainRenderer.draw(self)
	else:
		_draw_terrain_legacy()

func _draw_terrain_legacy() -> void:
	var darkness := Color("030509")
	var concealed := TerrainRenderer.hidden_pockets(self)
	# Keep the void beyond the finite dig-site boundary underground, not sky blue.
	draw_rect(Rect2(-4000, 0, 8000, 3000), darkness)
	draw_rect(Rect2(Grid.to_world(Vector2i(site.LEFT, 0)), Grid.to_world(Vector2i(site.RIGHT - site.LEFT, site.DEPTH))), darkness)
	for y in range(site.DEPTH):
		for x in range(site.LEFT, site.RIGHT):
			var cell := Vector2i(x, y)
			var rect := Grid.rect(cell)
			var kind := site.material(cell)
			if concealed.has(cell):
				kind = "stone"
			var light := _illumination(Grid.center(cell))
			if kind.is_empty():
				draw_rect(rect, darkness.lerp(Color("41444c"), light * 0.85))
				if show_grid and light > 0.15 and environment.liquid_volume(cell) < 0.01 and float(environment.gas.get(cell, 0)) < 0.015:
					draw_rect(rect, Color(0.65, 0.7, 0.73, light * 0.18), false, 1)
				continue
			var host: Color = planet_def.rock_color if planet_def != null else Color("a45148")
			var tint := host.lerp(Color("746b7a"), TerrainRenderer.geology(rect.get_center(), site.terrain_seed))
			var variation := float(posmod(x * 13 + y * 23, 9)) * 0.012
			tint = tint.lightened(variation)
			tint = darkness.lerp(tint, light)
			draw_rect(rect, tint)
			var p := rect.position
			if light > 0.12:
				_polygon([p, p + Vector2(40, 0), p + Vector2(29, 13), p + Vector2(7, 8)], tint.lightened(light * 0.1))
				_polygon([p + Vector2(40, 0), p + Vector2(40, 40), p + Vector2(27, 34), p + Vector2(29, 13)], tint.darkened(light * 0.13))
			if show_grid and light > 0.2:
				draw_rect(rect, Color(0.14, 0.12, 0.17, 0.3), false, 1)

func _illumination(point: Vector2) -> float:
	var hand := player_center() if is_instance_valid(player) else Vector2(0, -100)
	var reach := Grid.metres(PERSONAL_LIGHT_RADIUS_METRES)
	var depth := smoothstep(Grid.metres(2), Grid.metres(16), hand.y)
	reach *= lerpf(1, 0.42, depth)
	var distance := point.distance_to(hand)
	var light := (1.0 - smoothstep(reach * 0.65, reach * 1.4, distance)) * lerpf(1, 0.68, depth)
	var built_light: float = outpost.light_at(point) if is_instance_valid(outpost) else 0.0
	return maxf(light, built_light)

func _draw_beam() -> void:
	var start: Vector2 = player.beam_origin()
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
		var span: float = 160 + HATCH_RECT.position.x if floor_y == -80 else 240
		draw_rect(Rect2(-160, floor_y, span, 8), Color("49525a"))
		draw_line(Vector2(-160, floor_y), Vector2(-160 + span, floor_y), Color("dce5dc"), 3)
		var right_edge: float = HATCH_RECT.end.x if floor_y == -80 else 120
		draw_rect(Rect2(right_edge, floor_y, 160 - right_edge, 8), Color("49525a"))
		draw_rect(Rect2(-174, floor_y - 12, 14, 20), Color("e7ae47"))
		draw_rect(Rect2(160, floor_y - 12, 14, 20), Color("e7ae47"))
	_ladder(Vector2(100, -440), 360)
	_draw_cockpit()
	_draw_bedroom()
	_draw_workshop()
	for x in [-167, 167]:
		for y in range(-380, -80, 40):
			draw_circle(Vector2(x, y), 2, Color("81948f"))
	draw_rect(Rect2(HATCH_RECT.position.x - 7, HATCH_RECT.end.y, HATCH_RECT.size.x + 14, -HATCH_RECT.end.y), Color("4b5961"), false, 7)
	if not hatch_open:
		draw_rect(HATCH_RECT, Color("e8b553"))
		draw_line(HATCH_RECT.get_center() - Vector2(12, 0), HATCH_RECT.get_center() + Vector2(12, 0), Color("54636a"), 2)
	draw_circle(HATCH_RECT.position + Vector2(-12, -14), 4, Color("7cddd1") if hatch_open else Color("f1bd5a"))

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
	if is_robbie():
		CryoCrewView.draw_in(self)
		return
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
