extends RefCounted

const Grid = preload("res://scripts/world/world_grid.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
var jobs: Array = []
var cubes: Array = []
var carried_id := 0
var next_id := 1

func carried() -> Dictionary:
	for cube: Dictionary in cubes:
		if cube.uid == carried_id:
			return cube
	return {}

func job_at(station: Array) -> Dictionary:
	for job: Dictionary in jobs:
		if job.station == station:
			return job
	return {}

func output_at(station: Array) -> Dictionary:
	for cube: Dictionary in cubes:
		if cube.station == station:
			return cube
	return {}

func add_cube(point: Vector2, station: Array = [], id: String = "laboratory") -> Dictionary:
	if id not in Buildings.CUBE_IDS:
		return {}
	var cube := {"uid": next_id, "id": id, "level": 1, "position": point, "station": station.duplicate()}
	next_id += 1
	cubes.append(cube)
	return cube

func snapshot() -> Dictionary:
	var saved: Array = []
	for cube: Dictionary in cubes:
		var copy := cube.duplicate(true)
		copy.position = [cube.position.x, cube.position.y]
		saved.append(copy)
	return {"jobs": jobs.duplicate(true), "cubes": saved, "carried_id": carried_id, "next_id": next_id}

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum

static func station_valid(value: Variant, empty_allowed: bool = false) -> bool:
	if not value is Array:
		return false
	return (value.is_empty() and empty_allowed) or value == ["ship"] or (value.size() == 3 and value[0] == "laboratory" and integer(value[1], Site.LEFT, Site.RIGHT - 4) and integer(value[2], 0, Site.DEPTH - 3))

static func normalized_station(value: Array) -> Array:
	return ["laboratory", int(value[1]), int(value[2])] if value.size() == 3 else value.duplicate()

func restore(data: Variant) -> bool:
	if not data is Dictionary or not data.get("jobs", []) is Array or not data.get("cubes", []) is Array or data.get("jobs", []).size() > 200 or data.get("cubes", []).size() > 200:
		return false
	if not integer(data.get("carried_id", 0), 0, 1000000000) or not integer(data.get("next_id", 1), 1, 1000000000):
		return false
	if data.get("jobs", []).size() + data.get("cubes", []).size() > 200:
		return false
	var next_jobs: Array = []
	var next_cubes: Array = []
	var stations: Array = []
	var ids: Array = []
	for job in data.get("jobs", []):
		if not job is Dictionary or (job.get("id") not in Buildings.CUBE_IDS and job.get("id") != "bomb") or not station_valid(job.get("station")) or not integer(job.get("level"), 1, 1):
			return false
		for key: String in ["elapsed", "seconds"]:
			if not (job.get(key) is int or job.get(key) is float) or not is_finite(float(job[key])):
				return false
		if job.seconds <= 0 or job.seconds > 120 or job.elapsed < 0 or job.elapsed >= job.seconds:
			return false
		var station := normalized_station(job.station)
		if station in stations:
			return false
		stations.append(station)
		next_jobs.append({"id": job.id, "level": 1, "station": station, "elapsed": float(job.elapsed), "seconds": float(job.seconds)})
	for cube in data.get("cubes", []):
		if not cube is Dictionary or cube.get("id") not in Buildings.CUBE_IDS or not integer(cube.get("level"), 1, 1) or not integer(cube.get("uid"), 1, int(data.get("next_id", 1)) - 1) or cube.uid in ids or not station_valid(cube.get("station"), true):
			return false
		var point = cube.get("position")
		if not point is Array or point.size() != 2:
			return false
		for value in point:
			if not (value is int or value is float) or not is_finite(float(value)):
				return false
		var position := Vector2(float(point[0]), float(point[1]))
		if position.x < Grid.metres(Site.LEFT) or position.x > Grid.metres(Site.RIGHT) or position.y < -440 or position.y > Grid.metres(Site.DEPTH):
			return false
		var station := normalized_station(cube.station)
		if not station.is_empty():
			if station in stations or int(cube.uid) == int(data.get("carried_id", 0)):
				return false
			stations.append(station)
		ids.append(int(cube.uid))
		next_cubes.append({"uid": int(cube.uid), "id": cube.id, "level": 1, "station": station, "position": position})
	if int(data.get("carried_id", 0)) != 0 and int(data.carried_id) not in ids:
		return false
	jobs = next_jobs
	cubes = next_cubes
	carried_id = int(data.get("carried_id", 0))
	next_id = int(data.get("next_id", 1))
	return true

func valid_world(site: RefCounted, buildings: RefCounted) -> bool:
	for item: Dictionary in jobs + cubes:
		var station: Array = item.station
		if station.size() == 3 and not buildings.structures.any(func(lab: Dictionary): return lab.id == "laboratory" and lab.get("state", "active") == "active" and lab.origin == Vector2i(int(station[1]), int(station[2]))):
			return false
	for cube: Dictionary in cubes:
		if cube.uid == carried_id:
			continue
		var cell := Grid.to_cell(cube.position - Vector2(0, 1))
		if cell.y >= 0 and (not site.contains(cell) or not site.material(cell).is_empty()):
			return false
		if cell.y < 0 and (absf(cube.position.x) > 156 or cube.position.y < -376 or cube.position.y > -78):
			return false
	return true

func valid_ship() -> bool:
	if jobs.any(func(job: Dictionary): return job.station != ["ship"]):
		return false
	for cube: Dictionary in cubes:
		if not cube.station.is_empty() and cube.station != ["ship"]:
			return false
		if cube.uid != carried_id and (absf(cube.position.x) > 156 or cube.position.y < -376 or cube.position.y > -78):
			return false
	return true

func import_state(other: RefCounted) -> void:
	jobs.append_array(other.jobs.duplicate(true))
	for cube: Dictionary in other.cubes:
		var imported := add_cube(cube.position, cube.station, cube.id)
		if cube.uid == other.carried_id:
			carried_id = imported.uid
