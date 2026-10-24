extends RefCounted

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
