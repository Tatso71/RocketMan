extends CharacterBody2D

const Grid = preload("res://scripts/world/world_grid.gd")
const BASE := Vector2(0, -80)
var world: Node2D
var graph := AStar2D.new()
var revision := -1
var range_metres := 15.0
var route := PackedVector2Array()
var route_timer := 0.0
var clock := 0.0
var status := "Collegato"

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8
	collider.shape = circle
	add_child(collider)

func _id(cell: Vector2i) -> int:
	return (cell.y + 11) * (world.site.RIGHT - world.site.LEFT) + cell.x - world.site.LEFT

func signal_connected() -> bool:
	return position.distance_to(BASE) <= Grid.metres(range_metres) + 1

func aboard() -> bool:
	return position.y < -80 and absf(position.x) < 152

func _free(cell: Vector2i) -> bool:
	if cell.y >= 0:
		return world.site.contains(cell) and world.site.material(cell).is_empty()
	if cell.y >= -2:
		return cell.x in [-1, 0]
	return cell.y >= -11 and cell.x >= -4 and cell.x < 4

func _clear(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1, [get_rid(), world.player.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _rebuild() -> void:
	graph.clear()
	for y in range(-11, world.site.DEPTH):
		for x in range(world.site.LEFT, world.site.RIGHT):
			var cell := Vector2i(x, y)
			var center := Grid.center(cell)
			if _free(cell) and center.distance_to(BASE) <= Grid.metres(range_metres):
				graph.add_point(_id(cell), center)
	for y in range(-11, world.site.DEPTH):
		for x in range(world.site.LEFT, world.site.RIGHT):
			var cell := Vector2i(x, y)
			if not graph.has_point(_id(cell)):
				continue
			for offset in [Vector2i.RIGHT, Vector2i.DOWN]:
				var neighbor: Vector2i = cell + offset
				if neighbor.x < world.site.RIGHT and neighbor.y < world.site.DEPTH and graph.has_point(_id(neighbor)) and _clear(Grid.center(cell), Grid.center(neighbor)):
					graph.connect_points(_id(cell), _id(neighbor))
	revision = world.navigation_revision

func _physics_process(delta: float) -> void:
	if world.controls_blocked():
		return
	clock += delta
	var current_range: float = world.ship_state.drone_range_metres() if world.ship_state != null else 15
	if revision != world.navigation_revision or range_metres != current_range:
		range_metres = current_range
		_rebuild()
		route_timer = 0
	route_timer -= delta
	if route_timer <= 0 and graph.get_point_count() > 0:
		route_timer = 0.3
		var goal: Vector2 = world.player.position + Vector2(-world.player.facing * 48, -48)
		var outside: bool = goal.distance_to(BASE) > Grid.metres(range_metres)
		if outside:
			goal = BASE + (goal - BASE).normalized() * Grid.metres(range_metres - 0.5)
		var start := graph.get_closest_point(position)
		var end := graph.get_closest_point(goal)
		route = graph.get_point_path(start, end)
		status = "Limite segnale" if outside else ("Percorso ostruito" if route.is_empty() else "Ti seguo")
		if not route.is_empty() and position.distance_to(route[0]) < 8:
			route.remove_at(0)
	velocity = Vector2.ZERO
	if not route.is_empty():
		if position.distance_to(route[0]) < 5:
			route.remove_at(0)
		else:
			velocity = (route[0] - position).normalized() * minf(165, position.distance_to(route[0]) / delta)
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	var bob := sin(clock * 4) * 2
	var ink := Color("78e4dc") if status == "Ti seguo" or status == "Collegato" else Color("edbe72")
	draw_line(Vector2(-15, 5 + bob), Vector2(-21, 9 + bob), ink, 3)
	draw_line(Vector2(15, 5 + bob), Vector2(21, 9 + bob), ink, 3)
	draw_rect(Rect2(-17, -9 + bob, 34, 20), Color("dae2d8"))
	draw_rect(Rect2(-12, -5 + bob, 24, 11), Color("294b5a"))
	draw_circle(Vector2(0, bob), 4, ink)
	draw_line(Vector2(-22, -12 + bob), Vector2(-8, -12 + bob), Color("d9b25b"), 3)
	draw_line(Vector2(8, -12 + bob), Vector2(22, -12 + bob), Color("d9b25b"), 3)
	draw_rect(Rect2(-9, 11 + bob, 18, 7), Color("70888c"))
