extends CharacterBody2D

var ore_id := "copper"
var age := 0.0
var bounce_count := 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4
	collider.shape = shape
	add_child(collider)

func advance(delta: float, target: Variant = null) -> void:
	age += delta
	if not target is Vector2:
		velocity.y = minf(360, velocity.y + 600 * delta)
	if target is Vector2:
		velocity = velocity.move_toward((target - position).normalized() * 230, 850 * delta)
	var hit := move_and_collide(velocity * delta)
	if hit != null:
		if velocity.length() > 35:
			bounce_count += 1
		velocity = velocity.bounce(hit.get_normal()) * 0.38
		if hit.get_normal().y < -0.5:
			velocity.x *= 0.7
	queue_redraw()

func _draw() -> void:
	var ink: Color = preload("res://scripts/systems/field_cargo.gd").COLORS[ore_id]
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -2), Vector2(-1, -5), Vector2(5, -2), Vector2(3, 4), Vector2(-3, 5)]), ink)
	draw_line(Vector2(-2, -2), Vector2(2, -3), ink.lightened(0.4), 2)
