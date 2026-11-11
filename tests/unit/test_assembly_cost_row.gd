extends GdUnitTestSuite

const PATH := "res://scripts/ui/assembly_cost_row.gd"

func _row():
	assert_bool(ResourceLoader.exists(PATH)).is_true()
	if not ResourceLoader.exists(PATH): return null
	return auto_free(load(PATH).new())

func test_requirements_show_accessible_owned_before_needed() -> void:
	var row = _row()
	if row == null: return
	row.configure("laboratory", "Laboratorio", {"structural_component": 4, "electronic_component": 2})
	row.refresh({"structural_component": 2, "electronic_component": 0})
	assert_str(row.resource_labels.structural_component.text).is_equal("2 / 4")
	assert_str(row.resource_labels.electronic_component.text).is_equal("0 / 2")
	assert_bool(row.affordable).is_false()
	assert_bool(row.disabled).is_false()
	assert_bool(row.item_icon.texture != null).is_true()
	assert_bool(row.resource_icons.structural_component.texture != null).is_true()
	assert_bool(row.title.get_theme_color("font_color") == row.MISSING).is_true()

func test_sufficient_components_turn_the_row_green_without_changing_its_tracks() -> void:
	var row = _row()
	if row == null: return
	row.configure("pump", "Pompa acqua", {"structural_component": 2, "electronic_component": 2})
	row.refresh({})
	var minimum: Vector2 = row.custom_minimum_size
	row.refresh({"structural_component": 12, "electronic_component": 2})
	assert_bool(row.affordable).is_true()
	assert_bool(row.title.get_theme_color("font_color") == row.READY).is_true()
	assert_str(row.resource_labels.structural_component.text).is_equal("12 / 2")
	assert_vector(row.custom_minimum_size).is_equal(minimum)

func test_free_ladder_needs_no_fake_resource_and_stays_available() -> void:
	var row = _row()
	if row == null: return
	row.configure("ladder", "Scala", {})
	row.refresh({})
	assert_bool(row.affordable).is_true()
	assert_dict(row.resource_labels).is_empty()
	assert_str(row.free_label.text).is_equal("Gratis")
	assert_bool(row.disabled).is_false()
