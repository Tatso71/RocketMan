extends GdUnitTestSuite

const Site = preload("res://scripts/systems/dig_site.gd")
const Tools = preload("res://scripts/data/digital_tool_catalog.gd")

func test_only_useful_ores_have_a_cargo_yield() -> void:
	var site := Site.new()
	assert_bool(site.has_method("resource_yield")).is_true()
	if not site.has_method("resource_yield"):
		return
	for kind: String in ["soil", "stone", "bedrock"]:
		assert_str(site.resource_yield(kind)).is_empty()
	for kind: String in ["iron", "copper", "crystal", "silica", "cobalt"]:
		assert_str(site.resource_yield(kind)).is_equal(kind)

func test_starter_materials_are_mineable_before_unlocking_a_lab() -> void:
	var site := Site.new()
	var found := {"iron": 0, "copper": 0, "crystal": 0}
	for y in range(1, 6):
		for x in range(-5, 3):
			var kind: String = site.material(Vector2i(x, y))
			if found.has(kind):
				found[kind] += 1
	assert_int(found.iron).is_greater_equal(8)
	assert_int(found.copper).is_greater_equal(3)
	assert_int(found.crystal).is_greater_equal(1)
	for kind: String in found:
		assert_bool(kind in Tools.find("pulse").materials).is_true()
