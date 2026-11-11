extends GdUnitTestSuite

const Site = preload("res://scripts/systems/dig_site.gd")
const Tools = preload("res://scripts/data/digital_tool_catalog.gd")
const AnimationModel = preload("res://scripts/player/explorer_animation.gd")

func test_left_hand_tutorial_route_has_crystal_without_crossing_a_reservoir() -> void:
	var site := Site.new()
	var crystals := 0
	for y in range(1, 5):
		for x in range(-5, 0):
			if site.material(Vector2i(x, y)) == "crystal":
				crystals += 1
	assert_int(crystals).is_greater_equal(3)
	assert_bool("crystal" in Tools.find("pulse").materials).is_true()
	for y in range(3):
		assert_str(site.material(Vector2i(0, y))).is_not_empty()

func test_falling_relaxes_arms_and_bends_the_legs() -> void:
	var model := AnimationModel.new()
	model.advance(0.1, Vector2(0, 350), false, false, false)
	var pose := model.pose()
	assert_str(model.state).is_equal("fall")
	assert_float(pose.front_hand.y).is_greater(-20.0)
	assert_float(pose.rear_hand.y).is_greater(-20.0)
	assert_float(pose.front_foot.y).is_less(-2.0)
