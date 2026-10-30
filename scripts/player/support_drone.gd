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
var resting_goal := Vector2.ZERO
var has_resting_goal := false
var clearance := CircleShape2D.new()
var mission := "follow"
const UNLOAD_POINT := Vector2(-100, -140)
const SPEED := 125.0
const ACCELERATION := 420.0

func _ready() -> void:
	clearance.radius = 10
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
		return world.site.contains(cell) and world.site.material(cell).is_empty() and not world.environment._wet(Grid.center(cell) + Vector2(0, 10))
	if cell.y >= -2:
		return cell.x == 0
	return cell.y >= -11 and cell.x >= -4 and cell.x < 4

func _clear(from: Vector2, to: Vector2) -> bool:
	if to.distance_to(BASE) > Grid.metres(range_metres) + 1 and to.distance_to(BASE) > from.distance_to(BASE):
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = clearance
	query.transform = Transform2D(0, from)
	query.motion = to - from
	query.collision_mask = 1
	query.exclude = [get_rid(), world.player.get_rid()]
	var sweep := get_world_2d().direct_space_state.cast_motion(query)
	return sweep[0] >= 0.999

func _actor_clearance() -> Rect2:
	# In ladder shafts reserve only the actual body plus the drone's collision radius.
	if absf(world.player.position.x - 20) < 24 or absf(world.player.position.x - 100) < 20:
		return Rect2(world.player.position - Vector2(24, 76), Vector2(48, 88))
	return Rect2(world.player.position - Vector2(43, 83), Vector2(86, 102))

func send_to_ship() -> bool:
	if mission != "follow":
		world._note("Robbie e gia in viaggio / Attendi il rientro")
		return false
	if world.field_cargo.used(world.field_cargo.drone) == 0:
		world._note("Robbie non ha materiali da scaricare")
		return false
	mission = "outbound"
	has_resting_goal = false
	route_timer = 0
	world.field_cargo.drone_available = false
	world._note("Robbie torna alla nave / Lascia libera la botola")
	return true

func _route_clear(from: Vector2, to: Vector2) -> bool:
	if not _clear(from, to):
		return false
	# Lookahead may skip dry waypoints, but must not shortcut across a liquid pocket.
	var samples := maxi(1, ceili(from.distance_to(to) / 10))
	for index in range(samples + 1):
		if world.environment._wet(from.lerp(to, float(index) / samples) + Vector2(0, 10)):
			return false
	var actor := _actor_clearance()
	if actor.has_point(from):
		return not actor.has_point(to)
	if actor.has_point(to):
		return false
	var corners := [actor.position, Vector2(actor.end.x, actor.position.y), actor.end, Vector2(actor.position.x, actor.end.y)]
	for index in range(4):
		if Geometry2D.segment_intersects_segment(from, to, corners[index], corners[(index + 1) % 4]) != null:
			return false
	return true

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
	# Keep a comfortable resting place when the explorer only turns around.
	if has_resting_goal and resting_goal.distance_to(BASE) <= Grid.metres(range_metres) and resting_goal.distance_to(torso) >= MIN_CLEARANCE + 8 and resting_goal.distance_to(torso) <= Grid.metres(2.8) and not _actor_clearance().has_point(resting_goal) and _clear(torso, resting_goal) and _free(Grid.to_cell(resting_goal)):
		return resting_goal
	var best := position
	var score := INF
	var start := graph.get_closest_point(position)
	for id in graph.get_point_ids():
		var point := graph.get_point_position(id)
		var distance := point.distance_to(torso)
		if distance < MIN_CLEARANCE or distance > Grid.metres(3.2) or not _clear(torso, point):
			continue
		var candidate := point.distance_to(desired) + maxf(0, PERSONAL_SPACE - distance) * 8
		if candidate < score and not graph.get_id_path(start, id).is_empty():
			score = candidate
			best = point
	resting_goal = best
	has_resting_goal = score < INF
	return best

func _physics_process(delta: float) -> void:
	if world.controls_locked:
		velocity = Vector2.ZERO
		return
	clock += delta
	var danger: Dictionary = world.player_environment()
	if mission == "follow" and (danger.submerged or danger.oil):
		water_alarm = true
		status = "Allarme: stai subendo danni"
		velocity = Vector2.ZERO
		route.clear()
		route_timer = 0
		queue_redraw()
		return
	if mission == "outbound" and position.distance_to(UNLOAD_POINT) < 12:
		var stock: Dictionary = world.ship_state.resources if world.ship_state != null else world.local_store
		var capacity: int = world.ship_state.cargo_capacity() if world.ship_state != null else 120
		var unloaded: int = world.field_cargo.unload_drone(stock, capacity)
		mission = "returning"
		has_resting_goal = false
		route_timer = 0
		world._note("Robbie: scaricate %d unita / Torno da te%s" % [unloaded, " / Stiva piena" if world.field_cargo.used(world.field_cargo.drone) > 0 else ""])
	if mission == "returning" and position.distance_to(world.player.position - Vector2(0, 32)) <= 112 and _clear(position, world.player.position - Vector2(0, 32)):
		mission = "follow"
		has_resting_goal = false
		route_timer = 0
		world._note("Robbie e tornato / Raccolta disponibile")
	if water_alarm:
		water_alarm = false
		revision = -1
	water_timer -= delta
	var current_range: float = world.ship_state.drone_range_metres() if world.ship_state != null else 15
	if revision != world.navigation_revision or range_metres != current_range or ((not world.environment.water.is_empty() or not world.environment.oil.is_empty()) and water_timer <= 0):
		range_metres = current_range
		_rebuild()
		water_timer = 0.5
		route_timer = 0
	route_timer -= delta
	if route_timer <= 0 and graph.get_point_count() > 0:
		route_timer = 0.2
		for id in graph.get_point_ids():
			graph.set_point_disabled(id, false)
		var start := graph.get_closest_point(position)
		var torso: Vector2 = world.player.position - Vector2(0, 32)
		for id in graph.get_point_ids():
			# The body itself is excluded; personal space outside it is only a cost.
			graph.set_point_disabled(id, id != start and _actor_clearance().has_point(graph.get_point_position(id)))
			var proximity := graph.get_point_position(id).distance_to(torso)
			graph.set_point_weight_scale(id, 1 + maxf(0, PERSONAL_SPACE - proximity) / 10)
		var goal := follow_goal()
		var outside: bool = torso.distance_to(BASE) > Grid.metres(range_metres)
		if outside or not has_resting_goal:
			goal = BASE + (torso - BASE).limit_length(Grid.metres(range_metres - 0.7))
		if mission == "outbound":
			goal = UNLOAD_POINT
		var end := graph.get_closest_point(goal)
		route = graph.get_point_path(start, end)
		status = "Limite segnale" if outside else ("Percorso ostruito" if route.is_empty() else "Ti seguo")
		if mission != "follow":
			status = ("Alla nave per scaricare" if mission == "outbound" else "Rientro verso di te") if not route.is_empty() else "Passaggio ostruito / Libera la botola"
		# Never return to the centre of the start cell on every route refresh.
		if route.size() > 1 and _route_clear(position, route[1]):
			route.remove_at(0)
	var desired_velocity := Vector2.ZERO
	if not route.is_empty() and world.environment._wet(route[0]):
		route.clear()
		revision = -1
	if not route.is_empty():
		while route.size() > 1 and _route_clear(position, route[1]):
			route.remove_at(0)
		if position.distance_to(route[0]) < 3:
			route.remove_at(0)
		elif _route_clear(position, route[0]):
			desired_velocity = (route[0] - position).normalized() * minf(SPEED, position.distance_to(route[0]) * 4)
	var torso: Vector2 = world.player.position - Vector2(0, 32)
	var distance := position.distance_to(torso)
	var comfort := PERSONAL_SPACE
	if has_resting_goal and world.player.velocity.length() < 1:
		comfort = clampf(resting_goal.distance_to(torso) - 2, MIN_CLEARANCE, PERSONAL_SPACE)
	if distance < comfort:
		var away := (position - torso).normalized()
		if away.is_zero_approx():
			away = Vector2(-world.player.facing, -1).normalized()
		var escape := position + away * 28
		if not _free(Grid.to_cell(escape)) or not _clear(position, escape):
			for direction: Vector2 in [Vector2.UP, Vector2(-1, -1).normalized(), Vector2(1, -1).normalized(), Vector2.LEFT, Vector2.RIGHT]:
				var candidate := position + direction * 28
				if candidate.distance_to(torso) > distance and _free(Grid.to_cell(candidate)) and _clear(position, candidate):
					away = direction
					escape = candidate
					break
		if _free(Grid.to_cell(escape)) and _clear(position, escape):
			desired_velocity = away * minf(SPEED, (comfort - distance + 4) * 4)
	velocity = velocity.move_toward(desired_velocity, ACCELERATION * delta)
	if not _clear(position, position + velocity * delta):
		velocity = velocity.move_toward(Vector2.ZERO, ACCELERATION * delta)
		route_timer = 0
	move_and_slide()
	world.field_cargo.drone_available = world.drone_can_collect()
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
