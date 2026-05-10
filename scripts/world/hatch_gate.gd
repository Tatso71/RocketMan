extends StaticBody2D

@export var destination_scene: String

func interact() -> void:
	SceneRouter.go_to(destination_scene)
