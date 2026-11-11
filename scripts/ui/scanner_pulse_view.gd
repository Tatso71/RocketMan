extends Node2D

const Grid = preload("res://scripts/world/world_grid.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const Fluids = preload("res://scripts/data/fluid_catalog.gd")
const ItemIcons = preload("res://scripts/data/item_icon_catalog.gd")
const INTERVAL_SECONDS := 0.65
const DURATION_SECONDS := 1.8
const ICON_SIZE := Vector2(28, 28)
const UNKNOWN_COLOR := Color(0.8, 0.8, 0.8)
static var _unknown_texture: Texture2D
var world: Node2D
var pulses: Array[Dictionary] = []
var emission_timer := 0.0
var revealed: Dictionary = {}
var clock := 0.0

static func material_identity(kind: String, names: Dictionary = {}) -> Dictionary:
	if not Cargo.COLORS.has(kind) and not Fluids.KINDS.has(kind) and kind not in ["anchor", "bedrock"]:
		return {}
	var title: String = names.get(kind, Cargo.NAMES.get(kind, kind.capitalize()))
	var color: Color = Cargo.COLORS.get(kind, Color("d1dae0"))
	var detail := "Estrazione: Pulse"
	if Fluids.KINDS.has(kind):
		title = names.get(kind, Fluids.KINDS[kind].name)
		color = Fluids.KINDS[kind].edge
		detail = "Fluido / serbatoio"
	elif kind == "anchor":
		title = "Indistruttibile"
		color = Color("f2ac87")
		detail = "Aggirare: nessuno strumento"
	elif kind == "bedrock":
		title = names.get(kind, "Roccia compatta")
		detail = "Richiede Plasma"
	elif kind == "cobalt":
		detail = "Richiede Risonatore / Plasma"
	return {"name": title, "detail": detail, "color": color, "icon": ItemIcons.path(kind), "kind": kind}

func aimed_identity(cell: Vector2i) -> Dictionary:
	if reveal_strength(cell) <= 0 or not is_instance_valid(world) or not is_instance_valid(world.player):
		return {}
	var tool: Resource = world.active_tool()
	var origin: Vector2 = world.player_center()
	if origin.distance_to(Grid.center(cell)) > Grid.metres(tool.identification_reach_metres()):
		return {}
	var kind: String = revealed[cell].kind
	if kind == "cobalt" and tool.scanner_level < 3:
		return {}
	return material_identity(kind, world.MATERIAL_NAMES)

static func _generic_texture() -> Texture2D:
	if _unknown_texture == null:
		# Convert once: a gray tint alone would preserve the catalog icon's hues.
		var image := ItemIcons.texture("scanner").get_image()
		image.convert(Image.FORMAT_RGBA8)
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var pixel := image.get_pixel(x, y)
				var gray := pixel.get_luminance()
				image.set_pixel(x, y, Color(gray, gray, gray, pixel.a))
		_unknown_texture = ImageTexture.create_from_image(image)
	return _unknown_texture

func cell_marker(cell: Vector2i) -> Dictionary:
	var strength := reveal_strength(cell)
	if strength <= 0:
		return {}
	var identity := aimed_identity(cell)
	var identified := not identity.is_empty()
	var marker := {
		"rect": Rect2(Grid.center(cell) - ICON_SIZE * 0.5, ICON_SIZE),
		"texture": ItemIcons.texture(identity.kind) if identified else _generic_texture(),
		"color": Color(Color.WHITE if identified else UNKNOWN_COLOR, strength),
		"identified": identified}
	if identified:
		marker.border_rect = Grid.rect(cell).grow(-1)
		marker.border_color = Color(identity.color, strength)
	return marker

func reveal_strength(cell: Vector2i) -> float:
	if is_instance_valid(world) and (world.active_tool().mode != "scan" or world.controls_blocked()):
		return 0.0
	if not revealed.has(cell):
		return 0.0
	var entry: Dictionary = revealed[cell]
	return clampf((float(entry.until) - clock) / float(entry.duration), 0, 1)

func _ready() -> void:
	z_index = 7
	process_priority = 100

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	clock += delta
	for cell: Vector2i in revealed.keys():
		if reveal_strength(cell) <= 0:
			revealed.erase(cell)
	if not is_instance_valid(world.player) or world.active_tool().mode != "scan" or world.controls_blocked() or not world.outpost.fabrication.carried().is_empty():
		pulses.clear()
		revealed.clear()
		emission_timer = 0
		queue_redraw()
		return
	for pulse: Dictionary in pulses:
		pulse.age += delta
	# Bound catch-up after a stalled frame: expired emissions never need drawing.
	emission_timer = maxf(emission_timer - delta, -DURATION_SECONDS)
	while emission_timer <= 0:
		var tool: Resource = world.active_tool()
		if -emission_timer < DURATION_SECONDS:
			pulses.append({"origin": world.player_center(), "age": -emission_timer, "max_radius": Grid.metres(tool.effective_reach_metres()), "color": tool.beam_color, "duration": 2.0 + (tool.scanner_level - 1) * 0.7})
		emission_timer += INTERVAL_SECONDS
	var hidden: Dictionary = world.TerrainRenderer.hidden_pockets(world)
	for pulse: Dictionary in pulses:
		var radius := radius_at(pulse.age, pulse.max_radius)
		var reached: float = pulse.get("reached", -1.0)
		for y in range(maxi(0, floori((pulse.origin.y - radius) / 40)), mini(world.site.DEPTH, ceili((pulse.origin.y + radius) / 40))):
			for x in range(maxi(world.site.LEFT, floori((pulse.origin.x - radius) / 40)), mini(world.site.RIGHT, ceili((pulse.origin.x + radius) / 40))):
				var cell := Vector2i(x, y)
				var distance := Grid.center(cell).distance_to(pulse.origin)
				if distance > radius or distance <= reached:
					continue
				var kind: String = hidden.get(cell, world.site.material(cell))
				if kind.is_empty():
					for fluid: String in ["water", "gas", "oil", "acid"]:
						if float(world.environment.get(fluid).get(cell, 0)) > 0.03:
							kind = fluid
				if kind not in ["copper", "iron", "crystal", "silica", "cobalt", "anchor", "bedrock", "water", "gas", "oil", "acid"]:
					continue
				var duration: float = pulse.get("duration", 2.0)
				var expires: float = clock - float(pulse.age) + distance / float(pulse.max_radius) * DURATION_SECONDS + duration
				if expires > clock and expires > float(revealed.get(cell, {}).get("until", 0)):
					revealed[cell] = {"kind": kind, "until": expires, "duration": duration}
				world.scanned[cell] = kind
		pulse.reached = radius
	pulses = pulses.filter(func(pulse: Dictionary): return pulse.age < DURATION_SECONDS)
	queue_redraw()

static func radius_at(age: float, max_radius: float) -> float:
	return max_radius * clampf(age / DURATION_SECONDS, 0, 1)

static func alpha_at(age: float) -> float:
	var progress := clampf(age / DURATION_SECONDS, 0, 1)
	return 0.65 * smoothstep(0, 0.08, progress) * (1.0 - smoothstep(0.25, 1, progress))

func _draw() -> void:
	if world.active_tool().mode != "scan" or world.controls_blocked():
		return
	for cell: Vector2i in revealed:
		var marker := cell_marker(cell)
		if not marker.is_empty():
			if marker.identified:
				draw_rect(marker.border_rect, marker.border_color, false, 1.5, true)
			draw_texture_rect(marker.texture, marker.rect, false, marker.color)
	for pulse: Dictionary in pulses:
		var radius := radius_at(pulse.age, pulse.max_radius)
		var alpha := alpha_at(pulse.age)
		if radius < 1 or alpha <= 0:
			continue
		var segments := clampi(ceili(radius * 0.7), 48, 160)
		draw_arc(pulse.origin, radius, 0, TAU, segments, Color(pulse.color, alpha * 0.16), 7, true)
		draw_arc(pulse.origin, radius, 0, TAU, segments, Color(pulse.color, alpha), 1.6, true)
