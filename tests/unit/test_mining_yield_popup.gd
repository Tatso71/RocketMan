extends GdUnitTestSuite

const PATH := "res://scripts/ui/mining_yield_popup.gd"

func test_bonus_badge_rises_fades_and_expires() -> void:
	assert_bool(ResourceLoader.exists(PATH)).is_true()
	if not ResourceLoader.exists(PATH):
		return
	var badge: Node2D = auto_free(load(PATH).new())
	badge.amount = 3
	badge.position = Vector2(100, 200)
	add_child(badge)
	badge.set_process(false)
	assert_str(badge.label.text).is_equal("x3")
	assert_bool(badge.label.mouse_filter == Control.MOUSE_FILTER_IGNORE).is_true()
	badge.advance(0.6)
	assert_float(badge.position.y).is_less(200)
	assert_float(badge.modulate.a).is_less(1)
	assert_float(badge.modulate.a).is_greater(0)
	badge.advance(1)
	assert_bool(badge.is_queued_for_deletion()).is_true()
