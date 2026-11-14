extends Node2D

const Grid = preload("res://scripts/world/world_grid.gd")
var world: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for cell: Vector2i in world.ladders:
		var top := Grid.to_world(cell) + Vector2(20, 0)
		for x in [-14, 14]:
			draw_line(top + Vector2(x, 0), top + Vector2(x, 40), Color("dfb15a"), 3)
		for y in range(8, 40, 16):
			draw_line(top + Vector2(-14, y), top + Vector2(14, y), Color("e4c78b"), 3)
