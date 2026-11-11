extends GdUnitTestSuite

const PATH := "res://scripts/systems/lamp_power_network.gd"

func entry(id: String, x: int, y: int = 0, reach: float = 8.0) -> Dictionary:
	return {"building": {"id": id, "origin": Vector2i(x, y)}, "point": Vector2(x, y) * 40, "reach": reach * 40}

func test_rooted_chain_extends_beyond_lab_without_inventing_energy() -> void:
	assert_bool(ResourceLoader.exists(PATH)).is_true()
	if not ResourceLoader.exists(PATH): return
	var network = load(PATH)
	var root := entry("laboratory", 0)
	var first := entry("lamp", 7)
	var second := entry("lamp", 14)
	var third := entry("lamp", 21)
	var relays := [first, second, third]
	var routes: Dictionary = network.resolve([root], relays)
	assert_int(routes.size()).is_equal(3)
	assert_bool(routes[Vector2i(14, 0)].parent == first.building).is_true()
	assert_bool(routes[Vector2i(21, 0)].lab == root.building).is_true()
	assert_int(routes[Vector2i(21, 0)].hops).is_equal(3)
	assert_dict(network.resolve([], relays)).is_empty()

func test_gaps_cycles_and_unfinished_targets_do_not_create_sources() -> void:
	if not ResourceLoader.exists(PATH): return
	var network = load(PATH)
	var root := entry("laboratory", 0)
	var relays := [entry("lamp", 7), entry("lamp", 16), entry("lamp", 20)]
	var routes: Dictionary = network.resolve([root], relays)
	assert_int(routes.size()).is_equal(1)
	assert_dict(network.connection(entry("lamp", 24), [root], relays, routes)).is_empty()
	var target := entry("lamp", 14)
	var connection: Dictionary = network.connection(target, [root], relays, routes)
	assert_bool(connection.parent == relays[0].building).is_true()
	assert_int(routes.size()).is_equal(1)
	assert_dict(network.connection(entry("lamp", 23), [root], relays, routes)).is_empty()

func test_direct_nearest_lab_and_relay_hops_have_deterministic_parents() -> void:
	if not ResourceLoader.exists(PATH): return
	var network = load(PATH)
	var roots := [entry("laboratory", 0), entry("laboratory", 10)]
	var relays := [entry("lamp", 7), entry("lamp", 15), entry("lamp", 22)]
	var routes: Dictionary = network.resolve(roots, relays)
	assert_bool(routes[Vector2i(7, 0)].lab == roots[1].building).is_true()
	assert_bool(routes[Vector2i(15, 0)].parent == roots[1].building).is_true()
	assert_bool(routes[Vector2i(22, 0)].parent == relays[1].building).is_true()
	assert_int(routes[Vector2i(22, 0)].hops).is_equal(2)

func test_link_boundaries_are_metric_and_lab_upgrades_only_extend_the_root() -> void:
	if not ResourceLoader.exists(PATH): return
	var network = load(PATH)
	var root := entry("laboratory", 0, 0, 10)
	var relays := [entry("lamp", 10), entry("lamp", 18), entry("lamp", 27)]
	var routes: Dictionary = network.resolve([root], relays)
	assert_int(routes.size()).is_equal(2)
	assert_bool(routes.has(Vector2i(18, 0))).is_true()
	assert_bool(routes.has(Vector2i(27, 0))).is_false()

func test_alternate_branch_reconnects_without_duplicating_source_ownership() -> void:
	if not ResourceLoader.exists(PATH): return
	var network = load(PATH)
	var root := entry("laboratory", 0)
	var first := entry("lamp", 7)
	var broken := entry("lamp", 14)
	var alternate := entry("lamp", 14, 1)
	var end := entry("lamp", 21)
	var routes: Dictionary = network.resolve([root], [first, broken, alternate, end])
	assert_bool(routes[end.building.origin].parent == broken.building).is_true()
	var repaired_route: Dictionary = network.resolve([root], [first, alternate, end])
	assert_bool(repaired_route[end.building.origin].parent == alternate.building).is_true()
	assert_bool(repaired_route[end.building.origin].lab == root.building).is_true()
	assert_int(repaired_route[end.building.origin].hops).is_equal(3)
