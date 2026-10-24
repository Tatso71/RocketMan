extends RefCounted

static func workshop(world: Node2D) -> void:
	world.return_home()
	world.drone.position = Vector2(20, -140)
	world.drone.velocity = Vector2.ZERO

static func build(world: Node2D, id: String, cell: Vector2i) -> bool:
	if not world.outpost.place(id, cell):
		return false
	var site: Dictionary = world.outpost.buildings.structures.back()
	if not world.outpost.fund_site(site):
		return false
	world.outpost.advance(world.outpost.Buildings.build_seconds(id) + 0.01)
	return site.state == "active"

# Test-only excavations. Production worlds never start with these passages.
static func carve(world: Node2D, cell: Vector2i) -> void:
	world.site.removed[cell] = true
	if world.blocks.has(cell):
		var body: Node = world.blocks[cell]
		world.terrain.remove_child(body)
		body.queue_free()
		world.blocks.erase(cell)
	world.navigation_revision += 1

static func starter_tunnel(world: Node2D) -> void:
	for y in range(4):
		for x in range(-1, 1):
			carve(world, Vector2i(x, y))
		world.ladders[Vector2i(0, y)] = true
	for x in range(-5, -1):
		for y in range(2, 4):
			carve(world, Vector2i(x, y))

static func lab_room(world: Node2D) -> void:
	starter_tunnel(world)
	for x in range(-5, -1):
		carve(world, Vector2i(x, 1))
