extends PanelContainer

const Grid = preload("res://scripts/world/world_grid.gd")
var world: Node2D
var message: Label
var cell := Vector2i.ZERO
var remaining := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = 300
	var style := StyleBoxFlat.new()
	style.bg_color = Color("222b2ef2")
	style.border_color = Color("e88980")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, 10)
	add_theme_stylebox_override("panel", style)
	message = Label.new()
	message.custom_minimum_size.x = 280
	message.size.x = 280
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 16)
	message.add_theme_color_override("font_color", Color("ffd0c8"))
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message)
	hide()

func show_reason(target: Vector2i, reason: String) -> void:
	cell = target
	message.text = reason
	remaining = 2.8
	modulate.a = 1.0
	size = Vector2(300, message.get_minimum_size().y + 20)
	show()
	_reposition()

func clear() -> void:
	remaining = 0
	hide()

func _reposition() -> void:
	size.y = get_minimum_size().y
	var screen: Vector2 = world.get_global_transform_with_canvas() * Grid.center(cell)
	var bounds: Vector2 = world.get_viewport_rect().size
	var reserved: Array[Rect2] = []
	for panel: Control in [world.outpost.cargo_ui.compact, world.tutorial_ui.panel, world.guide.bubble, world.vitals_meters, world.hazard_label, world.drone_label, world.power_label]:
		if panel.is_visible_in_tree(): reserved.append(panel.get_global_rect().grow(8))
	reserved.append(world.get_global_transform_with_canvas() * world.player.body_rect_at(world.player.position).grow(8))
	var best := INF
	var nearest := INF
	var candidates: Array[Vector2] = []
	for offset: Vector2 in [Vector2(18, -size.y - 18), Vector2(-size.x - 18, -size.y - 18), Vector2(18, 18), Vector2(-size.x - 18, 18), Vector2(-size.x / 2, -size.y - 50)]:
		candidates.append(screen + offset)
	for occupied: Rect2 in reserved:
		candidates.append(Vector2(occupied.end.x + 12, screen.y - size.y / 2))
		candidates.append(Vector2(occupied.position.x - size.x - 12, screen.y - size.y / 2))
		candidates.append(Vector2(screen.x - size.x / 2, occupied.end.y + 12))
		candidates.append(Vector2(screen.x - size.x / 2, occupied.position.y - size.y - 12))
	for point: Vector2 in candidates:
		var candidate := point.clamp(Vector2(12, 104), bounds - size - Vector2(12, 104))
		var rect := Rect2(candidate, size)
		var overlap := 0.0
		for occupied: Rect2 in reserved:
			if rect.intersects(occupied): overlap += rect.intersection(occupied).get_area()
		var distance := rect.get_center().distance_squared_to(screen)
		if overlap < best or (is_equal_approx(overlap, best) and distance < nearest):
			position = candidate
			best = overlap
			nearest = distance

func _process(delta: float) -> void:
	if not visible: return
	if world.controls_blocked():
		clear()
		return
	remaining = maxf(0, remaining - delta)
	if remaining <= 0:
		clear()
		return
	modulate.a = minf(1, remaining / 0.35)
	_reposition()
