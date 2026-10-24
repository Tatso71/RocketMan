extends Node

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const CABIN := Rect2(-156, -434, 312, 114)
const BEDROOM := Rect2(-156, -314, 312, 114)
var world: Node2D
var popup: PopupMenu
var bed_window: Window
var status: Label
var rest_button: Button
var resting := false

func available(room: String) -> bool:
	if not is_instance_valid(world.player) or absf(world.player.position.x) >= 160:
		return false
	var y: float = world.player.position.y
	return y <= -318 and y > -440 if room == "cabin" else y <= -198 and y > -318

func is_open() -> bool:
	return popup.visible or bed_window.visible

func _ready() -> void:
	popup = PopupMenu.new()
	popup.prefer_native_menu = false
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_constant_override("v_separation", 14)
	popup.add_theme_stylebox_override("panel", UI.panel_style())
	popup.add_separator("Cabina di pilotaggio")
	popup.add_item("Gestisci nave", 0)
	popup.add_item("Batteria e potenziamenti", 1)
	popup.add_item("Decolla", 2)
	popup.id_pressed.connect(_cabin_action)
	add_child(popup)
	bed_window = Window.new()
	bed_window.title = "Letto / Riposo"
	bed_window.visible = false
	bed_window.transient = true
	bed_window.exclusive = true
	bed_window.unresizable = true
	bed_window.close_requested.connect(_close_bed)
	bed_window.window_input.connect(func(event: InputEvent):
		if event.is_action_pressed("pause"):
			_close_bed()
			bed_window.set_input_as_handled())
	add_child(bed_window)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	bed_window.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	column.add_child(UI.label("RIPOSO", 22))
	status = UI.label("", 17)
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(status)
	rest_button = UI.button(column, "Riposa", func(): resting = true)
	UI.button(column, "Alzati", _close_bed)

func handle_input(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return false
	var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
	if CABIN.has_point(point) and available("cabin"):
		world.mouse_mining = false
		var screen: Vector2 = world.get_viewport().get_screen_transform() * event.position
		for index in range(1, popup.item_count):
			popup.set_item_disabled(index, world.campaign == null)
		popup.popup(Rect2i(Vector2i(screen), Vector2i(310, 175)))
		return true
	if BEDROOM.has_point(point) and available("bedroom"):
		open_bed()
		return true
	return false

func open_bed() -> void:
	if not available("bedroom"):
		return
	world.mouse_mining = false
	resting = false
	world.guide_event("bed_inspected")
	bed_window.popup_centered(Vector2i(440, 300))
	_refresh()

func _cabin_action(id: int) -> void:
	popup.hide()
	if not available("cabin") or world.campaign == null:
		return
	if id == 2:
		world.campaign.request_takeoff.call_deferred()
	else:
		world.campaign.open_ship_menu()
		if id == 1:
			var modules: Array = world.campaign.Modules.all()
			for index in range(modules.size()):
				if modules[index].module_id == "battery":
					world.campaign.module_picker.select(index)
					world.campaign._refresh_ship_menu()

func _close_bed() -> void:
	resting = false
	bed_window.hide()

func _refresh() -> void:
	status.text = "Energia personale: %.0f / 100\nIntegrita tuta: %.0f / 100\n\n%s" % [world.crew_energy(), world.suit_integrity(), "Recupero in corso..." if resting else "Il riposo non ricarica la batteria della nave."]
	rest_button.disabled = resting or (world.crew_energy() >= 100 and world.suit_integrity() >= 100)

func _process(delta: float) -> void:
	if not bed_window.visible:
		return
	if not available("bedroom"):
		_close_bed()
		return
	if resting:
		world._set_crew_energy(world.crew_energy() + delta * 20)
		world._set_suit(world.suit_integrity() + delta * 20)
		world.outpost.advance(delta)
		if world.crew_energy() >= 100 and world.suit_integrity() >= 100:
			resting = false
	_refresh()
