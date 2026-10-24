extends CanvasLayer

const Guide = preload("res://scripts/systems/drone_guide_state.gd")
const InventoryUI = preload("res://scripts/ui/field_inventory_ui.gd")
var world: Node2D
var state: RefCounted
var bubble: PanelContainer
var tail: Polygon2D
var heading: Label
var speech: Label
var auto_toggle: CheckButton
var current_id := ""
var last_message_id := ""
var last_message_text := ""
var replay_id := ""
var replay_text := ""
var room_cache: Variant = null
var room_poll := 0.0
var room_revision := -1

func _ready() -> void:
	layer = 2
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	tail = Polygon2D.new()
	tail.color = Color("edf4ea")
	root.add_child(tail)
	bubble = PanelContainer.new()
	var style := InventoryUI.panel_style()
	style.bg_color = Color("edf4ea")
	style.border_color = Color("589d95")
	style.set_border_width_all(2)
	bubble.add_theme_stylebox_override("panel", style)
	root.add_child(bubble)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	bubble.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	heading = InventoryUI.label("", 13, Color("256c65"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(heading)
	var close := InventoryUI.button(header, "x", state.dismiss)
	close.custom_minimum_size = Vector2(24, 24)
	close.tooltip_text = "Chiudi il messaggio"
	speech = InventoryUI.label("", 16, Color("223933"))
	speech.custom_minimum_size = Vector2(300, 0)
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(speech)
	var controls := HBoxContainer.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.offset_left = -260
	controls.offset_top = -88
	controls.offset_right = -16
	controls.offset_bottom = -48
	controls.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(controls)
	var help := InventoryUI.button(controls, "?", request_help)
	help.custom_minimum_size.x = 38
	help.tooltip_text = "Chiedi un consiglio al drone (H)"
	auto_toggle = CheckButton.new()
	auto_toggle.text = "Aiuti drone"
	auto_toggle.button_pressed = not state.muted
	auto_toggle.tooltip_text = "Attiva o silenzia i balloon automatici"
	auto_toggle.toggled.connect(func(enabled: bool): state.set_muted(not enabled))
	controls.add_child(auto_toggle)
	bubble.hide()
	tail.hide()

func context() -> String:
	var danger: Dictionary = world.player_environment()
	if danger.submerged:
		return "water_danger"
	if float(danger.gas) >= 0.03:
		return "gas_danger"
	if world.ship_energy() < 5:
		return "energy_low"
	if world.crew_energy() < 25:
		return "bed_rest"
	if world.rooms.available("bedroom") and "bed_rest" not in state.seen:
		return "bed_rest"
	if world.drone.status == "Limite segnale":
		return "signal_limit"
	if world.field_cargo.free_space(world.drone_help_available()) <= 0:
		return "cargo_full" if world.drone_help_available() else "drone_unavailable"
	if not world.outpost.laboratory_unlocked() and state.facts.get("mined", false):
		for building: Dictionary in world.outpost.buildings.structures:
			if building.id == "laboratory":
				return "tutorial_fund" if building.state == "planned" else "tutorial_build"
		if room_poll <= 0 or room_revision != world.navigation_revision:
			room_cache = world.outpost.find_laboratory_space()
			room_revision = world.navigation_revision
			room_poll = 0.5
		if room_cache is Vector2i:
			return "tutorial_place"
		return "tutorial_excavate" if world.field_cargo.can_pay(world.Buildings.LAB_COST, world.drone_help_available(), world.outpost.payment_cache()) else "tutorial_collect"
	if world.outpost.build_mode:
		if world.outpost.blueprint == "ladder":
			return "ladder_tip"
		if world.outpost.blueprint == "lamp":
			return "lamp_crafted" if world.field_cargo.available("lamp_kit", world.drone_help_available()) > 0 else "lamp_plan"
		if world.outpost.blueprint == "pump":
			return "pump_plan"
		return "build_resources" if not world.outpost.cargo_ui.lab_missing().is_empty() and world.outpost.blueprint == "laboratory" else "build_space"
	for id: String in ["pump_built", "lamp_placed", "lamp_crafted", "lab_built", "deposited"]:
		if state.facts.get(id, false) and id not in state.seen:
			return id
	if world.outpost.has_lab():
		return "lamp_plan"
	if state.facts.get("mined", false):
		if "lab_plan" not in state.seen:
			return "lab_plan"
		if world.player.position.y > 100 and not state.facts.get("ladder", false):
			return "ladder_tip"
		return "tools"
	return "first_dig" if world.hatch_open else "welcome"

func request_help() -> void:
	replay_id = ""
	replay_text = ""
	current_id = ""
	var id := context()
	if world.aboard_workshop() and world.field_cargo.used(world.field_cargo.backpack) > 0 and not world.outpost.has_lab():
		id = "lab_plan" if world.field_cargo.free_space(world.drone_help_available()) > 0 else "cargo_full"
	state.offer(id, true)
	_update_bubble()

func repeat_last() -> void:
	if last_message_id.is_empty():
		request_help()
		return
	replay_id = last_message_id
	replay_text = last_message_text
	current_id = ""
	state.offer(replay_id, true)
	_update_bubble()

func event(id: String) -> void:
	if id in Guide.FACTS:
		state.facts[id] = true
	if id in ["gas_leak", "water_leak"]:
		state.offer(id)
	if id == "mined" and not world.outpost.laboratory_unlocked():
		state.offer("tutorial_collect")

func _process(delta: float) -> void:
	room_poll -= delta
	auto_toggle.set_pressed_no_signal(not state.muted)
	if world.controls_blocked():
		bubble.hide()
		tail.hide()
		return
	var id := context()
	state.tick(delta, id)
	state.offer(id)
	_update_bubble()

func _update_bubble() -> void:
	bubble.visible = not state.active_id.is_empty()
	tail.visible = bubble.visible
	if not bubble.visible:
		current_id = ""
		replay_id = ""
		replay_text = ""
		return
	if current_id != state.active_id:
		current_id = state.active_id
		if not state.active_manual or replay_id != current_id:
			replay_id = ""
			replay_text = ""
		speech.text = replay_text if not replay_text.is_empty() else Guide.MESSAGES[current_id][2]
		bubble.size = Vector2(332, 0)
	if current_id == "cargo_full" and replay_text.is_empty():
		speech.text = "Il laboratorio e raggiungibile: clic destro sul banco e Deposita materiali. Scarichi lo zaino e anche il mio carico se resto vicino. Per ripartire scegli Preleva materiali o Costruisci." if world.outpost.source_available() else Guide.MESSAGES[current_id][2]
	last_message_id = current_id
	last_message_text = speech.text
	var viewport := get_viewport().get_visible_rect().size
	var point: Vector2 = world.drone.get_global_transform_with_canvas() * Vector2.ZERO
	var actor: Vector2 = world.player.get_global_transform_with_canvas() * Vector2(0, -32)
	var body := Rect2(actor - Vector2(24, 45), Vector2(48, 90))
	var size := bubble.size.max(bubble.get_combined_minimum_size())
	var safe := Rect2(Vector2(16, 76), viewport - Vector2(32, 186))
	var radio := not safe.has_point(point) or current_id == "signal_limit"
	heading.text = "ROBBIE / " + ("RADIO" if radio else str(Guide.MESSAGES[current_id][1]).to_upper())
	var bubble_style := bubble.get_theme_stylebox("panel") as StyleBoxFlat
	bubble_style.border_color = Color("ef6666") if current_id == "water_danger" else Color("589d95")
	# Try both sides of the drone, avoiding the explorer and the fixed HUD areas.
	var candidates: Array[Vector2] = [point + Vector2(35, -size.y - 24), point - Vector2(size.x + 35, size.y + 24), point + Vector2(35, 32), point - Vector2(size.x + 35, -32)]
	if radio:
		candidates.push_front(Vector2(viewport.x - size.x - 24, 360))
	var best := Vector2.ZERO
	var best_score := INF
	for candidate: Vector2 in candidates:
		var clamped := candidate.clamp(safe.position, safe.end - size)
		var rect := Rect2(clamped, size)
		var score := candidate.distance_to(clamped)
		for obstacle: Rect2 in [body, Rect2(0, 70, 400, 125), Rect2(viewport.x - 280, 70, 280, 280)]:
			var overlap := rect.intersection(obstacle)
			score += overlap.get_area() * 10
		if score < best_score:
			best_score = score
			best = clamped
	bubble.position = best
	tail.visible = not radio and point.distance_to(best + size * 0.5) < 420
	if tail.visible:
		var base := point.clamp(best + Vector2(20, 12), best + size - Vector2(20, 12))
		var perpendicular := (point - base).normalized().orthogonal() * 7
		tail.polygon = PackedVector2Array([base + perpendicular, base - perpendicular, point + Vector2(0, -12)])
