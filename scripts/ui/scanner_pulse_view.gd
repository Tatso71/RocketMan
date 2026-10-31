extends Node2D

const Grid = preload("res://scripts/world/world_grid.gd")
const INTERVAL_SECONDS := 0.65
const DURATION_SECONDS := 1.8
var world: Node2D
var pulses: Array[Dictionary] = []
var emission_timer := 0.0

func _ready() -> void:
	z_index = 7

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_instance_valid(world.player) or world.active_tool().mode != "scan" or world.controls_blocked() or not world.outpost.fabrication.carried().is_empty():
		pulses.clear()
		emission_timer = 0
		queue_redraw()
		return
	for pulse: Dictionary in pulses:
		pulse.age += delta
	pulses = pulses.filter(func(pulse: Dictionary): return pulse.age < DURATION_SECONDS)
	# Bound catch-up after a stalled frame: expired emissions never need drawing.
	emission_timer = maxf(emission_timer - delta, -DURATION_SECONDS)
	while emission_timer <= 0:
		var tool: Resource = world.active_tool()
		if -emission_timer < DURATION_SECONDS:
			pulses.append({"origin": world.player.position - Vector2(0, 32), "age": -emission_timer, "max_radius": Grid.metres(tool.effective_reach_metres()), "color": tool.beam_color})
		emission_timer += INTERVAL_SECONDS
	queue_redraw()

static func radius_at(age: float, max_radius: float) -> float:
	return max_radius * clampf(age / DURATION_SECONDS, 0, 1)

static func alpha_at(age: float) -> float:
	var progress := clampf(age / DURATION_SECONDS, 0, 1)
	return 0.65 * smoothstep(0, 0.08, progress) * (1.0 - smoothstep(0.25, 1, progress))

func _draw() -> void:
	for pulse: Dictionary in pulses:
		var radius := radius_at(pulse.age, pulse.max_radius)
		var alpha := alpha_at(pulse.age)
		if radius < 1 or alpha <= 0:
			continue
		var segments := clampi(ceili(radius * 0.7), 48, 160)
		draw_arc(pulse.origin, radius, 0, TAU, segments, Color(pulse.color, alpha * 0.16), 7, true)
		draw_arc(pulse.origin, radius, 0, TAU, segments, Color(pulse.color, alpha), 1.6, true)
