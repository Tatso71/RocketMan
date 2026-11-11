extends RefCounted

const LAND_DURATION := 0.24
const LAUNCH_DURATION := 0.22
const RECOIL_DURATION := 0.18

var state := "idle"
var cycle := 0.0
var clock := 0.0
var _initialized := false
var _grounded := true
var _climbing := false
var _jetting := false
var _previous_velocity := Vector2.ZERO
var _velocity := Vector2.ZERO
var _landing := 0.0
var _impact := 0.0
var _launch := 0.0
var _recoil := 0.0

func reset() -> void:
	state = "idle"
	cycle = 0.0
	clock = 0.0
	_initialized = false
	_grounded = true
	_climbing = false
	_jetting = false
	_previous_velocity = Vector2.ZERO
	_velocity = Vector2.ZERO
	_landing = 0.0
	_launch = 0.0
	_recoil = 0.0

func fire() -> void:
	_recoil = RECOIL_DURATION

func stop_firing() -> void:
	_recoil = 0.0

func advance(delta: float, motion: Vector2, grounded: bool, on_ladder: bool, jetting: bool) -> void:
	clock += delta
	_landing = maxf(0.0, _landing - delta)
	_launch = maxf(0.0, _launch - delta)
	_recoil = maxf(0.0, _recoil - delta)
	if jetting and not _jetting:
		_launch = LAUNCH_DURATION
	if _initialized and grounded and not _grounded and not on_ladder and not _climbing and _previous_velocity.y > 80:
		_landing = LAND_DURATION
		_impact = clampf(_previous_velocity.y / 500.0, 0.35, 1.0)
	if on_ladder:
		cycle += motion.y * delta * 0.055
		state = "climb_up" if motion.y < -1 else ("climb_down" if motion.y > 1 else "climb_idle")
	elif jetting:
		state = "jet_launch" if _launch > 0 else "jetpack"
	elif not grounded:
		state = "jump" if motion.y < -20 else "fall"
	elif _landing > 0:
		state = "land"
	elif absf(motion.x) > 5:
		state = "walk"
		cycle += absf(motion.x) * delta * 0.065
	else:
		state = "idle"
	_velocity = motion
	_previous_velocity = motion
	_grounded = grounded
	_climbing = on_ladder
	_jetting = jetting
	_initialized = true

func pose() -> Dictionary:
	var stride := sin(cycle)
	var front_foot := Vector2(5, -1)
	var rear_foot := Vector2(-5, -1)
	var front_hand := Vector2(15, -15)
	var rear_hand := Vector2(-9, -14)
	var body_scale := Vector2.ONE
	var bob := sin(clock * 2.5) * 0.45
	var lean := 0.0
	if state == "walk":
		front_foot += Vector2(stride * 7, -maxf(0, stride) * 5)
		rear_foot += Vector2(-stride * 7, -maxf(0, -stride) * 5)
		rear_hand.x -= stride * 7
		front_hand.x += stride * 7
		bob = -absf(stride) * 1.5
		lean = _velocity.x / 190.0 * 0.055
	elif state.begins_with("climb"):
		front_foot = Vector2(7, -8 + stride * 6)
		rear_foot = Vector2(-7, -8 - stride * 6)
		front_hand = Vector2(9, -32 - stride * 8)
		rear_hand = Vector2(-9, -32 + stride * 8)
		bob = 0
	elif state == "jump" or state == "jet_launch":
		front_foot = Vector2(10, -9)
		rear_foot = Vector2(-8, -5)
		body_scale = Vector2(0.97, 1.04)
		bob = -1
	elif state == "jetpack":
		front_foot = Vector2(8, -4 + sin(clock * 9))
		rear_foot = Vector2(-6, -2 - sin(clock * 9))
		lean = _velocity.x / 190.0 * 0.12
	elif state == "fall":
		front_foot = Vector2(8, -1)
		rear_foot = Vector2(-7, -3)
		front_hand = Vector2(16, -22)
		rear_hand = Vector2(-16, -22)
	elif state == "land":
		var squash := sin((1.0 - _landing / LAND_DURATION) * PI) * _impact
		# Start the compression on the contact frame, then recover around the feet.
		squash = maxf(squash, _landing / LAND_DURATION * 0.45 * _impact)
		body_scale = Vector2(1 + squash * 0.13, 1 - squash * 0.16)
		front_foot.x = 8
		rear_foot.x = -8
		bob = 0
	return {"front_foot": front_foot, "rear_foot": rear_foot, "front_hand": front_hand, "rear_hand": rear_hand,
		"scale": body_scale, "bob": bob, "lean": lean, "recoil": pow(_recoil / RECOIL_DURATION, 2)}
