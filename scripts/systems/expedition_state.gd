extends RefCounted

const Ship = preload("res://scripts/systems/ship_state.gd")
const Planets = preload("res://scripts/data/planet_catalog.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
const DigSite = preload("res://scripts/systems/dig_site.gd")
enum Phase {SELECT, FLIGHT, LANDING, DIGGING, TAKEOFF}
const DURATIONS := {Phase.FLIGHT: 3.5, Phase.LANDING: 4.0, Phase.TAKEOFF: 2.5}
var ship := Ship.new()
var phase := Phase.SELECT
var selected_planet := "ochre"
var active_planet := ""
var progress := 0.0
var outposts: Dictionary = {}

func choose(planet_id: String) -> bool:
	if phase != Phase.SELECT or Planets.find(planet_id) == null:
		return false
	selected_planet = planet_id
	return true

func depart() -> bool:
	var destination := Planets.find(selected_planet)
	if phase != Phase.SELECT or destination == null or not ship.flight_blocker(destination).is_empty():
		return false
	ship.fuel -= ship.route_cost(destination)
	ship.energy -= 5
	active_planet = selected_planet
	phase = Phase.FLIGHT
	progress = 0
	return true

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0 or not DURATIONS.has(phase):
		return
	progress = minf(1, progress + delta / float(DURATIONS[phase]))
	if progress < 1:
		return
	progress = 0
	if phase == Phase.FLIGHT:
		phase = Phase.LANDING
	elif phase == Phase.LANDING:
		var planet := Planets.find(active_planet)
		ship.hull = maxf(0, ship.hull - planet.landing_hazard / int(ship.modules.landing_gear))
		phase = Phase.DIGGING
	elif phase == Phase.TAKEOFF:
		phase = Phase.SELECT

func takeoff() -> bool:
	if phase != Phase.DIGGING or ship.hull < 20 or ship.fuel < 6 or ship.energy < 2:
		return false
	ship.fuel -= 6
	ship.energy -= 2
	phase = Phase.TAKEOFF
	progress = 0
	return true

func snapshot() -> Dictionary:
	return {"version": 1, "phase": phase, "selected_planet": selected_planet, "active_planet": active_planet, "progress": progress, "ship": ship.snapshot(), "outposts": outposts.duplicate(true)}

func restore(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("ship") is Dictionary or not data.get("outposts") is Dictionary:
		return false
	var next_phase = data.get("phase")
	var next_progress = data.get("progress")
	if not (next_phase is float or next_phase is int) or float(next_phase) != floorf(float(next_phase)) or float(next_phase) < Phase.SELECT or float(next_phase) > Phase.TAKEOFF:
		return false
	if not (next_progress is float or next_progress is int) or not is_finite(float(next_progress)) or float(next_progress) < 0 or float(next_progress) >= 1:
		return false
	if not data.get("selected_planet") is String or Planets.find(data.selected_planet) == null:
		return false
	if not data.get("active_planet") is String or (not data.active_planet.is_empty() and Planets.find(data.active_planet) == null) or (int(next_phase) != Phase.SELECT and data.active_planet.is_empty()):
		return false
	for planet_id in data.outposts:
		if not planet_id is String or Planets.find(planet_id) == null or not data.outposts[planet_id] is Dictionary:
			return false
		var outpost: Dictionary = data.outposts[planet_id]
		if outpost.get("version") != 1 or outpost.get("cell_metres") != 1.0 or not outpost.get("removed") is Array or not outpost.get("ladders") is Array or not outpost.get("materials") is Dictionary:
			return false
		if outpost.get("terrain_seed", 0) != Planets.find(planet_id).terrain_seed:
			return false
		for entry in outpost.removed:
			var cell = Grid.decode_cell(entry)
			if not cell is Vector2i or cell.x < DigSite.LEFT or cell.x >= DigSite.RIGHT or cell.y < 0 or cell.y >= DigSite.DEPTH:
				return false
		for entry in outpost.ladders:
			var cell = Grid.decode_cell(entry)
			if not cell is Vector2i or cell.x < DigSite.LEFT or cell.x >= DigSite.RIGHT or cell.y < -2 or cell.y >= DigSite.DEPTH:
				return false
	if not ship.restore(data.ship):
		return false
	phase = int(next_phase)
	progress = float(next_progress)
	selected_planet = data.selected_planet
	active_planet = data.active_planet
	outposts = data.outposts.duplicate(true)
	return true
