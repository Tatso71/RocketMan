extends Node2D

var legs_deployed := false
var engines_on := true
var clock := 0.0

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	for side in [-1, 1]:
		var x: float = side * 200
		if legs_deployed:
			draw_line(Vector2(side * 150, -100), Vector2(side * 216, -8), Color("e8b553"), 12)
			draw_rect(Rect2(side * 216 - 28, -8, 56, 8), Color("46525c"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 34, -110), Vector2(x - 34, -260), Vector2(x - 20, -284), Vector2(x + 20, -284), Vector2(x + 34, -260), Vector2(x + 34, -110)]), Color("d6e0d7"))
		draw_rect(Rect2(x - 34, -132, 68, 22), Color("db9f3f"))
		draw_rect(Rect2(x - 22, -110, 44, 18), Color("394854"))
		draw_rect(Rect2(x - 7, -248, 14, 82), Color("254751"))
		draw_rect(Rect2(x - 3, -244, 6, 74), Color("76e2d9"))
		if engines_on:
			var length := 72 + sin(clock * 24 + side) * 12
			draw_colored_polygon(PackedVector2Array([Vector2(x - 18, -92), Vector2(x + 18, -92), Vector2(x, -92 + length)]), Color("efae58"))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 10, -92), Vector2(x + 10, -92), Vector2(x, -92 + length * 0.7)]), Color("fff0bb"))
	draw_colored_polygon(PackedVector2Array([Vector2(-174, -80), Vector2(-174, -429), Vector2(-138, -456), Vector2(138, -456), Vector2(174, -429), Vector2(174, -80)]), Color("e1e4d8"))
	draw_colored_polygon(PackedVector2Array([Vector2(-138, -456), Vector2(0, -520), Vector2(138, -456)]), Color("e8ad42"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -520), Vector2(48, -456), Vector2(138, -456)]), Color("f7ce69"))
	for y in [-320, -200, -96]:
		draw_rect(Rect2(-174, y, 348, 16), Color("daa549"))
	draw_rect(Rect2(-40, -80, 80, 14), Color("52616a"))
	draw_circle(Vector2(0, -375), 62, Color("e3ad52"))
	draw_circle(Vector2(0, -375), 51, Color("305362"))
	draw_arc(Vector2(0, -375), 46, 3.3, 5.5, 24, Color("9cded8"), 4)
	# The pilot remains visible through the same porthole while the hull is opaque.
	draw_rect(Rect2(-18, -377, 36, 35), Color("e7a94d"))
	draw_circle(Vector2(0, -394), 23, Color("f3c774"))
	draw_circle(Vector2(0, -393), 16, Color("304653"))
	draw_circle(Vector2(7, -397), 5, Color("8de2de"))
	draw_rect(Rect2(-38, -352, 76, 10), Color("718b91"))
	draw_circle(Vector2(0, -254), 15, Color("355562"))
	draw_circle(Vector2(0, -254), 10, Color("7bdfd6"))
