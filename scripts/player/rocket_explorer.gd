extends CharacterBody2D

const Grid = preload("res://scripts/world/world_grid.gd")
var world: Node2D
var facing := 1.0
var climbing := false
var walk_time := 0.0

func _ready() -> void:
	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = Grid.metres(Grid.PLAYER_WIDTH_METRES) * 0.5
	capsule.height = Grid.metres(Grid.PLAYER_HEIGHT_METRES)
	collider.shape = capsule
	collider.position.y = -capsule.height * 0.5
	add_child(collider)

func _physics_process(delta: float) -> void:
	if world.controls_blocked():
		return
	var horizontal := Input.get_axis("move_left", "move_right")
	var vertical := Input.get_axis("climb_up", "climb_down")
	var environment: Dictionary = world.player_environment()
	var wet: bool = environment.wet
	var speed_factor := 0.55 if wet else 1.0
	climbing = world.on_ladder(position) and (absf(vertical) > 0.1 or climbing or not is_on_floor())
	if climbing:
		velocity = Vector2(horizontal * 145, vertical * 150) * speed_factor
		if Input.is_action_just_pressed("jump"):
			climbing = false
	else:
		velocity.x = horizontal * 190 * speed_factor
		velocity.y = minf(velocity.y + (260 if wet else 900) * delta, 140 if wet else 650)
		if wet and vertical < -0.1:
			velocity.y = -100
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -330
	if horizontal != 0:
		facing = signf(horizontal)
	move_and_slide()
	walk_time += delta * absf(velocity.x) * 0.06
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * 1.35)
	var step := sin(walk_time) * 3 if is_on_floor() else 0.0
	draw_rect(Rect2(-14, -29, 9, 20), Color("485c66"))
	draw_rect(Rect2(-9, -23, 18, 18), Color("e9a43e"))
	draw_rect(Rect2(-8, -7, 6, 7 + step), Color("273d48"))
	draw_rect(Rect2(3, -7, 6, 7 - step), Color("273d48"))
	draw_circle(Vector2(0, -31), 13, Color("f7c45c"))
	draw_circle(Vector2(facing * 2, -31), 9, Color("25495c"))
	draw_circle(Vector2(facing * 4, -33), 3, Color("8de2e5"))
	draw_circle(Vector2(0, -43), 4, Color("fff3bf"))
	draw_line(Vector2(facing * 8, -20), Vector2(facing * 18, -22), Color("f7c45c"), 6)
	draw_colored_polygon(PackedVector2Array([Vector2(facing * 15, -29), Vector2(facing * 31, -29), Vector2(facing * 34, -25), Vector2(facing * 31, -20), Vector2(facing * 15, -20)]), Color("526e79"))
	draw_line(Vector2(facing * 22, -24), Vector2(facing * 34, -25), world.active_tool().beam_color, 3)
