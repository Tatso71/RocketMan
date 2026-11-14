extends GdUnitTestSuite

const REGISTRY := "res://scripts/data/item_icon_catalog.gd"
const Tools = preload("res://scripts/data/digital_tool_catalog.gd")

func test_solar_panel_and_its_repair_share_a_registered_structure_icon() -> void:
	var icons = load(REGISTRY)
	assert_str(icons.path("solar_panel")).is_equal("res://assets/ui/items/solar_panel.svg")
	assert_bool(FileAccess.file_exists(icons.path("solar_panel"))).is_true()
	assert_str(icons.path("repaired_solar_panel")).is_equal(icons.path("solar_panel"))

func test_every_production_node_and_tool_has_an_icon() -> void:
	assert_bool(FileAccess.file_exists(REGISTRY)).is_true()
	if not FileAccess.file_exists(REGISTRY):
		return
	var icons = load(REGISTRY)
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://design/generated/production-map.json"))
	for id: String in map.nodes:
		assert_bool(FileAccess.file_exists(icons.path(id))).is_true()
		assert_str("res://" + map.nodes[id].icon).is_equal(icons.path(id))
	for tool: Resource in Tools.all():
		assert_bool(FileAccess.file_exists(icons.path(tool.tool_id))).is_true()

func test_unknown_ids_are_not_misrepresented_and_aliases_share_identity() -> void:
	if not FileAccess.file_exists(REGISTRY):
		return
	var icons = load(REGISTRY)
	assert_str(icons.path("not_an_item")).is_empty()
	assert_str(icons.path("module_drone_3")).is_equal(icons.path("module_drone"))
	assert_str(icons.path("repaired_laboratory")).is_equal(icons.path("laboratory"))
	assert_str(icons.path("seed_potato")).is_not_equal(icons.path("potato"))
	assert_str(icons.path("gas_conduit")).is_not_equal(icons.path("water_conduit"))
