extends GdUnitTestSuite

const Terrain = preload("res://scripts/ui/terrain_renderer.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Scanner = preload("res://scripts/ui/scanner_pulse_view.gd")

func test_world_uvs_are_continuous_deterministic_and_not_cell_periodic() -> void:
	for layer in range(4):
		var point := Vector2(-80, 200)
		assert_bool(Terrain.surface_uv(point, 11, layer) == Terrain.surface_uv(point, 11, layer)).is_true()
		assert_bool(Terrain.surface_uv(point, 11, layer).distance_to(Terrain.surface_uv(point + Vector2(40, 0), 11, layer)) > 0.01).is_true()
		assert_bool(Terrain.surface_uv(point - Vector2(0.001, 0), 11, layer).distance_to(Terrain.surface_uv(point + Vector2(0.001, 0), 11, layer)) < 0.001).is_true()

func test_recorded_findings_validate_coordinates_types_and_duplicates() -> void:
	var site := Site.new()
	assert_bool(site.valid_scan_findings([{"cell": [0, 1], "kind": "iron"}, {"cell": [3, 3], "kind": "water"}])).is_true()
	for invalid in [[{"cell": [0.5, 1], "kind": "iron"}], [{"cell": [0, 1], "kind": "unknown"}], [{"cell": [0, 99], "kind": "iron"}], [{"cell": [0, 1], "kind": "iron"}, {"cell": [0, 1], "kind": "water"}]]:
		assert_bool(site.valid_scan_findings(invalid)).is_false()

func test_transient_scanner_strength_fades_without_erasing_knowledge() -> void:
	var view: Node2D = auto_free(Scanner.new())
	var cell := Vector2i(1, 3)
	view.revealed[cell] = {"kind": "crystal", "until": 2.0, "duration": 2.0}
	assert_float(view.reveal_strength(cell)).is_equal(1.0)
	view.clock = 1.0
	assert_float(view.reveal_strength(cell)).is_equal(0.5)
	view.clock = 3.0
	assert_float(view.reveal_strength(cell)).is_equal(0.0)
