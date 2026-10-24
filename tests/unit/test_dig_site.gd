extends GdUnitTestSuite

const DigSite = preload("res://scripts/systems/dig_site.gd")

func test_starter_shaft_and_room_are_air() -> void:
	var site := DigSite.new()
	assert_str(site.material(Vector2i(0, 0))).is_empty()
	assert_str(site.material(Vector2i(-5, 3))).is_empty()
	assert_bool(site.contains(Vector2i(-25, 0))).is_false()
	assert_str(site.material(Vector2i(24, 0))).is_empty()

func test_exposed_soil_is_removed_once() -> void:
	var site := DigSite.new()
	var cell := Vector2i(1, 0)
	assert_str(site.mine(cell)).is_equal("soil")
	assert_str(site.material(cell)).is_empty()
	assert_str(site.mine(cell)).is_empty()

func test_cannot_mine_buried_cells_or_bedrock() -> void:
	var site := DigSite.new()
	assert_str(site.mine(Vector2i(10, 8), 100)).is_empty()
	assert_str(site.material(Vector2i(10, 8))).is_not_empty()
	site.removed[Vector2i(0, 14)] = true
	assert_bool(site.exposed(Vector2i(0, 15))).is_true()
	assert_str(site.mine(Vector2i(0, 15), 100)).is_empty()
	assert_str(site.material(Vector2i(0, 15))).is_equal("bedrock")

func test_ore_needs_multiple_hits_and_credits_only_on_completion() -> void:
	var site := DigSite.new()
	var cell := Vector2i(0, 4)
	var kind := site.material(cell)
	assert_str(kind).is_equal("copper")
	assert_str(site.mine(cell)).is_empty()
	assert_int(site.damage[cell]).is_equal(1)
	assert_str(site.mine(cell)).is_equal("copper")
	assert_bool(site.damage.has(cell)).is_false()

func test_snapshot_survives_json_roundtrip_and_rejects_invalid_cells() -> void:
	var site := DigSite.new()
	site.mine(Vector2i(1, 0))
	var data: Array = JSON.parse_string(JSON.stringify(site.snapshot()))
	data.append([1000, 1000])
	data.append(["bad", 0])
	data.append([0])
	data.append([2.5, 0])
	var restored := DigSite.new()
	restored.restore(data)
	assert_str(restored.material(Vector2i(1, 0))).is_empty()
	assert_int(restored.removed.size()).is_equal(site.removed.size())

func test_protected_rock_requires_explicit_compatible_tool() -> void:
	var site := DigSite.new()
	site.removed[Vector2i(0, 14)] = true
	assert_str(site.mine(Vector2i(0, 15), 100)).is_empty()
	assert_str(site.mine(Vector2i(0, 15), 50, true)).is_empty()
	assert_str(site.mine(Vector2i(0, 15), 50, true)).is_equal("bedrock")
	assert_str(site.RESOURCE_YIELDS["bedrock"]).is_equal("stone")
