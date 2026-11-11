extends GdUnitTestSuite

const Terrain = preload("res://scripts/ui/terrain_renderer.gd")

class WaterWorld extends Node2D:
	var site := preload("res://scripts/systems/dig_site.gd").new()
	var environment := preload("res://scripts/systems/environment_field.gd").new(site)

func test_sealed_water_is_visible_without_releasing_or_draining_it() -> void:
	var world: Node2D = auto_free(WaterWorld.new())
	var before: Dictionary = world.environment.water.duplicate()
	var concealed := Terrain.hidden_pockets(world)
	for pocket: Dictionary in world.site.pockets():
		for cell: Vector2i in world.site.HazardLayout.cells(pocket):
			assert_bool(concealed.has(cell)).is_equal(pocket.kind != "water")
	assert_dict(world.environment.water).is_equal(before)
	assert_dict(world.environment.released).is_empty()
	assert_str(world.site.material(Vector2i(2, 3))).is_not_empty()

func test_irregular_water_mask_retains_rock_in_the_corners() -> void:
	var world: Node2D = auto_free(WaterWorld.new())
	var pocket: Dictionary = world.site.pockets().filter(func(p: Dictionary): return p.id == "water_deep")[0]
	assert_bool(world.environment.water.has(pocket.origin)).is_false()
	assert_str(world.site.material(pocket.origin)).is_not_empty()
	assert_bool(world.environment.water.has(pocket.origin + Vector2i(2, 0))).is_true()
	assert_str(world.site.material(pocket.origin + Vector2i(2, 0))).is_empty()

func test_animated_bubbles_remain_inside_actual_liquid_volume() -> void:
	var view: Node2D = auto_free(load("res://scripts/ui/reservoir_view.gd").new())
	assert_bool(view.has_method("bubble_marks")).is_true()
	if not view.has_method("bubble_marks"):
		return
	for height: float in [9, 20, 40]:
		var rect := Rect2(120, 200 + 40 - height, 40, height)
		var first: Array = view.call("bubble_marks", Vector2i(3, 5), rect, 0.0)
		assert_int(first.size()).is_greater(0)
		assert_bool(first == view.call("bubble_marks", Vector2i(3, 5), rect, 0.7)).is_false()
		for mark: Dictionary in first:
			assert_bool(rect.encloses(Rect2(mark.position - Vector2.ONE * mark.radius, Vector2.ONE * mark.radius * 2))).is_true()
	assert_array(view.call("bubble_marks", Vector2i(3, 5), Rect2(120, 239, 40, 1), 0.0)).is_empty()
