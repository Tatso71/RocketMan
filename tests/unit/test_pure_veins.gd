extends GdUnitTestSuite

const Site = preload("res://scripts/systems/dig_site.gd")
const Layout = preload("res://scripts/data/hazard_layout.gd")
const Tools = preload("res://scripts/data/digital_tool_catalog.gd")
const OFFSETS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var previous_gas_pockets_enabled: bool

func before() -> void:
	previous_gas_pockets_enabled = Layout.gas_pockets_enabled

func after() -> void:
	Layout.gas_pockets_enabled = previous_gas_pockets_enabled

func test_each_ore_has_a_connected_irregular_solid_region() -> void:
	var site := Site.new()
	if not _has_api(site):
		return
	var groups := _groups(site)
	assert_int(groups.size()).is_equal(5)
	for kind: String in ["copper", "iron", "crystal", "silica", "cobalt"]:
		assert_bool(groups.has(kind)).is_true()
		if not groups.has(kind):
			continue
		var cells: Array = groups[kind]
		assert_int(cells.size()).is_greater_equal(6)
		assert_int(_connected(cells).size()).is_equal(cells.size())
		var low: Vector2i = cells[0]
		var high := low
		for cell: Vector2i in cells:
			low = low.min(cell)
			high = high.max(cell)
			assert_str(site.material(cell)).is_equal(kind)
			assert_bool(site.removed.has(cell)).is_false()
			assert_bool(site.indestructible(cell)).is_false()
			var description: Dictionary = site.call("pure_vein", cell)
			assert_str(description.get("kind", "")).is_equal(kind)
		assert_int(high.x - low.x).is_greater(1)
		assert_int(high.y - low.y).is_greater(1)
		assert_int(cells.size()).is_less((high.x - low.x + 1) * (high.y - low.y + 1))

func test_pure_blocks_need_ten_strength_and_keep_rich_yield_after_mining() -> void:
	var site := Site.new()
	if not _has_api(site):
		return
	for kind: String in _groups(site):
		var fresh := Site.new()
		var cell: Vector2i = _groups(fresh)[kind][0]
		var description: Dictionary = fresh.call("pure_vein", cell)
		assert_str(fresh.mine(cell, 100)).is_empty()
		assert_bool(fresh.damage.has(cell)).is_false()
		fresh.removed[cell + Vector2i.UP] = true
		var before := _materials(fresh)
		assert_int(fresh.call("mining_cost", cell)).is_equal(10)
		assert_int(fresh.call("mining_cost", cell)).is_greater(int(Site.COST[kind]))
		assert_str(fresh.mine(cell, 0)).is_empty()
		assert_str(fresh.mine(cell, -1)).is_empty()
		assert_bool(fresh.damage.has(cell)).is_false()
		for hit in range(9):
			assert_str(fresh.mine(cell)).is_empty()
			assert_str(fresh.material(cell)).is_equal(kind)
		assert_int(fresh.damage[cell]).is_equal(9)
		assert_str(fresh.mine(cell)).is_equal(kind)
		assert_bool(fresh.damage.has(cell)).is_false()
		assert_str(fresh.material(cell)).is_empty()
		assert_str(fresh.mine(cell, 100)).is_empty()
		assert_dict(fresh.call("pure_vein", cell)).is_equal(description)
		assert_int(fresh.call("ore_yield_amount", cell)).is_equal(12)
		for other: Vector2i in before:
			if other != cell:
				assert_str(fresh.material(other)).is_equal(before[other])

func test_mining_strength_accumulates_without_changing_tool_material_gates() -> void:
	var site := Site.new()
	if not _has_api(site):
		return
	for kind: String in _groups(site):
		var cell: Vector2i = _groups(site)[kind][0]
		var tool: Resource = Tools.find("resonator" if kind == "cobalt" else "pulse")
		assert_bool(kind in tool.materials).is_true()
		assert_bool(kind in Tools.find("pulse").materials).is_equal(kind != "cobalt")
		site.removed[cell + Vector2i.UP] = true
		var spent := 0
		while spent + tool.power < 10:
			assert_str(site.mine(cell, tool.power)).is_empty()
			spent += tool.power
		assert_str(site.mine(cell, tool.power)).is_equal(kind)
		assert_int(site.call("ore_yield_amount", cell)).is_equal(12)

func test_whole_vein_is_finite_and_stays_excavated_after_json_restore() -> void:
	var site := Site.new()
	if not _has_api(site):
		return
	var cells: Array = _groups(site)["crystal"]
	var remaining := cells.duplicate()
	var first: Vector2i = cells[0]
	site.removed[first + Vector2i.UP] = true
	var mined := 0
	while not remaining.is_empty():
		var progressed := false
		for cell: Vector2i in remaining.duplicate():
			if not site.exposed(cell):
				continue
			assert_str(site.mine(cell, 10)).is_equal("crystal")
			mined += 1
			remaining.erase(cell)
			progressed = true
		assert_bool(progressed).is_true()
		if not progressed:
			return
	assert_int(mined).is_equal(cells.size())
	var loaded := Site.new()
	loaded.restore(JSON.parse_string(JSON.stringify(site.snapshot())))
	for cell: Vector2i in cells:
		assert_str(loaded.material(cell)).is_empty()
		assert_str(loaded.mine(cell, 100)).is_empty()
		assert_int(loaded.call("ore_yield_amount", cell)).is_equal(12)
		assert_dict(loaded.call("pure_vein", cell)).is_equal(site.call("pure_vein", cell))

func test_ordinary_starter_and_deeper_deposits_keep_original_cost_and_random_yield() -> void:
	var site := Site.new()
	if not _has_api(site):
		return
	var fixtures := [
		[Vector2i(1, 0), "soil", 1], [Vector2i(0, 5), "stone", 2],
		[Vector2i(-4, 1), "copper", 2], [Vector2i(-3, 2), "iron", 2],
		[Vector2i(-5, 2), "crystal", 3], [Vector2i(-5, 3), "crystal", 3],
		[Vector2i(-4, 4), "crystal", 3], [Vector2i(1, 3), "crystal", 3],
		[Vector2i(6, 10), "silica", 2], [Vector2i(-2, 12), "cobalt", 4],
		[Vector2i(0, 15), "bedrock", 99], [Vector2i(-18, 7), "anchor", 0]
	]
	for fixture: Array in fixtures:
		var cell: Vector2i = fixture[0]
		assert_str(site.material(cell)).is_equal(fixture[1])
		assert_dict(site.call("pure_vein", cell)).is_empty()
		assert_int(site.call("mining_cost", cell)).is_equal(fixture[2])
		assert_int(site.call("ore_yield_amount", cell)).is_equal(0)
	for cell in [Vector2i(-4, 1), Vector2i(-3, 2), Vector2i(-5, 2)]:
		var kind: String = site.material(cell)
		site.removed[cell + Vector2i.UP] = true
		assert_str(site.mine(cell, int(Site.COST[kind]) - 1)).is_empty()
		assert_str(site.mine(cell)).is_equal(kind)
		assert_int(site.call("ore_yield_amount", cell)).is_equal(0)

func test_hazard_cavities_and_protected_formations_never_become_pure_ore() -> void:
	for gas_enabled in [false, true]:
		Layout.gas_pockets_enabled = gas_enabled
		for seed_value in [0, 1, 2, 11, -17, 2147483647]:
			var site := Site.new(seed_value)
			if not _has_api(site):
				return
			for pocket: Dictionary in site.pockets():
				for cell: Vector2i in Layout.cells(pocket):
					assert_str(site.material(cell)).is_empty()
					assert_dict(site.call("pure_vein", cell)).is_empty()
					assert_int(site.call("mining_cost", cell)).is_equal(0)
					assert_int(site.call("ore_yield_amount", cell)).is_equal(0)
			for cell: Vector2i in _materials(site):
				if site.indestructible(cell):
					assert_str(site.material(cell)).is_equal("anchor")
					assert_dict(site.call("pure_vein", cell)).is_empty()
					assert_str(site.mine(cell, 1000000, true)).is_empty()

func test_seeded_maps_are_deterministic_connected_and_survive_restore() -> void:
	for seed_value in [0, 1, 2, 11, -17, 2147483647]:
		var site := Site.new(seed_value)
		if not _has_api(site):
			return
		var other := Site.new(seed_value)
		var groups := _groups(site)
		assert_int(groups.size()).is_equal(5)
		assert_dict(_groups(other)).is_equal(groups)
		other.restore([])
		assert_dict(_groups(other)).is_equal(groups)
		for kind: String in groups:
			var cells: Array = groups[kind]
			assert_int(_connected(cells).size()).is_equal(cells.size())
			for cell: Vector2i in cells:
				assert_str(site.material(cell)).is_equal(kind)
				assert_int(site.call("mining_cost", cell)).is_equal(10)
				assert_int(site.call("ore_yield_amount", cell)).is_equal(12)
				assert_dict(site.call("pure_vein", cell)).is_equal(other.call("pure_vein", cell))

func test_outside_cells_are_not_veins_and_descriptions_cannot_mutate_the_map() -> void:
	var site := Site.new()
	if not _has_api(site):
		return
	for cell in [Vector2i(-25, 0), Vector2i(24, 5), Vector2i(0, -1), Vector2i(0, 24)]:
		assert_dict(site.call("pure_vein", cell)).is_empty()
		assert_int(site.call("mining_cost", cell)).is_equal(0)
		assert_int(site.call("ore_yield_amount", cell)).is_equal(0)
	var cell: Vector2i = _groups(site)["copper"][0]
	var description: Dictionary = site.call("pure_vein", cell)
	description.kind = "cobalt"
	assert_str(site.material(cell)).is_equal("copper")
	assert_str(site.call("pure_vein", cell).get("kind", "")).is_equal("copper")

func _has_api(site: RefCounted) -> bool:
	var present := true
	for method: String in ["pure_vein", "mining_cost", "ore_yield_amount"]:
		assert_bool(site.has_method(method)).is_true()
		present = present and site.has_method(method)
	return present

func _groups(site: RefCounted) -> Dictionary:
	var groups := {}
	for cell: Vector2i in _materials(site):
		var vein: Dictionary = site.call("pure_vein", cell)
		if not vein.is_empty():
			if not groups.has(vein.kind):
				groups[vein.kind] = []
			groups[vein.kind].append(cell)
	return groups

func _materials(site: RefCounted) -> Dictionary:
	var result := {}
	for y in range(Site.DEPTH):
		for x in range(Site.LEFT, Site.RIGHT):
			var cell := Vector2i(x, y)
			result[cell] = site.material(cell)
	return result

func _connected(cells: Array) -> Array:
	var visited := [cells[0]]
	var cursor := 0
	while cursor < visited.size():
		var cell: Vector2i = visited[cursor]
		cursor += 1
		for offset: Vector2i in OFFSETS:
			var neighbor := cell + offset
			if neighbor in cells and neighbor not in visited:
				visited.append(neighbor)
	return visited
