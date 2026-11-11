extends CharacterBody2D

const Grid = preload("res://scripts/world/world_grid.gd")
const PERSONAL_SPACE := 70.0
const FOLLOW_DISTANCE := 96.0
const MIN_CLEARANCE := 42.0
var world: Node2D
var graph := AStar2D.new()
var navigation_components := {}
var revision := -1
var route := PackedVector2Array()
var route_timer := 0.0
var clock := 0.0
var status := "Collegato"
var water_alarm := false
var water_timer := 0.0
var had_navigation_liquids := false
var resting_goal := Vector2.ZERO
var has_resting_goal := false
var clearance := CircleShape2D.new()
var mission := "follow"
const UNLOAD_POINT := Vector2(-100, -140)
const SPEED := 125.0
const ACCELERATION := 420.0

func _ready() -> void:
	clearance.radius = 10
	if world.is_robbie():
		# Retain the shared cargo API, without a second visible or collidable actor.
		collision_layer = 0
		collision_mask = 0
		hide()
		sync_controlled()
		return
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8
	collider.shape = circle
	add_child(collider)

func _id(cell: Vector2i) -> int:
	return (cell.y + 11) * (world.site.RIGHT - world.site.LEFT) + cell.x - world.site.LEFT

func aboard() -> bool:
	return position.y < -80 and absf(position.x) < 152

func hit_test(viewport_point: Vector2) -> bool:
	if world.is_robbie():
		return false
	var local_point := get_global_transform_with_canvas().affine_inverse() * viewport_point
	return Rect2(-26, -20, 52, 42).has_point(local_point)

func _free(cell: Vector2i) -> bool:
	if cell.y >= 0:
		return world.site.contains(cell) and world.site.material(cell).is_empty() and not world.environment._wet(Grid.center(cell) + Vector2(0, 10))
	if cell.y < -11 or cell.x < world.site.LEFT or cell.x >= world.site.RIGHT:
		return false
	# Air below/around the hull connects the hatch to independent surface shafts.
	# Sweeps ignore initial overlaps, so reject occupied aerial nodes explicitly.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = clearance
	query.transform = Transform2D(0, Grid.center(cell))
	query.collision_mask = 1
	query.exclude = [get_rid(), world.player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _clear(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = clearance
	query.transform = Transform2D(0, from)
	query.motion = to - from
	query.collision_mask = 1
	query.exclude = [get_rid(), world.player.get_rid()]
	var sweep := get_world_2d().direct_space_state.cast_motion(query)
	return sweep[0] >= 0.999

func _actor_clearance() -> Rect2:
	# Only the body plus drone radius blocks paths; comfort is a soft path cost.
	return world.player.body_rect_at(world.player.position).grow(10)

func send_to_ship() -> bool:
	if world.is_robbie():
		if not world.outpost.source_available():
			world._note("Rientra in un laboratorio per depositare il tuo carico")
			return false
		var count: int = world.field_cargo.deposit(world.outpost.source_stock(), world.outpost.storage_capacity(), true)
		if count > 0:
			world.guide_event("deposited")
		world._note("Robbie: depositate %d unita" % count)
		return count > 0
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
	# The companion may pass the explorer in a narrow shaft, but never rest on them.
	return true

func _rebuild() -> void:
	graph.clear()
	navigation_components.clear()
	for y in range(-11, world.site.DEPTH):
		for x in range(world.site.LEFT, world.site.RIGHT):
			var cell := Vector2i(x, y)
			var center := Grid.center(cell)
			if _free(cell):
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
	# Connectivity changes only with the graph, not with comfort weights each replan.
	for id in graph.get_point_ids():
		if navigation_components.has(id):
			continue
		var pending := [id]
		navigation_components[id] = id
		var head := 0
		while head < pending.size():
			var current: int = pending[head]
			head += 1
			for neighbor in graph.get_point_connections(current):
				if not navigation_components.has(neighbor):
					navigation_components[neighbor] = id
					pending.append(neighbor)
	had_navigation_liquids = not world.environment.water.is_empty() or not world.environment.oil.is_empty() or not world.environment.acid.is_empty()
	revision = world.navigation_revision

func follow_goal() -> Vector2:
	var torso: Vector2 = world.player_center()
	var start := graph.get_closest_point(position)
	var component: int = navigation_components.get(start, -1)
	# Approach fallen ore rather than permanently hovering behind its magnet range.
	var ore_goal: Variant = null
	var ore_score := INF
	if world.field_cargo.used(world.field_cargo.drone) < world.field_cargo.drone_capacity:
		for cell: Vector2i in world.gear.drops:
			for ore: Vector2 in world.gear.fragment_positions(cell):
				if ore.distance_to(torso) > Grid.metres(4.5):
					continue
				var destination := graph.get_closest_point(ore)
				if destination < 0:
					continue
				var point := graph.get_point_position(destination)
				if point.distance_to(ore) > Grid.metres(world.gear.magnet_range_metres()) - 12 or _actor_clearance().has_point(point) or navigation_components.get(destination, -2) != component:
					continue
				if point.distance_to(position) < ore_score:
					ore_score = point.distance_to(position)
					ore_goal = point
	if ore_goal is Vector2:
		has_resting_goal = false
		return ore_goal
	var desired := torso + Vector2(-world.player.facing * FOLLOW_DISTANCE, -40)
	# Keep a comfortable resting place when the explorer only turns around.
	if has_resting_goal and resting_goal.distance_to(torso) >= MIN_CLEARANCE + 8 and resting_goal.distance_to(torso) <= Grid.metres(2.8) and not _actor_clearance().has_point(resting_goal) and _clear(torso, resting_goal) and _free(Grid.to_cell(resting_goal)):
		return resting_goal
	var best := position
	var score := INF
	var best_visible := false
	for id in graph.get_point_ids():
		if navigation_components.get(id, -2) != component:
			continue
		var point := graph.get_point_position(id)
		var distance := point.distance_to(torso)
		if distance < MIN_CLEARANCE or distance > Grid.metres(4.5) or _actor_clearance().has_point(point):
			continue
		var candidate := point.distance_to(desired) + maxf(0, PERSONAL_SPACE - distance) * 8
		if candidate >= score and best_visible:
			continue
		# A nearby resting point across a floor/corner leaves the magnet behind a wall.
		# Keep indirect goals only as a fallback while approaching a distant tunnel.
		var visible := _route_clear(point, torso)
		if (visible and not best_visible) or (visible == best_visible and candidate < score):
			score = candidate
			best = point
			best_visible = visible
	resting_goal = best
	has_resting_goal = score < INF
	return best

func sync_controlled() -> void:
	position = world.player_center()
	velocity = Vector2.ZERO
	mission = "follow"
	status = "Controllo manuale"
	world.field_cargo.drone_available = true

func _physics_process(delta: float) -> void:
	if world.is_robbie():
		sync_controlled()
		return
	if world.controls_locked:
		velocity = Vector2.ZERO
		return
	clock += delta
	var automated: bool = is_instance_valid(world.outpost) and world.outpost.logistics.enabled()
	if automated:
		world.outpost.logistics.advance(delta)
	var danger: Dictionary = world.player_environment()
	if mission in ["follow", "collecting"] and (danger.submerged or danger.oil or danger.acid):
		water_alarm = true
		status = "Allarme: stai subendo danni"
		velocity = Vector2.ZERO
		route.clear()
		route_timer = 0
		queue_redraw()
		return
	if not automated and mission == "outbound" and position.distance_to(UNLOAD_POINT) < 12:
		var stock: Dictionary = world.ship_state.resources if world.ship_state != null else world.local_store
		var capacity: int = world.ship_state.cargo_capacity() if world.ship_state != null else 120
		var unloaded: int = world.field_cargo.unload_drone(stock, capacity)
		mission = "returning"
		has_resting_goal = false
		route_timer = 0
		world._note("Robbie: scaricate %d unita / Torno da te%s" % [unloaded, " / Stiva piena" if world.field_cargo.used(world.field_cargo.drone) > 0 else ""])
	if not automated and mission == "returning" and position.distance_to(world.player_center()) <= 112 and _clear(position, world.player_center()):
		mission = "follow"
		has_resting_goal = false
		route_timer = 0
		world._note("Robbie e tornato / Raccolta disponibile")
	if water_alarm:
		water_alarm = false
		revision = -1
	water_timer -= delta
	if revision != world.navigation_revision or ((had_navigation_liquids or not world.environment.water.is_empty() or not world.environment.oil.is_empty() or not world.environment.acid.is_empty()) and water_timer <= 0):
		_rebuild()
		water_timer = 0.5
		route_timer = 0
	route_timer -= delta
	if route_timer <= 0 and graph.get_point_count() > 0:
		route_timer = 0.2
		var start := graph.get_closest_point(position)
		var torso: Vector2 = world.player_center()
		for id in graph.get_point_ids():
			# The body itself is excluded; personal space outside it is only a cost.
			graph.set_point_disabled(id, false)
			var proximity := graph.get_point_position(id).distance_to(torso)
			graph.set_point_weight_scale(id, 1 + maxf(0, PERSONAL_SPACE - proximity) / 10)
		var goal: Vector2 = world.outpost.logistics.goal() if automated and mission != "follow" else follow_goal()
		if mission == "outbound":
			goal = UNLOAD_POINT
		var end := graph.get_closest_point(goal)
		route = graph.get_point_path(start, end)
		status = "Percorso ostruito" if route.is_empty() or goal.distance_to(torso) > Grid.metres(4.5) else "Ti seguo"
		if mission != "follow":
			status = ("Alla nave per scaricare" if mission == "outbound" else "Rientro verso di te") if not route.is_empty() else "Passaggio ostruito / Libera la botola"
		if automated and not route.is_empty(): status = world.outpost.logistics.status
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
	var torso: Vector2 = world.player_center()
	var distance := position.distance_to(torso)
	var comfort := PERSONAL_SPACE
	if has_resting_goal and world.player.velocity.length() < 1:
		comfort = clampf(resting_goal.distance_to(torso) - 2, MIN_CLEARANCE, PERSONAL_SPACE)
	if mission in ["follow", "returning"] and distance < comfort and desired_velocity.is_zero_approx():
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
