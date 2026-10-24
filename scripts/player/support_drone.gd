extends CharacterBody2D

const Grid = preload("res://scripts/world/world_grid.gd")
const BASE := Vector2(0, -80)
const PERSONAL_SPACE := 70.0
const FOLLOW_DISTANCE := 96.0
const MIN_CLEARANCE := 42.0
var world: Node2D
var graph := AStar2D.new()
var revision := -1
var range_metres := 15.0
var route := PackedVector2Array()
var route_timer := 0.0
var clock := 0.0
var status := "Collegato"
var water_alarm := false
var water_timer := 0.0

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

func hit_test(viewport_point: Vector2) -> bool:
	var local_point := get_global_transform_with_canvas().affine_inverse() * viewport_point
	return Rect2(-26, -20, 52, 42).has_point(local_point)

func _free(cell: Vector2i) -> bool:
	if cell.y >= 0:
		return world.site.contains(cell) and world.site.material(cell).is_empty() and not world.environment._wet(Grid.center(cell))
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

func follow_goal() -> Vector2:
	var torso: Vector2 = world.player.position - Vector2(0, 32)
	var desired := torso + Vector2(-world.player.facing * FOLLOW_DISTANCE, -40)
	var best := desired
	var score := INF
	# Prefer a clear resting place beside the player, not the nearest occupied cell.
	for id in graph.get_point_ids():
		var point := graph.get_point_position(id)
		var distance := point.distance_to(torso)
		if distance < PERSONAL_SPACE or distance > Grid.metres(2.8) or not _clear(torso, point):
			continue
		var candidate := point.distance_to(desired)
		if candidate < score:
			score = candidate
			best = point
	return best

func _physics_process(delta: float) -> void:
	if world.controls_blocked():
		return
	clock += delta
	if world.player_environment().submerged:
		water_alarm = true
		status = "Allarme: stai subendo danni"
		velocity = Vector2.ZERO
		route.clear()
		route_timer = 0
		queue_redraw()
		return
	if water_alarm:
		water_alarm = false
		revision = -1
	water_timer -= delta
	var current_range: float = world.ship_state.drone_range_metres() if world.ship_state != null else 15
	if revision != world.navigation_revision or range_metres != current_range or (not world.environment.water.is_empty() and water_timer <= 0):
		range_metres = current_range
		_rebuild()
		water_timer = 0.5
		route_timer = 0
	route_timer -= delta
	if route_timer <= 0 and graph.get_point_count() > 0:
		route_timer = 0.3
		for id in graph.get_point_ids():
			graph.set_point_disabled(id, false)
		var start := graph.get_closest_point(position)
		var actor := Rect2(world.player.position - Vector2(12, 64), Vector2(24, 64)).grow(24)
		for id in graph.get_point_ids():
			graph.set_point_disabled(id, id != start and actor.has_point(graph.get_point_position(id)))
		var goal := follow_goal()
		var outside: bool = goal.distance_to(BASE) > Grid.metres(range_metres)
		if outside:
			goal = BASE + (goal - BASE).normalized() * Grid.metres(range_metres - 0.5)
		var end := graph.get_closest_point(goal)
		route = graph.get_point_path(start, end)
		status = "Limite segnale" if outside else ("Percorso ostruito" if route.is_empty() else "Ti seguo")
		if not route.is_empty() and position.distance_to(route[0]) < 8:
			route.remove_at(0)
	velocity = Vector2.ZERO
	if not route.is_empty() and world.environment._wet(route[0]):
		route.clear()
		revision = -1
	if not route.is_empty():
		if position.distance_to(route[0]) < 5:
			route.remove_at(0)
		else:
			velocity = (route[0] - position).normalized() * minf(125, position.distance_to(route[0]) / maxf(delta, 0.001))
	var torso: Vector2 = world.player.position - Vector2(0, 32)
	var distance := position.distance_to(torso)
	if distance < MIN_CLEARANCE:
		var away := (position - torso).normalized()
		if away.is_zero_approx():
			away = Vector2(-world.player.facing, -1).normalized()
		var escape := position + away * minf(MIN_CLEARANCE - distance + 4, 24)
		if _free(Grid.to_cell(escape)) and _clear(position, escape):
			velocity = away * minf(100, (MIN_CLEARANCE - distance + 4) / maxf(delta, 0.001))
		else:
			velocity = Vector2.ZERO
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	var bob := sin(clock * 4) * 2
	var ink := Color("78e4dc") if status == "Ti seguo" or status == "Collegato" else Color("edbe72")
	var flash := water_alarm and sin(clock * 12) >= 0
	if water_alarm:
		ink = Color("ff454e") if flash else Color("ffb5ae")
	if not world.controls_blocked() and hit_test(get_viewport().get_mouse_position()):
		draw_rect(Rect2(-24, -17 + bob, 48, 36), Color("b7ffb6"), false, 1.5)
	draw_line(Vector2(-15, 5 + bob), Vector2(-21, 9 + bob), ink, 3)
	draw_line(Vector2(15, 5 + bob), Vector2(21, 9 + bob), ink, 3)
	draw_rect(Rect2(-17, -9 + bob, 34, 20), Color("ff454e") if flash else Color("dae2d8"))
	if water_alarm:
		draw_rect(Rect2(-23, -17 + bob, 46, 38), ink, false, 2)
	draw_rect(Rect2(-12, -5 + bob, 24, 11), Color("294b5a"))
	draw_circle(Vector2(0, bob), 4, ink)
	draw_line(Vector2(-22, -12 + bob), Vector2(-8, -12 + bob), Color("d9b25b"), 3)
	draw_line(Vector2(8, -12 + bob), Vector2(22, -12 + bob), Color("d9b25b"), 3)
	draw_rect(Rect2(-9, 11 + bob, 18, 7), Color("70888c"))
