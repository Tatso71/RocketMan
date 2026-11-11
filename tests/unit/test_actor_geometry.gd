extends GdUnitTestSuite

const Explorer = preload("res://scripts/player/rocket_explorer.gd")

class ActorWorld extends Node2D:
	var robot := false
	func is_robbie() -> bool: return robot

func test_metric_body_and_center_match_the_selected_protagonist() -> void:
	var world: Node2D = auto_free(ActorWorld.new())
	var actor: CharacterBody2D = auto_free(Explorer.new())
	actor.world = world
	assert_bool(actor.has_method("body_size")).is_true()
	if not actor.has_method("body_size"): return
	actor.position = Vector2(100, 200)
	assert_vector(actor.body_size()).is_equal(Vector2(24, 64))
	assert_vector(actor.body_center()).is_equal(Vector2(100, 168))
	assert_bool(actor.body_rect_at(actor.position) == Rect2(88, 136, 24, 64)).is_true()
	world.robot = true
	assert_vector(actor.body_size()).is_equal(Vector2(20, 32))
	assert_vector(actor.body_center()).is_equal(Vector2(100, 184))
	assert_bool(actor.body_rect_at(actor.position) == Rect2(90, 168, 20, 32)).is_true()
