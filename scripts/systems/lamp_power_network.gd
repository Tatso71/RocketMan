extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const RELAY_REACH_METRES := 8.0
const RELAY_REACH := RELAY_REACH_METRES * Grid.PIXELS_PER_METRE

static func _direct(target: Dictionary, roots: Array) -> Dictionary:
	var best := {}
	var distance := INF
	for root: Dictionary in roots:
		var candidate: float = root.point.distance_to(target.point)
		if candidate <= float(root.reach) and candidate < distance:
			distance = candidate
			best = {"lab": root.building, "parent": root.building, "hops": 1}
	return best

static func _via(target: Dictionary, relays: Array, routes: Dictionary) -> Dictionary:
	var best := {}
	var hops := 2147483647
	var distance := INF
	for relay: Dictionary in relays:
		var origin: Vector2i = relay.building.origin
		if origin == target.building.origin or not routes.has(origin): continue
		var candidate: float = relay.point.distance_to(target.point)
		var depth: int = int(routes[origin].hops) + 1
		if candidate <= RELAY_REACH and (depth < hops or (depth == hops and candidate < distance)):
			hops = depth
			distance = candidate
			best = {"lab": routes[origin].lab, "parent": relay.building, "hops": hops}
	return best

static func resolve(roots: Array, relays: Array) -> Dictionary:
	var routes := {}
	var frontier: Array = []
	for relay: Dictionary in relays:
		var route := _direct(relay, roots)
		if not route.is_empty():
			routes[relay.building.origin] = route
			frontier.append(relay)
	# Advance whole layers: every parent is rooted and has strictly fewer hops.
	while not frontier.is_empty():
		var next: Array = []
		for relay: Dictionary in relays:
			if routes.has(relay.building.origin): continue
			var route := _via(relay, frontier, routes)
			if not route.is_empty():
				routes[relay.building.origin] = route
				next.append(relay)
		frontier = next
	return routes

static func connection(target: Dictionary, roots: Array, relays: Array, routes: Dictionary) -> Dictionary:
	if routes.has(target.building.origin): return routes[target.building.origin]
	var direct := _direct(target, roots)
	return direct if not direct.is_empty() else _via(target, relays, routes)
