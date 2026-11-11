extends CharacterBody2D

const Grid = preload("res://scripts/world/world_grid.gd")
const ExplorerAnimation = preload("res://scripts/player/explorer_animation.gd")
var animation := ExplorerAnimation.new()
var world: Node2D
var facing := 1.0
var climbing := false
var suppress_jet_until_release := false
var jump_was_held := false

func _ready() -> void:
	# Actors are not terrain: flying companions and ore must not hit the suit.
	collision_layer = 2
	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = Grid.metres(Grid.PLAYER_WIDTH_METRES) * 0.5
	capsule.height = Grid.metres(Grid.PLAYER_HEIGHT_METRES)
	collider.shape = capsule
	collider.position.y = -capsule.height * 0.5
	add_child(collider)

func _physics_process(delta: float) -> void:
	if world.controls_blocked():
		animation.stop_firing()
		queue_redraw()
		jump_was_held = Input.is_action_pressed("jump")
		return
	var horizontal := Input.get_axis("move_left", "move_right")
	var jump_held := Input.is_action_pressed("jump")
	var jump_pressed := jump_held and not jump_was_held
	jump_was_held = jump_held
	if not jump_held:
		suppress_jet_until_release = false
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
		velocity.y = move_toward(velocity.y, -world.gear.jetpack_thrust_speed(), 700 * world.gear.thrust_multiplier * delta)
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
	world.gear.observe_ground_contact(is_on_floor(), wet, climbing)
	animation.advance(delta, velocity, is_on_floor(), climbing, world.gear.flying)
	queue_redraw()

func mining_pulse() -> void:
	animation.fire()
	queue_redraw()

func reset_animation() -> void:
	animation.reset()
	queue_redraw()

func _firing() -> bool:
	return world.beam_time > 0 and world.active_tool().mode == "mine"

func _visual_transform() -> Transform2D:
	var pose := animation.pose()
	return Transform2D(pose.lean, Vector2.ZERO).scaled_local(pose.scale * Vector2(facing, 1) * 1.35)

func _weapon_transform() -> Transform2D:
	var pose := animation.pose()
	var shoulder := Vector2(7, -20 + pose.bob)
	var angle := 0.25 if animation.state == "walk" else 0.08
	if _firing():
		var target: Vector2 = _visual_transform().affine_inverse() * (world.beam_target - position)
		angle = (target - shoulder).angle() + 0.14
	angle -= pose.recoil * 0.08
	return Transform2D(angle, shoulder - Vector2(pose.recoil * 3, 0))

func beam_origin() -> Vector2:
	if world.is_robbie():
		return position + _robot_center() + Vector2(facing * 46, -2)
	return position + _visual_transform() * (_weapon_transform() * Vector2(26, -5))

func _draw() -> void:
	if world.is_robbie():
		_draw_robbie()
		return
	var pose := animation.pose()
	var body := _visual_transform()
	var weapon := _weapon_transform()
	var rear_hand: Vector2 = weapon * Vector2(18, -2) if _firing() else pose.rear_hand
	draw_set_transform_matrix(body)
	_draw_leg(Vector2(-5, -9), pose.rear_foot, Color("314954"))
	_draw_arm(Vector2(-7, -21 + pose.bob), rear_hand, Color("ba873b"))
	draw_rect(Rect2(-14, -29 + pose.bob, 9, 20), Color("485c66"))
	draw_rect(Rect2(-9, -23 + pose.bob, 18, 15), Color("e9a43e"))
	draw_line(Vector2(-8, -10 + pose.bob), Vector2(8, -10 + pose.bob), Color("f7c45c"), 3)
	_draw_leg(Vector2(5, -9), pose.front_foot, Color("273d48"))
	draw_circle(Vector2(0, -31 + pose.bob), 13, Color("f7c45c"))
	draw_circle(Vector2(2, -31 + pose.bob), 9, Color("25495c"))
	draw_circle(Vector2(4, -33 + pose.bob), 3, Color("8de2e5"))
	draw_circle(Vector2(0, -43 + pose.bob), 4, Color("fff3bf"))
	var show_weapon := not animation.state.begins_with("climb") or _firing()
	if not show_weapon or not world.outpost.fabrication.carried().is_empty():
		_draw_arm(Vector2(7, -21 + pose.bob), pose.front_hand, Color("f7c45c"))
		return
	var grip := weapon * Vector2(12, -2)
	_draw_arm(Vector2(7, -21 + pose.bob), grip, Color("f7c45c"))
	draw_set_transform_matrix(body * weapon)
	draw_colored_polygon(PackedVector2Array([Vector2(7, -9), Vector2(23, -9), Vector2(26, -5), Vector2(23, 0), Vector2(7, 0)]), Color("526e79"))
	draw_line(Vector2(14, -4), Vector2(26, -5), world.active_tool().beam_color, 3)
	if _firing():
		draw_circle(Vector2(26, -5), 2 + pose.recoil * 2, Color(world.active_tool().beam_color, 0.8))

func _draw_leg(hip: Vector2, foot: Vector2, ink: Color) -> void:
	var knee := hip.lerp(foot, 0.5) + Vector2(3, -1)
	draw_line(hip, knee, ink, 6, true)
	draw_line(knee, foot, ink, 5, true)
	draw_line(foot - Vector2(2, 0), foot + Vector2(4, 0), Color("1d333e"), 3, true)

func _draw_arm(shoulder: Vector2, hand: Vector2, ink: Color) -> void:
	var elbow := shoulder.lerp(hand, 0.5) + Vector2(-2, 3)
	draw_line(shoulder, elbow, ink, 5, true)
	draw_line(elbow, hand, ink, 5, true)
	draw_circle(hand, 2.7, Color("485c66"))

func _robot_center() -> Vector2:
	var pose := animation.pose()
	return Vector2(-facing * pose.recoil * 2, -32 + sin(animation.clock * 4) * 1.5 + (1 - pose.scale.y) * 24)

func _draw_robbie() -> void:
	var center := _robot_center()
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
