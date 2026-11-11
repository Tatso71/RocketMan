extends GdUnitTestSuite

const Gear = preload("res://scripts/prototype/expedition_gear.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")

func test_all_percentile_rolls_have_exact_yields() -> void:
	var gear: Node2D = auto_free(Gear.new())
	assert_bool(gear.has_method("yield_for_roll")).is_true()
	if not gear.has_method("yield_for_roll"):
		return
	var counts := [0, 0, 0]
	for roll in range(100):
		var expected := 1 if roll < 65 else (2 if roll < 90 else 3)
		var amount: int = gear.call("yield_for_roll", roll)
		assert_int(amount).is_equal(expected)
		counts[amount - 1] += 1
	assert_array(counts).contains_exactly([65, 25, 10])

func test_multi_piece_save_validates_amount_and_every_body() -> void:
	var site := Site.new()
	site.removed[Vector2i(-4, 1)] = true
	var buildings := Buildings.new()
	var entry := {"cell": [-4, 1], "material": "copper", "amount": 3,
		"position": [-140, 60], "velocity": [10, -20], "extra_pieces": [
			{"position": [-138, 62], "velocity": [-15, 30]},
			{"position": [-142, 58], "velocity": [20, -40]}]}
	assert_bool(Gear.valid({"drops": [entry]}, site, buildings)).is_true()
	assert_bool(Gear.valid(JSON.parse_string(JSON.stringify({"drops": [entry]})), site, buildings)).is_true()
	for amount in [0, 4, -1, 1.5, "3", true, null, INF, NAN]:
		var invalid := entry.duplicate(true)
		invalid.amount = amount
		assert_bool(Gear.valid({"drops": [invalid]}, site, buildings)).is_false()
	for count in [0, 1, 3]:
		var invalid := entry.duplicate(true)
		invalid.extra_pieces.resize(count)
		assert_bool(Gear.valid({"drops": [invalid]}, site, buildings)).is_false()
	for point in [[99999, 60], [-140, -441], [INF, 60], [NAN, 60], [0, 800], [1], "bad"]:
		var invalid := entry.duplicate(true)
		invalid.extra_pieces[1].position = point
		assert_bool(Gear.valid({"drops": [invalid]}, site, buildings)).is_false()
	for motion in [[INF, 0], [0, NAN], [10001, 0], [1], "bad"]:
		var invalid := entry.duplicate(true)
		invalid.extra_pieces[0].velocity = motion
		assert_bool(Gear.valid({"drops": [invalid]}, site, buildings)).is_false()
	for field in ["position", "velocity"]:
		var invalid := entry.duplicate(true)
		invalid.extra_pieces[0].erase(field)
		assert_bool(Gear.valid({"drops": [invalid]}, site, buildings)).is_false()
	for material in ["soil", "stone"]:
		var invalid := entry.duplicate(true)
		invalid.material = material
		assert_bool(Gear.valid({"drops": [invalid]}, site, buildings)).is_false()
	assert_bool(Gear.valid({"drops": [entry, entry]}, site, buildings)).is_false()
	assert_bool(Gear.valid({"drops": [{"cell": [-4, 1], "material": "copper"}]}, site, buildings)).is_true()
