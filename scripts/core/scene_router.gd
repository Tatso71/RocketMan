extends Node

signal scene_changed(scene_path: String)

func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
	scene_changed.emit(scene_path)
