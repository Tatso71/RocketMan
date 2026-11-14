extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0
var target := Vector2i(-12, 4)

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func rock(cell: Vector2i) -> void:
	world.site.removed.erase(cell)
	if not world.blocks.has(cell):
		world.blocks[cell] = world._body(world.Grid.rect(cell), world.terrain)

func setup_case(turn: int) -> void:
	for y in range(target.y - 3, target.y + 4):
		for x in range(target.x - 3, target.x + 4):
			Fixture.carve(world, Vector2i(x, y))
	rock(target)
	var side := Vector2i(roundi(cos(turn * PI / 2)), roundi(sin(turn * PI / 2)))
	rock(target + side)
	var hand: Vector2 = world.Grid.center(target) + Vector2(64, -52).rotated(turn * PI / 2)
	world.player.position = hand + Vector2(0, world.player.body_size().y / 2)
	world.target_cell = target
	for index in range(3): await physics_frame

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	for turn in range(4):
		await setup_case(turn)
		var ray := PhysicsRayQueryParameters2D.create(world.player_center(), world.Grid.center(target), 1, [world.player.get_rid()])
		var hit := world.get_world_2d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider != world.blocks[target], "fixture reproduces centre occlusion / turn %d" % turn)
		check(world.can_reach(target), "exposed face remains reachable beside a ledge / turn %d" % turn)
		check(world.target_blocker(target).is_empty(), "visible nearby block is not labelled out of reach / turn %d" % turn)
	await setup_case(0)
	world.mine_timer = 0
	var energy: float = world.ship_energy()
	world._mine_target()
	check(world.ship_energy() < energy and world.beam_time > 0, "actual mining click acts on the exposed face")
	check(world.beam_target != world.Grid.center(target), "beam aims at the reachable surface rather than through the neighbouring block")
	for index in range(15):
		if world.site.material(target).is_empty(): break
		world.mine_timer = 0
		world._mine_target()
	check(world.site.material(target).is_empty(), "nearby selected block can actually be excavated")
	await setup_case(0)
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]: rock(target + offset)
	for index in range(3): await physics_frame
	check(not world.can_reach(target), "fully enclosed block remains protected by intervening rock")
	world.player.position.x -= world.Grid.metres(6)
	check(not world.can_reach(target), "distant block remains outside tool range")
	Fixture.carve(world, target)
	for index in range(3): await physics_frame
	check(not world.can_reach(target), "empty cell is not a mining target")
	print("MINING REACH: %d failures" % failures)
	quit(1 if failures else 0)
