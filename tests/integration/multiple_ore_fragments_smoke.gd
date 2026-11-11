extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
var failures := 0
var world: Node2D
const CELL := Vector2i(-4, 1)
const YieldPopup = preload("res://scripts/ui/mining_yield_popup.gd")

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1

func _initialize() -> void:
	run.call_deferred()

func pieces() -> Array:
	return world.gear.get_children().filter(func(child): return child is CharacterBody2D and not child.is_queued_for_deletion())

func badges() -> Array:
	return world.gear.get_children().filter(func(child): return child is YieldPopup and not child.is_queued_for_deletion())

func step(count: int) -> void:
	for i in range(count):
		await physics_frame
		world.gear.advance(1.0 / 60)

func same_drops(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		var a: Dictionary = left[index]
		var b: Dictionary = right[index]
		if a.cell != b.cell or a.material != b.material or a.amount != b.amount or a.extra_pieces.size() != b.extra_pieces.size():
			return false
		var first: Array = [a] + a.extra_pieces
		var second: Array = [b] + b.extra_pieces
		for piece in range(first.size()):
			for key: String in ["position", "velocity"]:
				var v: Array = first[piece][key]
				var w: Array = second[piece][key]
				if Vector2(v[0], v[1]).distance_to(Vector2(w[0], w[1])) > 0.0001:
					return false
	return true

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.gear.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	Fixture.lab_room(world)
	world.player.position = Vector2(-100, 160)
	world.field_cargo.drone = {"copper": world.field_cargo.drone_capacity}
	check(world.gear.has_method("spawn_ore"), "mining has a shared ore spawning API")
	if not world.gear.has_method("spawn_ore"):
		quit(1)
		return
	for material in ["soil", "stone", "bedrock", ""]:
		world.gear.spawn_ore(CELL, material)
	check(world.gear.drops.is_empty() and pieces().is_empty(), "common terrain never creates cargo or bodies")
	check(badges().is_empty(), "common rock never shows a multiplier")
	var chosen_seed := 0
	for value in range(1000):
		seed(value)
		if randi_range(0, 99) >= 90:
			chosen_seed = value
			break
	seed(chosen_seed)
	world.gear.spawn_ore(CELL, "copper")
	check(pieces().size() == 3, "three-unit yield creates three physical bodies immediately")
	check(badges().size() == 1 and badges()[0].label.text == "x3", "three-unit yield shows one readable x3 at the broken block")
	world.gear.spawn_ore(CELL, "copper")
	check(pieces().size() == 3, "repeating spawn on an outstanding cell cannot duplicate ore")
	check(badges().size() == 1, "duplicate spawn cannot repeat multiplier feedback")
	for y in range(1, 4):
		for x in range(-12, 1): Fixture.carve(world, Vector2i(x, y))
	await physics_frame
	var spawned := pieces()
	var original_positions: Array = spawned.map(func(body): return body.position)
	spawned[0].position = Vector2(-420, 140)
	spawned[1].position = Vector2(-60, 140)
	spawned[2].position = Vector2(-380, 140)
	world.player.position = Vector2(20, 160)
	world.drone.position = Vector2(-200, 140)
	world.field_cargo.drone.clear()
	world.drone._rebuild()
	world.drone.has_resting_goal = false
	check(world.drone.follow_goal().distance_to(Vector2(-60, 140)) < 1 and not world.drone.has_resting_goal, "Robbie seeks a nearby extra piece even when the primary is beyond seeking range")
	for index in range(spawned.size()): spawned[index].position = original_positions[index]
	world.field_cargo.drone = {"copper": world.field_cargo.drone_capacity}
	world.player.position = Vector2(-100, 160)
	await step(100)
	var fallen := pieces()
	check(fallen.size() == 3 and fallen.all(func(body): return body.position.y > 90 and body.position.y < 160 and body.bounce_count > 0), "each independent piece falls and bounces on the native floor")
	check(fallen.size() == 3 and fallen[0].position.distance_to(fallen[1].position) > 1, "pieces separate physically")
	for index in range(fallen.size()):
		fallen[index].velocity = Vector2(17 + index * 9, -23 - index * 11)
	var saved: Dictionary = world.capture_state()
	var before: Dictionary = saved.gear.duplicate(true)
	check(world.restore_state(JSON.parse_string(JSON.stringify(saved))), "all pieces roundtrip through a real world JSON save")
	check(same_drops(world.gear.snapshot().drops, before.drops), "save preserves every remaining quantity, position and velocity")
	await physics_frame
	check(pieces().size() == 3, "restore leaves no duplicate or orphan bodies")
	var invalid := saved.duplicate(true)
	invalid.gear.drops[0].extra_pieces[0].position = [99999, 0]
	var cargo_before: Dictionary = world.field_cargo.snapshot()
	var live_before: Dictionary = world.gear.snapshot()
	check(not world.restore_state(invalid), "invalid extra piece rejects whole save")
	world.gear.restore(invalid.gear, true)
	check(world.gear.snapshot() == live_before and world.field_cargo.snapshot() == cargo_before and pieces().size() == 3, "invalid restore is atomic even when called directly")
	world.field_cargo.drone.copper -= 1
	world.player.position = Vector2(20, -320)
	world.drone.position = Vector2(-100, 140)
	world.drone.mission = "follow"
	var original_primary: CharacterBody2D = world.gear.fragments[CELL]
	var primary_id := original_primary.get_instance_id()
	original_primary.position = world.drone.position + Vector2(-8, 0)
	original_primary.velocity = Vector2.ZERO
	await step(150)
	check(world.field_cargo.drone.copper == world.field_cargo.drone_capacity and pieces().size() == 2, "one cargo slot collects exactly one piece and leaves two")
	check(world.gear.drops.has(CELL) and world.gear.fragments[CELL].get_instance_id() != primary_id and world.gear.snapshot().drops[0].amount == 2, "cell interface promotes a remaining primary without losing its quantity")
	var partial: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(partial))), "partially collected group can be saved and restored")
	await step(30)
	check(pieces().size() == 2 and world.field_cargo.drone.copper == world.field_cargo.drone_capacity, "full cargo preserves restored leftovers")
	world.field_cargo.drone.clear()
	world.drone.position = world.gear.fragment_position(CELL) + Vector2(20, -10)
	await step(150)
	check(world.field_cargo.drone.get("copper", 0) == 2 and world.gear.drops.is_empty() and pieces().is_empty(), "magnet collects each leftover exactly once")
	await step(30)
	check(world.field_cargo.drone.get("copper", 0) == 2, "no ore respawns after collection")
	world.field_cargo.drone = {"copper": world.field_cargo.drone_capacity}
	world.gear.drops[CELL] = "iron"
	await step(1)
	check(pieces().size() == 1 and world.gear.snapshot().drops[0].amount == 1, "direct drops assignments still default to one piece")
	world.gear.drops.clear()
	await step(2)
	check(pieces().is_empty(), "external drop removal cleans up every physical piece")
	# Leave one actual ore block in the blast; all other affected cells are empty.
	var bomb_cell := Vector2i(-4, 3)
	var ore_cell := Vector2i(-4, 4)
	for y in range(1, 6):
		for x in range(-6, -1):
			var cell := Vector2i(x, y)
			if cell != ore_cell:
				Fixture.carve(world, cell)
	var ore: String = world.site.material(ore_cell)
	check(not world.site.resource_yield(ore).is_empty(), "blast fixture contains a valuable ore block")
	seed(chosen_seed)
	world.gear._explode({"cell": bomb_cell, "number": 1, "body": world._body(Grid.rect(bomb_cell), world.gear)})
	var blast_amount: int = world.gear.drop_amounts.get(ore_cell, 0)
	check(world.gear.drops.get(ore_cell, "") == ore and blast_amount in [2, 3] and pieces().size() == blast_amount, "bomb mining uses the same random multi-piece spawn API")
	world.gear.drops.clear()
	await step(2)
	check(pieces().is_empty() and world.gear.drop_amounts.is_empty() and world.gear.extra_fragments.is_empty(), "clearing a multi-piece drop cleans all group state and bodies")
	print("MULTIPLE ORE FRAGMENTS: %d failures" % failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
