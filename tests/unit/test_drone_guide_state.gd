extends GdUnitTestSuite

const Guide = preload("res://scripts/systems/drone_guide_state.gd")
const Ship = preload("res://scripts/systems/ship_state.gd")

func test_tutorial_insists_until_its_condition_is_completed() -> void:
	var guide := Guide.new()
	guide.tick(2, "tutorial_collect")
	assert_bool(guide.offer("tutorial_collect")).is_true()
	guide.tick(25, "tutorial_collect")
	guide.tick(3, "tutorial_collect")
	assert_bool(guide.offer("tutorial_collect")).is_true()
	guide.tick(1, "tutorial_place")
	assert_str(guide.active_id).is_empty()
	guide.tick(3, "tutorial_place")
	assert_bool(guide.offer("tutorial_place")).is_true()

func test_once_only_and_manual_recall() -> void:
	var guide := Guide.new()
	guide.tick(2, "welcome")
	assert_bool(guide.offer("welcome")).is_true()
	guide.tick(25, "welcome")
	guide.tick(3, "welcome")
	assert_bool(guide.offer("welcome")).is_false()
	assert_bool(guide.offer("welcome", true)).is_true()

func test_mute_blocks_automatic_but_not_requested_help() -> void:
	var guide := Guide.new()
	guide.set_muted(true)
	guide.tick(3, "cargo_full")
	assert_bool(guide.offer("cargo_full")).is_false()
	assert_bool(guide.offer("cargo_full", true)).is_true()
	assert_str(guide.active_id).is_equal("cargo_full")

func test_danger_preempts_tutorial_and_stale_conditions_disappear() -> void:
	var guide := Guide.new()
	guide.tick(2, "welcome")
	guide.offer("welcome")
	assert_bool(guide.offer("gas_danger")).is_true()
	assert_str(guide.active_id).is_equal("gas_danger")
	guide.tick(0.1, "welcome")
	assert_str(guide.active_id).is_empty()

func test_urgent_warning_is_not_lost_during_reading_gap() -> void:
	var guide := Guide.new()
	assert_bool(guide.offer("gas_leak")).is_true()
	assert_str(guide.active_id).is_equal("gas_leak")

func test_full_cargo_does_not_repeat_until_condition_clears() -> void:
	var guide := Guide.new()
	guide.tick(2, "cargo_full")
	guide.offer("cargo_full")
	guide.tick(60, "cargo_full")
	guide.tick(3, "cargo_full")
	assert_bool(guide.offer("cargo_full")).is_false()
	guide.tick(3, "welcome")
	guide.tick(3, "cargo_full")
	assert_bool(guide.offer("cargo_full")).is_true()

func test_restore_is_atomic_and_accepts_legacy_empty_state() -> void:
	var guide := Guide.new()
	guide.offer("lab_plan", true)
	guide.facts.mined = true
	guide.set_muted(true)
	var saved := guide.snapshot()
	var restored := Guide.new()
	assert_bool(restored.restore(saved)).is_true()
	assert_dict(restored.snapshot()).is_equal(saved)
	assert_bool(restored.restore({"seen": ["not_a_message"]})).is_false()
	assert_dict(restored.snapshot()).is_equal(saved)
	assert_bool(restored.restore({"facts": {"mined": "true"}})).is_false()
	assert_bool(restored.restore({})).is_true()

func test_campaign_owns_guide_progress_and_preserves_reference() -> void:
	var ship := Ship.new()
	ship.drone_guide.facts.lab_built = true
	ship.drone_guide.offer("lab_built", true)
	ship.drone_guide.set_muted(true)
	var restored := Ship.new()
	var reference: RefCounted = restored.drone_guide
	assert_bool(restored.restore(ship.snapshot())).is_true()
	assert_bool(reference == restored.drone_guide).is_true()
	assert_dict(restored.drone_guide.snapshot()).is_equal(ship.drone_guide.snapshot())
