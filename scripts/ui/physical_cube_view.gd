extends Node2D

const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
var outpost: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var world: Node2D = outpost.world
	for job: Dictionary in outpost.fabrication.jobs:
		var station: Dictionary = outpost.resolve_station(job.station)
		if station.is_empty():
			continue
		var progress: float = float(job.elapsed) / float(job.seconds)
		var point: Vector2 = outpost.station_output(station)
		var paused: bool = not outpost.fabrication_pause_reason(job).is_empty()
		_draw_cube(point, progress, job.id)
		draw_string(ThemeDB.fallback_font, point + Vector2(-44, -82), Buildings.NAMES[job.id], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Buildings.CUBE_COLORS[job.id])
		draw_rect(Rect2(point + Vector2(-28, -60), Vector2(56, 6)), Color("17252c"))
		draw_rect(Rect2(point + Vector2(-28, -60), Vector2(56 * progress, 6)), Color("80e0d7"))
		draw_string(ThemeDB.fallback_font, point + Vector2(-24, -67), "PAUSA" if paused else "%.0f%%" % (progress * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffae87") if paused else Color("c4fff0"))
	for cube: Dictionary in outpost.fabrication.cubes:
		var carried: bool = cube.uid == outpost.fabrication.carried_id
		var point: Vector2 = world.player.position - Vector2(0, 66) if carried else cube.position
		_draw_cube(point, 1, cube.id)
		if carried or outpost.cube_near_player(cube):
			var text := "SPAZIO / posa" if carried else "SPAZIO / prendi"
			draw_string(ThemeDB.fallback_font, point + Vector2(-44, -68), Buildings.NAMES[cube.id], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Buildings.CUBE_COLORS[cube.id])
			draw_string(ThemeDB.fallback_font, point + Vector2(-44, -52), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e5fff4"))

func _draw_cube(point: Vector2, progress: float, id: String) -> void:
	var rect := Rect2(point - Vector2(20, 40), Vector2(40, 40))
	draw_rect(rect.grow(3), Color(0.4, 0.95, 0.8, 0.08), false, 2)
	var base := point - Vector2(0, 18)
	var color: Color = Buildings.CUBE_COLORS[id]
	color.a = 0.18 + 0.82 * progress
	draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -12), base + Vector2(0, -20), base + Vector2(16, -12), base + Vector2(0, -4)]), color.lightened(0.2))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -12), base + Vector2(0, -4), base + Vector2(0, 15), base + Vector2(-16, 7)]), color.darkened(0.28))
	draw_colored_polygon(PackedVector2Array([base + Vector2(0, -4), base + Vector2(16, -12), base + Vector2(16, 7), base + Vector2(0, 15)]), color)
	draw_rect(Rect2(base + Vector2(4, -1), Vector2(7, 7)), Color("253d48"))
	if progress < 1:
		var y: float = point.y - 40 + fposmod(outpost.world.ambient_time * 35, 40)
		draw_line(Vector2(point.x - 20, y), Vector2(point.x + 20, y), Color("c8fff1"), 2)
