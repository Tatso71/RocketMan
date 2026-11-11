extends Node2D

const LIFETIME := 1.1
var amount := 2
var label: Label
var age := 0.0
var origin := Vector2.ZERO

func _ready() -> void:
	origin = position
	label = Label.new()
	label.text = "x%d" % amount
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("fff1b2"))
	label.add_theme_color_override("font_outline_color", Color("152127"))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(-22, -25)
	label.size = Vector2(44, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	age += delta
	position = origin + Vector2(0, -28 * minf(age / LIFETIME, 1))
	modulate.a = 1 - smoothstep(0.35, LIFETIME, age)
	if age >= LIFETIME:
		queue_free()
