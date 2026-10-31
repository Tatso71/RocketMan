extends CharacterBody2D

const Grid = preload("res://scripts/world/world_grid.gd")
var world: Node2D
var facing := 1.0
var climbing := false
var walk_time := 0.0
var suppress_jet_until_release := false
var jump_was_held := false

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
		jump_was_held = Input.is_action_pressed("jump")
		return
	var horizontal := Input.get_axis("move_left", "move_right")
	var jump_held := Input.is_action_pressed("jump")
	var jump_pressed := jump_held and not jump_was_held
	jump_was_held = jump_held
	if not jump_held:
		suppress_jet_until_release = false
	if jump_pressed and world.outpost.use_cube():
		jump_pressed = false
		suppress_jet_until_release = true
	var vertical := Input.get_axis("climb_up", "climb_down")
	var environment: Dictionary = world.player_environment()
	var wet: bool = environment.wet
	var speed_factor := 0.55 if wet else 1.0
	if absf(horizontal) > 0.1 or absf(vertical) > 0.1:
		world._set_crew_energy(world.crew_energy() - delta * (0.8 if absf(vertical) > 0.1 else 0.4))
	if world.crew_energy() <= 0:
		speed_factor *= 0.65
	climbing = world.on_ladder(position) and (absf(vertical) > 0.1 or climbing or not is_on_floor())
	if suppress_jet_until_release:
		world.gear.flying = false
	if not suppress_jet_until_release and world.gear.thrust(delta):
		climbing = false
		velocity.x = horizontal * 190 * speed_factor
		velocity.y = move_toward(velocity.y, -180, 700 * delta)
	elif climbing:
		velocity = Vector2(horizontal * 145, vertical * 150) * speed_factor
		if jump_pressed:
			climbing = false
	else:
		velocity.x = horizontal * 190 * speed_factor
		velocity.y = minf(velocity.y + (260 if wet else 900) * delta, 140 if wet else 650)
		if wet and vertical < -0.1:
			velocity.y = -100
	if jump_pressed and is_on_floor() and not world.gear.flying:
		velocity.y = -330
	if horizontal != 0:
		facing = signf(horizontal)
	move_and_slide()
	walk_time += delta * absf(velocity.x) * 0.06
	queue_redraw()

func _draw() -> void:
	if world.is_robbie():
		_draw_robbie()
		return
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
	if not world.outpost.fabrication.carried().is_empty():
		return
	draw_colored_polygon(PackedVector2Array([Vector2(facing * 15, -29), Vector2(facing * 31, -29), Vector2(facing * 34, -25), Vector2(facing * 31, -20), Vector2(facing * 15, -20)]), Color("526e79"))
	draw_line(Vector2(facing * 22, -24), Vector2(facing * 34, -25), world.active_tool().beam_color, 3)

func _draw_robbie() -> void:
	var bob := sin(Time.get_ticks_msec() * 0.004) * 1.5
	var center := Vector2(0, -32 + bob)
	var ink := Color("78e4dc") if world.suit_integrity() > 25 else Color("ff7774")
	draw_line(center + Vector2(-17, -17), center + Vector2(-17, -27), Color("799198"), 3)
	draw_circle(center + Vector2(-17, -28), 3, ink)
	draw_rect(Rect2(center + Vector2(-23, -13), Vector2(46, 30)), Color("dce7df"))
	draw_rect(Rect2(center + Vector2(-17, -8), Vector2(34, 17)), Color("294b5a"))
	draw_circle(center + Vector2(facing * 3, 0), 6, ink)
	draw_circle(center + Vector2(facing * 5, -2), 2, Color("defbf1"))
	draw_line(center + Vector2(-29, -17), center + Vector2(-10, -17), Color("d9b25b"), 4)
	draw_line(center + Vector2(10, -17), center + Vector2(29, -17), Color("d9b25b"), 4)
	draw_rect(Rect2(center + Vector2(-11, 17), Vector2(22, 9)), Color("70888c"))
	var flame := 10.0 if world.gear.flying else 4.0
	draw_colored_polygon(PackedVector2Array([center + Vector2(-7, 26), center + Vector2(7, 26), center + Vector2(0, 26 + flame)]), Color(ink, 0.65))
	if world.outpost.fabrication.carried().is_empty():
		draw_line(center + Vector2(facing * 20, 7), center + Vector2(facing * 40, 0), Color("77939a"), 5)
		draw_line(center + Vector2(facing * 34, 2), center + Vector2(facing * 46, -2), world.active_tool().beam_color, 3)
