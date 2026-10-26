extends SceneTree

func _initialize() -> void:
	var failures: int = 0
	var checked: int = 0
	for filename in DirAccess.get_files_at("res://assets/design/materials"):
		if not filename.ends_with(".tres"):
			continue
		var material: StandardMaterial3D = load("res://assets/design/materials/" + filename) as StandardMaterial3D
		if material == null:
			push_error("Invalid StandardMaterial3D: " + filename)
			failures += 1
			continue
		if material.albedo_texture == null:
			push_error("Missing albedo texture: " + filename)
			failures += 1
			continue
		if material.albedo_texture.get_width() != 256:
			push_error("Unexpected texture size: " + filename)
			failures += 1
		checked += 1
	print("DESIGN_MATERIALS_CHECK checked=", checked, " failures=", failures)
	quit(1 if failures > 0 else 0)
