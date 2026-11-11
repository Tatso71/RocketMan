extends GdUnitTestSuite

const PATH := "res://scripts/player/explorer_animation.gd"

func _model():
	assert_bool(ResourceLoader.exists(PATH)).is_true()
	return load(PATH).new() if ResourceLoader.exists(PATH) else null

func test_walk_is_distance_driven_and_idle_does_not_slide() -> void:
	var model = _model()
	if model == null: return
	model.advance(0.1, Vector2(190, 0), true, false, false)
	assert_str(model.state).is_equal("walk")
	assert_bool(model.pose().front_foot != model.pose().rear_foot).is_true()
	var cycle: float = model.cycle
	model.advance(0.2, Vector2.ZERO, true, false, false)
	assert_str(model.state).is_equal("idle")
	assert_float(model.cycle).is_equal(cycle)
	assert_float(model.pose().front_foot.y).is_equal(-1.0)

func test_ladders_reverse_cycle_and_hold_when_stopped() -> void:
	var model = _model()
	if model == null: return
	model.advance(0.1, Vector2(0, -150), false, true, false)
	assert_str(model.state).is_equal("climb_up")
	var cycle: float = model.cycle
	model.advance(0.1, Vector2.ZERO, false, true, false)
	assert_str(model.state).is_equal("climb_idle")
	assert_float(model.cycle).is_equal(cycle)
	model.advance(0.1, Vector2(0, 150), false, true, false)
	assert_str(model.state).is_equal("climb_down")
	assert_float(model.cycle).is_equal_approx(0.0, 0.0001)

func test_jump_jet_launch_and_sustained_flight_have_distinct_poses() -> void:
	var model = _model()
	if model == null: return
	model.advance(0.01, Vector2.ZERO, true, false, false)
	model.advance(0.01, Vector2(0, -330), false, false, false)
	assert_str(model.state).is_equal("jump")
	model.advance(0.01, Vector2(0, -100), false, false, true)
	assert_str(model.state).is_equal("jet_launch")
	var launch_foot: Vector2 = model.pose().front_foot
	model.advance(0.3, Vector2(0, -250), false, false, true)
	assert_str(model.state).is_equal("jetpack")
	assert_bool(launch_foot != model.pose().front_foot).is_true()
	model.advance(0.1, Vector2(0, 150), false, false, false)
	assert_str(model.state).is_equal("fall")

func test_landing_compresses_then_recovers_without_false_spawn_impacts() -> void:
	var model = _model()
	if model == null: return
	model.advance(0.01, Vector2.ZERO, true, false, false)
	assert_str(model.state).is_equal("idle")
	model.advance(0.1, Vector2(0, 500), false, false, false)
	model.advance(0.05, Vector2.ZERO, true, false, false)
	assert_str(model.state).is_equal("land")
	assert_float(model.pose().scale.y).is_less(1.0)
	model.advance(0.4, Vector2.ZERO, true, false, false)
	assert_str(model.state).is_equal("idle")
	assert_vector(model.pose().scale).is_equal(Vector2.ONE)
	model.reset()
	model.advance(0.01, Vector2.ZERO, true, false, false)
	assert_str(model.state).is_equal("idle")

func test_ladder_exit_does_not_trigger_a_landing_squash() -> void:
	var model = _model()
	if model == null: return
	model.advance(0.1, Vector2(0, 150), false, true, false)
	model.advance(0.01, Vector2.ZERO, true, false, false)
	assert_str(model.state).is_equal("idle")

func test_mining_recoil_can_retrigger_and_be_cleared() -> void:
	var model = _model()
	if model == null: return
	model.fire()
	assert_float(model.pose().recoil).is_greater(0.0)
	model.advance(0.1, Vector2.ZERO, true, false, false)
	var decayed: float = model.pose().recoil
	model.fire()
	assert_float(model.pose().recoil).is_greater(decayed)
	model.stop_firing()
	assert_float(model.pose().recoil).is_equal(0.0)
	model.fire()
	model.reset()
	assert_float(model.pose().recoil).is_equal(0.0)
