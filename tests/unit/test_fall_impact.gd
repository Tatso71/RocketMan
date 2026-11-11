extends GdUnitTestSuite

const Explorer = preload("res://scripts/player/rocket_explorer.gd")

func test_normal_jump_and_braked_landings_are_safe_but_hard_impacts_scale() -> void:
	var explorer: CharacterBody2D = auto_free(Explorer.new())
	assert_bool(explorer.has_method("impact_energy_loss")).is_true()
	if not explorer.has_method("impact_energy_loss"):
		return
	for speed: float in [-330, 0, 140, 330, 440]:
		assert_float(explorer.call("impact_energy_loss", speed)).is_equal(0.0)
	var moderate: float = explorer.call("impact_energy_loss", 500)
	var hard: float = explorer.call("impact_energy_loss", 650)
	assert_float(moderate).is_greater(0)
	assert_float(hard).is_greater(moderate)
	assert_float(hard).is_less_equal(50)
	assert_float(explorer.call("impact_energy_loss", 10000)).is_equal(50.0)
