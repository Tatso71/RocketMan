extends GdUnitTestSuite

const PATH := "res://scripts/ui/vitals_meters.gd"

func test_energy_and_suit_are_thin_distinct_meters_with_percentages() -> void:
	assert_bool(ResourceLoader.exists(PATH)).is_true()
	if not ResourceLoader.exists(PATH): return
	var meters: Control = auto_free(load(PATH).new())
	meters.update_values(13, 89)
	assert_float(meters.energy_bar.value).is_equal(13.0)
	assert_float(meters.suit_bar.value).is_equal(89.0)
	assert_str(meters.energy_value.text).is_equal("13%")
	assert_str(meters.suit_value.text).is_equal("89%")
	assert_bool(meters.energy_bar.get_theme_stylebox("fill").bg_color == meters.ENERGY_COLOR).is_true()
	assert_bool(meters.suit_bar.get_theme_stylebox("fill").bg_color == meters.SUIT_COLOR).is_true()
	assert_bool(meters.ENERGY_COLOR != meters.SUIT_COLOR).is_true()
	for bar: ProgressBar in [meters.energy_bar, meters.suit_bar]:
		assert_float(bar.custom_minimum_size.y).is_between(3.0, 5.0)
		assert_bool(bar.show_percentage).is_false()
		assert_int(bar.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

func test_variant_labels_and_values_update_without_changing_color_identity() -> void:
	if not ResourceLoader.exists(PATH):
		assert_bool(false).is_true()
		return
	var meters: Control = auto_free(load(PATH).new())
	meters.update_values(120, -5, true)
	assert_float(meters.energy_bar.value).is_equal(100.0)
	assert_float(meters.suit_bar.value).is_equal(0.0)
	assert_str(meters.energy_title.text).is_equal("Carica")
	assert_str(meters.suit_title.text).is_equal("Scocca")
	meters.update_values(50, 100, false)
	assert_str(meters.energy_title.text).is_equal("Energia")
	assert_str(meters.suit_title.text).is_equal("Tuta")
	assert_str(meters.energy_value.text).is_equal("50%")
	assert_str(meters.suit_value.text).is_equal("100%")
