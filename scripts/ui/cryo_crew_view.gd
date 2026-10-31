extends RefCounted

const Crew = preload("res://scripts/data/cryo_crew.gd")

static func draw_in(world: Node2D) -> void:
	for index in range(Crew.MEMBERS.size()):
		var member: Dictionary = Crew.MEMBERS[index]
		var rect := Crew.capsule(index)
		var center := rect.get_center().x
		world.draw_rect(rect, Color("3b505b"))
		world.draw_rect(rect.grow(-4), Color("cddedb"))
		var glass := Rect2(rect.position + Vector2(8, 10), rect.size - Vector2(16, 24))
		world.draw_rect(glass, Color("1a3c49"))
		if member.species == "human":
			world.draw_rect(Rect2(center - 12, -263, 24, 38), member.color)
			world.draw_line(Vector2(center - 6, -225), Vector2(center - 6, -218), Color("486570"), 5)
			world.draw_line(Vector2(center + 6, -225), Vector2(center + 6, -218), Color("486570"), 5)
			if index == 1:
				world.draw_rect(Rect2(center - 13, -288, 26, 34), Color("824854"))
			world.draw_circle(Vector2(center, -275), 11, Color("e2b59d"))
			world.draw_rect(Rect2(center - 10, -286, 20, 6), Color("824854") if index == 1 else Color("4f4951"))
			world.draw_line(Vector2(center - 7, -274), Vector2(center - 2, -274), Color("4e414b"), 1.5)
			world.draw_line(Vector2(center + 2, -274), Vector2(center + 7, -274), Color("4e414b"), 1.5)
			if index == 0:
				world.draw_line(Vector2(center - 6, -247), Vector2(center + 6, -247), Color("edf5ef"), 3)
				world.draw_line(Vector2(center, -253), Vector2(center, -241), Color("edf5ef"), 3)
			else:
				world.draw_circle(Vector2(center, -246), 5, Color("d7eabb"))
		else:
			world.draw_circle(Vector2(center + 1, -244), 14, Color("d7ac7e"))
			world.draw_circle(Vector2(center, -263), 11, Color("e5bb8b"))
			world.draw_colored_polygon(PackedVector2Array([Vector2(center - 10, -267), Vector2(center - 10, -280), Vector2(center - 2, -271)]), Color("e5bb8b"))
			world.draw_colored_polygon(PackedVector2Array([Vector2(center + 10, -267), Vector2(center + 10, -280), Vector2(center + 2, -271)]), Color("e5bb8b"))
			world.draw_line(Vector2(center - 7, -262), Vector2(center - 2, -262), Color("654d4b"), 1.5)
			world.draw_line(Vector2(center + 2, -262), Vector2(center + 7, -262), Color("654d4b"), 1.5)
			world.draw_arc(Vector2(center, -244), 13, 0.3, 2.8, 18, Color("a57d62"), 4, true)
		world.draw_rect(glass, Color(0.4, 0.85, 0.86, 0.14))
		world.draw_line(glass.position + Vector2(5, 3), glass.position + Vector2(5, glass.size.y - 6), Color("87bdbd"), 2)
		world.draw_circle(rect.position + Vector2(11, 92), 2.5, Color("a0e4be"))
		world.draw_string(ThemeDB.fallback_font, rect.position + Vector2(20, 95), ["BIO", "BOT", "CAT"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e1eeea"))
