extends GdUnitTestSuite

const Tools = preload("res://scripts/data/digital_tool_catalog.gd")
const Pulses = preload("res://scripts/ui/scanner_pulse_view.gd")

func test_scanner_levels_match_the_design_ranges() -> void:
	var tool: Resource = Tools.find("scanner").duplicate()
	for level in range(1, 5):
		tool.scanner_level = level
		assert_float(tool.effective_reach_metres()).is_equal(3.0 + level)
	assert_float(Tools.find("scanner").effective_reach_metres()).is_equal(4.0)

func test_scanner_level_does_not_change_other_equipment() -> void:
	for definition: Resource in Tools.all():
		if definition.mode == "scan":
			continue
		var tool: Resource = definition.duplicate()
		tool.scanner_level = 4
		assert_float(tool.effective_reach_metres()).is_equal(tool.reach_metres)

func test_scanner_level_is_bounded_to_supported_levels() -> void:
	var tool: Resource = Tools.find("scanner").duplicate()
	tool.scanner_level = 0
	assert_float(tool.effective_reach_metres()).is_equal(4.0)
	tool.scanner_level = 99
	assert_float(tool.effective_reach_metres()).is_equal(7.0)

func test_radius_expands_monotonically_and_stops_at_maximum() -> void:
	for radius in [160.0, 200.0, 240.0, 280.0]:
		var previous := 0.0
		for step in range(21):
			var current := Pulses.radius_at(step * 0.1, radius)
			assert_bool(current >= previous and current <= radius).is_true()
			previous = current
		assert_float(Pulses.radius_at(Pulses.DURATION_SECONDS, radius)).is_equal(radius)
	assert_float(Pulses.radius_at(-1, 160)).is_equal(0.0)

func test_opacity_fades_to_zero_at_the_maximum_radius() -> void:
	assert_float(Pulses.alpha_at(0)).is_equal(0.0)
	assert_bool(Pulses.alpha_at(0.3) > 0.5).is_true()
	assert_bool(Pulses.alpha_at(0.8) > Pulses.alpha_at(1.3)).is_true()
	assert_bool(Pulses.alpha_at(1.3) > Pulses.alpha_at(1.7)).is_true()
	assert_float(Pulses.alpha_at(Pulses.DURATION_SECONDS)).is_equal(0.0)
	assert_float(Pulses.alpha_at(10)).is_equal(0.0)
